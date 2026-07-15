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

    func testLoadMovesLowAndExpiredInventoryToTop() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_020_000)
        let normal = InventoryItem(
            id: "inventory-normal",
            name: "Vanilla extract",
            unit: .milliliter,
            currentQuantity: 750,
            minimumQuantity: 250,
            createdAt: now,
            updatedAt: now
        )
        let expiringSoon = InventoryItem(
            id: "inventory-expiring",
            name: "Butter",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 250,
            earliestExpiryAt: now.addingTimeInterval(86_400),
            hasExpiringSoonStock: true,
            createdAt: now,
            updatedAt: now
        )
        let lowStock = InventoryItem(
            id: "inventory-low",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 500,
            createdAt: now,
            updatedAt: now
        )
        let expired = InventoryItem(
            id: "inventory-expired",
            name: "Cream",
            unit: .milliliter,
            currentQuantity: 500,
            minimumQuantity: 250,
            earliestExpiryAt: now.addingTimeInterval(-86_400),
            hasExpiredStock: true,
            createdAt: now,
            updatedAt: now
        )
        repository.items = [normal, expiringSoon, lowStock, expired]
        let viewModel = InventoryListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.items.map(\.id), [
            "inventory-expired",
            "inventory-low",
            "inventory-expiring",
            "inventory-normal"
        ])
    }

    func testVisibleItemsFilterBySearchTextAndKeepAttentionOrder() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_020_000)
        let normalFlour = InventoryItem(
            id: "inventory-normal-flour",
            name: "Bread flour",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 250,
            createdAt: now,
            updatedAt: now
        )
        let lowFlour = InventoryItem(
            id: "inventory-low-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 500,
            createdAt: now,
            updatedAt: now
        )
        let sugar = InventoryItem(
            id: "inventory-sugar",
            name: "Caster sugar",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 250,
            createdAt: now,
            updatedAt: now
        )
        repository.items = [normalFlour, sugar, lowFlour]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()

        viewModel.searchText = " flour "

        XCTAssertEqual(viewModel.visibleItems.map(\.id), [
            "inventory-low-flour",
            "inventory-normal-flour"
        ])
    }

    func testVisibleItemsFilterByLowStock() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_020_000)
        let lowStock = InventoryItem(
            id: "inventory-low",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 500,
            createdAt: now,
            updatedAt: now
        )
        let healthy = InventoryItem(
            id: "inventory-healthy",
            name: "Caster sugar",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 250,
            createdAt: now,
            updatedAt: now
        )
        repository.items = [healthy, lowStock]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()

        viewModel.itemFilter = .lowStock

        XCTAssertEqual(viewModel.visibleItems, [lowStock])
    }

    func testVisibleItemsFilterByExpiringSoonAndExpiredStock() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_020_000)
        let expiringSoon = InventoryItem(
            id: "inventory-expiring",
            name: "Butter",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 250,
            earliestExpiryAt: now.addingTimeInterval(86_400),
            hasExpiringSoonStock: true,
            createdAt: now,
            updatedAt: now
        )
        let expired = InventoryItem(
            id: "inventory-expired",
            name: "Cream",
            unit: .milliliter,
            currentQuantity: 500,
            minimumQuantity: 250,
            earliestExpiryAt: now.addingTimeInterval(-86_400),
            hasExpiredStock: true,
            createdAt: now,
            updatedAt: now
        )
        let healthy = InventoryItem(
            id: "inventory-healthy",
            name: "Caster sugar",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 250,
            createdAt: now,
            updatedAt: now
        )
        repository.items = [healthy, expiringSoon, expired]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()

        viewModel.itemFilter = .expiringSoon

        XCTAssertEqual(viewModel.visibleItems, [expired, expiringSoon])
    }

    func testItemDraftCanSubmitOnlyWhenRequiredQuantitiesAreValid() {
        let viewModel = InventoryListViewModel(repository: FakeInventoryItemRepository())

        XCTAssertFalse(viewModel.canSubmitItemDraft(requiresCurrentQuantity: true))

        viewModel.draftName = "Butter"
        viewModel.draftMinimumQuantity = "250"
        XCTAssertFalse(viewModel.canSubmitItemDraft(requiresCurrentQuantity: true))
        XCTAssertTrue(viewModel.canSubmitItemDraft(requiresCurrentQuantity: false))

        viewModel.draftCurrentQuantity = "-1"
        XCTAssertFalse(viewModel.canSubmitItemDraft(requiresCurrentQuantity: true))

        viewModel.draftCurrentQuantity = "100"
        XCTAssertTrue(viewModel.canSubmitItemDraft(requiresCurrentQuantity: true))

        viewModel.draftAmount = "-3"
        XCTAssertFalse(viewModel.canSubmitItemDraft(requiresCurrentQuantity: true))
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

    func testAddItemPersistsCleanedAliases() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { "inventory-flour" },
            dateProvider: { now }
        )
        viewModel.draftName = "Cake Flour"
        viewModel.draftAliases = "Maida, Aashirvaad Maida\nmaida"
        viewModel.draftCurrentQuantity = "100"
        viewModel.draftMinimumQuantity = "250"

        XCTAssertTrue(viewModel.addItem())

        XCTAssertEqual(repository.items.first?.aliases, ["Maida", "Aashirvaad Maida"])
        XCTAssertEqual(viewModel.draftAliases, "")
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
        viewModel.draftHasExpiryDate = true
        viewModel.draftExpiryDate = expiresAt
        viewModel.draftAmount = "2.50"

        XCTAssertTrue(viewModel.addItem())

        XCTAssertEqual(
            repository.batches,
            [
                InventoryStockBatch(
                    id: "batch-butter-initial",
                    inventoryItemId: "inventory-butter",
                    remainingQuantity: 100,
                    expiresAt: expiresAt,
                    amount: Decimal(string: "2.50"),
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
    }

    func testAddItemDefaultsInitialStockBatchToOneMonthExpiry() {
        let repository = FakeInventoryItemRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        var ids = ["inventory-sugar", "batch-sugar-initial"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.draftName = "Sugar"
        viewModel.draftCurrentQuantity = "100"
        viewModel.draftMinimumQuantity = "250"

        XCTAssertTrue(viewModel.draftHasExpiryDate)
        XCTAssertEqual(viewModel.draftExpiryDate, calendar.date(byAdding: .month, value: 1, to: now))
        XCTAssertTrue(viewModel.addItem())

        XCTAssertEqual(repository.batches.first?.expiresAt, calendar.date(byAdding: .month, value: 1, to: now))
    }

    func testAddItemUsesAndPersistsCustomDefaultExpiryDays() {
        let repository = FakeInventoryItemRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        var ids = ["inventory-flour", "batch-flour-initial"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.draftName = "Flour"
        viewModel.draftCurrentQuantity = "100"
        viewModel.draftMinimumQuantity = "25"
        viewModel.draftDefaultExpiryDays = "180"
        viewModel.updateDraftExpiryFromDefault()

        XCTAssertEqual(viewModel.draftExpiryDate, calendar.date(byAdding: .day, value: 180, to: now))
        XCTAssertTrue(viewModel.addItem())
        XCTAssertEqual(repository.items.first?.defaultExpiryDays, 180)
        XCTAssertEqual(repository.batches.first?.expiresAt, calendar.date(byAdding: .day, value: 180, to: now))
    }

    func testAddItemRejectsInvalidDefaultExpiryDays() {
        let viewModel = InventoryListViewModel(repository: FakeInventoryItemRepository())
        viewModel.draftName = "Flour"
        viewModel.draftCurrentQuantity = "100"
        viewModel.draftMinimumQuantity = "25"
        viewModel.draftDefaultExpiryDays = "1.5"

        XCTAssertFalse(viewModel.canSubmitItemDraft(requiresCurrentQuantity: true))
        XCTAssertFalse(viewModel.addItem())
        XCTAssertEqual(viewModel.errorMessage, "Default expiry days must be a whole number greater than zero.")
    }

    func testEditingItemUpdatesDefaultExpiryDaysWithoutChangingExistingBatchExpiry() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        let existingExpiry = Date(timeIntervalSince1970: 1_800_116_400)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Flour",
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 25,
            earliestExpiryAt: existingExpiry,
            createdAt: now,
            updatedAt: now
        )
        repository.items = [item]
        let viewModel = InventoryListViewModel(repository: repository, dateProvider: { now })

        viewModel.beginEditing(item)
        viewModel.draftDefaultExpiryDays = "90"

        XCTAssertTrue(viewModel.saveEditedItem())
        XCTAssertEqual(repository.items.first?.defaultExpiryDays, 90)
        XCTAssertEqual(repository.items.first?.earliestExpiryAt, existingExpiry)
    }

    func testBeginAddingClearsAPreviouslyDismissedEditDraft() {
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Flour",
            defaultExpiryDays: 45,
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 25,
            createdAt: now,
            updatedAt: now
        )
        let viewModel = InventoryListViewModel(repository: FakeInventoryItemRepository(), dateProvider: { now })

        viewModel.beginEditing(item)
        viewModel.beginAdding()

        XCTAssertEqual(viewModel.draftName, "")
        XCTAssertEqual(viewModel.draftDefaultExpiryDays, "")
        XCTAssertEqual(viewModel.draftCurrentQuantity, "")
        XCTAssertEqual(viewModel.draftMinimumQuantity, "")
        XCTAssertNil(viewModel.editingItem)
    }

    func testStockAdjustmentUsesItemDefaultExpiryDays() {
        let repository = FakeInventoryItemRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        let item = InventoryItem(
            id: "inventory-strawberry",
            name: "Strawberry",
            type: .perishable,
            defaultExpiryDays: 2,
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 25,
            createdAt: now,
            updatedAt: now
        )
        let viewModel = InventoryListViewModel(repository: repository, dateProvider: { now })

        viewModel.beginAdjusting(item)

        XCTAssertTrue(viewModel.draftAdjustmentHasExpiryDate)
        XCTAssertEqual(viewModel.draftAdjustmentExpiryDate, calendar.date(byAdding: .day, value: 2, to: now))
    }

    func testAddItemCanStoreInitialStockBatchWithoutExpiry() {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_030_000)
        var ids = ["inventory-sugar", "batch-sugar-initial"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.draftName = "Sugar"
        viewModel.draftCurrentQuantity = "100"
        viewModel.draftMinimumQuantity = "250"
        viewModel.draftHasExpiryDate = false

        XCTAssertTrue(viewModel.addItem())

        XCTAssertEqual(repository.batches.first?.expiresAt, nil)
    }

    func testSelectingPerishableDefaultsExpiryToFourDays() {
        let repository = FakeInventoryItemRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        let viewModel = InventoryListViewModel(
            repository: repository,
            dateProvider: { now }
        )

        viewModel.selectDraftType(.perishable)

        XCTAssertEqual(viewModel.draftType, .perishable)
        XCTAssertTrue(viewModel.draftHasExpiryDate)
        XCTAssertEqual(viewModel.draftExpiryDate, calendar.date(byAdding: .day, value: 4, to: now))
    }

    func testSelectingStandardDefaultsExpiryToOneMonth() {
        let repository = FakeInventoryItemRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        let viewModel = InventoryListViewModel(
            repository: repository,
            dateProvider: { now }
        )
        viewModel.selectDraftType(.perishable)

        viewModel.selectDraftType(.standard)

        XCTAssertEqual(viewModel.draftType, .standard)
        XCTAssertTrue(viewModel.draftHasExpiryDate)
        XCTAssertEqual(viewModel.draftExpiryDate, calendar.date(byAdding: .month, value: 1, to: now))
    }

    func testAddItemPersistsPerishableTypeAndFourDayExpiry() {
        let repository = FakeInventoryItemRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        var ids = ["inventory-strawberry", "batch-strawberry-initial"]
        let viewModel = InventoryListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.draftName = "Strawberry"
        viewModel.draftCurrentQuantity = "10"
        viewModel.draftMinimumQuantity = "5"
        viewModel.selectDraftType(.perishable)

        XCTAssertTrue(viewModel.addItem())

        XCTAssertEqual(repository.items.first?.type, .perishable)
        XCTAssertEqual(repository.batches.first?.expiresAt, calendar.date(byAdding: .day, value: 4, to: now))
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

    func testDeleteItemRemovesInventoryFromActiveAndArchivedCollections() {
        let active = InventoryItem(
            id: "inventory-unused",
            name: "Unused decoration",
            unit: .each,
            currentQuantity: 0,
            minimumQuantity: 0,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        let repository = FakeInventoryItemRepository()
        repository.items = [active]
        let viewModel = InventoryListViewModel(repository: repository)
        viewModel.load()

        XCTAssertTrue(viewModel.deleteItem(active))

        XCTAssertTrue(repository.items.isEmpty)
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertTrue(viewModel.archivedItems.isEmpty)
    }

    func testDeleteItemExplainsWhenHistoricalDependenciesRequireArchiving() {
        let item = InventoryItem(
            id: "inventory-used",
            name: "Used flour",
            unit: .gram,
            currentQuantity: 0,
            minimumQuantity: 0,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        let repository = FakeInventoryItemRepository()
        repository.items = [item]
        repository.inventoryItemDeletionError = InventoryItemDeletionError.inUse
        let viewModel = InventoryListViewModel(repository: repository)

        XCTAssertFalse(viewModel.deleteItem(item))

        XCTAssertEqual(repository.items, [item])
        XCTAssertEqual(
            viewModel.errorMessage,
            "This inventory item is used by stock history, a recipe, or an order. Archive it instead to preserve those records."
        )
    }

}
