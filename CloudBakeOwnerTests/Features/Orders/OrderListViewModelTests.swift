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

    func testVisibleOrdersFilterActiveAndCompletedScopes() {
        let repository = FakeOrderRepository()
        let earlierDueAt = Date(timeIntervalSince1970: 1_800_120_000)
        let laterDueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let birthday = makeOrder(
            id: "order-birthday",
            title: "Birthday Cake",
            status: .confirmed,
            dueAt: earlierDueAt
        )
        let wedding = makeOrder(
            id: "order-wedding",
            title: "Wedding Cake",
            status: .ready,
            dueAt: laterDueAt
        )
        let completed = makeOrder(
            id: "order-completed",
            title: "Completed Cake",
            status: .completed,
            dueAt: laterDueAt
        )
        repository.orders = [wedding, completed, birthday]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.load()
        viewModel.searchText = "wedding"

        XCTAssertEqual(viewModel.visibleActiveOrders, [wedding])
        XCTAssertEqual(viewModel.visibleCompletedOrders, [])

        viewModel.searchText = "completed"

        XCTAssertEqual(viewModel.visibleActiveOrders, [])
        XCTAssertEqual(viewModel.visibleCompletedOrders, [completed])
    }

    func testOrderDraftCanSubmitOnlyWhenRequiredFieldsAreValid() {
        let viewModel = OrderListViewModel(repository: FakeOrderRepository())

        XCTAssertFalse(viewModel.canSubmitOrderDraft)

        viewModel.draftTitle = "Chocolate birthday cake"
        XCTAssertFalse(viewModel.canSubmitOrderDraft)

        viewModel.draftCustomerName = "Amy"
        XCTAssertTrue(viewModel.canSubmitOrderDraft)

        viewModel.draftTitle = "   "
        XCTAssertFalse(viewModel.canSubmitOrderDraft)
    }

    func testOrderDraftCannotSubmitWithInvalidPaymentValues() {
        let viewModel = OrderListViewModel(repository: FakeOrderRepository())
        viewModel.draftTitle = "Chocolate birthday cake"
        viewModel.draftCustomerName = "Amy"

        viewModel.draftQuotedPrice = "40"
        viewModel.draftDepositPaid = "45"
        XCTAssertFalse(viewModel.canSubmitOrderDraft)

        viewModel.draftDepositPaid = "20"
        XCTAssertTrue(viewModel.canSubmitOrderDraft)

        viewModel.draftRecipeScaleMultiplier = "0"
        XCTAssertFalse(viewModel.canSubmitOrderDraft)
    }

    func testCalendarDaysUseFilteredActiveOrders() {
        let repository = FakeOrderRepository()
        let calendar = utcCalendar()
        let birthdayDueAt = Date(timeIntervalSince1970: 1_800_057_600)
        let weddingDueAt = Date(timeIntervalSince1970: 1_800_144_000)
        let birthday = makeOrder(id: "order-birthday", title: "Birthday Cake", dueAt: birthdayDueAt)
        let wedding = makeOrder(id: "order-wedding", title: "Wedding Cake", dueAt: weddingDueAt)
        repository.orders = [birthday, wedding]
        let viewModel = OrderListViewModel(repository: repository, calendar: calendar)

        viewModel.load()
        viewModel.searchText = "wedding"

        XCTAssertEqual(
            viewModel.calendarDays,
            [
                OrderCalendarDay(
                    day: calendar.startOfDay(for: weddingDueAt),
                    orders: [wedding]
                )
            ]
        )
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

    func testOverdueAlertUsesDueTimeForSameDayAndExcludesCompletedOrders() {
        let repository = FakeOrderRepository()
        let calendar = utcCalendar()
        let now = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 19))!
        let dueAt = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 18))!
        let order = makeOrder(id: "order-overdue", title: "Birthday Cake", status: .confirmed, dueAt: dueAt)
        repository.orders = [
            makeOrder(id: "order-completed", title: "Done Cake", status: .completed, dueAt: dueAt),
            order
        ]
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.load()

        XCTAssertEqual(viewModel.overdueAlert?.order.id, order.id)
        XCTAssertEqual(viewModel.overdueAlert?.message, "Birthday Cake was due at \(dueAt.formatted(date: .omitted, time: .shortened)), update status?")
        XCTAssertTrue(viewModel.isOverdue(order))
    }

    func testOverdueAlertUsesOverdueMessageAfterDueDayPasses() {
        let repository = FakeOrderRepository()
        let calendar = utcCalendar()
        let now = calendar.date(from: DateComponents(year: 2027, month: 2, day: 11, hour: 8))!
        let dueAt = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 18))!
        repository.orders = [
            makeOrder(id: "order-overdue", title: "Birthday Cake", status: .confirmed, dueAt: dueAt)
        ]
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.load()

        XCTAssertEqual(viewModel.overdueAlert?.message, "Birthday Cake is overdue. Update status?")
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
        viewModel.draftCakeMessage = " Happy Birthday Amy "
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
                    cakeMessage: "Happy Birthday Amy",
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
            photoReference: "photos/floral.jpg",
            tags: ["Birthday", "Floral"]
        )
        let minimalist = makeCakeDesign(id: "design-minimal", name: "Minimal buttercream")
        let hiddenInternet = makeCakeDesign(
            id: "design-internet-hidden",
            name: "Internet inspiration",
            sourceKind: .internetInspiration
        )
        repository.cakeDesigns = [minimalist, floral, hiddenInternet]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.load()
        viewModel.selectDraftCakeDesign(id: "design-floral")

        XCTAssertEqual(viewModel.draftCakeDesignId, "design-floral")
        XCTAssertEqual(viewModel.draftCakeDesignName(), "Pink florals")
        XCTAssertEqual(viewModel.cakeDesigns, [minimalist, floral])
        XCTAssertEqual(viewModel.cakeDesigns(matching: "palette"), [floral])
        XCTAssertEqual(viewModel.cakeDesigns(matching: "pink birthday"), [floral])
        XCTAssertEqual(viewModel.cakeDesigns(matching: "", tag: "Floral"), [floral])
        XCTAssertEqual(viewModel.cakeDesigns(matching: "minimal"), [minimalist])
        viewModel.clearDraftCakeDesignLink()
        XCTAssertEqual(viewModel.draftCakeDesignId, "")
        XCTAssertEqual(viewModel.draftCakeDesignName(), "No Linked Design")
    }

    func testCustomerReferenceSelectionPersistsOnlyWhenOrderIsSaved() {
        let repository = FakeOrderRepository()
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: { "order-from-reference" },
            dateProvider: { Date(timeIntervalSince1970: 1_800_140_000) }
        )
        viewModel.beginAddingOrder()

        viewModel.selectDraftCustomerReference(photoId: "photo-customer-reference")

        XCTAssertTrue(repository.orders.isEmpty)
        XCTAssertEqual(viewModel.draftDesignReferenceName, "Customer Reference")
        XCTAssertEqual(viewModel.draftCustomerReferencePhotoId, "photo-customer-reference")
        XCTAssertTrue(viewModel.draftCakeDesignId.isEmpty)

        viewModel.draftTitle = "Reference cake"
        viewModel.draftCustomerName = "Amy"
        XCTAssertTrue(viewModel.addOrder())
        XCTAssertEqual(
            repository.orders.first?.customerReferencePhotoId,
            "photo-customer-reference"
        )
        XCTAssertNil(repository.orders.first?.cakeDesignId)
    }

    func testOrderDesignPickerLoadsAndSearchesCustomerReferences() {
        let repository = FakeOrderRepository()
        let sourceOrder = makeOrder(
            id: "order-reference-source",
            title: "Blue wedding cake",
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        let photo = makeOrderPhoto(
            id: "photo-reference-picker",
            orderId: sourceOrder.id,
            kind: .customerReference,
            caption: "Floral sketch",
            tags: ["Wedding", "Blue"]
        )
        repository.orders = [sourceOrder]
        repository.orderPhotos = [photo]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginAddingOrder()

        XCTAssertEqual(viewModel.designCustomerReferences.map(\.id), [photo.id])
        XCTAssertEqual(
            viewModel.customerReferences(matching: "blue floral", tag: "Wedding").map(\.id),
            [photo.id]
        )
        XCTAssertEqual(viewModel.mostUsedDesignTags, ["Blue", "Wedding"])
    }

    func testEditingOrderRetainsHiddenHistoricalDesignLabelWithoutOfferingItAsChoice() {
        let repository = FakeOrderRepository()
        let historicalDesign = makeCakeDesign(
            id: "design-retired-internet",
            name: "Retired inspiration",
            sourceKind: .internetInspiration
        )
        let order = makeOrder(
            id: "order-historical-design",
            cakeDesignId: historicalDesign.id,
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        repository.orders = [order]
        repository.cakeDesigns = [historicalDesign]
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.beginViewingOrder(order)

        viewModel.beginEditingOrder()

        XCTAssertEqual(viewModel.draftCakeDesignName(), "Retired inspiration")
        XCTAssertEqual(viewModel.draftCakeDesignId, historicalDesign.id)
        XCTAssertTrue(viewModel.cakeDesigns(matching: "", tag: nil).isEmpty)
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

    func testCustomerCreationViewModelCanAddAndSelectCustomerFromOrderDraft() throws {
        let repository = FakeOrderRepository()
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
            dateProvider: { Date(timeIntervalSince1970: 1_800_060_000) }
        )

        viewModel.beginAddingOrder()
        let customerViewModel = viewModel.makeCustomerListViewModel()
        customerViewModel.beginAddingCustomer()
        customerViewModel.draftName = "Maya"
        customerViewModel.draftPhone = "5550303"

        XCTAssertTrue(customerViewModel.addCustomer())
        let customer = try XCTUnwrap(customerViewModel.lastSavedCustomer)
        viewModel.reloadCustomers()
        viewModel.selectDraftCustomer(id: customer.id)

        XCTAssertEqual(viewModel.customers, [customer])
        XCTAssertEqual(viewModel.draftCustomerId, customer.id)
        XCTAssertEqual(viewModel.draftCustomerName, "Maya")
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

    func testWhatsAppMessageURLUsesLinkedCustomerPhoneAndOrderContext() throws {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-chocolate",
            title: "Chocolate Truffle Cake",
            customerId: "customer-amy",
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        repository.orders = [order]
        repository.customers = [
            makeCustomer(id: "customer-amy", name: "Amy Rao", phone: "+65 9123 4567")
        ]
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.load()

        let url = try XCTUnwrap(viewModel.whatsappMessageURL(for: order))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "whatsapp")
        XCTAssertEqual(components.host, "send")
        XCTAssertEqual(components.queryItems?.first { $0.name == "phone" }?.value, "+6591234567")
        let message = try XCTUnwrap(components.queryItems?.first { $0.name == "text" }?.value)
        XCTAssertTrue(message.contains("Hi Amy, this is regarding your CloudBake order."))
        XCTAssertTrue(message.contains("Order: Chocolate Truffle Cake"))
        XCTAssertTrue(message.contains("Due:"))
    }

    func testWhatsAppMessageURLRequiresLinkedCustomerWithPhone() {
        let repository = FakeOrderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let unlinkedOrder = makeOrder(id: "order-unlinked", customerId: nil, dueAt: dueAt)
        let noPhoneOrder = makeOrder(id: "order-no-phone", customerId: "customer-no-phone", dueAt: dueAt)
        let nonDialablePhoneOrder = makeOrder(id: "order-non-dialable-phone", customerId: "customer-non-dialable-phone", dueAt: dueAt)
        repository.orders = [unlinkedOrder, noPhoneOrder, nonDialablePhoneOrder]
        repository.customers = [
            makeCustomer(id: "customer-no-phone", name: "Amy Rao", phone: " "),
            makeCustomer(id: "customer-non-dialable-phone", name: "Maya Rao", phone: "N/A")
        ]
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.load()

        XCTAssertNil(viewModel.whatsappMessageURL(for: unlinkedOrder))
        XCTAssertNil(viewModel.whatsappMessageURL(for: noPhoneOrder))
        XCTAssertNil(viewModel.whatsappMessageURL(for: nonDialablePhoneOrder))
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
        XCTAssertTrue(viewModel.selectedOrderExtraIngredients.isEmpty)
        XCTAssertTrue(viewModel.selectedOrderChecklistItems.isEmpty)
        XCTAssertTrue(viewModel.selectedOrderPhotos.isEmpty)
        XCTAssertEqual(viewModel.draftChecklistItemTitle, "")
    }

    func testBeginViewingOrderExposesInternetInspirationProvenance() {
        let repository = FakeOrderRepository()
        let design = makeCakeDesign(
            id: "design-internet",
            name: "Saved inspiration",
            sourceKind: .internetInspiration
        )
        let order = makeOrder(
            id: "order-internet-design",
            cakeDesignId: design.id,
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        repository.cakeDesigns = [design]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(viewModel.selectedOrderCakeDesign, design)
        XCTAssertEqual(viewModel.selectedOrderDesignSourceName, "Internet Inspiration")
    }

    func testBeginViewingOrderExposesCustomerReferenceProvenance() {
        let repository = FakeOrderRepository()
        let photo = makeOrderPhoto(
            id: "photo-customer-reference",
            orderId: "order-source",
            kind: .customerReference
        )
        let order = makeOrder(
            id: "order-customer-reference",
            customerReferencePhotoId: photo.id,
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        repository.orderPhotos = [photo]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(viewModel.selectedOrderCustomerReferencePhoto, photo)
        XCTAssertEqual(viewModel.selectedOrderDesignSourceName, "Customer Reference")
        XCTAssertNil(viewModel.selectedOrderCakeDesign)
    }

    func testExtraIngredientCanBeAddedAndDisplayedForSelectedOrder() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        let almonds = makeInventoryItem(id: "inventory-almonds", name: "Almonds", unit: .gram)
        repository.orders = [order]
        repository.inventoryItems = [almonds]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "extra"),
            dateProvider: { Date(timeIntervalSince1970: 1_800_150_000) }
        )
        viewModel.beginViewingOrder(order)
        viewModel.beginAddingExtraIngredient()

        viewModel.draftExtraIngredientQuantity = "75"
        viewModel.draftExtraIngredientNote = "Extra crunch"

        XCTAssertTrue(viewModel.addExtraIngredientToSelectedOrder())
        XCTAssertEqual(
            viewModel.selectedOrderExtraIngredients,
            [
                OrderExtraIngredientRow(
                    ingredient: OrderExtraIngredient(
                        id: "extra-1",
                        orderId: order.id,
                        inventoryItemId: almonds.id,
                        quantity: 75,
                        unit: .gram,
                        note: "Extra crunch",
                        createdAt: Date(timeIntervalSince1970: 1_800_150_000),
                        updatedAt: Date(timeIntervalSince1970: 1_800_150_000)
                    ),
                    inventoryItemName: "Almonds"
                )
            ]
        )
    }

    func testOrderFormSavesDraftExtraIngredientsWithNewOrder() throws {
        let repository = FakeOrderRepository()
        let recipe = makeRecipe(id: "recipe-vanilla", name: "Vanilla Sponge")
        let almonds = makeInventoryItem(id: "inventory-almonds", name: "Almonds", unit: .gram)
        repository.recipes = [recipe]
        repository.inventoryItems = [almonds]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "order-form"),
            dateProvider: { Date(timeIntervalSince1970: 1_800_150_000) }
        )

        viewModel.beginAddingOrder()
        viewModel.draftTitle = "Vanilla Almond Cake"
        viewModel.draftCustomerName = "Amy"
        viewModel.selectDraftRecipe(id: recipe.id)
        viewModel.beginAddingExtraIngredient()
        viewModel.draftExtraIngredientQuantity = "40"

        XCTAssertTrue(viewModel.addExtraIngredientToDraftOrder())
        XCTAssertEqual(viewModel.draftExtraIngredientRows.map(\.inventoryItemName), ["Almonds"])
        XCTAssertTrue(viewModel.addOrder())

        let savedOrder = try XCTUnwrap(repository.orders.first)
        XCTAssertEqual(savedOrder.id, "order-form-2")
        XCTAssertEqual(savedOrder.recipeId, recipe.id)
        XCTAssertEqual(
            repository.extraIngredients,
            [
                OrderExtraIngredient(
                    id: "order-form-1",
                    orderId: savedOrder.id,
                    inventoryItemId: almonds.id,
                    quantity: 40,
                    unit: .gram,
                    note: nil,
                    createdAt: Date(timeIntervalSince1970: 1_800_150_000),
                    updatedAt: Date(timeIntervalSince1970: 1_800_150_000)
                )
            ]
        )
    }

    func testClearingDraftRecipeRemovesDraftExtraIngredients() {
        let repository = FakeOrderRepository()
        repository.recipes = [makeRecipe(id: "recipe-vanilla", name: "Vanilla Sponge")]
        repository.inventoryItems = [makeInventoryItem(id: "inventory-almonds", name: "Almonds")]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginAddingOrder()
        viewModel.selectDraftRecipe(id: "recipe-vanilla")
        viewModel.beginAddingExtraIngredient()
        viewModel.draftExtraIngredientQuantity = "40"
        XCTAssertTrue(viewModel.addExtraIngredientToDraftOrder())

        viewModel.clearDraftRecipeLink()

        XCTAssertTrue(viewModel.draftRecipeId.isEmpty)
        XCTAssertTrue(viewModel.draftExtraIngredientRows.isEmpty)
    }

    func testOrderDetailShowsShortageFromDemandAcrossActiveOrders() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_140_000)
        let selectedOrder = makeOrder(
            id: "order-one",
            recipeId: "recipe-cake",
            status: .confirmed,
            dueAt: timestamp
        )
        repository.orders = [
            selectedOrder,
            makeOrder(
                id: "order-two",
                recipeId: "recipe-cake",
                status: .confirmed,
                dueAt: timestamp
            )
        ]
        repository.recipes = [makeRecipe(id: "recipe-cake", name: "Cake")]
        repository.inventoryItems = [
            makeInventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                currentQuantity: 10,
                minimumQuantity: 5
            )
        ]
        repository.recipeComponents = [
            RecipeComponent(
                id: "component-cake",
                recipeId: "recipe-cake",
                name: "Cake",
                sortOrder: 0,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        repository.recipeIngredients = [
            RecipeIngredient(
                id: "ingredient-flour",
                componentId: "component-cake",
                inventoryItemId: "inventory-flour",
                quantity: 6,
                unit: .gram,
                note: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        let viewModel = OrderListViewModel(repository: repository, dateProvider: { timestamp })

        viewModel.beginViewingOrder(selectedOrder)

        XCTAssertEqual(viewModel.selectedOrderIngredientShortages.count, 1)
        XCTAssertEqual(viewModel.selectedOrderIngredientShortages[0].requiredQuantity, 12, accuracy: 0.001)
        XCTAssertEqual(viewModel.selectedOrderIngredientShortages[0].availableQuantity, 10, accuracy: 0.001)
    }

    func testOrderDetailCalculatesEstimatedIngredientCostFromBatchAmount() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_140_000)
        let order = makeOrder(
            id: "order-cost",
            recipeId: "recipe-cake",
            status: .confirmed,
            dueAt: timestamp
        )
        repository.orders = [order]
        repository.recipes = [makeRecipe(id: "recipe-cake", name: "Cake")]
        repository.inventoryItems = [makeInventoryItem(id: "inventory-flour", name: "Cake flour")]
        repository.inventoryStockBatches = [
            InventoryStockBatch(
                id: "batch-flour",
                inventoryItemId: "inventory-flour",
                remainingQuantity: 100,
                expiresAt: timestamp.addingTimeInterval(86_400),
                amount: 50,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        repository.extraIngredients = [
            OrderExtraIngredient(
                id: "extra-flour",
                orderId: order.id,
                inventoryItemId: "inventory-flour",
                quantity: 10,
                unit: .gram,
                note: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        let viewModel = OrderListViewModel(repository: repository, dateProvider: { timestamp })

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(viewModel.selectedOrderIngredientCost?.knownCost, decimal("5"))
        XCTAssertFalse(viewModel.selectedOrderIngredientCostIsActual)
    }

    func testOrderFormCalculatesEstimatedIngredientCostBeforeQuoting() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_140_000)
        repository.recipes = [makeRecipe(id: "recipe-cake", name: "Cake")]
        repository.inventoryItems = [makeInventoryItem(id: "inventory-flour", name: "Cake flour")]
        repository.recipeComponents = [
            RecipeComponent(
                id: "component-cake",
                recipeId: "recipe-cake",
                name: "Cake",
                sortOrder: 0,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        repository.recipeIngredients = [
            RecipeIngredient(
                id: "ingredient-flour",
                componentId: "component-cake",
                inventoryItemId: "inventory-flour",
                quantity: 100,
                unit: .gram,
                note: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        repository.inventoryStockBatches = [
            InventoryStockBatch(
                id: "batch-flour",
                inventoryItemId: "inventory-flour",
                remainingQuantity: 500,
                expiresAt: timestamp.addingTimeInterval(86_400),
                amount: 50,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        let viewModel = OrderListViewModel(repository: repository, dateProvider: { timestamp })

        viewModel.beginAddingOrder()
        viewModel.selectDraftRecipe(id: "recipe-cake")

        XCTAssertEqual(viewModel.draftIngredientCost?.knownCost, decimal("10"))
        XCTAssertEqual(viewModel.draftIngredientCost?.itemsMissingPrice, [])
    }

    func testOrderDetailUsesPersistedActualIngredientCostAfterDeduction() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_140_000)
        let order = makeOrder(
            id: "order-cost",
            recipeId: "recipe-cake",
            status: .ready,
            dueAt: timestamp
        )
        repository.orders = [order]
        repository.recipes = [makeRecipe(id: "recipe-cake", name: "Cake")]
        repository.inventoryItems = [makeInventoryItem(id: "inventory-flour", name: "Cake flour")]
        repository.ingredientCosts = [
            OrderIngredientCost(
                id: "cost-flour",
                orderId: order.id,
                inventoryItemId: "inventory-flour",
                quantity: 10,
                unit: .gram,
                knownCost: 7,
                missingPriceQuantity: 0,
                recordedAt: timestamp
            )
        ]
        let viewModel = OrderListViewModel(repository: repository, dateProvider: { timestamp })

        viewModel.beginViewingOrder(order)
        viewModel.beginEditingOrder()

        XCTAssertEqual(viewModel.selectedOrderIngredientCost?.knownCost, decimal("7"))
        XCTAssertTrue(viewModel.selectedOrderIngredientCostIsActual)
        XCTAssertEqual(viewModel.draftIngredientCost?.knownCost, decimal("7"))
        XCTAssertTrue(viewModel.draftIngredientCostIsActual)
    }

    func testOrderDetailDoesNotEstimateHistoricalUsageWithoutActualCostSnapshot() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_140_000)
        let order = makeOrder(
            id: "order-historical-cost",
            recipeId: "recipe-cake",
            status: .completed,
            dueAt: timestamp
        )
        repository.orders = [order]
        repository.recipes = [makeRecipe(id: "recipe-cake", name: "Cake")]
        repository.usages = [
            OrderRecipeUsage(
                id: "usage-historical-cost",
                orderId: order.id,
                recipeId: "recipe-cake",
                usedAt: timestamp,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        let viewModel = OrderListViewModel(repository: repository, dateProvider: { timestamp })

        viewModel.beginViewingOrder(order)

        XCTAssertNil(viewModel.selectedOrderIngredientCost)
        XCTAssertTrue(viewModel.selectedOrderIngredientCostIsActual)
    }

    func testStatusConfirmationIsRequiredOnlyBeforeUnrecordedRecipeDeduction() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_140_000)
        let order = makeOrder(
            id: "order-confirmation",
            recipeId: "recipe-cake",
            status: .confirmed,
            dueAt: timestamp
        )
        let viewModel = OrderListViewModel(repository: repository)

        XCTAssertFalse(viewModel.requiresInventoryDeductionConfirmation(for: order, to: .inProgress))
        XCTAssertTrue(viewModel.requiresInventoryDeductionConfirmation(for: order, to: .ready))

        repository.usages = [
            OrderRecipeUsage(
                id: "usage-confirmation",
                orderId: order.id,
                recipeId: "recipe-cake",
                usedAt: timestamp,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]

        XCTAssertFalse(viewModel.requiresInventoryDeductionConfirmation(for: order, to: .completed))
    }

    func testOrderDetailKeepsActualCostForArchivedInventoryItem() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_140_000)
        let order = makeOrder(
            id: "order-archived-cost",
            recipeId: "recipe-cake",
            status: .completed,
            dueAt: timestamp
        )
        let archivedFlour = InventoryItem(
            id: "inventory-archived-flour",
            name: "Archived cake flour",
            unit: .gram,
            currentQuantity: 0,
            minimumQuantity: 10,
            createdAt: timestamp,
            updatedAt: timestamp,
            archivedAt: timestamp
        )
        repository.orders = [order]
        repository.recipes = [makeRecipe(id: "recipe-cake", name: "Cake")]
        repository.inventoryItems = [archivedFlour]
        repository.ingredientCosts = [
            OrderIngredientCost(
                id: "cost-archived-flour",
                orderId: order.id,
                inventoryItemId: archivedFlour.id,
                quantity: 100,
                unit: .gram,
                knownCost: 12,
                missingPriceQuantity: 0,
                recordedAt: timestamp
            )
        ]
        let viewModel = OrderListViewModel(repository: repository, dateProvider: { timestamp })

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(viewModel.selectedOrderIngredientCost?.knownCost, decimal("12"))
        XCTAssertEqual(viewModel.selectedOrderIngredientCost?.lines.first?.inventoryItemName, "Archived cake flour")
    }

    func testFailedStatusEditDoesNotPersistDraftExtraIngredients() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        repository.orders = [order]
        repository.recipes = [makeRecipe(id: "recipe-vanilla", name: "Vanilla Sponge")]
        repository.inventoryItems = [makeInventoryItem(id: "inventory-almonds", name: "Almonds")]
        repository.changeOrderStatusError = OrderRecipeUsageError.insufficientStock(itemName: "Almonds")
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.beginViewingOrder(order)
        viewModel.beginEditingOrder()
        viewModel.draftStatus = .ready
        viewModel.beginAddingExtraIngredient()
        viewModel.draftExtraIngredientQuantity = "40"
        XCTAssertTrue(viewModel.addExtraIngredientToDraftOrder())

        XCTAssertFalse(viewModel.saveEditedOrder(confirmingRecipeUsage: true))

        XCTAssertTrue(repository.extraIngredients.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "Not enough Almonds in inventory.")
    }

}
