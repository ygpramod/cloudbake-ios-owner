import XCTest
@testable import CloudBakeOwner

@MainActor
final class ReminderViewModelTests: XCTestCase {
    func testLoadShowsPaymentDueForActiveOrdersWithBalanceDue() {
        let repository = FakeReminderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        repository.orders = [
            makeOrder(
                id: "order-part-paid",
                title: "Chocolate Cake",
                status: .confirmed,
                dueAt: dueAt,
                quotedPrice: decimal("150"),
                depositPaid: decimal("50")
            ),
            makeOrder(
                id: "order-paid",
                title: "Paid Cake",
                status: .confirmed,
                dueAt: dueAt,
                quotedPrice: decimal("75"),
                depositPaid: decimal("75")
            ),
            makeOrder(
                id: "order-completed",
                title: "Completed Cake",
                status: .completed,
                dueAt: dueAt,
                quotedPrice: decimal("80"),
                depositPaid: decimal("20")
            )
        ]
        let viewModel = ReminderViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(
            viewModel.paymentDueItems,
            [
                PaymentDueReminderItem(
                    id: "order-part-paid",
                    orderName: "Chocolate Cake",
                    customerName: "Amy",
                    balanceDueText: MoneyDisplay.formatted(decimal("100"))
                )
            ]
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
}

private final class FakeReminderRepository: OrderRepository, InventoryItemRepository {
    var orders: [Order] = []
    var items: [InventoryItem] = []

    func save(_ order: Order) throws {}

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
