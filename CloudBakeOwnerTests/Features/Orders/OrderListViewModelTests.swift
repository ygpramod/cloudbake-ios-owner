import XCTest
@testable import CloudBakeOwner

@MainActor
final class OrderListViewModelTests: XCTestCase {
    func testLoadFetchesOrdersAndCustomers() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let order = makeOrder(id: "order-vanilla", dueAt: timestamp)
        let customer = makeCustomer(id: "customer-amy", name: "Amy")
        repository.orders = [order]
        repository.customers = [customer]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.orders, [order])
        XCTAssertEqual(viewModel.customers, [customer])
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

    func testBeginViewingOrderSelectsOrder() {
        let repository = FakeOrderRepository()
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(viewModel.selectedOrder, order)
        viewModel.closeOrderDetail()
        XCTAssertNil(viewModel.selectedOrder)
    }

    func testBeginEditingOrderPrefillsDraft() {
        let repository = FakeOrderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let order = Order(
            id: "order-vanilla",
            customerId: "customer-amy",
            cakeDesignId: nil,
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
        viewModel.draftStatus = .ready
        viewModel.draftFulfillmentType = .delivery
        viewModel.draftDeliveryAddress = "11 Cake Street"
        viewModel.draftCakeNotes = "Add gold leaf"

        XCTAssertTrue(viewModel.saveEditedOrder())

        let expected = Order(
            id: "order-vanilla",
            customerId: nil,
            cakeDesignId: nil,
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

    private func makeOrder(id: String, title: String = "Vanilla Birthday", dueAt: Date) -> Order {
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        return Order(
            id: id,
            customerId: nil,
            cakeDesignId: nil,
            title: title,
            customerName: "Amy",
            status: .draft,
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

    private func makeCustomer(id: String, name: String, address: String? = nil) -> Customer {
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        return Customer(
            id: id,
            name: name,
            phone: "5550101",
            email: nil,
            address: address,
            likes: nil,
            dislikes: nil,
            allergies: nil,
            dietaryRestrictions: nil,
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}

private final class FakeOrderRepository: OrderRepository, CustomerRepository {
    var orders: [Order] = []
    var customers: [Customer] = []

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
}
