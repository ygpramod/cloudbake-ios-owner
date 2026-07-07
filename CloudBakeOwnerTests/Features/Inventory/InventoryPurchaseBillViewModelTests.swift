import XCTest
@testable import CloudBakeOwner

@MainActor
extension InventoryListViewModelTests {
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

    func testCreatePurchaseBillDraftsMarksExistingInventoryMatches() {
        let repository = FakeInventoryItemRepository()
        let existingItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 250,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        repository.items = [existingItem]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "draft-flour" }
        )
        viewModel.load()
        viewModel.purchaseBillRecognizedText = "Cake Flour 1 kg"

        XCTAssertTrue(viewModel.createPurchaseBillDrafts(catalog: purchaseBillCatalog))

        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.matchedInventoryItemId, "inventory-flour")
        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.matchedInventoryItemName, "Cake flour")
    }

    func testRefreshPurchaseBillDraftMatchUpdatesAfterNameEdit() {
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 500,
                minimumQuantity: 250,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()
        viewModel.purchaseBillDrafts = [
            PurchaseBillInventoryDraft(
                id: "draft-flour",
                sourceLine: "Cake Flour 1 kg",
                name: "Cake Flour",
                quantityText: "1",
                unit: .kilogram,
                minimumQuantityText: "0",
                expiryDate: Date(timeIntervalSince1970: 1_800_116_400),
                isSelected: true,
                matchedInventoryItemId: "inventory-flour",
                matchedInventoryItemName: "Cake flour"
            )
        ]

        viewModel.purchaseBillDrafts[0].name = "Almond Meal"
        viewModel.refreshPurchaseBillDraftMatch(draftId: "draft-flour")

        XCTAssertNil(viewModel.purchaseBillDrafts.first?.matchedInventoryItemId)
        XCTAssertNil(viewModel.purchaseBillDrafts.first?.matchedInventoryItemName)
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

    func testSavePurchaseBillDraftsAddsMatchedDraftsToExistingInventory() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let expiry = Date(timeIntervalSince1970: 1_800_116_400)
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 500,
                minimumQuantity: 250,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "batch-flour" },
            dateProvider: { now }
        )
        viewModel.load()
        viewModel.purchaseBillDrafts = [
            PurchaseBillInventoryDraft(
                id: "draft-flour",
                sourceLine: "Cake Flour 1 kg",
                name: "Cake Flour",
                quantityText: "1",
                unit: .kilogram,
                minimumQuantityText: "0",
                expiryDate: expiry,
                isSelected: true
            )
        ]

        XCTAssertTrue(viewModel.savePurchaseBillDrafts())

        XCTAssertEqual(
            repository.items,
            [
                InventoryItem(
                    id: "inventory-flour",
                    name: "Cake flour",
                    unit: .gram,
                    currentQuantity: 1_500,
                    minimumQuantity: 250,
                    createdAt: createdAt,
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
                    remainingQuantity: 1_000,
                    expiresAt: expiry,
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
        XCTAssertEqual(viewModel.items, repository.items)
    }

    func testSavePurchaseBillDraftsAccumulatesMultipleDraftsForSameExistingInventory() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        var ids = ["batch-flour-one", "batch-flour-two"]
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 500,
                minimumQuantity: 250,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.load()
        viewModel.purchaseBillDrafts = [
            PurchaseBillInventoryDraft(
                id: "draft-flour-one",
                sourceLine: "Cake Flour 1 kg",
                name: "Cake Flour",
                quantityText: "1",
                unit: .kilogram,
                minimumQuantityText: "0",
                expiryDate: Date(timeIntervalSince1970: 1_800_116_400),
                isSelected: true
            ),
            PurchaseBillInventoryDraft(
                id: "draft-flour-two",
                sourceLine: "Cake Flour 500 g",
                name: "Cake Flour",
                quantityText: "500",
                unit: .gram,
                minimumQuantityText: "0",
                expiryDate: Date(timeIntervalSince1970: 1_800_202_800),
                isSelected: true
            )
        ]

        XCTAssertTrue(viewModel.savePurchaseBillDrafts())

        XCTAssertEqual(repository.items.first?.currentQuantity, 2_000)
        XCTAssertEqual(repository.batches.map(\.remainingQuantity), [1_000, 500])
    }

    func testSavePurchaseBillDraftsRejectsMatchedDraftWithIncompatibleUnit() {
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 500,
                minimumQuantity: 250,
                createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
        ]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()
        viewModel.purchaseBillDrafts = [
            PurchaseBillInventoryDraft(
                id: "draft-flour",
                sourceLine: "Cake Flour 1 L",
                name: "Cake Flour",
                quantityText: "1",
                unit: .liter,
                minimumQuantityText: "0",
                expiryDate: Date(timeIntervalSince1970: 1_800_116_400),
                isSelected: true
            )
        ]

        XCTAssertFalse(viewModel.savePurchaseBillDrafts())

        XCTAssertEqual(viewModel.errorMessage, "Draft unit must be compatible with Cake flour.")
        XCTAssertEqual(repository.items.first?.currentQuantity, 500)
        XCTAssertEqual(repository.batches, [])
    }
}
