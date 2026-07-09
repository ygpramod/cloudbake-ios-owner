import Foundation

@MainActor
final class InventoryNavigationRouter: ObservableObject {
    @Published private(set) var pendingInventoryItemId: String?

    func openInventoryItem(id: String) {
        pendingInventoryItemId = id
    }

    func consumePendingInventoryItemId() -> String? {
        defer {
            pendingInventoryItemId = nil
        }

        return pendingInventoryItemId
    }
}
