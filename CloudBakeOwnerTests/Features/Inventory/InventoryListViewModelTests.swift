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
        viewModel.draftExpiryDate = Date(timeIntervalSince1970: 1_800_116_400)

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

    func testAddItemStoresInitialStockBatchWithExpiry() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        let expiresAt = Date(timeIntervalSince1970: 1_800_116_400)
        var ids = ["inventory-butter", "batch-butter-initial"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.draftName = "Butter"
        viewModel.draftCurrentQuantity = "100"
        viewModel.draftMinimumQuantity = "250"
        viewModel.draftExpiryDate = expiresAt

        XCTAssertTrue(viewModel.addItem())

        XCTAssertEqual(
            repository.batches,
            [
                InventoryStockBatch(
                    id: "batch-butter-initial",
                    inventoryItemId: "inventory-butter",
                    remainingQuantity: 100,
                    expiresAt: expiresAt,
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
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

    func testAddItemWarnsBeforeAddingPossibleDuplicate() {
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-cake-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 250,
                minimumQuantity: 500,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()
        viewModel.draftName = "cake flours"
        viewModel.draftCurrentQuantity = "100"
        viewModel.draftMinimumQuantity = "250"

        XCTAssertFalse(viewModel.addItem())
        XCTAssertEqual(
            viewModel.duplicateWarningMessage,
            "Possible duplicate: Cake flour already exists. Tap Save again to add a separate item."
        )
        XCTAssertEqual(repository.items.count, 1)
    }

    func testAddItemAllowsDuplicateAfterWarningIsAcknowledged() {
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-cake-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 250,
                minimumQuantity: 500,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        let now = Date(timeIntervalSince1970: 1_800_031_000)
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "inventory-cake-flours" },
            dateProvider: { now }
        )
        viewModel.load()
        viewModel.draftName = "cake flours"
        viewModel.draftCurrentQuantity = "100"
        viewModel.draftMinimumQuantity = "250"

        XCTAssertFalse(viewModel.addItem())
        XCTAssertTrue(viewModel.addItem())

        XCTAssertEqual(repository.items.count, 2)
        XCTAssertEqual(repository.items.last?.name, "cake flours")
        XCTAssertNil(viewModel.duplicateWarningMessage)
    }

    func testBeginEditingCopiesItemIntoDraft() {
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .kilogram,
            currentQuantity: 1.5,
            minimumQuantity: 2,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        let viewModel = InventoryListViewModel(repository: FakeInventoryItemRepository())

        viewModel.beginEditing(item)

        XCTAssertEqual(viewModel.editingItem, item)
        XCTAssertEqual(viewModel.draftName, "Cake flour")
        XCTAssertEqual(viewModel.draftUnit, .kilogram)
        XCTAssertEqual(viewModel.draftCurrentQuantity, "1.5")
        XCTAssertEqual(viewModel.draftMinimumQuantity, "2")
        XCTAssertNil(viewModel.errorMessage)
    }

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

    func testSaveEditedItemUpdatesExistingItemAndPreservesCreatedAt() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let originalUpdatedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let editedUpdatedAt = Date(timeIntervalSince1970: 1_800_030_200)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: originalUpdatedAt
        )
        repository.items = [item]
        let viewModel = InventoryListViewModel(
            repository: repository,
            dateProvider: { editedUpdatedAt }
        )
        viewModel.load()
        viewModel.beginEditing(item)
        viewModel.draftName = " Cake flour fine "
        viewModel.draftUnit = .kilogram
        viewModel.draftCurrentQuantity = "1.25"
        viewModel.draftMinimumQuantity = "2"

        XCTAssertTrue(viewModel.saveEditedItem())

        XCTAssertEqual(
            repository.items,
            [
                InventoryItem(
                    id: "inventory-flour",
                    name: "Cake flour fine",
                    unit: .gram,
                    currentQuantity: 250,
                    minimumQuantity: 2,
                    createdAt: createdAt,
                    updatedAt: editedUpdatedAt
                )
            ]
        )
        XCTAssertEqual(viewModel.items, repository.items)
        XCTAssertNil(viewModel.editingItem)
        XCTAssertEqual(viewModel.draftName, "")
    }

    func testSaveEditedItemPreservesCurrentQuantityWhenDraftCurrentQuantityChanges() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let editedUpdatedAt = Date(timeIntervalSince1970: 1_800_030_200)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.items = [item]
        let viewModel = InventoryListViewModel(
            repository: repository,
            dateProvider: { editedUpdatedAt }
        )
        viewModel.load()
        viewModel.beginEditing(item)
        viewModel.draftCurrentQuantity = "750"

        XCTAssertTrue(viewModel.saveEditedItem())

        XCTAssertEqual(
            repository.items,
            [
                InventoryItem(
                    id: "inventory-flour",
                    name: "Cake flour",
                    unit: .gram,
                    currentQuantity: 250,
                    minimumQuantity: 500,
                    createdAt: createdAt,
                    updatedAt: editedUpdatedAt
                )
            ]
        )
    }

    func testSaveEditedItemDoesNotUpdateStockBatches() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let editedUpdatedAt = Date(timeIntervalSince1970: 1_800_030_200)
        let originalExpiry = Date(timeIntervalSince1970: 1_800_116_400)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            earliestExpiryAt: originalExpiry,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.items = [item]
        repository.batches = [
            InventoryStockBatch(
                id: "batch-flour-old",
                inventoryItemId: item.id,
                remainingQuantity: 250,
                expiresAt: originalExpiry,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            dateProvider: { editedUpdatedAt }
        )
        viewModel.load()
        viewModel.beginEditing(item)
        viewModel.draftMinimumQuantity = "600"

        XCTAssertTrue(viewModel.saveEditedItem())

        XCTAssertEqual(
            repository.batches,
            [
                InventoryStockBatch(
                    id: "batch-flour-old",
                    inventoryItemId: item.id,
                    remainingQuantity: 250,
                    expiresAt: originalExpiry,
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
            ]
        )
    }

    func testSaveEditedItemAcceptsFormattedMinimum() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let editedUpdatedAt = Date(timeIntervalSince1970: 1_800_030_200)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 50,
            minimumQuantity: 5_000,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.items = [item]
        let viewModel = InventoryListViewModel(
            repository: repository,
            dateProvider: { editedUpdatedAt }
        )
        viewModel.load()
        viewModel.beginEditing(item)
        viewModel.draftMinimumQuantity = "5,000"

        XCTAssertTrue(viewModel.saveEditedItem())

        XCTAssertEqual(
            repository.items,
            [
                InventoryItem(
                    id: "inventory-flour",
                    name: "Cake flour",
                    unit: .gram,
                    currentQuantity: 50,
                    minimumQuantity: 5_000,
                    createdAt: createdAt,
                    updatedAt: editedUpdatedAt
                )
            ]
        )
    }

    func testSaveEditedItemRejectsBlankName() {
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        let viewModel = InventoryListViewModel(repository: FakeInventoryItemRepository())
        viewModel.beginEditing(item)
        viewModel.draftName = " "

        XCTAssertFalse(viewModel.saveEditedItem())
        XCTAssertEqual(viewModel.errorMessage, "Inventory item name is required.")
    }

    func testSaveEditedItemRejectsBlankMinimumQuantityWithoutSaving() {
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        let repository = FakeInventoryItemRepository()
        repository.items = [item]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.beginEditing(item)
        viewModel.draftCurrentQuantity = "750"
        viewModel.draftMinimumQuantity = " "

        XCTAssertFalse(viewModel.saveEditedItem())

        XCTAssertEqual(viewModel.errorMessage, "Minimum quantity is required.")
        XCTAssertEqual(repository.items, [item])
    }

    func testSaveEditedItemDoesNotWarnWhenNameStillMatchesItself() {
        let repository = FakeInventoryItemRepository()
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        repository.items = [item]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()
        viewModel.beginEditing(item)
        viewModel.draftName = "Cake flours"

        XCTAssertTrue(viewModel.saveEditedItem())
        XCTAssertNil(viewModel.duplicateWarningMessage)
        XCTAssertEqual(repository.items.count, 1)
        XCTAssertEqual(repository.items.first?.name, "Cake flours")
    }

    func testSaveEditedItemWarnsBeforeUsingAnotherItemsSimilarName() {
        let repository = FakeInventoryItemRepository()
        let flour = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        let sugar = InventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram,
            currentQuantity: 1_000,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_031_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_031_000)
        )
        repository.items = [flour, sugar]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()
        viewModel.beginEditing(sugar)
        viewModel.draftName = "cake flours"

        XCTAssertFalse(viewModel.saveEditedItem())
        XCTAssertEqual(
            viewModel.duplicateWarningMessage,
            "Possible duplicate: Cake flour already exists. Tap Save again to keep this item separate."
        )
        XCTAssertEqual(repository.items, [flour, sugar])
    }

    func testArchiveItemHidesItemFromLoadedInventoryAndStoresArchiveTimestamp() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let updatedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let archivedAt = Date(timeIntervalSince1970: 1_800_030_200)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        repository.items = [item]
        let viewModel = InventoryListViewModel(
            repository: repository,
            dateProvider: { archivedAt }
        )
        viewModel.load()

        viewModel.archiveItem(item)

        XCTAssertEqual(viewModel.items, [])
        XCTAssertEqual(
            repository.items,
            [
                InventoryItem(
                    id: "inventory-flour",
                    name: "Cake flour",
                    unit: .gram,
                    currentQuantity: 250,
                    minimumQuantity: 500,
                    createdAt: createdAt,
                    updatedAt: archivedAt,
                    archivedAt: archivedAt
                )
            ]
        )
    }

    func testAddItemDoesNotWarnAboutArchivedDuplicate() {
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-archived-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 0,
                minimumQuantity: 500,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_100),
                archivedAt: Date(timeIntervalSince1970: 1_800_030_200)
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "inventory-new-flour" },
            dateProvider: { Date(timeIntervalSince1970: 1_800_030_300) }
        )
        viewModel.load()
        viewModel.draftName = "Cake flour"
        viewModel.draftCurrentQuantity = "250"
        viewModel.draftMinimumQuantity = "500"

        XCTAssertTrue(viewModel.addItem())
        XCTAssertNil(viewModel.duplicateWarningMessage)
    }

    func testLoadArchivedItemsFetchesArchivedInventory() {
        let repository = FakeInventoryItemRepository()
        let archived = InventoryItem(
            id: "inventory-archived-flour",
            name: "Archived flour",
            unit: .gram,
            currentQuantity: 0,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_100),
            archivedAt: Date(timeIntervalSince1970: 1_800_030_200)
        )
        repository.items = [archived]
        let viewModel = InventoryListViewModel(repository: repository)

        viewModel.loadArchivedItems()

        XCTAssertEqual(viewModel.archivedItems, [archived])
    }

    func testRestoreItemMovesArchivedItemBackToActiveInventory() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let archivedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let restoredAt = Date(timeIntervalSince1970: 1_800_030_200)
        let archived = InventoryItem(
            id: "inventory-archived-flour",
            name: "Archived flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: archivedAt,
            archivedAt: archivedAt
        )
        repository.items = [archived]
        let viewModel = InventoryListViewModel(
            repository: repository,
            dateProvider: { restoredAt }
        )
        viewModel.loadArchivedItems()

        viewModel.restoreItem(archived)

        let restored = InventoryItem(
            id: "inventory-archived-flour",
            name: "Archived flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: restoredAt
        )
        XCTAssertEqual(repository.items, [restored])
        XCTAssertEqual(viewModel.items, [restored])
        XCTAssertEqual(viewModel.archivedItems, [])
    }

}
