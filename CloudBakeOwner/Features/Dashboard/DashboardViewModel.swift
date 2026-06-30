import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var lowInventoryItems: [InventoryItem] = []
    @Published var errorMessage: String?

    private let repository: any InventoryItemRepository

    init(repository: any InventoryItemRepository) {
        self.repository = repository
    }

    func load() {
        do {
            lowInventoryItems = try repository.fetchInventoryItems().filter(\.isLowStock)
            errorMessage = nil
        } catch {
            lowInventoryItems = []
            errorMessage = "Low inventory could not be loaded."
        }
    }
}
