import Foundation

@MainActor
final class OrderNavigationRouter: ObservableObject {
    @Published private(set) var pendingNewOrderCustomerId: String?

    func beginNewOrder(customerId: String) {
        pendingNewOrderCustomerId = customerId
    }

    func clearPendingNewOrder() {
        pendingNewOrderCustomerId = nil
    }
}
