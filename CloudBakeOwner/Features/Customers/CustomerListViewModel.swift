import Foundation

@MainActor
final class CustomerListViewModel: ObservableObject {
    @Published private(set) var customers: [Customer] = []
    @Published private(set) var selectedCustomer: Customer?
    @Published private(set) var selectedCustomerImportantDates: [CustomerImportantDate] = []
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

    private let repository: any CustomerRepository & CustomerImportantDateRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date
    private var acknowledgedDuplicateKey: String?

    init(
        repository: any CustomerRepository & CustomerImportantDateRepository,
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
        loadSelectedCustomerImportantDates()
    }

    func closeCustomerDetail() {
        selectedCustomer = nil
        selectedCustomerImportantDates = []
        errorMessage = nil
    }

    func addCustomer() -> Bool {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Customer name is required."
            duplicateWarningMessage = nil
            return false
        }

        let phone = draftPhone.trimmingCharacters(in: .whitespacesAndNewlines)
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

        let importantDateLabel = draftImportantDateLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = dateProvider()
        let customer = Customer(
            id: idGenerator(),
            name: name,
            phone: phone,
            email: optionalText(draftEmail),
            address: optionalText(draftAddress),
            likes: optionalText(draftLikes),
            dislikes: optionalText(draftDislikes),
            allergies: optionalText(draftAllergies),
            dietaryRestrictions: optionalText(draftDietaryRestrictions),
            notes: optionalText(draftNotes),
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

        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Customer name is required."
            duplicateWarningMessage = nil
            return false
        }

        let phone = draftPhone.trimmingCharacters(in: .whitespacesAndNewlines)
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
            email: optionalText(draftEmail),
            address: optionalText(draftAddress),
            likes: optionalText(draftLikes),
            dislikes: optionalText(draftDislikes),
            allergies: optionalText(draftAllergies),
            dietaryRestrictions: optionalText(draftDietaryRestrictions),
            notes: optionalText(draftNotes),
            createdAt: editingCustomer.createdAt,
            updatedAt: dateProvider()
        )

        do {
            try repository.save(customer)
            selectedCustomer = customer
            resetDraft()
            load()
            loadSelectedCustomerImportantDates()
            return true
        } catch {
            errorMessage = "Customer could not be saved."
            return false
        }
    }

    func cancelEditingCustomer() {
        resetDraft()
    }

    private func loadSelectedCustomerImportantDates() {
        guard let selectedCustomer else {
            selectedCustomerImportantDates = []
            return
        }

        do {
            selectedCustomerImportantDates = try repository.fetchCustomerImportantDates(customerId: selectedCustomer.id)
            errorMessage = nil
        } catch {
            selectedCustomerImportantDates = []
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

            return normalizedPhone(customer.phone) == normalizedPhone(phone)
                || normalizedText(customer.name) == normalizedText(name)
                || normalizedText(customer.name).contains(normalizedText(name))
                || normalizedText(name).contains(normalizedText(customer.name))
        }

        guard let duplicate else {
            duplicateWarningMessage = nil
            acknowledgedDuplicateKey = nil
            return false
        }

        let warningKey = "\(normalizedText(name))|\(normalizedPhone(phone))"
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

    private func optionalText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func normalizedPhone(_ phone: String) -> String {
        phone.filter(\.isNumber)
    }
}
