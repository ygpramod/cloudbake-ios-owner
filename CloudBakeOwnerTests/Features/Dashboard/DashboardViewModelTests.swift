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
}

private func makeInventoryItem(
    id: String,
    name: String,
    currentQuantity: Double,
    minimumQuantity: Double,
    archivedAt: Date? = nil
) -> InventoryItem {
    let timestamp = Date(timeIntervalSince1970: 1_800_040_000)
    return InventoryItem(
        id: id,
        name: name,
        unit: .gram,
        currentQuantity: currentQuantity,
        minimumQuantity: minimumQuantity,
        createdAt: timestamp,
        updatedAt: timestamp,
        archivedAt: archivedAt
    )
}

private final class FakeDashboardInventoryItemRepository: InventoryItemRepository {
    var items: [InventoryItem] = []

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
}
