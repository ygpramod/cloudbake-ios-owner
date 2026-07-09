import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var lowInventoryItems: [InventoryItem] = []
    @Published private(set) var upcomingOrders: [Order] = []
    @Published private(set) var overdueOrderAlert: OrderOverdueAlert?
    @Published var errorMessage: String?

    var displayedLowInventoryItems: [InventoryItem] {
        Array(lowInventoryItems.prefix(3))
    }

    var additionalLowInventoryCount: Int {
        max(lowInventoryItems.count - displayedLowInventoryItems.count, 0)
    }

    var upcomingOrderCount: Int {
        upcomingOrders.count
    }

    var nextUpcomingOrder: Order? {
        upcomingOrders.first
    }

    private let repository: any InventoryItemRepository & OrderRepository
    private let orderPresentation: OrderListPresentation

    init(
        repository: any InventoryItemRepository & OrderRepository,
        orderPresentation: OrderListPresentation = OrderListPresentation(
            dateProvider: Date.init,
            calendar: .current
        )
    ) {
        self.repository = repository
        self.orderPresentation = orderPresentation
    }

    func load() {
        do {
            lowInventoryItems = try repository.fetchInventoryItems().filter(\.isLowStock)
            let orders = try repository.fetchOrders()
            upcomingOrders = orderPresentation.activeOrders(from: orders)
            overdueOrderAlert = orderPresentation.primaryOverdueAlert(from: orders)
            errorMessage = nil
        } catch {
            lowInventoryItems = []
            upcomingOrders = []
            overdueOrderAlert = nil
            errorMessage = "Low inventory could not be loaded."
        }
    }
}
