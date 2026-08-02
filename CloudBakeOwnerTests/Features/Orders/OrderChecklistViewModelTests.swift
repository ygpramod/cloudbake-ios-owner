import XCTest

@testable import CloudBakeOwner

private enum OrderDuplicationTestError: Error {
    case requiredDataUnavailable
}

@MainActor
final class OrderChecklistViewModelTests: XCTestCase {
    func testPreviousOrderIdentifierPreparesDraftWithoutLeavingDetailOpen() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-previous",
            title: "Previous Birthday",
            customerId: "customer-amy",
            dueAt: Date(timeIntervalSince1970: 1_800_140_000),
            quotedPrice: 120,
            depositPaid: 40
        )
        repository.orders = [order]
        repository.customers = [makeCustomer(id: "customer-amy", name: "Amy")]
        let viewModel = OrderListViewModel(repository: repository)

        XCTAssertTrue(viewModel.beginDuplicatingOrder(id: order.id))

        XCTAssertNil(viewModel.selectedOrder)
        XCTAssertEqual(viewModel.draftTitle, "Previous Birthday")
        XCTAssertEqual(viewModel.draftCustomerId, "customer-amy")
        XCTAssertEqual(viewModel.draftStatus, .draft)
        XCTAssertEqual(viewModel.draftQuotedPrice, "")
        XCTAssertEqual(viewModel.draftDepositPaid, "")
    }

    func testPreviousOrderDuplicationPreservesDraftWhenRequiredDataCannotLoad() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-previous",
            title: "Previous Birthday",
            customerId: "customer-amy",
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        repository.orders = [order]
        repository.customers = [makeCustomer(id: "customer-amy", name: "Amy")]
        repository.fetchOrderChecklistItemsError = OrderDuplicationTestError.requiredDataUnavailable
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.beginAddingOrder()
        viewModel.draftTitle = "Unsaved New Order"

        XCTAssertFalse(viewModel.beginDuplicatingOrder(id: order.id))

        XCTAssertEqual(viewModel.draftTitle, "Unsaved New Order")
        XCTAssertNil(viewModel.selectedOrder)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Order could not be duplicated because its details could not be loaded."
        )
    }

    func testDuplicateOrderCreatesReviewableDraftWithoutTransactionalHistory() throws {
        let repository = FakeOrderRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 2, hour: 10, minute: 31)
        )!
        let source = Order(
            id: "order-source",
            customerId: "customer-amy",
            cakeDesignId: "design-floral",
            customerReferencePhotoId: "photo-customer-reference",
            recipeId: "recipe-vanilla",
            recipeScaleMultiplier: 2,
            title: "Floral Vanilla Cake",
            customerName: "Amy",
            status: .completed,
            dueAt: now.addingTimeInterval(-86_400),
            fulfillmentType: .delivery,
            deliveryAddress: "1 Bakery Street",
            cakeNotes: "Two tiers",
            cakeMessage: "Happy birthday",
            quotedPrice: 180,
            depositPaid: 80,
            paymentNotes: "Cash",
            completedAt: now.addingTimeInterval(-3_600),
            createdAt: now.addingTimeInterval(-172_800),
            updatedAt: now.addingTimeInterval(-3_600)
        )
        repository.orders = [source]
        repository.customers = [makeCustomer(id: "customer-amy", name: "Amy")]
        repository.recipes = [makeRecipe(id: "recipe-vanilla", name: "Vanilla")]
        repository.cakeDesigns = [makeCakeDesign(id: "design-floral", name: "Florals")]
        repository.inventoryItems = [makeInventoryItem(id: "inventory-berries", name: "Berries")]
        repository.extraIngredients = [
            OrderExtraIngredient(
                id: "extra-source",
                orderId: source.id,
                inventoryItemId: "inventory-berries",
                quantity: 120,
                unit: .gram,
                note: "Decoration",
                createdAt: source.createdAt,
                updatedAt: source.updatedAt
            )
        ]
        repository.checklistItems = [
            makeChecklistItem(
                id: "checklist-source",
                orderId: source.id,
                title: "Add topper",
                isCompleted: true
            )
        ]
        repository.orderReminderConfigurations[source.id] = try OrderReminderConfiguration(
            mode: .custom,
            dayOffsets: [5, 1],
            includesDueTime: false
        )
        repository.orderPhotos = [
            makeOrderPhoto(id: "order-photo", orderId: source.id, kind: .finalCake)
        ]
        repository.inventoryReservations = [
            OrderInventoryReservation(
                id: "reservation-source",
                orderId: source.id,
                inventoryItemId: "inventory-berries",
                requiredQuantity: 120,
                unit: .gram,
                createdAt: source.createdAt,
                updatedAt: source.updatedAt
            )
        ]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "duplicate"),
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.beginViewingOrder(source)

        XCTAssertTrue(viewModel.beginDuplicatingSelectedOrder())
        XCTAssertEqual(viewModel.draftTitle, source.title)
        XCTAssertEqual(viewModel.draftCustomerId, source.customerId)
        XCTAssertEqual(viewModel.draftRecipeId, source.recipeId)
        XCTAssertEqual(viewModel.draftRecipeScaleMultiplier, "2")
        XCTAssertEqual(viewModel.draftCakeDesignId, source.cakeDesignId)
        XCTAssertEqual(viewModel.draftFulfillmentType, .delivery)
        XCTAssertEqual(viewModel.draftDeliveryAddress, "1 Bakery Street")
        XCTAssertEqual(viewModel.draftCakeNotes, "Two tiers")
        XCTAssertEqual(viewModel.draftCakeMessage, "Happy birthday")
        XCTAssertEqual(viewModel.draftStatus, .draft)
        XCTAssertEqual(
            viewModel.draftDueAt,
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 11))
        )
        XCTAssertEqual(viewModel.draftQuotedPrice, "")
        XCTAssertEqual(viewModel.draftDepositPaid, "")
        XCTAssertEqual(viewModel.draftPaymentNotes, "")
        XCTAssertEqual(viewModel.draftCustomerReferencePhotoId, "")
        XCTAssertEqual(viewModel.draftReminderMode, .custom)
        XCTAssertEqual(viewModel.draftReminderDayOffsets, "5, 1")
        XCTAssertFalse(viewModel.draftReminderIncludesDueTime)
        XCTAssertEqual(viewModel.draftExtraIngredientRows.map(\.id), ["duplicate-1"])
        XCTAssertEqual(viewModel.draftExtraIngredientRows.map(\.inventoryItemName), ["Berries"])
        XCTAssertEqual(
            viewModel.draftChecklistItems,
            [OrderChecklistDraftItem(id: "duplicate-2", title: "Add topper")]
        )

        XCTAssertTrue(viewModel.addOrder())

        let duplicate = try XCTUnwrap(repository.orders.first { $0.id == "duplicate-3" })
        XCTAssertEqual(duplicate.status, .draft)
        XCTAssertNil(duplicate.quotedPrice)
        XCTAssertNil(duplicate.depositPaid)
        XCTAssertNil(duplicate.completedAt)
        XCTAssertEqual(
            repository.extraIngredients.first { $0.orderId == duplicate.id }?.id,
            "duplicate-1"
        )
        XCTAssertEqual(
            repository.checklistItems.first { $0.orderId == duplicate.id },
            OrderChecklistItem(
                id: "duplicate-2",
                orderId: duplicate.id,
                title: "Add topper",
                isCompleted: false,
                sortOrder: 0,
                createdAt: now,
                updatedAt: now
            )
        )
        XCTAssertFalse(repository.orderPhotos.contains { $0.orderId == duplicate.id })
        XCTAssertFalse(repository.inventoryReservations.contains { $0.orderId == duplicate.id })
    }

    func testDraftChecklistCanBeEditedBeforeNewOrderIsSaved() {
        let viewModel = OrderListViewModel(
            repository: FakeOrderRepository(),
            idGenerator: makeIncrementingIdGenerator(prefix: "checklist")
        )

        viewModel.beginAddingOrder()
        viewModel.draftNewChecklistItemTitle = "  Confirm cake message  "
        viewModel.addChecklistItemToDraftOrder()

        XCTAssertEqual(
            viewModel.draftChecklistItems,
            [OrderChecklistDraftItem(id: "checklist-1", title: "Confirm cake message")]
        )
        XCTAssertEqual(viewModel.draftNewChecklistItemTitle, "")

        viewModel.deleteDraftChecklistItem(viewModel.draftChecklistItems[0])

        XCTAssertTrue(viewModel.draftChecklistItems.isEmpty)
    }

    func testBeginViewingOrderLoadsChecklistItems() {
        let repository = FakeOrderRepository()
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let checklistItem = makeChecklistItem(id: "checklist-crumb-coat", orderId: order.id, title: "Crumb coat")
        repository.checklistItems = [checklistItem]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(viewModel.selectedOrderChecklistItems, [checklistItem])
    }

    func testAddChecklistItemToSelectedOrderPersistsTrimmedTitle() {
        let repository = FakeOrderRepository()
        let now = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        repository.checklistItems = [
            makeChecklistItem(id: "checklist-existing", orderId: order.id, title: "Bake sponge", sortOrder: 0)
        ]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: { "checklist-crumb-coat" },
            dateProvider: { now }
        )

        viewModel.beginViewingOrder(order)
        viewModel.draftChecklistItemTitle = " Crumb coat "

        XCTAssertTrue(viewModel.addChecklistItemToSelectedOrder())
        XCTAssertEqual(viewModel.draftChecklistItemTitle, "")
        XCTAssertEqual(
            repository.checklistItems.last,
            OrderChecklistItem(
                id: "checklist-crumb-coat",
                orderId: order.id,
                title: "Crumb coat",
                isCompleted: false,
                sortOrder: 1,
                createdAt: now,
                updatedAt: now
            )
        )
        XCTAssertEqual(viewModel.selectedOrderChecklistItems.map(\.title), ["Bake sponge", "Crumb coat"])
    }

    func testToggleChecklistItemUpdatesCompletionState() {
        let repository = FakeOrderRepository()
        let now = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let checklistItem = makeChecklistItem(id: "checklist-bake", orderId: order.id, title: "Bake sponge")
        repository.checklistItems = [checklistItem]
        let viewModel = OrderListViewModel(repository: repository, dateProvider: { now })

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.toggleChecklistItem(checklistItem))
        XCTAssertEqual(viewModel.selectedOrderChecklistItems.first?.isCompleted, true)
        XCTAssertEqual(viewModel.selectedOrderChecklistItems.first?.updatedAt, now)
    }

    func testToggleChecklistItemPreservesEntryOrder() {
        let repository = FakeOrderRepository()
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let firstItem = makeChecklistItem(id: "checklist-first", orderId: order.id, title: "Bake sponge", sortOrder: 0)
        let secondItem = makeChecklistItem(id: "checklist-second", orderId: order.id, title: "Crumb coat", sortOrder: 1)
        repository.checklistItems = [secondItem, firstItem]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.toggleChecklistItem(firstItem))
        XCTAssertEqual(viewModel.selectedOrderChecklistItems.map(\.id), ["checklist-first", "checklist-second"])
    }

    func testUpdateChecklistItemTitlePersistsTrimmedTitleAndPreservesState() {
        let repository = FakeOrderRepository()
        let now = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let item = makeChecklistItem(
            id: "checklist-first",
            orderId: order.id,
            title: "Crumb coat",
            isCompleted: true,
            sortOrder: 2
        )
        repository.checklistItems = [item]
        let viewModel = OrderListViewModel(repository: repository, dateProvider: { now })

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.updateChecklistItemTitle(item, title: "  Final photo  "))
        XCTAssertEqual(repository.checklistItems.first?.title, "Final photo")
        XCTAssertEqual(repository.checklistItems.first?.isCompleted, true)
        XCTAssertEqual(repository.checklistItems.first?.sortOrder, 2)
        XCTAssertEqual(repository.checklistItems.first?.createdAt, item.createdAt)
        XCTAssertEqual(repository.checklistItems.first?.updatedAt, now)
        XCTAssertEqual(viewModel.selectedOrderChecklistItems.first?.title, "Final photo")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testUpdateChecklistItemTitleRejectsBlankTitle() {
        let repository = FakeOrderRepository()
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let item = makeChecklistItem(id: "checklist-first", orderId: order.id, title: "Crumb coat")
        repository.checklistItems = [item]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertFalse(viewModel.updateChecklistItemTitle(item, title: "   "))
        XCTAssertEqual(repository.checklistItems.first?.title, "Crumb coat")
        XCTAssertEqual(viewModel.errorMessage, "Checklist item is required.")
    }

    func testDeleteChecklistItemRemovesItFromSelectedOrder() {
        let repository = FakeOrderRepository()
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let firstItem = makeChecklistItem(id: "checklist-first", orderId: order.id, title: "Bake sponge", sortOrder: 0)
        let secondItem = makeChecklistItem(id: "checklist-second", orderId: order.id, title: "Crumb coat", sortOrder: 1)
        repository.checklistItems = [firstItem, secondItem]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.deleteChecklistItem(firstItem))
        XCTAssertEqual(viewModel.selectedOrderChecklistItems, [secondItem])
        XCTAssertEqual(repository.checklistItems, [secondItem])
    }
}
