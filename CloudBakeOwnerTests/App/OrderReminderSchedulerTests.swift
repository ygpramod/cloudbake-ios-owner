import UserNotifications
import XCTest
@testable import CloudBakeOwner

final class OrderReminderSchedulerTests: XCTestCase {
    func testMakeReminderRequestsSchedulesFutureActiveOrderReminders() throws {
        let repository = FakeOrderReminderRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 9, minute: 0))!
        let dueAt = calendar.date(from: DateComponents(year: 2027, month: 2, day: 14, hour: 15, minute: 30))!
        repository.orders = [
            makeOrder(id: "order-vanilla", title: "Vanilla Birthday", customerName: "Amy", status: .confirmed, dueAt: dueAt, now: now)
        ]
        let scheduler = OrderReminderScheduler(
            repository: repository,
            notificationCenter: FakeOrderReminderNotificationCenter(),
            dateProvider: { now }
        )

        let requests = try scheduler.makeReminderRequests()

        XCTAssertEqual(requests.map(\.identifier), [
            "order-reminder-order-vanilla-3d",
            "order-reminder-order-vanilla-2d",
            "order-reminder-order-vanilla-1d",
            "order-reminder-order-vanilla-0d"
        ])
        XCTAssertEqual(requests[0].content.title, "Order reminder")
        XCTAssertEqual(
            requests[0].content.body,
            "Vanilla Birthday for Amy is due \(dueAt.formatted(date: .abbreviated, time: .shortened))."
        )
        let trigger = try XCTUnwrap(requests[0].trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.day, 11)
        XCTAssertEqual(trigger.dateComponents.hour, 15)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
        XCTAssertEqual(
            requests[3].content.body,
            "Vanilla Birthday was due at \(dueAt.formatted(date: .omitted, time: .shortened)), update status?"
        )
        XCTAssertEqual(
            requests[3].content.userInfo[OrderReminderScheduler.orderNotificationOrderIdKey] as? String,
            "order-vanilla"
        )
    }

    func testMakeReminderRequestsIgnoresInactivePastAndSchedulesDueTimeReminder() throws {
        let repository = FakeOrderReminderRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 9, minute: 0))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: now)!
        repository.orders = [
            makeOrder(id: "order-draft", status: .draft, dueAt: nextWeek, now: now),
            makeOrder(id: "order-completed", status: .completed, dueAt: nextWeek, now: now),
            makeOrder(id: "order-cancelled", status: .cancelled, dueAt: nextWeek, now: now),
            makeOrder(id: "order-past", status: .confirmed, dueAt: calendar.date(byAdding: .day, value: -1, to: now)!, now: now),
            makeOrder(id: "order-tomorrow", status: .confirmed, dueAt: tomorrow, now: now)
        ]
        let scheduler = OrderReminderScheduler(
            repository: repository,
            notificationCenter: FakeOrderReminderNotificationCenter(),
            dateProvider: { now }
        )

        let requests = try scheduler.makeReminderRequests()

        XCTAssertEqual(requests.map(\.identifier), ["order-reminder-order-tomorrow-0d"])
    }

    func testRefreshRemindersRequestsPermissionReplacesStaleOrderRequestsAndAddsCurrentRequests() async throws {
        let repository = FakeOrderReminderRepository()
        let notificationCenter = FakeOrderReminderNotificationCenter()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        repository.orders = [
            makeOrder(
                id: "order-vanilla",
                status: .confirmed,
                dueAt: Calendar(identifier: .gregorian).date(byAdding: .day, value: 4, to: now)!,
                now: now
            )
        ]
        notificationCenter.pendingRequests = [
            UNNotificationRequest(identifier: "order-reminder-stale-3d", content: UNNotificationContent(), trigger: nil),
            UNNotificationRequest(identifier: "inventory-expiry-batch", content: UNNotificationContent(), trigger: nil)
        ]
        let scheduler = OrderReminderScheduler(
            repository: repository,
            notificationCenter: notificationCenter,
            dateProvider: { now }
        )

        await scheduler.refreshReminders()

        XCTAssertEqual(notificationCenter.requestedAuthorizationOptions, [.alert, .sound, .badge])
        XCTAssertEqual(notificationCenter.removedIdentifiers, ["order-reminder-stale-3d"])
        XCTAssertEqual(notificationCenter.addedRequests.map(\.identifier), [
            "order-reminder-order-vanilla-3d",
            "order-reminder-order-vanilla-2d",
            "order-reminder-order-vanilla-1d",
            "order-reminder-order-vanilla-0d"
        ])
    }

    private func makeOrder(
        id: String,
        title: String = "Vanilla Birthday",
        customerName: String = "Amy",
        status: OrderStatus,
        dueAt: Date,
        now: Date
    ) -> Order {
        Order(
            id: id,
            customerId: nil,
            cakeDesignId: nil,
            title: title,
            customerName: customerName,
            status: status,
            dueAt: dueAt,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}

private final class FakeOrderReminderRepository: OrderRepository {
    var orders: [Order] = []

    func save(_ order: Order) throws {}

    func fetchOrder(id: String) throws -> Order? {
        orders.first { $0.id == id }
    }

    func fetchOrders() throws -> [Order] {
        orders
    }
}

private final class FakeOrderReminderNotificationCenter: LocalNotificationCenter {
    var requestedAuthorizationOptions: UNAuthorizationOptions?
    var pendingRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var addedRequests: [UNNotificationRequest] = []
    var allowsAuthorization = true

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedAuthorizationOptions = options
        return allowsAuthorization
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers = identifiers
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }
}
