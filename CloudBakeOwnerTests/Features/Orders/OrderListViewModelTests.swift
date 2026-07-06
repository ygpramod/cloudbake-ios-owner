import XCTest
@testable import CloudBakeOwner

@MainActor
final class OrderListViewModelTests: XCTestCase {
    func testLoadFetchesOrdersCustomersAndRecipes() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let order = makeOrder(id: "order-vanilla", dueAt: timestamp)
        let customer = makeCustomer(id: "customer-amy", name: "Amy")
        let recipe = makeRecipe(id: "recipe-vanilla", name: "Vanilla sponge")
        let design = makeCakeDesign(id: "design-floral", name: "Pink florals")
        repository.orders = [order]
        repository.customers = [customer]
        repository.recipes = [recipe]
        repository.cakeDesigns = [design]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.orders, [order])
        XCTAssertEqual(viewModel.customers, [customer])
        XCTAssertEqual(viewModel.recipes, [recipe])
        XCTAssertEqual(viewModel.cakeDesigns, [design])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testCalendarDaysGroupsOrdersByDueDate() {
        let repository = FakeOrderRepository()
        let calendar = utcCalendar()
        let firstDayMorning = Date(timeIntervalSince1970: 1_800_057_600)
        let firstDayAfternoon = Date(timeIntervalSince1970: 1_800_075_600)
        let secondDay = Date(timeIntervalSince1970: 1_800_144_000)
        let firstOrder = makeOrder(
            id: "order-morning",
            title: "Morning Cake",
            dueAt: firstDayMorning,
            createdAt: Date(timeIntervalSince1970: 1_800_010_000)
        )
        let secondOrder = makeOrder(
            id: "order-afternoon",
            title: "Afternoon Cake",
            dueAt: firstDayAfternoon,
            createdAt: Date(timeIntervalSince1970: 1_800_020_000)
        )
        let thirdOrder = makeOrder(
            id: "order-next-day",
            title: "Next Day Cake",
            dueAt: secondDay,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        repository.orders = [thirdOrder, secondOrder, firstOrder]
        let viewModel = OrderListViewModel(repository: repository, calendar: calendar)

        viewModel.load()

        XCTAssertEqual(
            viewModel.calendarDays,
            [
                OrderCalendarDay(
                    day: calendar.startOfDay(for: firstDayMorning),
                    orders: [firstOrder, secondOrder]
                ),
                OrderCalendarDay(
                    day: calendar.startOfDay(for: secondDay),
                    orders: [thirdOrder]
                )
            ]
        )
    }

    func testOrderScopesSeparateActiveAndCompletedOrdersInEntryOrder() {
        let repository = FakeOrderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let olderActive = makeOrder(
            id: "order-older-active",
            title: "Older Active",
            status: .confirmed,
            dueAt: dueAt,
            createdAt: Date(timeIntervalSince1970: 1_800_010_000)
        )
        let newerActive = makeOrder(
            id: "order-newer-active",
            title: "Newer Active",
            status: .ready,
            dueAt: dueAt,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        let cancelled = makeOrder(
            id: "order-cancelled",
            title: "Cancelled",
            status: .cancelled,
            dueAt: dueAt,
            createdAt: Date(timeIntervalSince1970: 1_800_020_000)
        )
        let completed = makeOrder(
            id: "order-completed",
            title: "Completed",
            status: .completed,
            dueAt: dueAt,
            createdAt: Date(timeIntervalSince1970: 1_800_040_000)
        )
        repository.orders = [completed, newerActive, cancelled, olderActive]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.activeOrders, [olderActive, newerActive])
        XCTAssertEqual(viewModel.completedOrders, [completed])
    }

    func testReminderPlanUsesThreeTwoAndOneDaysBeforeDueDate() {
        let repository = FakeOrderRepository()
        let calendar = utcCalendar()
        let dueAt = Date(timeIntervalSince1970: 1_800_144_000)
        let order = makeOrder(id: "order-vanilla", dueAt: dueAt)
        let viewModel = OrderListViewModel(repository: repository, calendar: calendar)

        XCTAssertEqual(
            viewModel.reminderPlan(for: order),
            [
                OrderReminderPlanItem(
                    offsetDays: 3,
                    remindAt: calendar.date(byAdding: .day, value: -3, to: dueAt)!
                ),
                OrderReminderPlanItem(
                    offsetDays: 2,
                    remindAt: calendar.date(byAdding: .day, value: -2, to: dueAt)!
                ),
                OrderReminderPlanItem(
                    offsetDays: 1,
                    remindAt: calendar.date(byAdding: .day, value: -1, to: dueAt)!
                )
            ]
        )
    }

    func testDueReminderGroupsIncludeActiveOrdersWithReachedReminderDates() {
        let repository = FakeOrderRepository()
        let calendar = utcCalendar()
        let now = Date(timeIntervalSince1970: 1_800_057_600)
        let dueInTwoDays = calendar.date(byAdding: .day, value: 2, to: now)!
        let dueInFourDays = calendar.date(byAdding: .day, value: 4, to: now)!
        let dueTomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let dueCancelled = calendar.date(byAdding: .day, value: 1, to: now)!
        let dueCompleted = calendar.date(byAdding: .day, value: 1, to: now)!
        let activeOrder = makeOrder(id: "order-active", title: "Active Cake", dueAt: dueInTwoDays)
        let futureOrder = makeOrder(id: "order-future", title: "Future Cake", dueAt: dueInFourDays)
        let tomorrowOrder = makeOrder(id: "order-tomorrow", title: "Tomorrow Cake", dueAt: dueTomorrow)
        let cancelledOrder = makeOrder(
            id: "order-cancelled",
            title: "Cancelled Cake",
            status: .cancelled,
            dueAt: dueCancelled
        )
        let completedOrder = makeOrder(
            id: "order-completed",
            title: "Completed Cake",
            status: .completed,
            dueAt: dueCompleted
        )
        repository.orders = [futureOrder, activeOrder, cancelledOrder, completedOrder, tomorrowOrder]
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.load()

        XCTAssertEqual(
            viewModel.dueReminderGroups,
            [
                OrderReminderDueGroup(
                    order: tomorrowOrder,
                    reminders: [viewModel.reminderPlan(for: tomorrowOrder)[2]]
                ),
                OrderReminderDueGroup(
                    order: activeOrder,
                    reminders: [viewModel.reminderPlan(for: activeOrder)[1]]
                )
            ]
        )
    }

    func testNextReminderReturnsOnlyNextUpcomingReminder() {
        let repository = FakeOrderRepository()
        let calendar = utcCalendar()
        let now = Date(timeIntervalSince1970: 1_800_057_600)
        let dueInTwoDays = calendar.date(byAdding: .day, value: 2, to: now)!
        let order = makeOrder(id: "order-active", title: "Active Cake", dueAt: dueInTwoDays)
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )

        XCTAssertEqual(viewModel.nextReminder(for: order), viewModel.reminderPlan(for: order)[2])
    }

    func testAddOrderPersistsRequiredAndOptionalFields() {
        let repository = FakeOrderRepository()
        let now = Date(timeIntervalSince1970: 1_800_060_000)
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: { "order-vanilla" },
            dateProvider: { now }
        )
        viewModel.draftTitle = " Vanilla Birthday "
        viewModel.draftCustomerName = " Amy "
        viewModel.draftDueAt = dueAt
        viewModel.draftStatus = .confirmed
        viewModel.draftRecipeId = "recipe-vanilla"
        viewModel.draftCakeDesignId = "design-floral"
        viewModel.draftFulfillmentType = .delivery
        viewModel.draftDeliveryAddress = " 10 Cake Street "
        viewModel.draftCakeNotes = " Less sweet "

        XCTAssertTrue(viewModel.addOrder())

        XCTAssertEqual(
            repository.orders,
            [
                Order(
                    id: "order-vanilla",
                    customerId: nil,
                    cakeDesignId: "design-floral",
                    recipeId: "recipe-vanilla",
                    title: "Vanilla Birthday",
                    customerName: "Amy",
                    status: .confirmed,
                    dueAt: dueAt,
                    fulfillmentType: .delivery,
                    deliveryAddress: "10 Cake Street",
                    cakeNotes: "Less sweet",
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
        XCTAssertEqual(viewModel.draftTitle, "")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDesignSelectionStateUsesLoadedDesigns() {
        let repository = FakeOrderRepository()
        let floral = makeCakeDesign(
            id: "design-floral",
            name: "Pink florals",
            notes: "Palette knife flowers",
            photoReference: "photos/floral.jpg"
        )
        let minimalist = makeCakeDesign(id: "design-minimal", name: "Minimal buttercream")
        repository.cakeDesigns = [minimalist, floral]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.load()
        viewModel.selectDraftCakeDesign(id: "design-floral")

        XCTAssertEqual(viewModel.draftCakeDesignId, "design-floral")
        XCTAssertEqual(viewModel.draftCakeDesignName(), "Pink florals")
        XCTAssertEqual(viewModel.cakeDesigns(matching: "palette"), [floral])
        XCTAssertEqual(viewModel.cakeDesigns(matching: "photos"), [floral])
        XCTAssertEqual(viewModel.cakeDesigns(matching: "minimal"), [minimalist])
        viewModel.clearDraftCakeDesignLink()
        XCTAssertEqual(viewModel.draftCakeDesignId, "")
        XCTAssertEqual(viewModel.draftCakeDesignName(), "No Linked Design")
    }

    func testRecipeSelectionStateUsesLoadedRecipes() {
        let repository = FakeOrderRepository()
        let vanilla = makeRecipe(id: "recipe-vanilla", name: "Vanilla sponge", notes: "Birthday base")
        let chocolate = makeRecipe(id: "recipe-chocolate", name: "Chocolate sponge")
        repository.recipes = [vanilla, chocolate]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.load()
        viewModel.selectDraftRecipe(id: "recipe-vanilla")

        XCTAssertEqual(viewModel.draftRecipeId, "recipe-vanilla")
        XCTAssertEqual(viewModel.draftRecipeName(), "Vanilla sponge")
        XCTAssertEqual(viewModel.recipes(matching: "birthday"), [vanilla])
        XCTAssertEqual(viewModel.recipes(matching: "chocolate"), [chocolate])
        viewModel.clearDraftRecipeLink()
        XCTAssertEqual(viewModel.draftRecipeId, "")
        XCTAssertEqual(viewModel.draftRecipeName(), "No Linked Recipe")
    }

    func testAddOrderRequiresTitleAndCustomerName() {
        let repository = FakeOrderRepository()
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.draftCustomerName = "Amy"
        XCTAssertFalse(viewModel.addOrder())
        XCTAssertEqual(viewModel.errorMessage, "Order title is required.")

        viewModel.draftTitle = "Vanilla Birthday"
        viewModel.draftCustomerName = " "
        XCTAssertFalse(viewModel.addOrder())
        XCTAssertEqual(viewModel.errorMessage, "Customer name is required.")
        XCTAssertTrue(repository.orders.isEmpty)
    }

    func testSelectedCustomerPrefillsNameAndAddress() {
        let repository = FakeOrderRepository()
        repository.customers = [
            makeCustomer(id: "customer-amy", name: "Amy", address: "10 Cake Street")
        ]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginAddingOrder()
        viewModel.draftCustomerId = "customer-amy"
        viewModel.applySelectedCustomer()

        XCTAssertEqual(viewModel.draftCustomerName, "Amy")
        XCTAssertEqual(viewModel.draftDeliveryAddress, "10 Cake Street")
    }

    func testSelectDraftCustomerPrefillsNameAndAddress() {
        let repository = FakeOrderRepository()
        repository.customers = [
            makeCustomer(id: "customer-amy", name: "Amy", address: "10 Cake Street")
        ]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginAddingOrder()
        viewModel.selectDraftCustomer(id: "customer-amy")

        XCTAssertEqual(viewModel.draftCustomerId, "customer-amy")
        XCTAssertEqual(viewModel.draftCustomerRecordName(), "Amy")
        XCTAssertEqual(viewModel.draftCustomerName, "Amy")
        XCTAssertEqual(viewModel.draftDeliveryAddress, "10 Cake Street")
    }

    func testClearDraftCustomerLinkKeepsEnteredCustomerName() {
        let repository = FakeOrderRepository()
        repository.customers = [makeCustomer(id: "customer-amy", name: "Amy")]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginAddingOrder()
        viewModel.selectDraftCustomer(id: "customer-amy")
        viewModel.draftCustomerName = "Amy B"
        viewModel.clearDraftCustomerLink()

        XCTAssertEqual(viewModel.draftCustomerId, "")
        XCTAssertEqual(viewModel.draftCustomerRecordName(), "No Linked Customer")
        XCTAssertEqual(viewModel.draftCustomerName, "Amy B")
    }

    func testCustomersMatchingSearchesNamePhoneEmailAndAddress() {
        let repository = FakeOrderRepository()
        let amy = makeCustomer(
            id: "customer-amy",
            name: "Amy",
            address: "10 Cake Street",
            email: "amy@example.com"
        )
        let zoe = makeCustomer(
            id: "customer-zoe",
            name: "Zoe",
            phone: "5550202",
            address: "20 Sugar Road"
        )
        repository.customers = [amy, zoe]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginAddingOrder()

        XCTAssertEqual(viewModel.customers(matching: "cake"), [amy])
        XCTAssertEqual(viewModel.customers(matching: "0202"), [zoe])
        XCTAssertEqual(viewModel.customers(matching: "EXAMPLE"), [amy])
        XCTAssertEqual(viewModel.customers(matching: " "), [amy, zoe])
    }

    func testBeginViewingOrderSelectsOrderAndLinkedCustomer() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-vanilla",
            customerId: "customer-amy",
            recipeId: "recipe-vanilla",
            cakeDesignId: "design-floral",
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        let customer = makeCustomer(
            id: "customer-amy",
            name: "Amy",
            likes: "Vanilla",
            dislikes: "Coffee",
            allergies: "Nuts",
            dietaryRestrictions: "Eggless",
            notes: "Prefers pale colors"
        )
        repository.customers = [customer]
        let recipe = makeRecipe(id: "recipe-vanilla", name: "Vanilla sponge")
        repository.recipes = [recipe]
        let design = makeCakeDesign(id: "design-floral", name: "Pink florals")
        repository.cakeDesigns = [design]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(viewModel.selectedOrder, order)
        XCTAssertEqual(viewModel.selectedOrderCustomer, customer)
        XCTAssertEqual(viewModel.selectedOrderRecipe, recipe)
        XCTAssertEqual(viewModel.selectedOrderCakeDesign, design)
        viewModel.closeOrderDetail()
        XCTAssertNil(viewModel.selectedOrder)
        XCTAssertNil(viewModel.selectedOrderCustomer)
        XCTAssertNil(viewModel.selectedOrderRecipe)
        XCTAssertNil(viewModel.selectedOrderCakeDesign)
        XCTAssertTrue(viewModel.selectedOrderChecklistItems.isEmpty)
        XCTAssertEqual(viewModel.draftChecklistItemTitle, "")
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

    func testChangeSelectedOrderStatusToReadyRecordsLinkedRecipeUsage() {
        let repository = FakeOrderRepository()
        let updatedAt = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_150_000)
        )
        repository.orders = [order]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
            dateProvider: { updatedAt }
        )

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.changeSelectedOrderStatus(to: .ready))
        XCTAssertEqual(viewModel.selectedOrder?.status, .ready)
        XCTAssertEqual(
            viewModel.selectedOrderRecipeUsage,
            OrderRecipeUsage(
                id: "generated-1",
                orderId: order.id,
                recipeId: "recipe-vanilla",
                usedAt: updatedAt,
                createdAt: updatedAt,
                updatedAt: updatedAt
            )
        )
        XCTAssertEqual(repository.recordedTransactionIds, ["generated-2"])
    }

    func testChangeSelectedOrderStatusToCompletedRecordsLinkedRecipeUsage() {
        let repository = FakeOrderRepository()
        let updatedAt = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_150_000)
        )
        repository.orders = [order]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
            dateProvider: { updatedAt }
        )

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.changeSelectedOrderStatus(to: .completed))
        XCTAssertEqual(viewModel.selectedOrder?.status, .completed)
        XCTAssertEqual(viewModel.selectedOrderRecipeUsage?.recipeId, "recipe-vanilla")
        XCTAssertEqual(repository.recordedTransactionIds, ["generated-2"])
    }

    func testChangeSelectedOrderStatusFromDraftToCompletedDoesNotRecordRecipeUsage() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            status: .draft,
            dueAt: Date(timeIntervalSince1970: 1_800_150_000)
        )
        repository.orders = [order]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.changeSelectedOrderStatus(to: .completed))
        XCTAssertEqual(viewModel.selectedOrder?.status, .completed)
        XCTAssertNil(viewModel.selectedOrderRecipeUsage)
        XCTAssertTrue(repository.recordedTransactionIds.isEmpty)
    }

    func testChangeSelectedOrderStatusShowsRecipeUsageError() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_150_000)
        )
        repository.orders = [order]
        repository.changeOrderStatusError = OrderRecipeUsageError.insufficientStock(itemName: "Cake Flour")
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertFalse(viewModel.changeSelectedOrderStatus(to: .ready))
        XCTAssertEqual(viewModel.selectedOrder?.status, .confirmed)
        XCTAssertEqual(viewModel.errorMessage, "Not enough Cake Flour in inventory.")
    }


    func testBeginViewingUnlinkedOrderClearsLinkedCustomer() {
        let repository = FakeOrderRepository()
        let linkedOrder = makeOrder(
            id: "order-vanilla",
            customerId: "customer-amy",
            recipeId: "recipe-vanilla",
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        let unlinkedOrder = makeOrder(id: "order-chocolate", dueAt: Date(timeIntervalSince1970: 1_800_150_000))
        repository.customers = [makeCustomer(id: "customer-amy", name: "Amy", allergies: "Nuts")]
        repository.recipes = [makeRecipe(id: "recipe-vanilla", name: "Vanilla sponge")]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(linkedOrder)
        viewModel.beginViewingOrder(unlinkedOrder)

        XCTAssertEqual(viewModel.selectedOrder, unlinkedOrder)
        XCTAssertNil(viewModel.selectedOrderCustomer)
        XCTAssertNil(viewModel.selectedOrderRecipe)
    }

    func testBeginEditingOrderPrefillsDraft() {
        let repository = FakeOrderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let order = Order(
            id: "order-vanilla",
            customerId: "customer-amy",
            cakeDesignId: "design-floral",
            recipeId: "recipe-vanilla",
            title: "Vanilla Birthday",
            customerName: "Amy",
            status: .confirmed,
            dueAt: dueAt,
            fulfillmentType: .delivery,
            deliveryAddress: "10 Cake Street",
            cakeNotes: "Pink flowers",
            createdAt: Date(timeIntervalSince1970: 1_800_060_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_060_000)
        )
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)
        viewModel.beginEditingOrder()

        XCTAssertEqual(viewModel.draftTitle, "Vanilla Birthday")
        XCTAssertEqual(viewModel.draftCustomerName, "Amy")
        XCTAssertEqual(viewModel.draftCustomerId, "customer-amy")
        XCTAssertEqual(viewModel.draftRecipeId, "recipe-vanilla")
        XCTAssertEqual(viewModel.draftCakeDesignId, "design-floral")
        XCTAssertEqual(viewModel.draftDueAt, dueAt)
        XCTAssertEqual(viewModel.draftStatus, .confirmed)
        XCTAssertEqual(viewModel.draftFulfillmentType, .delivery)
        XCTAssertEqual(viewModel.draftDeliveryAddress, "10 Cake Street")
        XCTAssertEqual(viewModel.draftCakeNotes, "Pink flowers")
    }

    func testSaveEditedOrderPersistsChangesAndStatusTransition() {
        let repository = FakeOrderRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_060_000)
        let updatedAt = Date(timeIntervalSince1970: 1_800_080_000)
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let original = makeOrder(id: "order-vanilla", dueAt: dueAt)
        repository.orders = [original]
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { updatedAt }
        )

        viewModel.beginViewingOrder(original)
        viewModel.beginEditingOrder()
        viewModel.draftTitle = "Chocolate Birthday"
        viewModel.draftCustomerName = "Amy B"
        viewModel.draftRecipeId = "recipe-chocolate"
        viewModel.draftCakeDesignId = "design-floral"
        viewModel.draftStatus = .ready
        viewModel.draftFulfillmentType = .delivery
        viewModel.draftDeliveryAddress = "11 Cake Street"
        viewModel.draftCakeNotes = "Add gold leaf"

        XCTAssertTrue(viewModel.saveEditedOrder())

        let expected = Order(
            id: "order-vanilla",
            customerId: nil,
            cakeDesignId: "design-floral",
            recipeId: "recipe-chocolate",
            title: "Chocolate Birthday",
            customerName: "Amy B",
            status: .ready,
            dueAt: dueAt,
            fulfillmentType: .delivery,
            deliveryAddress: "11 Cake Street",
            cakeNotes: "Add gold leaf",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        XCTAssertEqual(repository.orders, [expected])
        XCTAssertEqual(viewModel.selectedOrder, expected)
        XCTAssertEqual(viewModel.orders, [expected])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSaveEditedOrderRefreshesLinkedCustomerDetails() {
        let repository = FakeOrderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let original = makeOrder(id: "order-vanilla", dueAt: dueAt)
        let customer = makeCustomer(id: "customer-zoe", name: "Zoe", allergies: "Sesame")
        repository.orders = [original]
        repository.customers = [customer]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(original)
        viewModel.beginEditingOrder()
        viewModel.draftCustomerId = "customer-zoe"
        viewModel.applySelectedCustomer()

        XCTAssertTrue(viewModel.saveEditedOrder())

        XCTAssertEqual(viewModel.selectedOrder?.customerId, "customer-zoe")
        XCTAssertEqual(viewModel.selectedOrder?.customerName, "Zoe")
        XCTAssertEqual(viewModel.selectedOrderCustomer, customer)
    }

    private func makeOrder(
        id: String,
        title: String = "Vanilla Birthday",
        customerId: String? = nil,
        recipeId: String? = nil,
        cakeDesignId: String? = nil,
        status: OrderStatus = .draft,
        dueAt: Date,
        createdAt: Date = Date(timeIntervalSince1970: 1_800_060_000)
    ) -> Order {
        return Order(
            id: id,
            customerId: customerId,
            cakeDesignId: cakeDesignId,
            recipeId: recipeId,
            title: title,
            customerName: "Amy",
            status: status,
            dueAt: dueAt,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeCustomer(
        id: String,
        name: String,
        phone: String = "5550101",
        address: String? = nil,
        email: String? = nil,
        likes: String? = nil,
        dislikes: String? = nil,
        allergies: String? = nil,
        dietaryRestrictions: String? = nil,
        notes: String? = nil
    ) -> Customer {
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        return Customer(
            id: id,
            name: name,
            phone: phone,
            email: email,
            address: address,
            likes: likes,
            dislikes: dislikes,
            allergies: allergies,
            dietaryRestrictions: dietaryRestrictions,
            notes: notes,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private func makeRecipe(id: String, name: String, notes: String? = nil) -> Recipe {
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        return Recipe(
            id: id,
            name: name,
            notes: notes,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private func makeCakeDesign(
        id: String,
        name: String,
        notes: String? = nil,
        photoReference: String? = nil
    ) -> CakeDesign {
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        return CakeDesign(
            id: id,
            name: name,
            notes: notes,
            photoReference: photoReference,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private func makeChecklistItem(
        id: String,
        orderId: String,
        title: String,
        isCompleted: Bool = false,
        sortOrder: Int = 0
    ) -> OrderChecklistItem {
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        return OrderChecklistItem(
            id: id,
            orderId: orderId,
            title: title,
            isCompleted: isCompleted,
            sortOrder: sortOrder,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private func makeIncrementingIdGenerator(prefix: String) -> () -> String {
        var counter = 0
        return {
            counter += 1
            return "\(prefix)-\(counter)"
        }
    }
}

private final class FakeOrderRepository: OrderRepository,
    CustomerRepository,
    RecipeRepository,
    CakeDesignRepository,
    OrderRecipeUsageRepository,
    OrderStatusChangeRepository,
    OrderChecklistRepository {
    var orders: [Order] = []
    var customers: [Customer] = []
    var recipes: [Recipe] = []
    var cakeDesigns: [CakeDesign] = []
    var usages: [OrderRecipeUsage] = []
    var checklistItems: [OrderChecklistItem] = []
    var recordedTransactionIds: [String] = []
    var recordRecipeUsageError: Error?
    var changeOrderStatusError: Error?

    func save(_ order: Order) throws {
        orders.removeAll { $0.id == order.id }
        orders.append(order)
    }

    func fetchOrder(id: String) throws -> Order? {
        orders.first { $0.id == id }
    }

    func fetchOrders() throws -> [Order] {
        orders.sorted { lhs, rhs in
            lhs.dueAt == rhs.dueAt ? lhs.title < rhs.title : lhs.dueAt < rhs.dueAt
        }
    }

    func save(_ customer: Customer) throws {
        customers.removeAll { $0.id == customer.id }
        customers.append(customer)
    }

    func fetchCustomer(id: String) throws -> Customer? {
        customers.first { $0.id == id }
    }

    func fetchCustomers() throws -> [Customer] {
        customers
    }

    func save(_ recipe: Recipe) throws {
        recipes.removeAll { $0.id == recipe.id }
        recipes.append(recipe)
    }

    func fetchRecipe(id: String) throws -> Recipe? {
        recipes.first { $0.id == id }
    }

    func fetchRecipes() throws -> [Recipe] {
        recipes.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func save(_ design: CakeDesign) throws {
        cakeDesigns.removeAll { $0.id == design.id }
        cakeDesigns.append(design)
    }

    func fetchCakeDesign(id: String) throws -> CakeDesign? {
        cakeDesigns.first { $0.id == id }
    }

    func fetchCakeDesigns() throws -> [CakeDesign] {
        cakeDesigns.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func fetchOrderRecipeUsage(orderId: String) throws -> OrderRecipeUsage? {
        usages.first { $0.orderId == orderId }
    }

    func save(_ item: OrderChecklistItem) throws {
        checklistItems.removeAll { $0.id == item.id }
        checklistItems.append(item)
    }

    func fetchOrderChecklistItems(orderId: String) throws -> [OrderChecklistItem] {
        checklistItems
            .filter { $0.orderId == orderId }
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.id < $1.id
                }

                return $0.sortOrder < $1.sortOrder
            }
    }

    func deleteOrderChecklistItem(id: String) throws {
        checklistItems.removeAll { $0.id == id }
    }

    func recordRecipeUsage(
        for order: Order,
        usageId: String,
        usedAt: Date,
        transactionIdProvider: () -> String
    ) throws {
        if let recordRecipeUsageError {
            throw recordRecipeUsageError
        }
        guard let recipeId = order.recipeId else {
            throw OrderRecipeUsageError.orderHasNoLinkedRecipe
        }

        recordedTransactionIds.append(transactionIdProvider())
        usages.append(
            OrderRecipeUsage(
                id: usageId,
                orderId: order.id,
                recipeId: recipeId,
                usedAt: usedAt,
                createdAt: usedAt,
                updatedAt: usedAt
            )
        )
    }

    func changeOrderStatus(
        order: Order,
        status: OrderStatus,
        updatedAt: Date,
        usageId: String,
        transactionIdProvider: () -> String
    ) throws -> Order {
        if let changeOrderStatusError {
            throw changeOrderStatusError
        }

        let updatedOrder = Order(
            id: order.id,
            customerId: order.customerId,
            cakeDesignId: order.cakeDesignId,
            recipeId: order.recipeId,
            title: order.title,
            customerName: order.customerName,
            status: status,
            dueAt: order.dueAt,
            fulfillmentType: order.fulfillmentType,
            deliveryAddress: order.deliveryAddress,
            cakeNotes: order.cakeNotes,
            createdAt: order.createdAt,
            updatedAt: updatedAt
        )
        try save(updatedOrder)

        if shouldRecordRecipeUsage(from: order.status, to: status),
           let recipeId = order.recipeId,
           usages.first(where: { $0.orderId == order.id }) == nil {
            recordedTransactionIds.append(transactionIdProvider())
            usages.append(
                OrderRecipeUsage(
                    id: usageId,
                    orderId: order.id,
                    recipeId: recipeId,
                    usedAt: updatedAt,
                    createdAt: updatedAt,
                    updatedAt: updatedAt
                )
            )
        }

        return updatedOrder
    }

    private func shouldRecordRecipeUsage(from currentStatus: OrderStatus, to newStatus: OrderStatus) -> Bool {
        currentStatus == .confirmed && (newStatus == .ready || newStatus == .completed)
    }
}
