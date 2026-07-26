import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var lowInventoryItems: [InventoryItem] = []
    @Published private(set) var upcomingOrders: [Order] = []
    @Published private(set) var overdueOrderAlert: OrderOverdueAlert?
    @Published private(set) var projectedIngredientShortages: [String: ProjectedIngredientShortage] = [:]
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

    func lowInventoryDetail(for item: InventoryItem) -> String {
        if let shortage = projectedIngredientShortages[item.id] {
            return "\(shortage.availableQuantity.formatted()) usable / \(shortage.requiredQuantity.formatted()) needed \(shortage.unit.displayName)"
        }

        if item.hasExpiredStock { return "Expired stock" }
        if item.hasExpiringSoonStock { return "Expiring soon" }
        return "\(item.currentQuantity.formatted()) / \(item.minimumQuantity.formatted()) \(item.unit.displayName)"
    }

    private let repository: any InventoryItemRepository & InventoryStockBatchRepository & OrderRepository & OrderRecipeUsageRepository & OrderInventoryReservationRepository & RecipeComponentRepository & RecipeIngredientRepository & OrderExtraIngredientRepository
    private let orderPresentation: OrderListPresentation

    init(
        repository: any InventoryItemRepository & InventoryStockBatchRepository & OrderRepository & OrderRecipeUsageRepository & OrderInventoryReservationRepository & RecipeComponentRepository & RecipeIngredientRepository & OrderExtraIngredientRepository,
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
            let orders = try repository.fetchOrders()
            let inventoryItems = try repository.fetchInventoryItems()
            let now = orderPresentation.dateProvider()
            let activeOrders = orders.filter(\.hasActiveReminderState)
            let planningSnapshot = try repository.fetchOrderInventoryReservationPlanningSnapshot(
                orderIds: activeOrders.map(\.id)
            )
            let demandSummary = ProjectedIngredientDemand.summary(
                inventoryItems: inventoryItems,
                orders: activeOrders,
                at: now,
                planningSnapshot: planningSnapshot
            )
            let shortages = demandSummary.shortages
            projectedIngredientShortages = Dictionary(uniqueKeysWithValues: shortages.map { ($0.id, $0) })
            lowInventoryItems = InventoryLowInventoryAlertRules.itemsForAlerts(
                inventoryItems: inventoryItems,
                neededInventoryItemIds: demandSummary.neededInventoryItemIds,
                projectedShortageIds: Set(shortages.map(\.inventoryItemId))
            )
            upcomingOrders = orderPresentation.upcomingOrders(from: orders)
            overdueOrderAlert = orderPresentation.primaryOverdueAlert(from: orders)
            errorMessage = nil
        } catch {
            lowInventoryItems = []
            projectedIngredientShortages = [:]
            upcomingOrders = []
            overdueOrderAlert = nil
            errorMessage = "Low inventory could not be loaded."
        }
    }
}
