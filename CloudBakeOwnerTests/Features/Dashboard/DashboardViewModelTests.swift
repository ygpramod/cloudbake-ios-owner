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
}

private final class FakeDashboardInventoryItemRepository: InventoryItemRepository {
    var items: [InventoryItem] = []

    func save(_ item: InventoryItem) throws {}

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        items.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        items
    }
}
