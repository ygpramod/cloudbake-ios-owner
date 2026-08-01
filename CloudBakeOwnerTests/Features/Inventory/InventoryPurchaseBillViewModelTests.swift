import XCTest

@testable import CloudBakeOwner

@MainActor
extension InventoryListViewModelTests {
    func testCreatePurchaseBillDraftsFromRecognizedText() {
        var ids = ["draft-flour", "draft-detergent", "draft-butter"]
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

        XCTAssertEqual(viewModel.purchaseBillDrafts.map(\.id), idsForExpectedPurchaseBillDrafts)
        XCTAssertEqual(
            viewModel.purchaseBillDrafts.map(\.name),
            ["Cake Flour", "Laundry Detergent", "Butter"]
        )
        XCTAssertEqual(viewModel.purchaseBillDrafts.map(\.quantityText), ["1", "1", "500"])
        XCTAssertEqual(viewModel.purchaseBillDrafts.map(\.unit), [.kilogram, .liter, .gram])
        XCTAssertEqual(viewModel.purchaseBillDrafts.map(\.destination), [.newItem, .newItem, .newItem])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testCreatePurchaseBillDraftsMarksExistingInventoryMatches() {
        let repository = FakeInventoryItemRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        let existingItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            defaultExpiryDays: 45,
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 250,
            createdAt: now,
            updatedAt: now
        )
        repository.items = [existingItem]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "draft-flour" },
            dateProvider: { now }
        )
        viewModel.load()
        viewModel.purchaseBillRecognizedText = "Cake Flour 1 kg"

        XCTAssertTrue(viewModel.createPurchaseBillDrafts(catalog: purchaseBillCatalog))

        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.matchedInventoryItemId, "inventory-flour")
        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.matchedInventoryItemName, "Cake flour")
        XCTAssertEqual(
            viewModel.purchaseBillDrafts.first?.expiryDate,
            calendar.date(byAdding: .day, value: 45, to: now)
        )
    }

    func testCreatePurchaseBillDraftsUsesInventoryAliases() {
        var ids = ["draft-flour"]
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake Flour",
                aliases: ["Aashirvaad Maida", "Plain Flour"],
                unit: .gram,
                currentQuantity: 500,
                minimumQuantity: 250,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() }
        )
        viewModel.load()
        viewModel.purchaseBillRecognizedText = "Aashirvaad Maida 1 kg"

        XCTAssertTrue(viewModel.createPurchaseBillDrafts(catalog: []))

        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.name, "Cake Flour")
        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.matchedInventoryItemId, "inventory-flour")
        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.quantityText, "1")
        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.unit, .kilogram)
    }

    func testExactOwnerOCRIncludesMeasuredProductsAndDefaultsUncertainChargesOff() {
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-oreo",
                name: "Oreo",
                aliases: ["OREO S COOKIES VANILLA"],
                unit: .gram,
                currentQuantity: 200,
                minimumQuantity: 0,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        var draftNumber = 0
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: {
                draftNumber += 1
                return "draft-\(draftNumber)"
            }
        )
        viewModel.load()
        viewModel.purchaseBillRecognizedText = exactOwnerOCRProductText

        XCTAssertTrue(viewModel.createPurchaseBillDrafts(catalog: []))

        XCTAssertEqual(viewModel.purchaseBillDrafts.count, 7)
        XCTAssertEqual(
            viewModel.purchaseBillDrafts.map(\.destination),
            [
                .newItem,
                .existingItem("inventory-oreo"),
                .newItem,
                .newItem,
                .newItem,
                .ignored,
                .newItem,
            ]
        )
        XCTAssertEqual(
            viewModel.purchaseBillDrafts.map(\.amountPaidText),
            ["4", "1.85", "3.15", "5.35", "3.95", "0.05", "6.9"]
        )
        XCTAssertTrue(viewModel.canSavePurchaseBillDrafts)
    }

    func testPurchaseBillDraftCanBeExcludedAndReincluded() {
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-oreo",
                name: "Oreo",
                aliases: ["OREO S COOKIES VANILLA"],
                unit: .gram,
                currentQuantity: 200,
                minimumQuantity: 0,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "draft-oreo" }
        )
        viewModel.load()
        viewModel.purchaseBillRecognizedText = "OREO S COOKIES VANILLA 105G 1.85"
        XCTAssertTrue(viewModel.createPurchaseBillDrafts(catalog: []))

        viewModel.ignorePurchaseBillDraft("draft-oreo")

        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.destination, .ignored)
        XCTAssertFalse(viewModel.canSavePurchaseBillDrafts)

        viewModel.refreshPurchaseBillDraftMatch(draftId: "draft-oreo")

        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.destination, .existingItem("inventory-oreo"))
        XCTAssertTrue(viewModel.canSavePurchaseBillDrafts)
    }

    func testMappedPurchaseBillDraftSavesReceiptAliasAndBatchAmount() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        repository.items = [
            InventoryItem(
                id: "inventory-garlic",
                name: "Garlic",
                unit: .gram,
                currentQuantity: 100,
                minimumQuantity: 20,
                createdAt: now,
                updatedAt: now
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "batch-garlic" },
            dateProvider: { now }
        )
        viewModel.load()
        viewModel.purchaseBillDrafts = [
            PurchaseBillInventoryDraft(
                id: "draft-garlic",
                sourceLine: "WHITE GARLIC CHINA 500G 3. 15",
                name: "White Garlic China",
                quantityText: "500",
                unit: .gram,
                minimumQuantityText: "0",
                expiryDate: Date(timeIntervalSince1970: 1_800_116_400),
                receiptName: "WHITE GARLIC CHINA",
                amountPaidText: "3.15"
            )
        ]

        viewModel.mapPurchaseBillDraft("draft-garlic", to: "inventory-garlic")
        XCTAssertTrue(viewModel.savePurchaseBillDrafts())

        XCTAssertEqual(repository.items.first?.currentQuantity, 600)
        XCTAssertEqual(repository.items.first?.aliases, ["WHITE GARLIC CHINA"])
        XCTAssertEqual(repository.batches.first?.amount, 3.15)
        XCTAssertEqual(repository.batches.first?.remainingQuantity, 500)
    }

    func testInventoryAliasMatchesBeforeBundledCatalog() {
        var ids = ["draft-flour"]
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-owner-flour",
                name: "Owner Cake Flour",
                aliases: ["Maida"],
                unit: .gram,
                currentQuantity: 500,
                minimumQuantity: 250,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() }
        )
        viewModel.load()
        viewModel.purchaseBillRecognizedText = "Maida 1 kg"

        XCTAssertTrue(
            viewModel.createPurchaseBillDrafts(
                catalog: [
                    BakingCatalogItem(
                        name: "Bundled Cake Flour",
                        aliases: ["maida"],
                        category: "Ingredient",
                        active: true
                    )
                ]
            )
        )

        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.name, "Owner Cake Flour")
        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.matchedInventoryItemId, "inventory-owner-flour")
    }

    func testPurchaseBillDraftDoesNotAutomaticallyMapAPartialInventoryName() {
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-garlic",
                name: "Garlic",
                unit: .gram,
                currentQuantity: 100,
                minimumQuantity: 0,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "draft-garlic" }
        )
        viewModel.load()
        viewModel.purchaseBillRecognizedText = "WHITE GARLIC CHINA 500G 3. 15"

        XCTAssertTrue(viewModel.createPurchaseBillDrafts(catalog: []))

        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.destination, .newItem)
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
                matchedInventoryItemId: "inventory-flour",
                matchedInventoryItemName: "Cake flour"
            )
        ]

        viewModel.purchaseBillDrafts[0].name = "Almond Meal"
        viewModel.refreshPurchaseBillDraftMatch(draftId: "draft-flour")

        XCTAssertNil(viewModel.purchaseBillDrafts.first?.matchedInventoryItemId)
        XCTAssertNil(viewModel.purchaseBillDrafts.first?.matchedInventoryItemName)
    }

    func testRefreshPurchaseBillDraftMatchAppliesMatchedItemDefaultExpiry() {
        let repository = FakeInventoryItemRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        repository.items = [
            InventoryItem(
                id: "inventory-strawberry",
                name: "Strawberry",
                defaultExpiryDays: 2,
                unit: .gram,
                currentQuantity: 0,
                minimumQuantity: 0,
                createdAt: now,
                updatedAt: now
            )
        ]
        let viewModel = InventoryListViewModel(repository: repository, dateProvider: { now })
        viewModel.load()
        viewModel.purchaseBillDrafts = [
            PurchaseBillInventoryDraft(
                id: "draft-strawberry",
                sourceLine: "Strawberries 100 g",
                name: "Strawberries",
                quantityText: "100",
                unit: .gram,
                minimumQuantityText: "0",
                expiryDate: calendar.date(byAdding: .month, value: 1, to: now)!
            )
        ]

        viewModel.purchaseBillDrafts[0].name = "Strawberry"
        viewModel.refreshPurchaseBillDraftMatch(draftId: "draft-strawberry")

        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.matchedInventoryItemId, "inventory-strawberry")
        XCTAssertEqual(
            viewModel.purchaseBillDrafts.first?.expiryDate,
            calendar.date(byAdding: .day, value: 2, to: now)
        )
    }

    func testRefreshPurchaseBillDraftMatchPreservesOwnerEditedExpiry() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        let ownerExpiry = Date(timeIntervalSince1970: 1_801_000_000)
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                defaultExpiryDays: 2,
                unit: .gram,
                currentQuantity: 0,
                minimumQuantity: 0,
                createdAt: now,
                updatedAt: now
            )
        ]
        let viewModel = InventoryListViewModel(repository: repository, dateProvider: { now })
        viewModel.load()
        viewModel.purchaseBillDrafts = [
            PurchaseBillInventoryDraft(
                id: "draft-flour",
                sourceLine: "Flour 100 g",
                name: "Cake flour",
                quantityText: "100",
                unit: .gram,
                minimumQuantityText: "0",
                expiryDate: ownerExpiry,
                expiryUsesDefault: false
            )
        ]

        viewModel.refreshPurchaseBillDraftMatch(draftId: "draft-flour")

        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.matchedInventoryItemId, "inventory-flour")
        XCTAssertEqual(viewModel.purchaseBillDrafts.first?.expiryDate, ownerExpiry)
    }

    func testCreatePurchaseBillDraftsShowsErrorWhenNoPurchaseItemsAreFound() {
        let viewModel = InventoryListViewModel(repository: FakeInventoryItemRepository())
        viewModel.purchaseBillRecognizedText = "GST M200010132 TAX Invoice"

        XCTAssertFalse(viewModel.createPurchaseBillDrafts(catalog: purchaseBillCatalog))

        XCTAssertEqual(viewModel.purchaseBillDrafts, [])
        XCTAssertEqual(viewModel.errorMessage, "No purchase items were found in the bill text.")
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
                expiryDate: Date(timeIntervalSince1970: 1_800_116_400)
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
                destination: .newItem
            ),
            PurchaseBillInventoryDraft(
                id: "draft-butter",
                sourceLine: "Butter 500 g",
                name: "Butter",
                quantityText: "500",
                unit: .gram,
                minimumQuantityText: "0",
                expiryDate: expiry,
                destination: .ignored
            ),
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

    func testSavePurchaseBillDraftsCanCreateStockWithoutExpiry() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
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
                minimumQuantityText: "0",
                expiryDate: Date(timeIntervalSince1970: 1_800_116_400),
                hasExpiryDate: false,
                expiryUsesDefault: false,
                destination: .newItem
            )
        ]

        XCTAssertTrue(viewModel.savePurchaseBillDrafts())

        XCTAssertNil(repository.batches.first?.expiresAt)
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
                destination: .newItem
            )
        ]

        XCTAssertFalse(viewModel.savePurchaseBillDrafts())

        XCTAssertEqual(viewModel.errorMessage, "Draft quantity must be greater than zero.")
        XCTAssertEqual(repository.items, [])
        XCTAssertEqual(repository.batches, [])
    }

    func testSavePurchaseBillDraftsAcceptsGroupedQuantities() {
        let repository = FakeInventoryItemRepository()
        var ids = ["inventory-flour", "batch-flour"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() }
        )
        viewModel.purchaseBillDrafts = [
            PurchaseBillInventoryDraft(
                id: "draft-flour",
                sourceLine: "Cake Flour 1,000 g",
                name: "Cake Flour",
                quantityText: "1,000",
                unit: .gram,
                minimumQuantityText: "2,000",
                expiryDate: Date(timeIntervalSince1970: 1_800_116_400),
                destination: .newItem
            )
        ]

        XCTAssertTrue(viewModel.savePurchaseBillDrafts())
        XCTAssertEqual(repository.items.first?.currentQuantity, 1_000)
        XCTAssertEqual(repository.items.first?.minimumQuantity, 2_000)
        XCTAssertEqual(repository.batches.first?.remainingQuantity, 1_000)
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
                destination: .existingItem("inventory-flour")
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
                destination: .existingItem("inventory-flour")
            ),
            PurchaseBillInventoryDraft(
                id: "draft-flour-two",
                sourceLine: "Cake Flour 500 g",
                name: "Cake Flour",
                quantityText: "500",
                unit: .gram,
                minimumQuantityText: "0",
                expiryDate: Date(timeIntervalSince1970: 1_800_202_800),
                destination: .existingItem("inventory-flour")
            ),
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
                destination: .existingItem("inventory-flour")
            )
        ]

        XCTAssertFalse(viewModel.savePurchaseBillDrafts())

        XCTAssertEqual(viewModel.errorMessage, "Draft unit must be compatible with Cake flour.")
        XCTAssertEqual(repository.items.first?.currentQuantity, 500)
        XCTAssertEqual(repository.batches, [])
    }
}

private let idsForExpectedPurchaseBillDrafts = [
    "draft-flour",
    "draft-detergent",
    "draft-butter",
]

private let exactOwnerOCRProductText = """
    CHIPSMORE DOUBLE CHOCO 135G
    2 4.00
    OREO S COOKIES VANILLA 105G
    1.85
    WHITE GARLIC CHINA 500G 3. 15
    DORITOS SPICY NACHO 190G 5.35
    RUSSET POTATO USA 800G 3.95
    PLASTIC BAG CHARGE 0.05
    MEIJI FRESH MILK 2L. 6.90
    PRICE OFF 0. 20-
    Total saving 0. 20-
    Total (SGD) INCL. GST 25. 05
    """

final class VoiceInventoryDraftParserTests: XCTestCase {
    func testParserAcceptsArbitraryItemsAcrossCommonSpeechSeparators() {
        XCTAssertEqual(
            VoiceInventoryDraftParser.items(
                from: "flour 800 grams, strawberry 100 g and cake box 2 pieces vanilla 50 ml"
            ),
            [
                ParsedVoiceInventoryItem(name: "flour", sourcePhrase: "flour 800 grams", quantity: 800, unit: .gram),
                ParsedVoiceInventoryItem(name: "strawberry", sourcePhrase: "strawberry 100 g", quantity: 100, unit: .gram),
                ParsedVoiceInventoryItem(name: "cake box", sourcePhrase: "cake box 2 pieces", quantity: 2, unit: .each),
                ParsedVoiceInventoryItem(name: "vanilla", sourcePhrase: "vanilla 50 ml", quantity: 50, unit: .milliliter),
            ]
        )
    }

    func testParserRejectsPhrasesWithoutACompletePositiveMeasurement() {
        XCTAssertEqual(VoiceInventoryDraftParser.items(from: "flour and strawberries"), [])
        XCTAssertEqual(VoiceInventoryDraftParser.items(from: "flour 0 grams"), [])
    }

    func testParserTreatsPausedUtteranceLinesAsSeparateItems() {
        XCTAssertEqual(
            VoiceInventoryDraftParser.items(
                from: "flour 800 grams\nstrawberry 100 grams"
            ),
            [
                ParsedVoiceInventoryItem(name: "flour", sourcePhrase: "flour 800 grams", quantity: 800, unit: .gram),
                ParsedVoiceInventoryItem(name: "strawberry", sourcePhrase: "strawberry 100 grams", quantity: 100, unit: .gram),
            ]
        )
    }
}

@MainActor
extension InventoryListViewModelTests {
    func testCreateVoiceInventoryDraftsMatchesExistingAndLeavesUnknownForDecision() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake Flour",
                aliases: ["Maida"],
                defaultExpiryDays: 45,
                unit: .gram,
                currentQuantity: 100,
                minimumQuantity: 25,
                createdAt: now,
                updatedAt: now
            )
        ]
        var ids = ["draft-flour", "draft-strawberry"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.load()
        viewModel.voiceInventoryTranscript = "Maida 800 grams, strawberry 100 grams"

        XCTAssertTrue(viewModel.createVoiceInventoryDrafts())

        XCTAssertEqual(
            viewModel.voiceInventoryDrafts.map(\.destination),
            [
                .existingItem("inventory-flour"),
                .unresolved,
            ])
        XCTAssertEqual(viewModel.voiceInventoryDrafts.map(\.showsMinimumQuantity), [false, true])
        XCTAssertEqual(
            viewModel.voiceInventoryDrafts[0].expiryDate,
            Calendar.current.date(byAdding: .day, value: 45, to: now)
        )
    }

    func testMappedVoiceDraftAddsSpokenNameAsAliasAndStock() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake Flour",
                aliases: ["Maida"],
                unit: .gram,
                currentQuantity: 100,
                minimumQuantity: 25,
                createdAt: now,
                updatedAt: now
            )
        ]
        var ids = ["draft-flour", "batch-flour"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.load()
        viewModel.voiceInventoryTranscript = "Plain Flour 800 grams"
        XCTAssertTrue(viewModel.createVoiceInventoryDrafts())

        viewModel.voiceInventoryDrafts[0].minimumQuantityText = "invalid"
        viewModel.mapVoiceInventoryDraft("draft-flour", to: "inventory-flour")
        XCTAssertFalse(viewModel.voiceInventoryDrafts[0].showsMinimumQuantity)
        XCTAssertTrue(viewModel.saveVoiceInventoryDrafts())

        XCTAssertEqual(repository.items.first?.aliases, ["Maida", "Plain Flour"])
        XCTAssertEqual(repository.items.first?.currentQuantity, 900)
        XCTAssertEqual(repository.items.first?.minimumQuantity, 25)
        XCTAssertEqual(repository.batches.first?.remainingQuantity, 800)
    }

    func testUnknownVoiceDraftCanCreateNewInventoryWithoutExpiry() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        var ids = ["draft-box", "inventory-box", "batch-box"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.voiceInventoryTranscript = "Cake box 2 pieces"
        XCTAssertTrue(viewModel.createVoiceInventoryDrafts())
        viewModel.resolveVoiceInventoryDraftAsNew("draft-box")
        viewModel.voiceInventoryDrafts[0].hasExpiryDate = false

        XCTAssertTrue(viewModel.saveVoiceInventoryDrafts())

        XCTAssertEqual(repository.items.first?.name, "Cake box")
        XCTAssertEqual(repository.items.first?.currentQuantity, 2)
        XCTAssertNil(repository.batches.first?.expiresAt)
    }

    func testVoiceDraftSaveAcceptsAGroupedQuantity() {
        let repository = FakeInventoryItemRepository()
        var ids = ["draft-sugar", "inventory-sugar", "batch-sugar"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() }
        )
        viewModel.voiceInventoryTranscript = "Sugar 1000 grams"
        XCTAssertTrue(viewModel.createVoiceInventoryDrafts())
        viewModel.voiceInventoryDrafts[0].quantityText = "1,000"
        viewModel.resolveVoiceInventoryDraftAsNew("draft-sugar")

        XCTAssertTrue(viewModel.saveVoiceInventoryDrafts())
        XCTAssertEqual(repository.items.first?.currentQuantity, 1_000)
        XCTAssertEqual(repository.batches.first?.remainingQuantity, 1_000)
    }

    func testVoiceDraftSaveRequiresUnknownItemDecision() {
        let viewModel = InventoryListViewModel(repository: FakeInventoryItemRepository())
        viewModel.voiceInventoryTranscript = "Strawberry 100 grams"
        XCTAssertTrue(viewModel.createVoiceInventoryDrafts())

        XCTAssertFalse(viewModel.saveVoiceInventoryDrafts())
        XCTAssertEqual(viewModel.errorMessage, "Choose whether each new item should be mapped or created.")
    }

    func testEditingMatchedVoiceDraftNameReevaluatesItsDestination() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake Flour",
                unit: .gram,
                currentQuantity: 100,
                minimumQuantity: 25,
                createdAt: now,
                updatedAt: now
            )
        ]
        let viewModel = InventoryListViewModel(repository: repository, idGenerator: { "draft-flour" })
        viewModel.load()
        viewModel.voiceInventoryTranscript = "Cake Flour 800 grams"
        XCTAssertTrue(viewModel.createVoiceInventoryDrafts())
        XCTAssertEqual(viewModel.voiceInventoryDrafts[0].destination, .existingItem("inventory-flour"))

        viewModel.updateVoiceInventoryDraftName("draft-flour", name: "Almond Flour")

        XCTAssertEqual(viewModel.voiceInventoryDrafts[0].destination, .unresolved)
        XCTAssertFalse(viewModel.canSaveVoiceInventoryDrafts)
        XCTAssertFalse(viewModel.saveVoiceInventoryDrafts())
        XCTAssertEqual(repository.items[0].currentQuantity, 100)
        XCTAssertEqual(repository.items[0].aliases, [])
    }

    func testVoiceDraftRequiresDecisionForAmbiguousExactAlias() {
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-cake-flour",
                name: "Cake Flour",
                aliases: ["Bakers Flour"],
                unit: .gram,
                currentQuantity: 100,
                minimumQuantity: 25,
                createdAt: now,
                updatedAt: now
            ),
            InventoryItem(
                id: "inventory-bread-flour",
                name: "Bread Flour",
                aliases: ["Bakers Flour"],
                unit: .gram,
                currentQuantity: 100,
                minimumQuantity: 25,
                createdAt: now,
                updatedAt: now
            ),
        ]
        let viewModel = InventoryListViewModel(repository: repository, idGenerator: { "draft-flour" })
        viewModel.load()
        viewModel.voiceInventoryTranscript = "Bakers Flour 800 grams"

        XCTAssertTrue(viewModel.createVoiceInventoryDrafts())
        XCTAssertEqual(viewModel.voiceInventoryDrafts[0].destination, .unresolved)
        XCTAssertFalse(viewModel.canSaveVoiceInventoryDrafts)
    }

    func testVoiceInventoryImportRollsBackWhenAtomicSaveFails() {
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake Flour",
                unit: .gram,
                currentQuantity: 100,
                minimumQuantity: 25,
                createdAt: now,
                updatedAt: now
            )
        ]
        repository.shouldFailVoiceInventoryImportAfterItemSave = true
        var ids = ["draft-flour", "batch-flour"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.load()
        viewModel.voiceInventoryTranscript = "Cake Flour 800 grams"
        XCTAssertTrue(viewModel.createVoiceInventoryDrafts())

        XCTAssertFalse(viewModel.saveVoiceInventoryDrafts())

        XCTAssertEqual(repository.items[0].currentQuantity, 100)
        XCTAssertEqual(repository.items[0].aliases, [])
        XCTAssertEqual(repository.batches, [])
    }
}

@MainActor
private final class FakeVoiceInventorySpeechRecognizer: VoiceInventorySpeechRecognizing {
    var permissionContinuation: CheckedContinuation<Bool, Never>?
    var onPermissionRequest: (() -> Void)?
    var onStart: (() -> Void)?
    var startCount = 0
    var stopCount = 0
    var rebasedTranscript: String?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            permissionContinuation = continuation
            onPermissionRequest?()
        }
    }

    func start(
        onTranscript: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (VoiceInventoryRecognitionError) -> Void
    ) throws {
        startCount += 1
        onStart?()
    }

    func stop() {
        stopCount += 1
    }

    func rebaseTranscript(to transcript: String) {
        rebasedTranscript = transcript
    }

    func completePermission(_ allowed: Bool) {
        permissionContinuation?.resume(returning: allowed)
        permissionContinuation = nil
    }
}

@MainActor
final class VoiceInventoryRecognitionSessionTests: XCTestCase {
    func testStoppingWhilePermissionIsPendingPreventsRecordingFromStarting() async {
        let recognizer = FakeVoiceInventorySpeechRecognizer()
        let session = VoiceInventoryRecognitionSession(recognizer: recognizer)
        let permissionRequested = expectation(description: "Permission requested")
        recognizer.onPermissionRequest = { permissionRequested.fulfill() }
        session.start(onTranscript: { _ in })
        await fulfillment(of: [permissionRequested], timeout: 1)

        session.stop()
        recognizer.completePermission(true)
        await Task.yield()

        XCTAssertEqual(recognizer.startCount, 0)
        XCTAssertEqual(recognizer.stopCount, 1)
        XCTAssertFalse(session.isListening)
        XCTAssertFalse(session.isRequestingPermission)
    }

    func testSessionStopsTheSameRecognizerThatItStarted() async {
        let recognizer = FakeVoiceInventorySpeechRecognizer()
        let session = VoiceInventoryRecognitionSession(recognizer: recognizer)
        let permissionRequested = expectation(description: "Permission requested")
        let recognitionStarted = expectation(description: "Recognition started")
        recognizer.onPermissionRequest = { permissionRequested.fulfill() }
        recognizer.onStart = { recognitionStarted.fulfill() }
        session.start(baselineTranscript: "Edited sugar 300 g", onTranscript: { _ in })
        await fulfillment(of: [permissionRequested], timeout: 1)
        recognizer.completePermission(true)
        await fulfillment(of: [recognitionStarted], timeout: 1)

        XCTAssertEqual(recognizer.rebasedTranscript, "Edited sugar 300 g")
        session.stop()

        XCTAssertEqual(recognizer.startCount, 1)
        XCTAssertEqual(recognizer.stopCount, 1)
        XCTAssertFalse(session.isListening)
    }

    func testSessionRebasesTheRecognizerToTheEditedTranscript() {
        let recognizer = FakeVoiceInventorySpeechRecognizer()
        let session = VoiceInventoryRecognitionSession(recognizer: recognizer)

        session.rebaseTranscript(to: "Edited sugar 300 g")

        XCTAssertEqual(recognizer.rebasedTranscript, "Edited sugar 300 g")
    }
}

final class VoiceInventoryTranscriptAccumulatorTests: XCTestCase {
    func testRevisedPartialResultReplacesTheCurrentUtterance() {
        var accumulator = VoiceInventoryTranscriptAccumulator()

        XCTAssertEqual(
            accumulator.merge([
                segment("flour", at: 0, duration: 0.3),
                segment("800", at: 0.4, duration: 0.2),
            ]),
            "flour 800"
        )
        XCTAssertEqual(
            accumulator.merge([
                segment("flour", at: 0, duration: 0.3),
                segment("800", at: 0.4, duration: 0.2),
                segment("grams", at: 0.7, duration: 0.3),
            ]),
            "flour 800 grams"
        )
    }

    func testNewUtteranceAfterSilenceAppendsToTheExistingTranscript() {
        var accumulator = VoiceInventoryTranscriptAccumulator()
        _ = accumulator.merge([
            segment("flour", at: 0, duration: 0.3),
            segment("800", at: 0.4, duration: 0.2),
            segment("grams", at: 0.7, duration: 0.3),
        ])

        XCTAssertEqual(
            accumulator.merge([
                segment("strawberry", at: 2.2, duration: 0.5),
                segment("100", at: 2.8, duration: 0.2),
                segment("grams", at: 3.1, duration: 0.3),
            ]),
            "flour 800 grams\nstrawberry 100 grams"
        )
    }

    func testRepeatedFinalUtteranceIsNotDuplicatedAndResetSpeechAppends() {
        var accumulator = VoiceInventoryTranscriptAccumulator()
        _ = accumulator.merge([
            segment("flour", at: 0, duration: 0.3),
            segment("800", at: 0.4, duration: 0.2),
            segment("grams", at: 0.7, duration: 0.3),
        ])

        XCTAssertEqual(
            accumulator.merge(
                [
                    segment("flour", at: 1.5, duration: 0.3),
                    segment("800", at: 1.9, duration: 0.2),
                    segment("grams", at: 2.2, duration: 0.3),
                ],
                isFinal: true
            ),
            "flour 800 grams"
        )
        XCTAssertEqual(
            accumulator.merge([
                segment("strawberry", at: 0, duration: 0.5),
                segment("100", at: 0.6, duration: 0.2),
                segment("grams", at: 0.9, duration: 0.3),
            ]),
            "flour 800 grams\nstrawberry 100 grams"
        )
    }

    func testRepeatedShiftedSnapshotMarksPauseWithoutFinalResult() {
        var accumulator = VoiceInventoryTranscriptAccumulator()
        _ = accumulator.merge([
            segment("flour", at: 0, duration: 0.3),
            segment("800", at: 0.4, duration: 0.2),
        ])
        XCTAssertEqual(
            accumulator.merge([
                segment("flour", at: 1.5, duration: 0.3),
                segment("800", at: 1.9, duration: 0.2),
            ]),
            "flour 800"
        )

        XCTAssertEqual(
            accumulator.merge([
                segment("sugar", at: 0, duration: 0.3),
                segment("100", at: 0.4, duration: 0.2),
            ]),
            "flour 800\nsugar 100"
        )
    }

    func testFullSnapshotCorrectionReplacesTheActiveUtterance() {
        var accumulator = VoiceInventoryTranscriptAccumulator()
        _ = accumulator.merge([
            segment("flower", at: 0, duration: 0.3),
            segment("800", at: 0.4, duration: 0.2),
        ])

        XCTAssertEqual(
            accumulator.merge([
                segment("flour", at: 0, duration: 0.3),
                segment("800", at: 0.4, duration: 0.2),
                segment("grams", at: 0.7, duration: 0.3),
            ]),
            "flour 800 grams"
        )
    }

    func testFinalCorrectionReplacesAndCompletesTheActiveUtterance() {
        var accumulator = VoiceInventoryTranscriptAccumulator()
        _ = accumulator.merge([
            segment("flour", at: 0, duration: 0.3),
            segment("eight", at: 0.4, duration: 0.2),
        ])

        XCTAssertEqual(
            accumulator.merge(
                [
                    segment("flour", at: 0, duration: 0.3),
                    segment("800", at: 0.4, duration: 0.2),
                ],
                isFinal: true
            ),
            "flour 800"
        )
        XCTAssertEqual(
            accumulator.merge([
                segment("sugar", at: 0, duration: 0.3),
                segment("100", at: 0.4, duration: 0.2),
            ]),
            "flour 800\nsugar 100"
        )
    }

    func testSplitNumericCorrectionCreatesTheExpectedDraft() {
        var accumulator = VoiceInventoryTranscriptAccumulator()
        _ = accumulator.merge([
            segment("Sugar", at: 0, duration: 0.3),
            segment("three", at: 0.4, duration: 0.3),
        ])

        let transcript = accumulator.merge([
            segment("Sugar", at: 0, duration: 0.3),
            segment("3", at: 0.4, duration: 0.1),
            segment("00", at: 0.55, duration: 0.15),
            segment("g", at: 0.8, duration: 0.1),
        ])

        XCTAssertEqual(transcript, "Sugar 300 g")
        XCTAssertEqual(
            VoiceInventoryDraftParser.items(from: transcript),
            [
                ParsedVoiceInventoryItem(
                    name: "Sugar",
                    sourcePhrase: "Sugar 300 g",
                    quantity: 300,
                    unit: .gram
                )
            ]
        )
    }

    func testEditedTranscriptBecomesTheBaselineForLaterSpeech() {
        var accumulator = VoiceInventoryTranscriptAccumulator()
        _ = accumulator.merge(
            [
                segment("Sugar", at: 0, duration: 0.3),
                segment("3", at: 0.4, duration: 0.1),
                segment("00", at: 0.55, duration: 0.15),
                segment("g", at: 0.8, duration: 0.1),
            ]
        )
        accumulator.rebase(to: "Brown sugar 250 g")

        XCTAssertEqual(
            accumulator.merge([
                segment("Sugar", at: 0, duration: 0.3),
                segment("300", at: 0.4, duration: 0.2),
                segment("g", at: 0.7, duration: 0.1),
                segment("Flour", at: 1.7, duration: 0.3),
                segment("800", at: 2.1, duration: 0.2),
                segment("g", at: 2.4, duration: 0.1),
            ]),
            "Brown sugar 250 g\nFlour 800 g"
        )
    }

    func testLexicalCorrectionBeforeNewSpeechPreservesTheEditedBaseline() {
        var accumulator = VoiceInventoryTranscriptAccumulator()
        _ = accumulator.merge([
            segment("Sugar", at: 0, duration: 0.3),
            segment("three", at: 0.4, duration: 0.3),
        ])
        accumulator.rebase(to: "Brown sugar 250 g")

        XCTAssertEqual(
            accumulator.merge([
                segment("Sugar", at: 0, duration: 0.3),
                segment("3", at: 0.4, duration: 0.1),
                segment("00", at: 0.55, duration: 0.15),
                segment("g", at: 0.8, duration: 0.1),
                segment("Flour", at: 1.7, duration: 0.3),
                segment("800", at: 2.1, duration: 0.2),
                segment("g", at: 2.4, duration: 0.1),
            ]),
            "Brown sugar 250 g\nFlour 800 g"
        )
    }

    func testShorterStaleCallbackCannotReplaceAnEditedBaseline() {
        var accumulator = VoiceInventoryTranscriptAccumulator()
        _ = accumulator.merge([
            segment("Sugar", at: 0, duration: 0.3),
            segment("300", at: 0.4, duration: 0.2),
            segment("g", at: 0.7, duration: 0.1),
        ])
        accumulator.rebase(to: "Brown sugar 250 g")

        XCTAssertEqual(
            accumulator.merge([
                segment("Sugar", at: 0, duration: 0.3),
                segment("300", at: 0.4, duration: 0.2),
            ]),
            "Brown sugar 250 g"
        )
    }

    func testOverlappingRevisionReplacesOnlyTheAffectedSuffix() {
        var accumulator = VoiceInventoryTranscriptAccumulator()
        _ = accumulator.merge([
            segment("cake", at: 0, duration: 0.3),
            segment("flower", at: 0.4, duration: 0.4),
        ])

        XCTAssertEqual(
            accumulator.merge([
                segment("flour", at: 0.4, duration: 0.4),
                segment("800", at: 0.9, duration: 0.2),
                segment("grams", at: 1.2, duration: 0.3),
            ]),
            "cake flour 800 grams"
        )
    }

    func testParserNormalizesAPauseInsideAMultiWordItemName() {
        var accumulator = VoiceInventoryTranscriptAccumulator()
        _ = accumulator.merge([
            segment("cake", at: 0, duration: 0.3)
        ])
        let transcript = accumulator.merge([
            segment("flour", at: 1.2, duration: 0.3),
            segment("800", at: 1.6, duration: 0.2),
            segment("grams", at: 1.9, duration: 0.3),
        ])

        XCTAssertEqual(transcript, "cake\nflour 800 grams")
        XCTAssertEqual(
            VoiceInventoryDraftParser.items(from: transcript),
            [
                ParsedVoiceInventoryItem(
                    name: "cake flour",
                    sourcePhrase: "cake flour 800 grams",
                    quantity: 800,
                    unit: .gram
                )
            ]
        )
    }

    private func segment(
        _ text: String,
        at startTime: TimeInterval,
        duration: TimeInterval
    ) -> VoiceInventoryTranscriptionSegment {
        VoiceInventoryTranscriptionSegment(
            text: text,
            startTime: startTime,
            duration: duration
        )
    }
}
