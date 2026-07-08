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
}

private func makeInventoryItem(
    id: String,
    name: String,
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

private final class FakeDashboardInventoryItemRepository: InventoryItemRepository, OrderRepository {
    var items: [InventoryItem] = []
    var orders: [Order] = []

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
}
