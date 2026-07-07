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
            createdAt: Date(timeIntervalSince1970: 1_800_020_000)
        )
        let secondOrder = makeOrder(
            id: "order-afternoon",
            title: "Afternoon Cake",
            dueAt: firstDayAfternoon,
            createdAt: Date(timeIntervalSince1970: 1_800_010_000)
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

    func testOrderScopesSortActiveByDueDateAndCompletedDescending() {
        let repository = FakeOrderRepository()
        let earlierDueAt = Date(timeIntervalSince1970: 1_800_120_000)
        let laterDueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let firstActiveDue = makeOrder(
            id: "order-first-active-due",
            title: "First Active Due",
            status: .confirmed,
            dueAt: earlierDueAt,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        let secondActiveDue = makeOrder(
            id: "order-second-active-due",
            title: "Second Active Due",
            status: .ready,
            dueAt: laterDueAt,
            createdAt: Date(timeIntervalSince1970: 1_800_010_000)
        )
        let cancelled = makeOrder(
            id: "order-cancelled",
            title: "Cancelled",
            status: .cancelled,
            dueAt: earlierDueAt,
            createdAt: Date(timeIntervalSince1970: 1_800_020_000)
        )
        let laterCompleted = makeOrder(
            id: "order-later-completed",
            title: "Later Completed",
            status: .completed,
            dueAt: laterDueAt,
            createdAt: Date(timeIntervalSince1970: 1_800_040_000)
        )
        let earlierCompleted = makeOrder(
            id: "order-earlier-completed",
            title: "Earlier Completed",
            status: .completed,
            dueAt: earlierDueAt,
            createdAt: Date(timeIntervalSince1970: 1_800_050_000)
        )
        repository.orders = [earlierCompleted, secondActiveDue, laterCompleted, cancelled, firstActiveDue]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.activeOrders, [firstActiveDue, secondActiveDue])
        XCTAssertEqual(viewModel.completedOrders, [laterCompleted, earlierCompleted, cancelled])
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
                    remindAt: date(byAddingDays: -3, to: dueAt, calendar: calendar)
                ),
                OrderReminderPlanItem(
                    offsetDays: 2,
                    remindAt: date(byAddingDays: -2, to: dueAt, calendar: calendar)
                ),
                OrderReminderPlanItem(
                    offsetDays: 1,
                    remindAt: date(byAddingDays: -1, to: dueAt, calendar: calendar)
                )
            ]
        )
    }

    func testDueReminderGroupsIncludeActiveOrdersWithReachedReminderDates() {
        let repository = FakeOrderRepository()
        let calendar = utcCalendar()
        let now = Date(timeIntervalSince1970: 1_800_057_600)
        let dueInTwoDays = date(byAddingDays: 2, to: now, calendar: calendar)
        let dueInFourDays = date(byAddingDays: 4, to: now, calendar: calendar)
        let dueTomorrow = date(byAddingDays: 1, to: now, calendar: calendar)
        let dueCancelled = date(byAddingDays: 1, to: now, calendar: calendar)
        let dueCompleted = date(byAddingDays: 1, to: now, calendar: calendar)
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
        let dueInTwoDays = date(byAddingDays: 2, to: now, calendar: calendar)
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
        viewModel.draftRecipeScaleMultiplier = "1.5"
        viewModel.draftCakeDesignId = "design-floral"
        viewModel.draftFulfillmentType = .delivery
        viewModel.draftDeliveryAddress = " 10 Cake Street "
        viewModel.draftCakeNotes = " Less sweet "
        viewModel.draftQuotedPrice = "125.50"
        viewModel.draftDepositPaid = "25.50"
        viewModel.draftPaymentNotes = " Bank transfer received "

        XCTAssertTrue(viewModel.addOrder())

        XCTAssertEqual(
            repository.orders,
            [
                Order(
                    id: "order-vanilla",
                    customerId: nil,
                    cakeDesignId: "design-floral",
                    recipeId: "recipe-vanilla",
                    recipeScaleMultiplier: decimal("1.5"),
                    title: "Vanilla Birthday",
                    customerName: "Amy",
                    status: .confirmed,
                    dueAt: dueAt,
                    fulfillmentType: .delivery,
                    deliveryAddress: "10 Cake Street",
                    cakeNotes: "Less sweet",
                    quotedPrice: Decimal(string: "125.50"),
                    depositPaid: Decimal(string: "25.50"),
                    paymentNotes: "Bank transfer received",
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
        XCTAssertEqual(viewModel.draftTitle, "")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddOrderRejectsInvalidRecipeMultiplier() {
        let repository = FakeOrderRepository()
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.draftTitle = "Vanilla Birthday"
        viewModel.draftCustomerName = "Amy"
        viewModel.draftRecipeId = "recipe-vanilla"
        viewModel.draftRecipeScaleMultiplier = "0"

        XCTAssertFalse(viewModel.addOrder())
        XCTAssertEqual(viewModel.errorMessage, "Recipe multiplier must be greater than zero.")

        viewModel.draftRecipeScaleMultiplier = "abc"
        XCTAssertFalse(viewModel.addOrder())
        XCTAssertEqual(viewModel.errorMessage, "Recipe multiplier must be greater than zero.")
        XCTAssertTrue(repository.orders.isEmpty)
    }

    func testAddOrderRejectsInvalidPricingAmounts() {
        let repository = FakeOrderRepository()
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.draftTitle = "Vanilla Birthday"
        viewModel.draftCustomerName = "Amy"
        viewModel.draftQuotedPrice = "abc"

        XCTAssertFalse(viewModel.addOrder())
        XCTAssertEqual(viewModel.errorMessage, "Quoted price must be a positive number.")

        viewModel.draftQuotedPrice = "100"
        viewModel.draftDepositPaid = "125"
        XCTAssertFalse(viewModel.addOrder())
        XCTAssertEqual(viewModel.errorMessage, "Deposit paid cannot be more than quoted price.")
        XCTAssertTrue(repository.orders.isEmpty)
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
        XCTAssertEqual(viewModel.draftRecipeScaleMultiplier, "1")
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
        XCTAssertTrue(viewModel.selectedOrderPhotos.isEmpty)
        XCTAssertEqual(viewModel.draftChecklistItemTitle, "")
    }

}
