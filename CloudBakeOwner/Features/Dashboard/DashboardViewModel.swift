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

    private let repository: any InventoryItemRepository & InventoryStockBatchRepository & OrderRepository & OrderRecipeUsageRepository & RecipeComponentRepository & RecipeIngredientRepository & OrderExtraIngredientRepository
    private let orderPresentation: OrderListPresentation

    init(
        repository: any InventoryItemRepository & InventoryStockBatchRepository & OrderRepository & OrderRecipeUsageRepository & RecipeComponentRepository & RecipeIngredientRepository & OrderExtraIngredientRepository,
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
            let shortages = try ProjectedIngredientDemand.shortages(
                inventoryItems: inventoryItems,
                orders: orders,
                at: now,
                stockBatches: repository.fetchInventoryStockBatches(inventoryItemId:),
                recipeUsage: repository.fetchOrderRecipeUsage(orderId:),
                recipeComponents: repository.fetchRecipeComponents(recipeId:),
                recipeIngredients: repository.fetchRecipeIngredients(componentId:),
                orderExtraIngredients: repository.fetchOrderExtraIngredients(orderId:)
            )
            projectedIngredientShortages = Dictionary(uniqueKeysWithValues: shortages.map { ($0.id, $0) })
            lowInventoryItems = try InventoryLowInventoryAlertRules.itemsForAlerts(
                inventoryItems: inventoryItems,
                activeOrders: orders,
                date: now,
                inventoryStockBatches: repository.fetchInventoryStockBatches(inventoryItemId:),
                orderRecipeUsage: repository.fetchOrderRecipeUsage(orderId:),
                recipeComponents: repository.fetchRecipeComponents(recipeId:),
                recipeIngredients: repository.fetchRecipeIngredients(componentId:),
                orderExtraIngredients: repository.fetchOrderExtraIngredients(orderId:)
            )
            upcomingOrders = orderPresentation.activeOrders(from: orders)
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
