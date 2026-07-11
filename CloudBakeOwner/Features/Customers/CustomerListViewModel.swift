import Foundation

struct CustomerPresentation: Equatable {
    let customer: Customer
    let displayPhone: String
    let canCall: Bool
    let canMessage: Bool

    var hasSafetyNotes: Bool {
        customer.allergies?.isEmpty == false || customer.dietaryRestrictions?.isEmpty == false
    }
}

@MainActor
final class CustomerListViewModel: ObservableObject {
    @Published private(set) var customers: [Customer] = []
    @Published private(set) var selectedCustomer: Customer?
    @Published private(set) var selectedCustomerImportantDates: [CustomerImportantDate] = []
    @Published private(set) var selectedCustomerOrders: [Order] = []
    @Published private(set) var editingCustomer: Customer?
    @Published private(set) var lastSavedCustomer: Customer?
    @Published var draftName = ""
    @Published var draftPhone = ""
    @Published var draftEmail = ""
    @Published var draftAddress = ""
    @Published var draftLikes = ""
    @Published var draftDislikes = ""
    @Published var draftAllergies = ""
    @Published var draftDietaryRestrictions = ""
    @Published var draftNotes = ""
    @Published var draftImportantDateLabel = ""
    @Published var draftImportantDate = Date()
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var duplicateWarningMessage: String?

    private let repository: any CustomerRepository & CustomerImportantDateRepository & OrderRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date
    private var acknowledgedDuplicateKey: String?

    init(
        repository: any CustomerRepository & CustomerImportantDateRepository & OrderRepository,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    func load() {
        do {
            customers = try repository.fetchCustomers()
            errorMessage = nil
        } catch {
            errorMessage = "Customers could not be loaded."
        }
    }

    var visibleCustomers: [Customer] {
        let query = TextInputFormatting.normalizedSearchKey(searchText)
        guard !query.isEmpty else {
            return customers
        }

        return customers.filter { customer in
            [
                customer.name,
                customer.phone,
                Self.formattedPhone(customer.phone),
                customer.email,
                customer.address,
                customer.likes,
                customer.dislikes,
                customer.allergies,
                customer.dietaryRestrictions,
                customer.notes
            ]
            .compactMap { $0 }
            .map(TextInputFormatting.normalizedSearchKey)
            .contains { $0.contains(query) }
        }
    }

    func presentation(for customer: Customer) -> CustomerPresentation {
        CustomerPresentation(
            customer: customer,
            displayPhone: Self.formattedPhone(customer.phone),
            canCall: Self.isSupportedPhone(customer.phone),
            canMessage: Self.isSupportedPhone(customer.phone)
        )
    }

    func phoneURL(for customer: Customer) -> URL? {
        guard Self.isSupportedPhone(customer.phone) else {
            return nil
        }

        return URL(string: "tel://\(Self.callablePhone(customer.phone))")
    }

    func whatsappMessageURL(for customer: Customer) -> URL? {
        guard Self.isSupportedPhone(customer.phone) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "whatsapp"
        components.host = "send"
        components.queryItems = [
            URLQueryItem(name: "phone", value: TextInputFormatting.digitsOnly(customer.phone)),
            URLQueryItem(name: "text", value: "Hi \(Self.firstName(from: customer.name)), ")
        ]
        return components.url
    }

    func beginViewingCustomer(_ customer: Customer) {
        selectedCustomer = customer
        loadSelectedCustomerDetails()
    }

    func closeCustomerDetail() {
        selectedCustomer = nil
        selectedCustomerImportantDates = []
        selectedCustomerOrders = []
        errorMessage = nil
    }

    func beginAddingCustomer(importedDraft: CustomerContactDraft? = nil) {
        resetDraft()
        errorMessage = nil
        duplicateWarningMessage = nil
        acknowledgedDuplicateKey = nil
        lastSavedCustomer = nil

        guard let importedDraft else {
            return
        }

        draftName = importedDraft.name
        draftPhone = importedDraft.phone
        draftEmail = importedDraft.email
        draftAddress = importedDraft.address
        draftImportantDateLabel = importedDraft.importantDateLabel
        if let importantDate = importedDraft.importantDate {
            draftImportantDate = importantDate
        }
    }

    func addCustomer() -> Bool {
        guard let draft = validatedDraft() else {
            return false
        }

        if shouldWarnAboutDuplicate(
            name: draft.name,
            phone: draft.phone,
            excludingCustomerId: nil,
            confirmationInstruction: "Tap Save again to add a separate customer."
        ) {
            return false
        }

        let importantDateLabel = TextInputFormatting.trimmed(draftImportantDateLabel)
        let now = dateProvider()
        let customer = Customer(
            id: idGenerator(),
            name: draft.name,
            phone: draft.phone,
            email: TextInputFormatting.optionalText(draftEmail),
            address: TextInputFormatting.optionalText(draftAddress),
            likes: TextInputFormatting.optionalText(draftLikes),
            dislikes: TextInputFormatting.optionalText(draftDislikes),
            allergies: TextInputFormatting.optionalText(draftAllergies),
            dietaryRestrictions: TextInputFormatting.optionalText(draftDietaryRestrictions),
            notes: TextInputFormatting.optionalText(draftNotes),
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.save(customer)
            if !importantDateLabel.isEmpty {
                try repository.save(
                    CustomerImportantDate(
                        id: idGenerator(),
                        customerId: customer.id,
                        label: importantDateLabel,
                        date: draftImportantDate,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            }
            lastSavedCustomer = customer
            resetDraft()
            load()
            return true
        } catch {
            errorMessage = "Customer could not be saved."
            return false
        }
    }

    func cancelAddCustomer() {
        resetDraft()
        errorMessage = nil
        duplicateWarningMessage = nil
    }

    func beginEditingCustomer() {
        guard let selectedCustomer else {
            errorMessage = "Customer could not be found."
            return
        }

        editingCustomer = selectedCustomer
        draftName = selectedCustomer.name
        draftPhone = selectedCustomer.phone
        draftEmail = selectedCustomer.email ?? ""
        draftAddress = selectedCustomer.address ?? ""
        draftLikes = selectedCustomer.likes ?? ""
        draftDislikes = selectedCustomer.dislikes ?? ""
        draftAllergies = selectedCustomer.allergies ?? ""
        draftDietaryRestrictions = selectedCustomer.dietaryRestrictions ?? ""
        draftNotes = selectedCustomer.notes ?? ""
        draftImportantDateLabel = ""
        draftImportantDate = dateProvider()
        errorMessage = nil
        duplicateWarningMessage = nil
        acknowledgedDuplicateKey = nil
    }

    func saveEditedCustomer() -> Bool {
        guard let editingCustomer else {
            errorMessage = "Customer could not be found."
            duplicateWarningMessage = nil
            return false
        }

        guard let draft = validatedDraft() else {
            return false
        }

        if shouldWarnAboutDuplicate(
            name: draft.name,
            phone: draft.phone,
            excludingCustomerId: editingCustomer.id,
            confirmationInstruction: "Tap Save again to keep this customer separate."
        ) {
            return false
        }

        let customer = Customer(
            id: editingCustomer.id,
            name: draft.name,
            phone: draft.phone,
            email: TextInputFormatting.optionalText(draftEmail),
            address: TextInputFormatting.optionalText(draftAddress),
            likes: TextInputFormatting.optionalText(draftLikes),
            dislikes: TextInputFormatting.optionalText(draftDislikes),
            allergies: TextInputFormatting.optionalText(draftAllergies),
            dietaryRestrictions: TextInputFormatting.optionalText(draftDietaryRestrictions),
            notes: TextInputFormatting.optionalText(draftNotes),
            createdAt: editingCustomer.createdAt,
            updatedAt: dateProvider()
        )

        do {
            try repository.save(customer)
            selectedCustomer = customer
            lastSavedCustomer = customer
            resetDraft()
            load()
            loadSelectedCustomerDetails()
            return true
        } catch {
            errorMessage = "Customer could not be saved."
            return false
        }
    }

    func cancelEditingCustomer() {
        resetDraft()
    }

    func deleteSelectedCustomer() -> Bool {
        guard let selectedCustomer else {
            errorMessage = "Customer could not be found."
            return false
        }

        do {
            try repository.deleteCustomer(id: selectedCustomer.id)
            closeCustomerDetail()
            load()
            return true
        } catch {
            errorMessage = "Customer could not be deleted."
            return false
        }
    }

    private func loadSelectedCustomerDetails() {
        guard let selectedCustomer else {
            selectedCustomerImportantDates = []
            selectedCustomerOrders = []
            return
        }

        do {
            selectedCustomerImportantDates = try repository.fetchCustomerImportantDates(customerId: selectedCustomer.id)
            selectedCustomerOrders = try repository.fetchOrders()
                .filter { $0.customerId == selectedCustomer.id }
                .sorted { lhs, rhs in
                    lhs.dueAt == rhs.dueAt ? lhs.title < rhs.title : lhs.dueAt < rhs.dueAt
                }
            errorMessage = nil
        } catch {
            selectedCustomerImportantDates = []
            selectedCustomerOrders = []
            errorMessage = "Customer details could not be loaded."
        }
    }

    private func validatedDraft() -> ValidatedCustomerDraft? {
        switch CustomerDraftValidation.validate(
            CustomerDraftValidationInput(
                name: draftName,
                phone: draftPhone
            )
        ) {
        case .success(let draft):
            return draft
        case .failure(let error):
            errorMessage = error.message
            duplicateWarningMessage = nil
            return nil
        }
    }

    private func shouldWarnAboutDuplicate(
        name: String,
        phone: String,
        excludingCustomerId: String?,
        confirmationInstruction: String
    ) -> Bool {
        let duplicate = customers.first { customer in
            guard customer.id != excludingCustomerId else {
                return false
            }

            let customerPhone = TextInputFormatting.digitsOnly(customer.phone)
            let draftPhone = TextInputFormatting.digitsOnly(phone)
            let customerName = TextInputFormatting.normalizedSearchKey(customer.name)
            let draftName = TextInputFormatting.normalizedSearchKey(name)

            return customerPhone == draftPhone
                || customerName == draftName
                || customerName.contains(draftName)
                || draftName.contains(customerName)
        }

        guard let duplicate else {
            duplicateWarningMessage = nil
            acknowledgedDuplicateKey = nil
            return false
        }

        let warningKey = "\(TextInputFormatting.normalizedSearchKey(name))|\(TextInputFormatting.digitsOnly(phone))"
        guard acknowledgedDuplicateKey != warningKey else {
            duplicateWarningMessage = nil
            return false
        }

        duplicateWarningMessage = "Possible duplicate: \(duplicate.name) already exists. \(confirmationInstruction)"
        errorMessage = nil
        acknowledgedDuplicateKey = warningKey
        return true
    }

    private func resetDraft() {
        draftName = ""
        draftPhone = ""
        draftEmail = ""
        draftAddress = ""
        draftLikes = ""
        draftDislikes = ""
        draftAllergies = ""
        draftDietaryRestrictions = ""
        draftNotes = ""
        draftImportantDateLabel = ""
        draftImportantDate = dateProvider()
        editingCustomer = nil
        errorMessage = nil
        duplicateWarningMessage = nil
        acknowledgedDuplicateKey = nil
    }

    private static func formattedPhone(_ phone: String) -> String {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = TextInputFormatting.digitsOnly(trimmed)

        guard !digits.isEmpty else {
            return trimmed
        }

        if trimmed.hasPrefix("+"), digits.count >= 9 {
            let countryCodeLength = max(1, digits.count - 8)
            let countryCode = digits.prefix(countryCodeLength)
            let local = digits.suffix(8)
            return "+\(countryCode) \(local.prefix(4)) \(local.suffix(4))"
        }

        switch digits.count {
        case 7:
            return "\(digits.prefix(3))-\(digits.suffix(4))"
        case 8:
            return "\(digits.prefix(4)) \(digits.suffix(4))"
        case 10:
            let area = digits.prefix(3)
            let middleStart = digits.index(digits.startIndex, offsetBy: 3)
            let middleEnd = digits.index(middleStart, offsetBy: 3)
            return "(\(area)) \(digits[middleStart..<middleEnd])-\(digits.suffix(4))"
        default:
            return trimmed
        }
    }

    private static func isSupportedPhone(_ phone: String) -> Bool {
        TextInputFormatting.digitsOnly(phone).count >= 7
    }

    private static func callablePhone(_ phone: String) -> String {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = TextInputFormatting.digitsOnly(trimmed)
        return trimmed.hasPrefix("+") ? "+\(digits)" : digits
    }

    private static func firstName(from name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? name
    }

}
