import XCTest
@testable import CloudBakeOwner

@MainActor
final class DashboardViewModelTests: XCTestCase {
    func testLoadShowsOnlyLowInventoryItems() {
        let repository = FakeDashboardInventoryItemRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_040_000)
        let lowItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let healthyItem = InventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.items = [healthyItem, lowItem]
        let viewModel = DashboardViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.lowInventoryItems, [lowItem])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLowInventoryDisplayLimitsToThreeItemsAndCountsAdditionalAlerts() {
        let repository = FakeDashboardInventoryItemRepository()
        let lowItems = (1...4).map { index in
            makeInventoryItem(
                id: "inventory-low-\(index)",
                name: "Low item \(index)",
                currentQuantity: Double(index),
                minimumQuantity: 10
            )
        }
        repository.items = lowItems
        let viewModel = DashboardViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.displayedLowInventoryItems, Array(lowItems.prefix(3)))
        XCTAssertEqual(viewModel.additionalLowInventoryCount, 1)
    }

    func testLoadDoesNotShowArchivedLowInventoryItems() {
        let repository = FakeDashboardInventoryItemRepository()
        repository.items = [
            makeInventoryItem(
                id: "inventory-archived-low",
                name: "Archived low item",
                currentQuantity: 1,
                minimumQuantity: 10,
                archivedAt: Date(timeIntervalSince1970: 1_800_040_100)
            )
        ]
        let viewModel = DashboardViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.lowInventoryItems, [])
    }

    func testLoadShowsExpiredInventoryItemsEvenWhenQuantityIsAboveMinimum() {
        let repository = FakeDashboardInventoryItemRepository()
        let expiredItem = makeInventoryItem(
            id: "inventory-expired-flour",
            name: "Expired flour",
            currentQuantity: 900,
            minimumQuantity: 500,
            hasExpiredStock: true
        )
        repository.items = [expiredItem]
        let viewModel = DashboardViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.lowInventoryItems, [expiredItem])
    }

    func testLoadShowsSoonExpiringInventoryItemsEvenWhenQuantityIsAboveMinimum() {
        let repository = FakeDashboardInventoryItemRepository()
        let expiringSoonItem = makeInventoryItem(
            id: "inventory-expiring-butter",
            name: "Expiring butter",
            currentQuantity: 900,
            minimumQuantity: 500,
            hasExpiringSoonStock: true
        )
        repository.items = [expiringSoonItem]
        let viewModel = DashboardViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.lowInventoryItems, [expiringSoonItem])
    }

    func testLoadSuppressesPerishableLowInventoryWhenNoActiveOrderNeedsIt() {
        let repository = FakeDashboardInventoryItemRepository()
        let fruit = makeInventoryItem(
            id: "inventory-strawberry",
            name: "Strawberry",
            type: .perishable,
            currentQuantity: 0,
            minimumQuantity: 10
        )
        repository.items = [fruit]
        let viewModel = DashboardViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.lowInventoryItems, [])
    }

    func testLoadShowsPerishableLowInventoryWhenActiveOrderRecipeNeedsIt() {
        let repository = FakeDashboardInventoryItemRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let fruit = makeInventoryItem(
            id: "inventory-strawberry",
            name: "Strawberry",
            type: .perishable,
            currentQuantity: 0,
            minimumQuantity: 10
        )
        let component = makeRecipeComponent(id: "component-filling", recipeId: "recipe-fruit-cake")
        repository.items = [fruit]
        repository.orders = [
            makeOrder(id: "order-fruit-cake", recipeId: "recipe-fruit-cake", status: .confirmed, dueAt: dueAt)
        ]
        repository.components = [component]
        repository.ingredients = [
            makeRecipeIngredient(id: "ingredient-strawberry", componentId: component.id, inventoryItemId: fruit.id)
        ]
        let viewModel = DashboardViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.lowInventoryItems, [fruit])
    }

    func testLoadCountsOnlyActiveUpcomingOrders() {
        let repository = FakeDashboardInventoryItemRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        repository.orders = [
            makeOrder(id: "order-confirmed", status: .confirmed, dueAt: dueAt),
            makeOrder(id: "order-ready", status: .ready, dueAt: dueAt.addingTimeInterval(3_600)),
            makeOrder(id: "order-completed", status: .completed, dueAt: dueAt.addingTimeInterval(7_200)),
            makeOrder(id: "order-cancelled", status: .cancelled, dueAt: dueAt.addingTimeInterval(10_800))
        ]
        let viewModel = DashboardViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.upcomingOrderCount, 2)
        XCTAssertEqual(viewModel.nextUpcomingOrder?.id, "order-confirmed")
    }

    func testLoadShowsPrimaryOverdueOrderAlert() {
        let repository = FakeDashboardInventoryItemRepository()
        let calendar = utcCalendar()
        let now = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 19))!
        let overdueToday = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 18))!
        let laterOverdue = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 18, minute: 30))!
        repository.orders = [
            makeOrder(id: "order-later", title: "Later Cake", status: .confirmed, dueAt: laterOverdue),
            makeOrder(id: "order-overdue", title: "Birthday Cake", status: .confirmed, dueAt: overdueToday)
        ]
        let viewModel = DashboardViewModel(
            repository: repository,
            orderPresentation: OrderListPresentation(
                dateProvider: { now },
                calendar: calendar
            )
        )

        viewModel.load()

        XCTAssertEqual(viewModel.overdueOrderAlert?.order.id, "order-overdue")
        XCTAssertEqual(
            viewModel.overdueOrderAlert?.message,
            "Birthday Cake was due at \(overdueToday.formatted(date: .omitted, time: .shortened)), update status?"
        )
    }
}

private func makeInventoryItem(
    id: String,
    name: String,
    type: InventoryItemType = .standard,
    currentQuantity: Double,
    minimumQuantity: Double,
    hasExpiredStock: Bool = false,
    hasExpiringSoonStock: Bool = false,
    archivedAt: Date? = nil
) -> InventoryItem {
    let timestamp = Date(timeIntervalSince1970: 1_800_040_000)
    return InventoryItem(
        id: id,
        name: name,
        type: type,
        unit: .gram,
        currentQuantity: currentQuantity,
        minimumQuantity: minimumQuantity,
        hasExpiredStock: hasExpiredStock,
        hasExpiringSoonStock: hasExpiringSoonStock,
        createdAt: timestamp,
        updatedAt: timestamp,
        archivedAt: archivedAt
    )
}

private final class FakeDashboardInventoryItemRepository: InventoryItemRepository,
    OrderRepository,
    RecipeComponentRepository,
    RecipeIngredientRepository,
    OrderExtraIngredientRepository {
    var items: [InventoryItem] = []
    var orders: [Order] = []
    var components: [RecipeComponent] = []
    var ingredients: [RecipeIngredient] = []
    var extraIngredients: [OrderExtraIngredient] = []

    func save(_ item: InventoryItem) throws {}

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        items.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        items.filter { !$0.isArchived }
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        items.filter(\.isArchived)
    }

    func save(_ order: Order) throws {}

    func fetchOrder(id: String) throws -> Order? {
        orders.first { $0.id == id }
    }

    func fetchOrders() throws -> [Order] {
        orders
    }

    func save(_ component: RecipeComponent) throws {}

    func fetchRecipeComponent(id: String) throws -> RecipeComponent? {
        components.first { $0.id == id }
    }

    func fetchRecipeComponents(recipeId: String) throws -> [RecipeComponent] {
        components.filter { $0.recipeId == recipeId }
    }

    func save(_ ingredient: RecipeIngredient) throws {}

    func fetchRecipeIngredient(id: String) throws -> RecipeIngredient? {
        ingredients.first { $0.id == id }
    }

    func fetchRecipeIngredients(componentId: String) throws -> [RecipeIngredient] {
        ingredients.filter { $0.componentId == componentId }
    }

    func deleteRecipeIngredient(id: String) throws {}

    func save(_ ingredient: OrderExtraIngredient) throws {}

    func fetchOrderExtraIngredients(orderId: String) throws -> [OrderExtraIngredient] {
        extraIngredients.filter { $0.orderId == orderId }
    }

    func deleteOrderExtraIngredient(id: String) throws {}
}

private func makeRecipeComponent(id: String, recipeId: String) -> RecipeComponent {
    let timestamp = Date(timeIntervalSince1970: 1_800_040_000)
    return RecipeComponent(
        id: id,
        recipeId: recipeId,
        name: "Component",
        sortOrder: 0,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

private func makeRecipeIngredient(id: String, componentId: String, inventoryItemId: String) -> RecipeIngredient {
    let timestamp = Date(timeIntervalSince1970: 1_800_040_000)
    return RecipeIngredient(
        id: id,
        componentId: componentId,
        inventoryItemId: inventoryItemId,
        quantity: 1,
        unit: .gram,
        note: nil,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}
