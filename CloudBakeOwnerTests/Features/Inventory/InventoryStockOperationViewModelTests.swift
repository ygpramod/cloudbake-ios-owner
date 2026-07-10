import XCTest
@testable import CloudBakeOwner

@MainActor
final class InventoryStockOperationViewModelTests: XCTestCase {
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
        XCTAssertTrue(viewModel.draftAdjustmentHasExpiryDate)
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
        viewModel.draftAdjustmentHasExpiryDate = true
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

    func testRecordStockAdjustmentCombinesBatchWhenExpiryAndUnitCostMatch() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let adjustedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let expiry = Date(timeIntervalSince1970: 1_800_116_400)
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
                expiresAt: expiry,
                amount: Decimal(string: "2.50"),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        var ids = ["transaction-flour-adjustment", "batch-flour-adjustment"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { adjustedAt }
        )

        viewModel.beginAdjusting(item)
        viewModel.draftAdjustmentQuantity = "100"
        viewModel.draftAdjustmentHasExpiryDate = true
        viewModel.draftAdjustmentExpiryDate = expiry
        viewModel.draftAdjustmentAmount = "2.50"

        XCTAssertTrue(viewModel.recordStockAdjustment())

        XCTAssertEqual(repository.batches.count, 1)
        XCTAssertEqual(repository.batches[0].id, "batch-flour-initial")
        XCTAssertEqual(repository.batches[0].remainingQuantity, 350)
        XCTAssertEqual(repository.batches[0].amount, Decimal(string: "2.50"))
    }

    func testRecordStockAdjustmentKeepsSeparateBatchWhenUnitCostDiffers() {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let adjustedAt = Date(timeIntervalSince1970: 1_800_030_100)
        let expiry = Date(timeIntervalSince1970: 1_800_116_400)
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
                expiresAt: expiry,
                amount: Decimal(string: "2.50"),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        var ids = ["transaction-flour-adjustment", "batch-flour-adjustment"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { adjustedAt }
        )

        viewModel.beginAdjusting(item)
        viewModel.draftAdjustmentQuantity = "100"
        viewModel.draftAdjustmentHasExpiryDate = true
        viewModel.draftAdjustmentExpiryDate = expiry
        viewModel.draftAdjustmentAmount = "3.00"

        XCTAssertTrue(viewModel.recordStockAdjustment())

        XCTAssertEqual(repository.batches.count, 2)
        XCTAssertEqual(repository.batches.map(\.remainingQuantity), [250, 100])
        XCTAssertEqual(repository.batches.map(\.amount), [Decimal(string: "2.50"), Decimal(string: "3.00")])
    }

    func testRecordStockAdjustmentRefreshesSelectedItemDetailState() {
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
        var ids = ["transaction-flour-adjustment", "batch-flour-adjustment"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { adjustedAt }
        )
        viewModel.beginViewingItem(item)
        viewModel.beginAdjusting(item)
        viewModel.draftAdjustmentQuantity = "100"
        viewModel.draftAdjustmentHasExpiryDate = true
        viewModel.draftAdjustmentExpiryDate = Date(timeIntervalSince1970: 1_800_202_800)

        XCTAssertTrue(viewModel.recordStockAdjustment())

        XCTAssertEqual(viewModel.selectedItem?.currentQuantity, 350)
        XCTAssertEqual(viewModel.selectedItemBatches.map(\.remainingQuantity), [250, 100])
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
        var currentDate = adjustedAt
        var ids = ["transaction-flour-adjustment", "batch-flour-adjustment"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { currentDate }
        )
        viewModel.load()
        viewModel.beginAdjusting(item)
        viewModel.draftAdjustmentQuantity = "100"
        XCTAssertTrue(viewModel.recordStockAdjustment())

        currentDate = archivedAt
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

    func testRecordStockConsumptionRefreshesSelectedItemDetailState() {
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
        viewModel.beginViewingItem(item)
        viewModel.beginConsuming(item)
        viewModel.draftConsumptionQuantity = "100"

        XCTAssertTrue(viewModel.recordStockConsumption())

        XCTAssertEqual(viewModel.selectedItem?.currentQuantity, 250)
        XCTAssertEqual(viewModel.selectedItemBatches.map(\.remainingQuantity), [50, 200])
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
}
