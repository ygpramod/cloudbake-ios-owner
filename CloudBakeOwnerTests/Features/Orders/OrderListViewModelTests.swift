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
        repository.orders = [order]
        repository.customers = [customer]
        repository.recipes = [recipe]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.orders, [order])
        XCTAssertEqual(viewModel.customers, [customer])
        XCTAssertEqual(viewModel.recipes, [recipe])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testCalendarDaysGroupsOrdersByDueDate() {
        let repository = FakeOrderRepository()
        let calendar = utcCalendar()
        let firstDayMorning = Date(timeIntervalSince1970: 1_800_057_600)
        let firstDayAfternoon = Date(timeIntervalSince1970: 1_800_075_600)
        let secondDay = Date(timeIntervalSince1970: 1_800_144_000)
        let firstOrder = makeOrder(id: "order-morning", title: "Morning Cake", dueAt: firstDayMorning)
        let secondOrder = makeOrder(id: "order-afternoon", title: "Afternoon Cake", dueAt: firstDayAfternoon)
        let thirdOrder = makeOrder(id: "order-next-day", title: "Next Day Cake", dueAt: secondDay)
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
                    reminders: viewModel.reminderPlan(for: tomorrowOrder)
                ),
                OrderReminderDueGroup(
                    order: activeOrder,
                    reminders: Array(viewModel.reminderPlan(for: activeOrder).prefix(2))
                )
            ]
        )
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
                    cakeDesignId: nil,
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
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(viewModel.selectedOrder, order)
        XCTAssertEqual(viewModel.selectedOrderCustomer, customer)
        XCTAssertEqual(viewModel.selectedOrderRecipe, recipe)
        viewModel.closeOrderDetail()
        XCTAssertNil(viewModel.selectedOrder)
        XCTAssertNil(viewModel.selectedOrderCustomer)
        XCTAssertNil(viewModel.selectedOrderRecipe)
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
            cakeDesignId: nil,
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
        viewModel.draftStatus = .ready
        viewModel.draftFulfillmentType = .delivery
        viewModel.draftDeliveryAddress = "11 Cake Street"
        viewModel.draftCakeNotes = "Add gold leaf"

        XCTAssertTrue(viewModel.saveEditedOrder())

        let expected = Order(
            id: "order-vanilla",
            customerId: nil,
            cakeDesignId: nil,
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
        status: OrderStatus = .draft,
        dueAt: Date
    ) -> Order {
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        return Order(
            id: id,
            customerId: customerId,
            cakeDesignId: nil,
            recipeId: recipeId,
            title: title,
            customerName: "Amy",
            status: status,
            dueAt: dueAt,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
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
}

private final class FakeOrderRepository: OrderRepository, CustomerRepository, RecipeRepository {
    var orders: [Order] = []
    var customers: [Customer] = []
    var recipes: [Recipe] = []

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
}
