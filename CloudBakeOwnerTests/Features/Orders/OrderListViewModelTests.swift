import XCTest

@testable import CloudBakeOwner

@MainActor
final class OrderListViewModelTests: XCTestCase {
    func testApplyingOrderTemplatePreservesOrderContextAndClearsCommercialFields() throws {
        let repository = FakeOrderRepository()
        let now = Date(timeIntervalSince1970: 1_800_060_000)
        let dueAt = now.addingTimeInterval(172_800)
        repository.inventoryItems = [
            makeInventoryItem(id: "inventory-berries", name: "Berries")
        ]
        let template = OrderTemplate(
            id: "template-birthday",
            name: "Birthday Standard",
            cakeTitle: "Vanilla Birthday Cake",
            cakeDesignId: "design-floral",
            recipeId: "recipe-vanilla",
            recipeScaleMultiplier: 2,
            fulfillmentType: .delivery,
            cakeNotes: "Pink flowers",
            cakeMessage: "Happy Birthday",
            cakeSpecification: OrderCakeSpecification(
                occasion: "Birthday",
                servings: 28,
                weightKilograms: 2,
                shape: "Circle",
                spongeFlavour: "Chocolate",
                packaging: "Tall Box"
            ),
            reminderConfiguration: try OrderReminderConfiguration(
                mode: .custom,
                dayOffsets: [5, 1],
                includesDueTime: false
            ),
            extraIngredients: [
                OrderTemplateExtraIngredient(
                    id: "template-extra",
                    inventoryItemId: "inventory-berries",
                    quantity: 100,
                    unit: .gram,
                    note: "Decoration",
                    sortOrder: 0
                )
            ],
            checklistItems: [
                OrderTemplateChecklistItem(
                    id: "template-checklist",
                    title: "Add topper",
                    sortOrder: 0
                )
            ],
            createdAt: now,
            updatedAt: now
        )
        repository.orderTemplates = [template]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "applied"),
            dateProvider: { now }
        )

        viewModel.beginAddingOrder()
        viewModel.draftCustomerId = "customer-amy"
        viewModel.draftCustomerName = "Amy"
        viewModel.draftDeliveryAddress = "Amy's current address"
        viewModel.draftDueAt = dueAt
        viewModel.draftQuotedPrice = "200"
        viewModel.draftDepositPaid = "50"
        viewModel.draftPaymentNotes = "Cash"

        viewModel.applyOrderTemplate(template)

        XCTAssertEqual(viewModel.draftCustomerId, "customer-amy")
        XCTAssertEqual(viewModel.draftCustomerName, "Amy")
        XCTAssertEqual(viewModel.draftDueAt, dueAt)
        XCTAssertEqual(viewModel.draftTitle, "Vanilla Birthday Cake")
        XCTAssertEqual(viewModel.draftRecipeId, "recipe-vanilla")
        XCTAssertEqual(viewModel.draftRecipeScaleMultiplier, "2")
        XCTAssertEqual(viewModel.draftCakeDesignId, "design-floral")
        XCTAssertEqual(viewModel.draftFulfillmentType, .delivery)
        XCTAssertEqual(viewModel.draftDeliveryAddress, "Amy's current address")
        XCTAssertEqual(viewModel.draftCakeOccasion, "Birthday")
        XCTAssertEqual(viewModel.draftCakeServings, "28")
        XCTAssertEqual(viewModel.draftCakeWeightKilograms, "2")
        XCTAssertEqual(viewModel.draftCakeShape, "Circle")
        XCTAssertEqual(viewModel.draftCakeSpongeFlavour, "Chocolate")
        XCTAssertEqual(viewModel.draftCakePackaging, "Tall Box")
        XCTAssertEqual(viewModel.draftQuotedPrice, "")
        XCTAssertEqual(viewModel.draftDepositPaid, "")
        XCTAssertEqual(viewModel.draftPaymentNotes, "")
        XCTAssertEqual(viewModel.draftExtraIngredientRows.map(\.id), ["applied-1"])
        XCTAssertEqual(viewModel.draftExtraIngredientRows.map(\.inventoryItemName), ["Berries"])
        XCTAssertEqual(
            viewModel.draftChecklistItems,
            [OrderChecklistDraftItem(id: "applied-2", title: "Add topper")]
        )
    }

    func testDraftCanBeSavedRenamedAndDeletedAsOrderTemplate() throws {
        let repository = FakeOrderRepository()
        let now = Date(timeIntervalSince1970: 1_800_060_000)
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "template"),
            dateProvider: { now }
        )

        viewModel.beginAddingOrder()
        viewModel.draftTitle = "Chocolate Cake"
        viewModel.draftCustomerName = "Customer who must not be stored"
        viewModel.draftQuotedPrice = "150"
        viewModel.draftPaymentNotes = "Payment that must not be stored"
        viewModel.draftCakeNotes = "Ganache"
        viewModel.draftCakeSpongeFlavour = "Pandan"
        viewModel.draftCakePackaging = "Window Box"
        viewModel.draftFulfillmentType = .pickup

        XCTAssertTrue(viewModel.saveCurrentDraftAsTemplate(named: "  Chocolate Standard  "))
        let saved = try XCTUnwrap(repository.orderTemplates.first)
        XCTAssertEqual(saved.id, "template-1")
        XCTAssertEqual(saved.name, "Chocolate Standard")
        XCTAssertEqual(saved.cakeTitle, "Chocolate Cake")
        XCTAssertEqual(saved.cakeNotes, "Ganache")
        XCTAssertEqual(saved.cakeSpecification.spongeFlavour, "Pandan")
        XCTAssertEqual(saved.cakeSpecification.packaging, "Window Box")
        XCTAssertEqual(repository.cakeRequirementChoices[.spongeFlavour], ["Pandan"])

        XCTAssertTrue(viewModel.renameOrderTemplate(saved, to: "Chocolate Celebration"))
        let renamed = try XCTUnwrap(repository.orderTemplates.first)
        XCTAssertEqual(renamed.name, "Chocolate Celebration")
        XCTAssertEqual(renamed.createdAt, now)

        XCTAssertTrue(viewModel.deleteOrderTemplate(renamed))
        XCTAssertTrue(repository.orderTemplates.isEmpty)
        XCTAssertTrue(viewModel.orderTemplates.isEmpty)
    }

    func testTemplateRejectsInvalidCakeCapacityWithoutCustomerFields() {
        let repository = FakeOrderRepository()
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.beginAddingOrder()
        viewModel.draftTitle = "Pandan Cake"
        viewModel.draftCakeServings = "3.5"

        XCTAssertFalse(viewModel.saveCurrentDraftAsTemplate(named: "Pandan Standard"))
        XCTAssertEqual(viewModel.errorMessage, "Servings must be a positive whole number.")
        XCTAssertEqual(viewModel.draftCakeServings, "3.5")

        viewModel.draftCakeServings = "28"
        viewModel.draftCakeWeightKilograms = "0"
        XCTAssertFalse(viewModel.saveCurrentDraftAsTemplate(named: "Pandan Standard"))
        XCTAssertEqual(viewModel.errorMessage, "Weight must be greater than zero.")
        XCTAssertEqual(viewModel.draftCakeWeightKilograms, "0")
        XCTAssertTrue(repository.orderTemplates.isEmpty)
    }

    func testCakeCapacitySuggestionsNeverOverwriteEnteredValues() {
        let viewModel = OrderListViewModel(repository: FakeOrderRepository())

        viewModel.beginAddingOrder()
        viewModel.draftCakeServings = "28"
        viewModel.applySuggestedCakeWeight()
        XCTAssertEqual(viewModel.draftCakeWeightKilograms, "2")

        viewModel.draftCakeWeightKilograms = "3"
        viewModel.draftCakeServings = ""
        viewModel.applySuggestedCakeServings()
        XCTAssertEqual(viewModel.draftCakeServings, "42")

        viewModel.draftCakeServings = "30"
        viewModel.applySuggestedCakeServings()
        XCTAssertEqual(viewModel.draftCakeServings, "30")
    }

    func testEditingOrderLoadsAndPersistsStructuredCakeRequirements() {
        let repository = FakeOrderRepository()
        let now = Date(timeIntervalSince1970: 1_800_060_000)
        let order = makeOrder(
            id: "structured-edit",
            dueAt: now.addingTimeInterval(86_400),
            cakeSpecification: OrderCakeSpecification(
                occasion: "Anniversary",
                servings: 28,
                weightKilograms: 2,
                shape: "Oval",
                spongeFlavour: "Pandan",
                packaging: "Tall Box"
            )
        )
        repository.orders = [order]
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { now }
        )

        viewModel.beginViewingOrder(order)
        viewModel.beginEditingOrder()

        XCTAssertEqual(viewModel.draftCakeOccasion, "Anniversary")
        XCTAssertEqual(viewModel.draftCakeServings, "28")
        XCTAssertEqual(viewModel.draftCakeWeightKilograms, "2")
        XCTAssertEqual(viewModel.draftCakeShape, "Oval")
        XCTAssertEqual(viewModel.draftCakeSpongeFlavour, "Pandan")
        viewModel.draftCakeTheme = "Botanical"

        XCTAssertTrue(viewModel.saveEditedOrder())
        XCTAssertEqual(repository.orders.first?.cakeSpecification.theme, "Botanical")
        XCTAssertEqual(repository.orders.first?.cakeSpecification.spongeFlavour, "Pandan")
    }

    func testTemplateWithDeletedRecipeDoesNotApplyHiddenExtraIngredients() {
        let repository = FakeOrderRepository()
        repository.inventoryItems = [
            makeInventoryItem(id: "inventory-berries", name: "Berries")
        ]
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let template = OrderTemplate(
            id: "template-with-deleted-recipe",
            name: "Historical Template",
            cakeTitle: "Cake",
            cakeDesignId: nil,
            recipeId: nil,
            recipeScaleMultiplier: 1,
            fulfillmentType: .pickup,
            cakeNotes: nil,
            cakeMessage: nil,
            reminderConfiguration: .initialDefault,
            extraIngredients: [
                OrderTemplateExtraIngredient(
                    id: "stale-extra",
                    inventoryItemId: "inventory-berries",
                    quantity: 10,
                    unit: .gram,
                    note: nil,
                    sortOrder: 0
                )
            ],
            checklistItems: [],
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginAddingOrder()
        viewModel.applyOrderTemplate(template)

        XCTAssertTrue(viewModel.draftExtraIngredientRows.isEmpty)
        XCTAssertEqual(
            viewModel.errorMessage,
            "The template recipe is no longer available, so its extra ingredients were not added. Choose a recipe and review ingredients before saving."
        )
    }

    func testTemplateOmitsArchivedExtraIngredientsWithWarning() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let template = OrderTemplate(
            id: "template-archived-extra",
            name: "Archived Extra",
            cakeTitle: "Cake",
            cakeDesignId: nil,
            recipeId: "recipe-cake",
            recipeScaleMultiplier: 1,
            fulfillmentType: .pickup,
            cakeNotes: nil,
            cakeMessage: nil,
            reminderConfiguration: .initialDefault,
            extraIngredients: [
                OrderTemplateExtraIngredient(
                    id: "archived-extra",
                    inventoryItemId: "archived-inventory",
                    quantity: 10,
                    unit: .gram,
                    note: nil,
                    sortOrder: 0
                )
            ],
            checklistItems: [],
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginAddingOrder()
        viewModel.applyOrderTemplate(template)

        XCTAssertTrue(viewModel.draftExtraIngredientRows.isEmpty)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Some template ingredients are archived and were not added. Add an active replacement before saving."
        )
    }

    func testOrderDetailOnlyOffersDuplicateWhenHostProvidesWorkflow() {
        XCTAssertTrue(OrderDetailView.duplicateActions(onDuplicate: nil).isEmpty)

        var didDuplicate = false
        let actions = OrderDetailView.duplicateActions {
            didDuplicate = true
        }

        XCTAssertEqual(actions.map(\.accessibilityIdentifier), ["orders.detail.duplicate"])
        actions[0].action()
        XCTAssertTrue(didDuplicate)
    }

    func testBeginAddingOrderDefaultsDueTimeToNextDayAtNearestHour() {
        let repository = FakeOrderRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let beforeHalfHour = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 1, hour: 12, minute: 23, second: 56)
        )!
        let afterHalfHour = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 1, hour: 12, minute: 31)
        )!
        var now = beforeHalfHour
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.beginAddingOrder()

        XCTAssertEqual(
            viewModel.draftDueAt,
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 12))
        )

        now = afterHalfHour
        viewModel.beginAddingOrder()

        XCTAssertEqual(
            viewModel.draftDueAt,
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 13))
        )
    }

    func testOrderWithoutRecipeCanMoveToReadyAndCompleted() throws {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let order = makeOrder(
            id: "order-no-recipe",
            recipeId: nil,
            status: .confirmed,
            dueAt: timestamp
        )
        repository.orders = [order]
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { timestamp }
        )

        XCTAssertTrue(viewModel.changeOrderStatus(order, to: .ready))
        let readyOrder = try XCTUnwrap(viewModel.order(id: order.id))
        XCTAssertTrue(viewModel.changeOrderStatus(readyOrder, to: .completed))

        XCTAssertEqual(viewModel.order(id: order.id)?.status, .completed)
        XCTAssertTrue(repository.usages.isEmpty)
    }

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

    func testLoadPagesActiveAndCompletedOrdersIndependently() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let activeOrders = (0..<26).map { index in
            makeOrder(
                id: String(format: "active-%02d", index),
                status: .confirmed,
                dueAt: timestamp.addingTimeInterval(TimeInterval(index))
            )
        }
        let completedOrders = (0..<26).map { index in
            makeOrder(
                id: String(format: "completed-%02d", index),
                status: .completed,
                dueAt: timestamp.addingTimeInterval(TimeInterval(index))
            )
        }
        repository.orders = activeOrders + completedOrders
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.activeOrders.count, 25)
        XCTAssertEqual(viewModel.completedOrders.count, 25)
        XCTAssertTrue(viewModel.canLoadMoreActiveOrders)
        XCTAssertTrue(viewModel.canLoadMoreCompletedOrders)
        XCTAssertEqual(viewModel.order(id: "active-25"), activeOrders[25])

        viewModel.loadMoreActiveOrders()
        viewModel.loadMoreCompletedOrders()

        XCTAssertEqual(viewModel.activeOrders.count, 26)
        XCTAssertEqual(viewModel.completedOrders.count, 26)
        XCTAssertFalse(viewModel.canLoadMoreActiveOrders)
        XCTAssertFalse(viewModel.canLoadMoreCompletedOrders)
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
                ),
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

    func testNewOrderCopiesCurrentReminderDefaultsAndRefreshesNotifications() throws {
        let repository = FakeOrderRepository()
        repository.defaultOrderReminderConfiguration = try OrderReminderConfiguration(
            mode: .defaultSnapshot,
            dayOffsets: [7, 2],
            includesDueTime: false
        )
        var refreshCount = 0
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: { "order-reminder-default" },
            onReminderDataChanged: { refreshCount += 1 }
        )

        viewModel.beginAddingOrder()
        viewModel.draftTitle = "Vanilla cake"
        viewModel.draftCustomerName = "Amy"

        XCTAssertEqual(viewModel.draftReminderMode, .useDefaults)
        XCTAssertEqual(viewModel.draftReminderDayOffsets, "7, 2")
        XCTAssertFalse(viewModel.draftReminderIncludesDueTime)
        XCTAssertTrue(viewModel.addOrder())
        XCTAssertEqual(
            repository.orderReminderConfigurations["order-reminder-default"],
            repository.defaultOrderReminderConfiguration
        )
        XCTAssertEqual(refreshCount, 1)
    }

    func testEditingOrderCanSaveCustomOrDisabledReminderPlan() throws {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-custom-reminder",
            dueAt: Date(timeIntervalSince1970: 1_800_120_000)
        )
        repository.orders = [order]
        repository.orderReminderConfigurations[order.id] = try OrderReminderConfiguration(
            mode: .custom,
            dayOffsets: [10, 1],
            includesDueTime: true
        )
        var refreshCount = 0
        let viewModel = OrderListViewModel(
            repository: repository,
            onReminderDataChanged: { refreshCount += 1 }
        )

        viewModel.load()
        viewModel.beginViewingOrder(order)
        viewModel.beginEditingOrder()

        XCTAssertEqual(viewModel.draftReminderMode, .custom)
        XCTAssertEqual(viewModel.draftReminderDayOffsets, "10, 1")
        XCTAssertTrue(viewModel.draftReminderIncludesDueTime)

        viewModel.draftReminderMode = .disabled
        XCTAssertTrue(viewModel.saveEditedOrder())
        XCTAssertEqual(
            repository.orderReminderConfigurations[order.id],
            .disabled
        )
        XCTAssertEqual(refreshCount, 1)
    }

    func testEditingCompletedOrderPreservesFirstCompletionTime() {
        let repository = FakeOrderRepository()
        let completedAt = Date(timeIntervalSince1970: 1_800_070_000)
        let order = makeOrder(
            id: "order-completed-edit",
            status: .completed,
            dueAt: Date(timeIntervalSince1970: 1_800_120_000),
            completedAt: completedAt
        )
        repository.orders = [order]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.load()
        viewModel.beginViewingOrder(order)
        viewModel.beginEditingOrder()
        viewModel.draftCakeNotes = "Keep completion history"

        XCTAssertTrue(viewModel.saveEditedOrder())
        XCTAssertEqual(viewModel.selectedOrder?.completedAt, completedAt)
        XCTAssertEqual(repository.orders.first?.completedAt, completedAt)
    }

    func testInvalidCustomReminderPlanKeepsOrderDraftOpen() {
        let repository = FakeOrderRepository()
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: { "order-invalid-reminder" }
        )
        viewModel.beginAddingOrder()
        viewModel.draftTitle = "Vanilla cake"
        viewModel.draftCustomerName = "Amy"
        viewModel.draftReminderMode = .custom
        viewModel.draftReminderDayOffsets = "3, 3"

        XCTAssertFalse(viewModel.addOrder())
        XCTAssertTrue(repository.orders.isEmpty)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Enter each reminder day only once."
        )
    }

    func testChoosingDefaultsReplacesCustomDraftWithCurrentDefaults() throws {
        let repository = FakeOrderRepository()
        repository.defaultOrderReminderConfiguration = try OrderReminderConfiguration(
            mode: .defaultSnapshot,
            dayOffsets: [6, 1],
            includesDueTime: false
        )
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.draftReminderMode = .custom
        viewModel.draftReminderDayOffsets = "20"
        viewModel.draftReminderIncludesDueTime = true

        viewModel.selectDraftReminderMode(.useDefaults)

        XCTAssertEqual(viewModel.draftReminderMode, .useDefaults)
        XCTAssertEqual(viewModel.draftReminderDayOffsets, "6, 1")
        XCTAssertFalse(viewModel.draftReminderIncludesDueTime)
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

    func testReminderPlanUsesSavedDefaultIncludingDueTime() {
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
                ),
                OrderReminderPlanItem(
                    offsetDays: 0,
                    remindAt: dueAt
                ),
            ]
        )
    }

    func testReminderPlanUsesCustomPlanAndCanBeDisabled() throws {
        let repository = FakeOrderRepository()
        let calendar = utcCalendar()
        let dueAt = Date(timeIntervalSince1970: 1_800_144_000)
        let customOrder = makeOrder(id: "order-custom-reminder", dueAt: dueAt)
        let disabledOrder = makeOrder(id: "order-disabled-reminder", dueAt: dueAt)
        repository.orders = [customOrder, disabledOrder]
        repository.orderReminderConfigurations = [
            customOrder.id: try OrderReminderConfiguration(
                mode: .custom,
                dayOffsets: [10, 2],
                includesDueTime: false
            ),
            disabledOrder.id: .disabled,
        ]
        let viewModel = OrderListViewModel(repository: repository, calendar: calendar)

        viewModel.load()

        XCTAssertEqual(
            viewModel.reminderPlan(for: customOrder),
            [
                OrderReminderPlanItem(
                    offsetDays: 10,
                    remindAt: date(byAddingDays: -10, to: dueAt, calendar: calendar)
                ),
                OrderReminderPlanItem(
                    offsetDays: 2,
                    remindAt: date(byAddingDays: -2, to: dueAt, calendar: calendar)
                ),
            ]
        )
        XCTAssertTrue(viewModel.reminderPlan(for: disabledOrder).isEmpty)
        XCTAssertNil(viewModel.nextReminder(for: disabledOrder))
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
                ),
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
            order,
        ]
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.load()

        XCTAssertEqual(viewModel.overdueAlert?.order.id, order.id)
        XCTAssertEqual(
            viewModel.overdueAlert?.message, "Birthday Cake was due at \(dueAt.formatted(date: .omitted, time: .shortened)), update status?"
        )
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
                    cakeSpecification: .newOrderDefaults,
                    quotedPrice: Decimal(string: "125.50"),
                    depositPaid: Decimal(string: "25.50"),
                    paymentNotes: "Bank transfer received",
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
        XCTAssertEqual(repository.paymentReceipts.map(\.amount), [decimal("25.50")])
        XCTAssertEqual(repository.paymentReceipts.first?.receivedAt, now)
        XCTAssertEqual(repository.paymentReceipts.first?.note, "Bank transfer received")
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

    func testAddOrderRejectsInvalidCakeCapacityWithoutDiscardingInput() {
        let repository = FakeOrderRepository()
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.draftTitle = "Vanilla Birthday"
        viewModel.draftCustomerName = "Amy"
        viewModel.draftCakeServings = "3.5"

        XCTAssertFalse(viewModel.addOrder())
        XCTAssertEqual(viewModel.errorMessage, "Servings must be a positive whole number.")
        XCTAssertEqual(viewModel.draftCakeServings, "3.5")

        viewModel.draftCakeServings = "28"
        viewModel.draftCakeWeightKilograms = "0"
        XCTAssertFalse(viewModel.addOrder())
        XCTAssertEqual(viewModel.errorMessage, "Weight must be greater than zero.")
        XCTAssertEqual(viewModel.draftCakeWeightKilograms, "0")
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

    func testOrderDesignPickerLoadsAndSearchesExplicitReferences() {
        let repository = FakeOrderRepository()
        let reference = makeCakeDesign(
            id: "design-reference-picker",
            name: "Floral sketch",
            sourceKind: .customerReference,
            tags: ["Wedding", "Blue"]
        )
        repository.cakeDesigns = [reference]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginAddingOrder()

        XCTAssertEqual(
            viewModel.references(matching: "blue floral", tag: "Wedding").map(\.id),
            [reference.id]
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
            makeCustomer(id: "customer-non-dialable-phone", name: "Maya Rao", phone: "N/A"),
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
        XCTAssertEqual(
            viewModel.selectedOrder?.updatedAt,
            Date(timeIntervalSince1970: 1_800_150_000)
        )
    }

    func testOrderDetailSurfacesFailedInventoryReservationRepair() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_150_000)
        let order = makeOrder(
            id: "order-repair-warning",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: timestamp.addingTimeInterval(86_400)
        )
        repository.orders = [order]
        repository.inventoryReservationRepairs = [
            OrderInventoryReservationRepair(
                orderId: order.id,
                state: .failed,
                attemptCount: 1,
                lastAttemptedAt: timestamp,
                failureCode: .incompatibleUnit,
                updatedAt: timestamp
            )
        ]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(
            viewModel.selectedOrderInventoryReservationRepairWarning,
            "This order’s reservation needs attention because an ingredient unit is incompatible."
        )
    }

    func testOrderDetailShowsReservedInventoryWithNamesAndQuantities() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_150_000)
        let order = makeOrder(
            id: "order-reserved-inventory",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: timestamp.addingTimeInterval(86_400)
        )
        let sugar = makeInventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram
        )
        let flour = makeInventoryItem(
            id: "inventory-flour",
            name: "Cake Flour",
            unit: .gram
        )
        repository.orders = [order]
        repository.inventoryItems = [sugar, flour]
        repository.inventoryReservations = [
            OrderInventoryReservation(
                id: "\(order.id):\(sugar.id)",
                orderId: order.id,
                inventoryItemId: sugar.id,
                requiredQuantity: 80,
                unit: .gram,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            OrderInventoryReservation(
                id: "\(order.id):\(flour.id)",
                orderId: order.id,
                inventoryItemId: flour.id,
                requiredQuantity: 250,
                unit: .gram,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
        ]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(
            viewModel.selectedOrderInventoryReservations.map(\.inventoryItemName),
            ["Cake Flour", "Sugar"]
        )
        XCTAssertEqual(
            viewModel.selectedOrderInventoryReservations.map {
                $0.reservation.requiredQuantity
            },
            [250, 80]
        )

        viewModel.closeOrderDetail()

        XCTAssertTrue(viewModel.selectedOrderInventoryReservations.isEmpty)
    }

    func testAddingExtraIngredientRequiresReservationShortageOverride() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-short-extra",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        let almonds = makeInventoryItem(id: "inventory-almonds", name: "Almonds", unit: .gram)
        let existingIngredient = OrderExtraIngredient(
            id: "existing-extra",
            orderId: order.id,
            inventoryItemId: almonds.id,
            quantity: 10,
            unit: .gram,
            note: "Existing garnish",
            createdAt: Date(timeIntervalSince1970: 1_800_130_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_130_000)
        )
        repository.orders = [order]
        repository.inventoryItems = [almonds]
        repository.extraIngredients = [existingIngredient]
        repository.changeOrderStatusError = OrderRecipeUsageError.insufficientStock([
            OrderInventoryShortage(
                inventoryItemId: almonds.id,
                inventoryItemName: almonds.name,
                requiredQuantity: 75,
                availableQuantity: 25,
                unit: .gram
            )
        ])
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "extra"),
            dateProvider: { Date(timeIntervalSince1970: 1_800_150_000) }
        )
        viewModel.beginViewingOrder(order)
        viewModel.beginAddingExtraIngredient()
        viewModel.draftExtraIngredientQuantity = "75"
        viewModel.draftExtraIngredientNote = "Extra crunch"

        XCTAssertFalse(viewModel.addExtraIngredientToSelectedOrder())

        XCTAssertEqual(repository.extraIngredients, [existingIngredient])
        XCTAssertEqual(viewModel.draftExtraIngredientQuantity, "75")
        XCTAssertEqual(viewModel.draftExtraIngredientNote, "Extra crunch")
        XCTAssertEqual(
            viewModel.inventoryShortageWarningMessage,
            "Almonds: short by 50 g"
        )
        XCTAssertEqual(repository.allowInventoryShortageRequests, [false])

        viewModel.cancelInventoryShortageOverride()

        XCTAssertTrue(viewModel.pendingInventoryShortages.isEmpty)
        XCTAssertEqual(viewModel.draftExtraIngredientQuantity, "75")
        XCTAssertEqual(viewModel.draftExtraIngredientNote, "Extra crunch")
        XCTAssertFalse(viewModel.addExtraIngredientToSelectedOrder())

        XCTAssertTrue(
            viewModel.addExtraIngredientToSelectedOrder(
                allowingInventoryShortage: true
            )
        )

        XCTAssertEqual(repository.extraIngredients.map(\.id), ["existing-extra", "extra-1"])
        XCTAssertTrue(viewModel.pendingInventoryShortages.isEmpty)
        XCTAssertEqual(repository.allowInventoryShortageRequests, [false, false, true])
    }

    func testExtraIngredientOverrideFailurePreservesDraftAndCanBeRetried() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-short-extra-retry",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        let almonds = makeInventoryItem(id: "inventory-almonds", name: "Almonds", unit: .gram)
        repository.orders = [order]
        repository.inventoryItems = [almonds]
        repository.changeOrderStatusError = OrderRecipeUsageError.insufficientStock([
            OrderInventoryShortage(
                inventoryItemId: almonds.id,
                inventoryItemName: almonds.name,
                requiredQuantity: 75,
                availableQuantity: 25,
                unit: .gram
            )
        ])
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "extra"),
            dateProvider: { Date(timeIntervalSince1970: 1_800_150_000) }
        )
        viewModel.beginViewingOrder(order)
        viewModel.beginAddingExtraIngredient()
        viewModel.draftExtraIngredientQuantity = "75"
        viewModel.draftExtraIngredientNote = "Extra crunch"

        XCTAssertFalse(viewModel.addExtraIngredientToSelectedOrder())

        repository.saveOrderOverrideError = OrderRecipeUsageError.missingInventoryItem(almonds.id)
        XCTAssertFalse(
            viewModel.addExtraIngredientToSelectedOrder(
                allowingInventoryShortage: true
            )
        )

        XCTAssertTrue(viewModel.pendingInventoryShortages.isEmpty)
        XCTAssertEqual(
            viewModel.errorMessage,
            "An inventory item required by this order could not be found."
        )
        XCTAssertEqual(viewModel.draftExtraIngredientQuantity, "75")
        XCTAssertEqual(viewModel.draftExtraIngredientNote, "Extra crunch")
        XCTAssertTrue(repository.extraIngredients.isEmpty)

        repository.saveOrderOverrideError = nil
        XCTAssertTrue(
            viewModel.addExtraIngredientToSelectedOrder(
                allowingInventoryShortage: true
            )
        )
        XCTAssertEqual(repository.extraIngredients.map(\.id), ["extra-1"])
    }

    func testAddConfirmedOrderRequiresExplicitReservationShortageOverride() {
        let repository = FakeOrderRepository()
        repository.changeOrderStatusError = OrderRecipeUsageError.insufficientStock([
            OrderInventoryShortage(
                inventoryItemId: "inventory-flour",
                inventoryItemName: "Cake flour",
                requiredQuantity: 300,
                availableQuantity: 200,
                unit: .gram
            )
        ])
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: { "order-short-reservation" },
            dateProvider: { Date(timeIntervalSince1970: 1_800_060_000) }
        )
        viewModel.draftTitle = "Short reservation cake"
        viewModel.draftCustomerName = "Amy"
        viewModel.draftDueAt = Date(timeIntervalSince1970: 1_800_140_000)
        viewModel.draftStatus = .confirmed
        viewModel.draftRecipeId = "recipe-short-reservation"

        XCTAssertFalse(viewModel.addOrder())

        XCTAssertTrue(repository.orders.isEmpty)
        XCTAssertEqual(
            viewModel.inventoryShortageWarningMessage,
            "Cake flour: short by 100 g"
        )
        XCTAssertEqual(repository.allowInventoryShortageRequests, [false])

        XCTAssertTrue(viewModel.addOrder(allowingInventoryShortage: true))

        XCTAssertEqual(repository.orders.map(\.id), ["order-short-reservation"])
        XCTAssertTrue(viewModel.pendingInventoryShortages.isEmpty)
        XCTAssertEqual(repository.allowInventoryShortageRequests, [false, true])
    }

    func testCancellingAddOrderClearsPendingReservationShortage() {
        let repository = FakeOrderRepository()
        repository.changeOrderStatusError = OrderRecipeUsageError.insufficientStock([
            OrderInventoryShortage(
                inventoryItemId: "inventory-flour",
                inventoryItemName: "Cake flour",
                requiredQuantity: 300,
                availableQuantity: 200,
                unit: .gram
            )
        ])
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.draftTitle = "Short reservation cake"
        viewModel.draftCustomerName = "Amy"
        viewModel.draftStatus = .confirmed
        viewModel.draftRecipeId = "recipe-short-reservation"
        XCTAssertFalse(viewModel.addOrder())

        viewModel.cancelAddOrder()

        XCTAssertTrue(viewModel.pendingInventoryShortages.isEmpty)
        XCTAssertTrue(viewModel.draftTitle.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
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
            ),
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
        repository.changeOrderStatusError = OrderRecipeUsageError.insufficientStock([
            OrderInventoryShortage(
                inventoryItemId: "inventory-almonds",
                inventoryItemName: "Almonds",
                requiredQuantity: 40,
                availableQuantity: 0,
                unit: .gram
            )
        ])
        let viewModel = OrderListViewModel(repository: repository)
        viewModel.beginViewingOrder(order)
        viewModel.beginEditingOrder()
        viewModel.draftStatus = .ready
        viewModel.beginAddingExtraIngredient()
        viewModel.draftExtraIngredientQuantity = "40"
        XCTAssertTrue(viewModel.addExtraIngredientToDraftOrder())

        XCTAssertFalse(viewModel.saveEditedOrder(confirmingRecipeUsage: true))

        XCTAssertTrue(repository.extraIngredients.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.inventoryShortageWarningMessage, "Almonds: short by 40 g")

        XCTAssertTrue(
            viewModel.saveEditedOrder(
                confirmingRecipeUsage: true,
                allowingInventoryShortage: true
            )
        )
        XCTAssertEqual(viewModel.selectedOrder?.status, .ready)
        XCTAssertEqual(repository.extraIngredients.count, 1)
    }

}
