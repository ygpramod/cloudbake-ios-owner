import Foundation

@MainActor
final class InventoryListViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    @Published var draftName = ""
    @Published var draftUnit: InventoryUnit = .gram
    @Published var draftCurrentQuantity = ""
    @Published var draftMinimumQuantity = ""
    @Published var errorMessage: String?
    @Published var duplicateWarningMessage: String?
    @Published private(set) var editingItem: InventoryItem?

    private let repository: any InventoryItemRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date
    private var acknowledgedDuplicateNameKey: String?

    init(
        repository: any InventoryItemRepository,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    func load() {
        do {
            items = try repository.fetchInventoryItems()
            errorMessage = nil
        } catch {
            errorMessage = "Inventory could not be loaded."
        }
    }

    func addItem() -> Bool {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Inventory item name is required."
            duplicateWarningMessage = nil
            return false
        }

        if shouldWarnAboutDuplicate(
            named: name,
            excludingItemId: nil,
            warningMessage: { "Possible duplicate: \($0.name) already exists. Tap Save again to add a separate item." }
        ) {
            return false
        }

        guard let quantities = validatedDraftQuantities() else {
            return false
        }

        let now = dateProvider()
        let item = InventoryItem(
            id: idGenerator(),
            name: name,
            unit: draftUnit,
            currentQuantity: quantities.current,
            minimumQuantity: quantities.minimum,
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.save(item)
            resetDraft()
            load()
            return true
        } catch {
            errorMessage = "Inventory item could not be saved."
            return false
        }
    }

    func beginEditing(_ item: InventoryItem) {
        editingItem = item
        draftName = item.name
        draftUnit = item.unit
        draftCurrentQuantity = item.currentQuantity.formatted()
        draftMinimumQuantity = item.minimumQuantity.formatted()
        errorMessage = nil
        duplicateWarningMessage = nil
        acknowledgedDuplicateNameKey = nil
    }

    func saveEditedItem() -> Bool {
        guard let editingItem else {
            errorMessage = "Inventory item could not be found."
            duplicateWarningMessage = nil
            return false
        }

        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Inventory item name is required."
            duplicateWarningMessage = nil
            return false
        }

        if shouldWarnAboutDuplicate(
            named: name,
            excludingItemId: editingItem.id,
            warningMessage: { "Possible duplicate: \($0.name) already exists. Tap Save again to keep this item separate." }
        ) {
            return false
        }

        guard let quantities = validatedDraftQuantities() else {
            return false
        }

        let item = InventoryItem(
            id: editingItem.id,
            name: name,
            unit: draftUnit,
            currentQuantity: quantities.current,
            minimumQuantity: quantities.minimum,
            createdAt: editingItem.createdAt,
            updatedAt: dateProvider()
        )

        do {
            try repository.save(item)
            resetDraft()
            load()
            return true
        } catch {
            errorMessage = "Inventory item could not be saved."
            return false
        }
    }

    func cancelEditing() {
        resetDraft()
    }

    func archiveItem(_ item: InventoryItem) {
        let now = dateProvider()
        let archivedItem = InventoryItem(
            id: item.id,
            name: item.name,
            unit: item.unit,
            currentQuantity: item.currentQuantity,
            minimumQuantity: item.minimumQuantity,
            createdAt: item.createdAt,
            updatedAt: now,
            archivedAt: now
        )

        do {
            try repository.save(archivedItem)
            load()
        } catch {
            errorMessage = "Inventory item could not be archived."
        }
    }

    private func shouldWarnAboutDuplicate(
        named name: String,
        excludingItemId: String?,
        warningMessage: (InventoryItem) -> String
    ) -> Bool {
        let nameKey = duplicateKey(for: name)
        if acknowledgedDuplicateNameKey != nameKey,
           let matchingItem = matchingInventoryItem(for: name, nameKey: nameKey, excludingItemId: excludingItemId) {
            duplicateWarningMessage = warningMessage(matchingItem)
            errorMessage = nil
            acknowledgedDuplicateNameKey = nameKey
            return true
        }

        return false
    }

    private func validatedDraftQuantities() -> (current: Double, minimum: Double)? {
        let minimumQuantityText = draftMinimumQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let minimumQuantity = Double(minimumQuantityText) ?? 0
        guard minimumQuantity >= 0 else {
            errorMessage = "Minimum quantity cannot be negative."
            duplicateWarningMessage = nil
            return nil
        }

        let currentQuantityText = draftCurrentQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentQuantity = Double(currentQuantityText) ?? 0
        guard currentQuantity >= 0 else {
            errorMessage = "Current quantity cannot be negative."
            duplicateWarningMessage = nil
            return nil
        }

        return (current: currentQuantity, minimum: minimumQuantity)
    }

    private func resetDraft() {
        draftName = ""
        draftUnit = .gram
        draftCurrentQuantity = ""
        draftMinimumQuantity = ""
        errorMessage = nil
        duplicateWarningMessage = nil
        acknowledgedDuplicateNameKey = nil
        editingItem = nil
    }

    private func matchingInventoryItem(for name: String, nameKey: String, excludingItemId: String?) -> InventoryItem? {
        items.first { item in
            if item.id == excludingItemId {
                return false
            }

            let existingKey = duplicateKey(for: item.name)
            return existingKey == nameKey || existingKey.contains(nameKey) || nameKey.contains(existingKey)
        }
    }

    private func duplicateKey(for name: String) -> String {
        name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { token in
                if token.count > 3, token.hasSuffix("s") {
                    return String(token.dropLast())
                }
                return token
            }
            .joined(separator: " ")
    }
}
