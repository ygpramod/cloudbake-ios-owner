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

        let nameKey = duplicateKey(for: name)
        if acknowledgedDuplicateNameKey != nameKey,
           let matchingItem = matchingInventoryItem(for: name, nameKey: nameKey) {
            duplicateWarningMessage = "Possible duplicate: \(matchingItem.name) already exists. Tap Save again to add a separate item."
            errorMessage = nil
            acknowledgedDuplicateNameKey = nameKey
            return false
        }

        let minimumQuantityText = draftMinimumQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let minimumQuantity = Double(minimumQuantityText) ?? 0
        guard minimumQuantity >= 0 else {
            errorMessage = "Minimum quantity cannot be negative."
            duplicateWarningMessage = nil
            return false
        }

        let currentQuantityText = draftCurrentQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentQuantity = Double(currentQuantityText) ?? 0
        guard currentQuantity >= 0 else {
            errorMessage = "Current quantity cannot be negative."
            duplicateWarningMessage = nil
            return false
        }

        let now = dateProvider()
        let item = InventoryItem(
            id: idGenerator(),
            name: name,
            unit: draftUnit,
            currentQuantity: currentQuantity,
            minimumQuantity: minimumQuantity,
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

    private func resetDraft() {
        draftName = ""
        draftUnit = .gram
        draftCurrentQuantity = ""
        draftMinimumQuantity = ""
        errorMessage = nil
        duplicateWarningMessage = nil
        acknowledgedDuplicateNameKey = nil
    }

    private func matchingInventoryItem(for name: String, nameKey: String) -> InventoryItem? {
        items.first { item in
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
