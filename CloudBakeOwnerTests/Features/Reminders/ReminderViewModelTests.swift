import XCTest
@testable import CloudBakeOwner

@MainActor
final class ReminderViewModelTests: XCTestCase {
    func testLoadShowsPaymentDueForReadyAndCompletedOrdersWithBalanceDue() throws {
        let repository = FakeReminderRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        let dueAt = calendar.date(from: DateComponents(year: 2026, month: 7, day: 8, hour: 18))!
        repository.customers = [
            makeCustomer(id: "customer-amy", name: "Amy Rao", phone: "+65 9123 4567")
        ]
        repository.orders = [
            makeOrder(
                id: "order-confirmed",
                title: "Confirmed Cake",
                status: .confirmed,
                dueAt: dueAt,
                quotedPrice: decimal("150"),
                depositPaid: decimal("50")
            ),
            makeOrder(
                id: "order-ready",
                title: "Chocolate Truffle Cake",
                customerId: "customer-amy",
                status: .ready,
                dueAt: dueAt,
                quotedPrice: decimal("150"),
                depositPaid: decimal("50")
            ),
            makeOrder(
                id: "order-completed",
                title: "Completed Cake",
                status: .completed,
                dueAt: dueAt,
                quotedPrice: decimal("80"),
                depositPaid: decimal("20")
            ),
            makeOrder(
                id: "order-paid",
                title: "Paid Cake",
                status: .ready,
                dueAt: dueAt,
                quotedPrice: decimal("75"),
                depositPaid: decimal("75")
            )
        ]
        let viewModel = ReminderViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.paymentDueItems.count, 2)
        XCTAssertEqual(viewModel.paymentDueItems[0].id, "order-ready")
        XCTAssertEqual(viewModel.paymentDueItems[0].orderName, "Chocolate Truffle Cake")
        XCTAssertEqual(viewModel.paymentDueItems[0].customerName, "Amy Rao")
        XCTAssertEqual(viewModel.paymentDueItems[0].firstName, "Amy")
        XCTAssertEqual(viewModel.paymentDueItems[0].balanceDueText, MoneyDisplay.formatted(decimal("100")))
        XCTAssertEqual(
            viewModel.paymentDueItems[0].paymentMessage,
            "Amy has \(MoneyDisplay.formatted(decimal("100"))) balance due for Chocolate Truffle Cake."
        )
        XCTAssertEqual(viewModel.paymentDueItems[1].id, "order-completed")
        XCTAssertEqual(viewModel.paymentDueItems[1].whatsappURL, nil)
        let whatsappURL = try XCTUnwrap(viewModel.paymentDueItems.first?.whatsappURL)
        let components = try XCTUnwrap(URLComponents(url: whatsappURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "whatsapp")
        XCTAssertEqual(components.host, "send")
        XCTAssertEqual(components.queryItems?.first { $0.name == "phone" }?.value, "+6591234567")
        XCTAssertEqual(
            components.queryItems?.first { $0.name == "text" }?.value,
            """
            Hi Amy, this is a reminder for your CloudBake order.

            Balance due: \(MoneyDisplay.formatted(decimal("100")))
            Order: Chocolate Truffle Cake
            Due: 8 Jul 2026, 6:00 PM

            You can make the payment when convenient. Thank you!
            """
        )
    }

    func testLoadShowsActiveOrdersForTodayOnly() {
        let repository = FakeReminderRepository()
        let calendar = utcCalendar()
        let now = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 10))!
        let todayMorning = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 9))!
        let todayEvening = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 18))!
        let tomorrow = calendar.date(from: DateComponents(year: 2027, month: 2, day: 11, hour: 9))!
        repository.orders = [
            makeOrder(id: "order-evening", title: "Evening Cake", status: .ready, dueAt: todayEvening),
            makeOrder(id: "order-tomorrow", title: "Tomorrow Cake", status: .confirmed, dueAt: tomorrow),
            makeOrder(id: "order-morning", title: "Morning Cake", status: .confirmed, dueAt: todayMorning),
            makeOrder(id: "order-cancelled", title: "Cancelled Cake", status: .cancelled, dueAt: todayMorning)
        ]
        let viewModel = ReminderViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.load()

        XCTAssertEqual(
            viewModel.todayOrderItems,
            [
                TodayOrderReminderItem(id: "order-morning", orderName: "Morning Cake", customerName: "Amy"),
                TodayOrderReminderItem(id: "order-evening", orderName: "Evening Cake", customerName: "Amy")
            ]
        )
    }

    func testLoadShowsLowInventoryWithCurrentAndMinimumQuantity() {
        let repository = FakeReminderRepository()
        repository.items = [
            makeInventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                currentQuantity: 250,
                minimumQuantity: 500
            ),
            makeInventoryItem(
                id: "inventory-sugar",
                name: "Sugar",
                currentQuantity: 1000,
                minimumQuantity: 500
            )
        ]
        let viewModel = ReminderViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(
            viewModel.lowInventoryItems,
            [
                LowInventoryReminderItem(
                    id: "inventory-flour",
                    name: "Cake flour",
                    quantityText: "250 / 500 g"
                )
            ]
        )
    }

    func testMarkPaidUpdatesOrderAndRemovesPaymentDueReminder() {
        let repository = FakeReminderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        repository.orders = [
            makeOrder(
                id: "order-ready",
                title: "Chocolate Cake",
                status: .ready,
                dueAt: dueAt,
                quotedPrice: decimal("150"),
                depositPaid: decimal("50")
            )
        ]
        let viewModel = ReminderViewModel(repository: repository)
        viewModel.load()

        XCTAssertTrue(viewModel.markPaid(orderId: "order-ready"))

        XCTAssertEqual(repository.orders.first?.depositPaid, decimal("150"))
        XCTAssertEqual(viewModel.paymentDueItems, [])
    }
}

private final class FakeReminderRepository: OrderRepository, InventoryItemRepository, CustomerRepository {
    var orders: [Order] = []
    var items: [InventoryItem] = []
    var customers: [Customer] = []

    func save(_ order: Order) throws {
        if let existingIndex = orders.firstIndex(where: { $0.id == order.id }) {
            orders[existingIndex] = order
        } else {
            orders.append(order)
        }
    }

    func fetchOrder(id: String) throws -> Order? {
        orders.first { $0.id == id }
    }

    func fetchOrders() throws -> [Order] {
        orders
    }

    func save(_ item: InventoryItem) throws {}

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        items.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        items.filter { !$0.isArchived }
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        items.filter(\.isArchived)
    }

    func save(_ customer: Customer) throws {
        if let existingIndex = customers.firstIndex(where: { $0.id == customer.id }) {
            customers[existingIndex] = customer
        } else {
            customers.append(customer)
        }
    }

    func fetchCustomer(id: String) throws -> Customer? {
        customers.first { $0.id == id }
    }

    func fetchCustomers() throws -> [Customer] {
        customers
    }

    func deleteCustomer(id: String) throws {
        customers.removeAll { $0.id == id }
    }
}

private func makeInventoryItem(
    id: String,
    name: String,
    currentQuantity: Double,
    minimumQuantity: Double
) -> InventoryItem {
    let timestamp = Date(timeIntervalSince1970: 1_800_040_000)
    return InventoryItem(
        id: id,
        name: name,
        unit: .gram,
        currentQuantity: currentQuantity,
        minimumQuantity: minimumQuantity,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}
