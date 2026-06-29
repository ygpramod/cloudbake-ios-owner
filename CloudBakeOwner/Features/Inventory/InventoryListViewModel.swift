import Foundation

@MainActor
final class InventoryListViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    @Published var draftName = ""
    @Published var draftUnit: InventoryUnit = .gram
    @Published var draftMinimumQuantity = ""
    @Published var errorMessage: String?

    private let repository: any InventoryItemRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date

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
            return false
        }

        let minimumQuantityText = draftMinimumQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let minimumQuantity = Double(minimumQuantityText) ?? 0
        guard minimumQuantity >= 0 else {
            errorMessage = "Minimum quantity cannot be negative."
            return false
        }

        let now = dateProvider()
        let item = InventoryItem(
            id: idGenerator(),
            name: name,
            unit: draftUnit,
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
        draftMinimumQuantity = ""
        errorMessage = nil
    }
}
