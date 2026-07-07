import XCTest
@testable import CloudBakeOwner

@MainActor
final class InventoryBatchEditingViewModelTests: XCTestCase {
    func testBeginViewingItemLoadsStockBatches() {
        let repository = FakeInventoryItemRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 320,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let olderBatch = InventoryStockBatch(
            id: "batch-flour-older",
            inventoryItemId: item.id,
            remainingQuantity: 20,
            expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let newerBatch = InventoryStockBatch(
            id: "batch-flour-newer",
            inventoryItemId: item.id,
            remainingQuantity: 300,
            expiresAt: Date(timeIntervalSince1970: 1_800_202_800),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.items = [item]
        repository.batches = [newerBatch, olderBatch]
        let viewModel = InventoryListViewModel(repository: repository)

        viewModel.beginViewingItem(item)

        XCTAssertEqual(viewModel.selectedItem, item)
        XCTAssertEqual(viewModel.selectedItemBatches, [olderBatch, newerBatch])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSaveEditedBatchUpdatesQuantityExpiryAndCurrentStock() {
        let repository = FakeInventoryItemRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let editedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let originalExpiry = Date(timeIntervalSince1970: 1_800_116_400)
        let updatedExpiry = Date(timeIntervalSince1970: 1_800_202_800)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let batch = InventoryStockBatch(
            id: "batch-flour-initial",
            inventoryItemId: item.id,
            remainingQuantity: 250,
            expiresAt: originalExpiry,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.items = [item]
        repository.batches = [batch]
        let viewModel = InventoryListViewModel(
            repository: repository,
            dateProvider: { editedAt }
        )
        viewModel.load()
        viewModel.beginViewingItem(item)

        viewModel.beginEditingBatch(batch)
        viewModel.draftBatchQuantity = "300"
        viewModel.draftBatchExpiryDate = updatedExpiry

        XCTAssertTrue(viewModel.saveEditedBatch())

        let updatedBatch = InventoryStockBatch(
            id: "batch-flour-initial",
            inventoryItemId: item.id,
            remainingQuantity: 300,
            expiresAt: updatedExpiry,
            createdAt: timestamp,
            updatedAt: editedAt
        )
        let updatedItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 300,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: editedAt
        )
        XCTAssertEqual(repository.items, [updatedItem])
        XCTAssertEqual(repository.batches, [updatedBatch])
        XCTAssertEqual(viewModel.selectedItem, updatedItem)
        XCTAssertEqual(viewModel.selectedItemBatches, [updatedBatch])
        XCTAssertNil(viewModel.editingBatch)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSaveEditedBatchRejectsInvalidQuantityWithoutSaving() {
        let repository = FakeInventoryItemRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let batch = InventoryStockBatch(
            id: "batch-flour-initial",
            inventoryItemId: item.id,
            remainingQuantity: 250,
            expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.items = [item]
        repository.batches = [batch]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()
        viewModel.beginViewingItem(item)
        viewModel.beginEditingBatch(batch)
        viewModel.draftBatchQuantity = "-1"

        XCTAssertFalse(viewModel.saveEditedBatch())

        XCTAssertEqual(viewModel.errorMessage, "Batch quantity must be zero or greater.")
        XCTAssertEqual(repository.items, [item])
        XCTAssertEqual(repository.batches, [batch])
    }

    func testSaveEditedBatchFailureLeavesItemAndBatchUnchanged() {
        let repository = FakeInventoryItemRepository()
        repository.shouldFailBatchCorrectionSave = true
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let batch = InventoryStockBatch(
            id: "batch-flour-initial",
            inventoryItemId: item.id,
            remainingQuantity: 250,
            expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.items = [item]
        repository.batches = [batch]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()
        viewModel.beginViewingItem(item)
        viewModel.beginEditingBatch(batch)
        viewModel.draftBatchQuantity = "300"

        XCTAssertFalse(viewModel.saveEditedBatch())

        XCTAssertEqual(viewModel.errorMessage, "Stock batch could not be saved.")
        XCTAssertEqual(repository.items, [item])
        XCTAssertEqual(repository.batches, [batch])
    }

    func testDeleteBatchRemovesBatchAndUpdatesCurrentStock() {
        let repository = FakeInventoryItemRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let deletedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 250,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let batch = InventoryStockBatch(
            id: "batch-flour-initial",
            inventoryItemId: item.id,
            remainingQuantity: 200,
            expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.items = [item]
        repository.batches = [batch]
        let viewModel = InventoryListViewModel(
            repository: repository,
            dateProvider: { deletedAt }
        )
        viewModel.load()
        viewModel.beginViewingItem(item)

        viewModel.deleteBatch(batch)

        XCTAssertEqual(repository.batches, [])
        XCTAssertEqual(
            repository.items,
            [
                InventoryItem(
                    id: "inventory-flour",
                    name: "Cake flour",
                    unit: .gram,
                    currentQuantity: 300,
                    minimumQuantity: 250,
                    createdAt: timestamp,
                    updatedAt: deletedAt
                )
            ]
        )
        XCTAssertEqual(viewModel.selectedItemBatches, [])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDeleteBatchFailureLeavesItemAndBatchUnchanged() {
        let repository = FakeInventoryItemRepository()
        repository.shouldFailBatchCorrectionDelete = true
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 250,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let batch = InventoryStockBatch(
            id: "batch-flour-initial",
            inventoryItemId: item.id,
            remainingQuantity: 200,
            expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.items = [item]
        repository.batches = [batch]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()
        viewModel.beginViewingItem(item)

        viewModel.deleteBatch(batch)

        XCTAssertEqual(viewModel.errorMessage, "Stock batch could not be deleted.")
        XCTAssertEqual(repository.items, [item])
        XCTAssertEqual(repository.batches, [batch])
    }
}
