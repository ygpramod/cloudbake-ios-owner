import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var lowInventoryItems: [InventoryItem] = []
    @Published private(set) var upcomingOrders: [Order] = []
    @Published private(set) var upcomingOrderCount = 0
    @Published private(set) var overdueOrderAlert: OrderOverdueAlert?
    @Published private(set) var projectedIngredientShortages: [String: ProjectedIngredientShortage] = [:]
    @Published var errorMessage: String?

    var displayedLowInventoryItems: [InventoryItem] {
        Array(lowInventoryItems.prefix(3))
    }

    var additionalLowInventoryCount: Int {
        max(lowInventoryItems.count - displayedLowInventoryItems.count, 0)
    }

    var nextUpcomingOrder: Order? {
        upcomingOrders.first
    }

    func lowInventoryDetail(for item: InventoryItem) -> String {
        if let shortage = projectedIngredientShortages[item.id] {
            return "\(shortage.availableQuantity.formatted()) usable / \(shortage.requiredQuantity.formatted()) needed \(shortage.unit.displayName)"
        }

        if item.hasExpiredStock { return "Expired stock" }
        if item.hasExpiringSoonStock { return "Expiring soon" }
        return "\(item.currentQuantity.formatted()) / \(item.minimumQuantity.formatted()) \(item.unit.displayName)"
    }

    private let repository: any InventoryItemRepository & OrderRepository & ProjectedIngredientDemandRepository
    private let orderPresentation: OrderListPresentation

    init(
        repository: any InventoryItemRepository & OrderRepository & ProjectedIngredientDemandRepository,
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
            let inventoryItems = try repository.fetchInventoryItems()
            let now = orderPresentation.dateProvider()
            let upcomingPage: OrderPage
            let upcomingCount: Int
            if let range = orderPresentation.upcomingDateRange() {
                let query = OrderPageQuery.upcoming(
                    from: range.lowerBound,
                    through: range.upperBound
                )
                upcomingPage = try repository.fetchOrderPage(
                    query: query,
                    after: nil,
                    limit: 25
                )
                upcomingCount = try repository.fetchOrderCount(query: query)
            } else {
                upcomingPage = OrderPage(orders: [], nextCursor: nil)
                upcomingCount = 0
            }
            let earliestActivePage = try repository.fetchOrderPage(
                query: .active(dueAtRange: nil),
                after: nil,
                limit: 1
            )
            let demandSummary = try repository.fetchProjectedIngredientDemandSummary(at: now)
            let shortages = demandSummary.shortages
            projectedIngredientShortages = Dictionary(uniqueKeysWithValues: shortages.map { ($0.id, $0) })
            lowInventoryItems = InventoryLowInventoryAlertRules.itemsForAlerts(
                inventoryItems: inventoryItems,
                neededInventoryItemIds: demandSummary.neededInventoryItemIds,
                projectedShortageIds: Set(shortages.map(\.inventoryItemId))
            )
            upcomingOrders = upcomingPage.orders
            upcomingOrderCount = upcomingCount
            overdueOrderAlert = orderPresentation.primaryOverdueAlert(
                from: earliestActivePage.orders
            )
            errorMessage = nil
        } catch {
            lowInventoryItems = []
            projectedIngredientShortages = [:]
            upcomingOrders = []
            upcomingOrderCount = 0
            overdueOrderAlert = nil
            errorMessage = "Low inventory could not be loaded."
        }
    }
}
