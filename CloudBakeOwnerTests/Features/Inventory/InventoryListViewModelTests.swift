import CoreGraphics
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

    func testSaveEditedBatchExpiryUpdatesOnlySelectedBatch() {
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

        viewModel.beginEditingBatchExpiry(batch)
        viewModel.draftBatchExpiryDate = updatedExpiry

        XCTAssertTrue(viewModel.saveEditedBatchExpiry())

        let updatedBatch = InventoryStockBatch(
            id: "batch-flour-initial",
            inventoryItemId: item.id,
            remainingQuantity: 250,
            expiresAt: updatedExpiry,
            createdAt: timestamp,
            updatedAt: editedAt
        )
        XCTAssertEqual(repository.batches, [updatedBatch])
        XCTAssertEqual(viewModel.selectedItemBatches, [updatedBatch])
        XCTAssertNil(viewModel.editingBatch)
        XCTAssertNil(viewModel.errorMessage)
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

    func testBeginAdjustingCopiesItemIntoAdjustmentDraft() {
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

        viewModel.beginAdjusting(item)

        XCTAssertEqual(viewModel.adjustingItem, item)
        XCTAssertEqual(viewModel.draftAdjustmentQuantity, "")
        XCTAssertEqual(viewModel.draftAdjustmentUnit, .gram)
        XCTAssertEqual(viewModel.draftAdjustmentNote, "")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRecordStockAdjustmentIncreasesCurrentQuantityAndStoresTransaction() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let adjustedAt = Date(timeIntervalSince1970: 1_800_030_100)
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
        repository.batches = [
            InventoryStockBatch(
                id: "batch-flour-initial",
                inventoryItemId: item.id,
                remainingQuantity: 250,
                expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "transaction-flour-adjustment" },
            dateProvider: { adjustedAt }
        )
        viewModel.load()
        viewModel.beginAdjusting(item)
        viewModel.draftAdjustmentQuantity = "100"
        viewModel.draftAdjustmentExpiryDate = Date(timeIntervalSince1970: 1_800_202_800)
        viewModel.draftAdjustmentNote = " Restocked from supplier "

        XCTAssertTrue(viewModel.recordStockAdjustment())

        let updatedItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 350,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: adjustedAt
        )
        XCTAssertEqual(repository.items, [updatedItem])
        XCTAssertEqual(viewModel.items, [updatedItem])
        XCTAssertEqual(
            repository.transactions,
            [
                InventoryTransaction(
                    id: "transaction-flour-adjustment",
                    inventoryItemId: "inventory-flour",
                    kind: .adjustment,
                    quantity: 100,
                    occurredAt: adjustedAt,
                    note: "Restocked from supplier",
                    createdAt: adjustedAt,
                    updatedAt: adjustedAt
                )
            ]
        )
        XCTAssertEqual(
            repository.batches.last,
            InventoryStockBatch(
                id: "transaction-flour-adjustment",
                inventoryItemId: "inventory-flour",
                remainingQuantity: 100,
                expiresAt: Date(timeIntervalSince1970: 1_800_202_800),
                createdAt: adjustedAt,
                updatedAt: adjustedAt
            )
        )
        XCTAssertNil(viewModel.adjustingItem)
        XCTAssertEqual(viewModel.draftAdjustmentQuantity, "")
        XCTAssertEqual(viewModel.draftAdjustmentNote, "")
    }

    func testRecordStockAdjustmentConvertsDraftUnitToItemUnit() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let adjustedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.items = [item]
        var ids = ["transaction-flour-adjustment", "batch-flour-adjustment"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { adjustedAt }
        )
        viewModel.beginAdjusting(item)
        viewModel.draftAdjustmentQuantity = "1.25"
        viewModel.draftAdjustmentUnit = .kilogram

        XCTAssertTrue(viewModel.recordStockAdjustment())

        XCTAssertEqual(repository.items.first?.currentQuantity, 1_750)
        XCTAssertEqual(repository.transactions.first?.quantity, 1_250)
        XCTAssertEqual(repository.batches.first?.remainingQuantity, 1_250)
    }

    func testRecordStockAdjustmentRejectsZeroQuantity() {
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
        viewModel.beginAdjusting(item)
        viewModel.draftAdjustmentQuantity = "0"

        XCTAssertFalse(viewModel.recordStockAdjustment())

        XCTAssertEqual(viewModel.errorMessage, "Adjustment quantity must be greater than zero.")
        XCTAssertEqual(repository.items, [item])
        XCTAssertEqual(repository.transactions, [])
    }

    func testArchiveItemAfterStockAdjustmentHidesAdjustedItem() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let adjustedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let archivedAt = Date(timeIntervalSince1970: 1_800_030_200)
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
        repository.batches = [
            InventoryStockBatch(
                id: "batch-flour-old",
                inventoryItemId: item.id,
                remainingQuantity: 250,
                expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        var dates = [adjustedAt, archivedAt]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "transaction-flour-adjustment" },
            dateProvider: { dates.removeFirst() }
        )
        viewModel.load()
        viewModel.beginAdjusting(item)
        viewModel.draftAdjustmentQuantity = "100"
        XCTAssertTrue(viewModel.recordStockAdjustment())

        viewModel.archiveItem(item)

        XCTAssertEqual(viewModel.items, [])
        XCTAssertEqual(
            repository.items,
            [
                InventoryItem(
                    id: "inventory-flour",
                    name: "Cake flour",
                    unit: .gram,
                    currentQuantity: 350,
                    minimumQuantity: 500,
                    createdAt: createdAt,
                    updatedAt: archivedAt,
                    archivedAt: archivedAt
                )
            ]
        )
    }

    func testBeginConsumingCopiesItemIntoConsumptionDraft() {
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

        viewModel.beginConsuming(item)

        XCTAssertEqual(viewModel.consumingItem, item)
        XCTAssertEqual(viewModel.draftConsumptionQuantity, "")
        XCTAssertEqual(viewModel.draftConsumptionUnit, .gram)
        XCTAssertEqual(viewModel.draftConsumptionNote, "")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRecordStockConsumptionDecreasesCurrentQuantityAndStoresTransaction() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let consumedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 350,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.items = [item]
        repository.batches = [
            InventoryStockBatch(
                id: "batch-flour-old",
                inventoryItemId: item.id,
                remainingQuantity: 150,
                expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            InventoryStockBatch(
                id: "batch-flour-new",
                inventoryItemId: item.id,
                remainingQuantity: 200,
                expiresAt: Date(timeIntervalSince1970: 1_800_202_800),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "transaction-flour-consumption" },
            dateProvider: { consumedAt }
        )
        viewModel.load()
        viewModel.beginConsuming(item)
        viewModel.draftConsumptionQuantity = "100"
        viewModel.draftConsumptionNote = " Vanilla sponge "

        XCTAssertTrue(viewModel.recordStockConsumption())

        let updatedItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: consumedAt
        )
        XCTAssertEqual(repository.items, [updatedItem])
        XCTAssertEqual(viewModel.items, [updatedItem])
        XCTAssertEqual(
            repository.transactions,
            [
                InventoryTransaction(
                    id: "transaction-flour-consumption",
                    inventoryItemId: "inventory-flour",
                    kind: .consumption,
                    quantity: 100,
                    occurredAt: consumedAt,
                    note: "Vanilla sponge",
                    createdAt: consumedAt,
                    updatedAt: consumedAt
                )
            ]
        )
        XCTAssertEqual(
            repository.batches,
            [
                InventoryStockBatch(
                    id: "batch-flour-old",
                    inventoryItemId: item.id,
                    remainingQuantity: 50,
                    expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
                    createdAt: createdAt,
                    updatedAt: consumedAt
                ),
                InventoryStockBatch(
                    id: "batch-flour-new",
                    inventoryItemId: item.id,
                    remainingQuantity: 200,
                    expiresAt: Date(timeIntervalSince1970: 1_800_202_800),
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
            ]
        )
        XCTAssertNil(viewModel.consumingItem)
        XCTAssertEqual(viewModel.draftConsumptionQuantity, "")
        XCTAssertEqual(viewModel.draftConsumptionNote, "")
    }

    func testRecordStockConsumptionContinuesIntoNewerBatchAfterOldBatchIsUsed() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let consumedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 350,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.items = [item]
        repository.batches = [
            InventoryStockBatch(
                id: "batch-flour-old",
                inventoryItemId: item.id,
                remainingQuantity: 150,
                expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            InventoryStockBatch(
                id: "batch-flour-new",
                inventoryItemId: item.id,
                remainingQuantity: 200,
                expiresAt: Date(timeIntervalSince1970: 1_800_202_800),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "transaction-flour-consumption" },
            dateProvider: { consumedAt }
        )
        viewModel.beginConsuming(item)
        viewModel.draftConsumptionQuantity = "200"

        XCTAssertTrue(viewModel.recordStockConsumption())

        XCTAssertEqual(repository.batches[0].remainingQuantity, 0)
        XCTAssertEqual(repository.batches[1].remainingQuantity, 150)
        XCTAssertEqual(repository.items.first?.currentQuantity, 150)
    }

    func testRecordStockConsumptionConvertsDraftUnitToItemUnitBeforeDeductingBatches() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let consumedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let item = InventoryItem(
            id: "inventory-oil",
            name: "Vegetable oil",
            unit: .milliliter,
            currentQuantity: 1_000,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.items = [item]
        repository.batches = [
            InventoryStockBatch(
                id: "batch-oil-old",
                inventoryItemId: item.id,
                remainingQuantity: 600,
                expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            InventoryStockBatch(
                id: "batch-oil-new",
                inventoryItemId: item.id,
                remainingQuantity: 400,
                expiresAt: Date(timeIntervalSince1970: 1_800_202_800),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "transaction-oil-consumption" },
            dateProvider: { consumedAt }
        )
        viewModel.beginConsuming(item)
        viewModel.draftConsumptionQuantity = "0.75"
        viewModel.draftConsumptionUnit = .liter

        XCTAssertTrue(viewModel.recordStockConsumption())

        XCTAssertEqual(repository.items.first?.currentQuantity, 250)
        XCTAssertEqual(repository.transactions.first?.quantity, 750)
        XCTAssertEqual(repository.batches[0].remainingQuantity, 0)
        XCTAssertEqual(repository.batches[1].remainingQuantity, 250)
    }

    func testRecordStockConsumptionRejectsZeroQuantity() {
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
        viewModel.beginConsuming(item)
        viewModel.draftConsumptionQuantity = "0"

        XCTAssertFalse(viewModel.recordStockConsumption())

        XCTAssertEqual(viewModel.errorMessage, "Consumption quantity must be greater than zero.")
        XCTAssertEqual(repository.items, [item])
        XCTAssertEqual(repository.transactions, [])
    }

    func testRecordStockConsumptionRejectsQuantityGreaterThanCurrentStock() {
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
        viewModel.beginConsuming(item)
        viewModel.draftConsumptionQuantity = "251"

        XCTAssertFalse(viewModel.recordStockConsumption())

        XCTAssertEqual(viewModel.errorMessage, "Consumption quantity cannot be greater than current stock.")
        XCTAssertEqual(repository.items, [item])
        XCTAssertEqual(repository.transactions, [])
    }

    func testBeginViewingHistoryLoadsTransactionsNewestFirstForSelectedItem() {
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
        let olderTransaction = InventoryTransaction(
            id: "transaction-older",
            inventoryItemId: item.id,
            kind: .adjustment,
            quantity: 100,
            occurredAt: Date(timeIntervalSince1970: 1_800_030_100),
            note: "Restocked",
            createdAt: Date(timeIntervalSince1970: 1_800_030_100),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_100)
        )
        let otherItemTransaction = InventoryTransaction(
            id: "transaction-other",
            inventoryItemId: "inventory-sugar",
            kind: .adjustment,
            quantity: 200,
            occurredAt: Date(timeIntervalSince1970: 1_800_030_300),
            note: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_030_300),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_300)
        )
        let newerTransaction = InventoryTransaction(
            id: "transaction-newer",
            inventoryItemId: item.id,
            kind: .consumption,
            quantity: 50,
            occurredAt: Date(timeIntervalSince1970: 1_800_030_200),
            note: "Vanilla sponge",
            createdAt: Date(timeIntervalSince1970: 1_800_030_200),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_200)
        )
        repository.transactions = [olderTransaction, otherItemTransaction, newerTransaction]
        let viewModel = InventoryListViewModel(repository: repository)

        viewModel.beginViewingHistory(item)

        XCTAssertEqual(viewModel.historyItem, item)
        XCTAssertEqual(viewModel.historyTransactions, [newerTransaction, olderTransaction])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testCloseHistoryClearsSelectedItemAndTransactions() {
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
        repository.transactions = [
            InventoryTransaction(
                id: "transaction-flour",
                inventoryItemId: item.id,
                kind: .adjustment,
                quantity: 100,
                occurredAt: Date(timeIntervalSince1970: 1_800_030_100),
                note: nil,
                createdAt: Date(timeIntervalSince1970: 1_800_030_100),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_100)
            )
        ]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.beginViewingHistory(item)

        viewModel.closeHistory()

        XCTAssertNil(viewModel.historyItem)
        XCTAssertEqual(viewModel.historyTransactions, [])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testCreatePurchaseBillDraftsFromRecognizedText() {
        var ids = ["draft-flour", "draft-butter"]
        let viewModel = InventoryListViewModel(
            repository: FakeInventoryItemRepository(),
            idGenerator: { ids.removeFirst() }
        )
        viewModel.purchaseBillRecognizedText = """
        Cake Flour 1 kg
        Laundry Detergent 1 L
        Unsalted Butter 500 g
        """

        XCTAssertTrue(viewModel.createPurchaseBillDrafts(catalog: purchaseBillCatalog))

        XCTAssertEqual(
            viewModel.purchaseBillDrafts,
            [
                PurchaseBillInventoryDraft(
                    id: "draft-flour",
                    sourceLine: "Cake Flour 1 kg",
                    name: "Cake Flour",
                    quantityText: "1",
                    unit: .kilogram,
                    minimumQuantityText: "0",
                    expiryDate: viewModel.purchaseBillDrafts[0].expiryDate,
                    isSelected: true
                ),
                PurchaseBillInventoryDraft(
                    id: "draft-butter",
                    sourceLine: "Unsalted Butter 500 g",
                    name: "Butter",
                    quantityText: "500",
                    unit: .gram,
                    minimumQuantityText: "0",
                    expiryDate: viewModel.purchaseBillDrafts[1].expiryDate,
                    isSelected: true
                )
            ]
        )
        XCTAssertNil(viewModel.errorMessage)
    }

    func testCreatePurchaseBillDraftsShowsErrorWhenNoBakingItemsMatch() {
        let viewModel = InventoryListViewModel(repository: FakeInventoryItemRepository())
        viewModel.purchaseBillRecognizedText = "Laundry Detergent 1 L"

        XCTAssertFalse(viewModel.createPurchaseBillDrafts(catalog: purchaseBillCatalog))

        XCTAssertEqual(viewModel.purchaseBillDrafts, [])
        XCTAssertEqual(viewModel.errorMessage, "No baking inventory items were found in the bill text.")
    }

    func testRecognizePurchaseBillImageCreatesDraftsFromRecognizedText() async throws {
        var ids = ["draft-flour"]
        let viewModel = InventoryListViewModel(
            repository: FakeInventoryItemRepository(),
            idGenerator: { ids.removeFirst() }
        )

        let didCreateDrafts = await viewModel.recognizePurchaseBillImage(
            try makeTestCGImage(),
            recognizer: FakePurchaseBillTextRecognizer(result: .success("Cake Flour 1 kg")),
            catalog: purchaseBillCatalog
        )

        XCTAssertTrue(didCreateDrafts)

        XCTAssertFalse(viewModel.isRecognizingPurchaseBill)
        XCTAssertEqual(viewModel.purchaseBillRecognizedText, "Cake Flour 1 kg")
        XCTAssertEqual(viewModel.purchaseBillDrafts.map(\.name), ["Cake Flour"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRecognizePurchaseBillImageShowsErrorWhenOCRFails() async throws {
        let viewModel = InventoryListViewModel(repository: FakeInventoryItemRepository())
        viewModel.purchaseBillDrafts = [
            PurchaseBillInventoryDraft(
                id: "stale-draft",
                sourceLine: "Cake Flour 1 kg",
                name: "Cake Flour",
                quantityText: "1",
                unit: .kilogram,
                minimumQuantityText: "0",
                expiryDate: Date(timeIntervalSince1970: 1_800_116_400),
                isSelected: true
            )
        ]

        let didCreateDrafts = await viewModel.recognizePurchaseBillImage(
            try makeTestCGImage(),
            recognizer: FakePurchaseBillTextRecognizer(result: .failure(PurchaseBillTextRecognitionError.unreadableResult)),
            catalog: purchaseBillCatalog
        )

        XCTAssertFalse(didCreateDrafts)

        XCTAssertFalse(viewModel.isRecognizingPurchaseBill)
        XCTAssertEqual(viewModel.purchaseBillDrafts, [])
        XCTAssertEqual(
            viewModel.errorMessage,
            "The bill photo could not be read. Try another photo or enter the bill text manually."
        )
    }

    func testSavePurchaseBillDraftsPersistsSelectedDraftsWithStockBatches() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        let expiry = Date(timeIntervalSince1970: 1_800_116_400)
        var ids = ["inventory-flour", "batch-flour"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.purchaseBillDrafts = [
            PurchaseBillInventoryDraft(
                id: "draft-flour",
                sourceLine: "Cake Flour 1 kg",
                name: "Cake Flour",
                quantityText: "1",
                unit: .kilogram,
                minimumQuantityText: "0.5",
                expiryDate: expiry,
                isSelected: true
            ),
            PurchaseBillInventoryDraft(
                id: "draft-butter",
                sourceLine: "Butter 500 g",
                name: "Butter",
                quantityText: "500",
                unit: .gram,
                minimumQuantityText: "0",
                expiryDate: expiry,
                isSelected: false
            )
        ]

        XCTAssertTrue(viewModel.savePurchaseBillDrafts())

        XCTAssertEqual(
            repository.items,
            [
                InventoryItem(
                    id: "inventory-flour",
                    name: "Cake Flour",
                    unit: .kilogram,
                    currentQuantity: 1,
                    minimumQuantity: 0.5,
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
        XCTAssertEqual(
            repository.batches,
            [
                InventoryStockBatch(
                    id: "batch-flour",
                    inventoryItemId: "inventory-flour",
                    remainingQuantity: 1,
                    expiresAt: expiry,
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
        XCTAssertEqual(viewModel.purchaseBillDrafts.count, 2)
        XCTAssertEqual(viewModel.items, repository.items)
    }

    func testSavePurchaseBillDraftsRejectsInvalidQuantityWithoutSaving() {
        let repository = FakeInventoryItemRepository()
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.purchaseBillDrafts = [
            PurchaseBillInventoryDraft(
                id: "draft-flour",
                sourceLine: "Cake Flour",
                name: "Cake Flour",
                quantityText: "",
                unit: .gram,
                minimumQuantityText: "0",
                expiryDate: Date(timeIntervalSince1970: 1_800_116_400),
                isSelected: true
            )
        ]

        XCTAssertFalse(viewModel.savePurchaseBillDrafts())

        XCTAssertEqual(viewModel.errorMessage, "Draft quantity must be zero or greater.")
        XCTAssertEqual(repository.items, [])
        XCTAssertEqual(repository.batches, [])
    }
}

private struct FakePurchaseBillTextRecognizer: PurchaseBillTextRecognizing {
    let result: Result<String, Error>

    func recognizedText(from image: CGImage) async throws -> String {
        try result.get()
    }
}

private func makeTestCGImage() throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ),
    let image = context.makeImage() else {
        throw TestImageError.unavailable
    }

    return image
}

private enum TestImageError: Error {
    case unavailable
}

private final class FakeInventoryItemRepository: InventoryItemRepository, InventoryTransactionRepository, InventoryStockBatchRepository {
    var items: [InventoryItem] = []
    var transactions: [InventoryTransaction] = []
    var batches: [InventoryStockBatch] = []

    func save(_ item: InventoryItem) throws {
        if let existingIndex = items.firstIndex(where: { $0.id == item.id }) {
            items[existingIndex] = item
        } else {
            items.append(item)
        }
    }

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        items.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        items.filter { !$0.isArchived }
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        items.filter(\.isArchived)
    }

    func save(_ transaction: InventoryTransaction) throws {
        if let existingIndex = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[existingIndex] = transaction
        } else {
            transactions.append(transaction)
        }
    }

    func fetchInventoryTransaction(id: String) throws -> InventoryTransaction? {
        transactions.first { $0.id == id }
    }

    func fetchInventoryTransactions(inventoryItemId: String) throws -> [InventoryTransaction] {
        transactions
            .filter { $0.inventoryItemId == inventoryItemId }
            .sorted {
                if $0.occurredAt == $1.occurredAt {
                    return $0.createdAt > $1.createdAt
                }

                return $0.occurredAt > $1.occurredAt
            }
    }

    func save(_ batch: InventoryStockBatch) throws {
        if let existingIndex = batches.firstIndex(where: { $0.id == batch.id }) {
            batches[existingIndex] = batch
        } else {
            batches.append(batch)
        }
    }

    func fetchInventoryStockBatches(inventoryItemId: String) throws -> [InventoryStockBatch] {
        batches
            .filter { $0.inventoryItemId == inventoryItemId }
            .sorted {
                switch ($0.expiresAt, $1.expiresAt) {
                case let (.some(left), .some(right)):
                    if left == right {
                        return $0.createdAt < $1.createdAt
                    }

                    return left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return $0.createdAt < $1.createdAt
                }
            }
    }
}

private let purchaseBillCatalog = [
    BakingCatalogItem(
        name: "Cake Flour",
        aliases: ["flour"],
        category: "Ingredient",
        active: true
    ),
    BakingCatalogItem(
        name: "Butter",
        aliases: ["unsalted butter"],
        category: "Ingredient",
        active: true
    )
]
