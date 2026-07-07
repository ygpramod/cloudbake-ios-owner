import Foundation

@MainActor
final class CustomerListViewModel: ObservableObject {
    @Published private(set) var customers: [Customer] = []
    @Published private(set) var selectedCustomer: Customer?
    @Published private(set) var selectedCustomerImportantDates: [CustomerImportantDate] = []
    @Published private(set) var selectedCustomerOrders: [Order] = []
    @Published private(set) var editingCustomer: Customer?
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
        let name = TextInputFormatting.trimmed(draftName)
        guard !name.isEmpty else {
            errorMessage = "Customer name is required."
            duplicateWarningMessage = nil
            return false
        }

        let phone = TextInputFormatting.trimmed(draftPhone)
        guard !phone.isEmpty else {
            errorMessage = "Customer phone is required."
            duplicateWarningMessage = nil
            return false
        }

        if shouldWarnAboutDuplicate(
            name: name,
            phone: phone,
            excludingCustomerId: nil,
            confirmationInstruction: "Tap Save again to add a separate customer."
        ) {
            return false
        }

        let importantDateLabel = TextInputFormatting.trimmed(draftImportantDateLabel)
        let now = dateProvider()
        let customer = Customer(
            id: idGenerator(),
            name: name,
            phone: phone,
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

        let name = TextInputFormatting.trimmed(draftName)
        guard !name.isEmpty else {
            errorMessage = "Customer name is required."
            duplicateWarningMessage = nil
            return false
        }

        let phone = TextInputFormatting.trimmed(draftPhone)
        guard !phone.isEmpty else {
            errorMessage = "Customer phone is required."
            duplicateWarningMessage = nil
            return false
        }

        if shouldWarnAboutDuplicate(
            name: name,
            phone: phone,
            excludingCustomerId: editingCustomer.id,
            confirmationInstruction: "Tap Save again to keep this customer separate."
        ) {
            return false
        }

        let customer = Customer(
            id: editingCustomer.id,
            name: name,
            phone: phone,
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

}
