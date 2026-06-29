import XCTest
@testable import CloudBakeOwner

@MainActor
final class InventoryListViewModelTests: XCTestCase {
    func testLoadFetchesInventoryItems() {
        let repository = FakeInventoryItemRepository()
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_020_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_020_000)
        )
        repository.items = [item]
        let viewModel = InventoryListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.items, [item])
    }

    func testAddItemPersistsAndReloadsInventory() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "inventory-butter" },
            dateProvider: { now }
        )
        viewModel.draftName = " Butter "
        viewModel.draftUnit = .gram
        viewModel.draftCurrentQuantity = "100"
        viewModel.draftMinimumQuantity = "250"

        XCTAssertTrue(viewModel.addItem())

        XCTAssertEqual(
            repository.items,
            [
                InventoryItem(
                    id: "inventory-butter",
                    name: "Butter",
                    unit: .gram,
                    currentQuantity: 100,
                    minimumQuantity: 250,
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
        XCTAssertEqual(viewModel.items, repository.items)
        XCTAssertEqual(viewModel.draftName, "")
        XCTAssertEqual(viewModel.draftCurrentQuantity, "")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddItemRejectsBlankName() {
        let viewModel = InventoryListViewModel(repository: FakeInventoryItemRepository())
        viewModel.draftName = " "

        XCTAssertFalse(viewModel.addItem())
        XCTAssertEqual(viewModel.errorMessage, "Inventory item name is required.")
    }

    func testAddItemRejectsNegativeCurrentQuantity() {
        let viewModel = InventoryListViewModel(repository: FakeInventoryItemRepository())
        viewModel.draftName = "Sugar"
        viewModel.draftCurrentQuantity = "-1"

        XCTAssertFalse(viewModel.addItem())
        XCTAssertEqual(viewModel.errorMessage, "Current quantity cannot be negative.")
    }
}

private final class FakeInventoryItemRepository: InventoryItemRepository {
    var items: [InventoryItem] = []

    func save(_ item: InventoryItem) throws {
        items.append(item)
    }

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        items.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        items
    }
}
