import UserNotifications
import XCTest
@testable import CloudBakeOwner

final class OrderReminderSchedulerTests: XCTestCase {
    func testNewestRefreshRunsAfterOverlappingStaleRefresh() async {
        let coordinator = LocalReminderRefreshCoordinator()
        let gate = AsyncTestGate()
        let events = RefreshEventRecorder()

        let staleRefresh = Task {
            await coordinator.refresh {
                await events.record("stale-unpaid")
                await gate.wait()
            }
        }
        await waitUntil {
            await events.values == ["stale-unpaid"]
        }

        let intermediateRefresh = Task {
            await coordinator.refresh {
                await events.record("intermediate-paid")
            }
        }
        let newestRefresh = Task {
            await coordinator.refresh {
                await events.record("newest-paid")
            }
        }
        await waitUntil {
            await coordinator.pendingRequestCount == 2
        }

        await gate.open()
        await staleRefresh.value
        await intermediateRefresh.value
        await newestRefresh.value
        let recordedEvents = await events.values

        XCTAssertEqual(
            recordedEvents,
            ["stale-unpaid", "newest-paid"]
        )
    }

    @MainActor
    func testPaymentNotificationRoutesToPaymentReport() {
        let router = OrderNotificationRouter()

        router.routeNotification(
            userInfo: [
                PaymentPendingReminderScheduler.notificationDestinationKey:
                    PaymentPendingReminderScheduler.notificationDestination
            ]
        )

        XCTAssertTrue(router.isPaymentReportPending)
        XCTAssertNil(router.pendingOrderId)
        router.clearPendingPaymentReport()
        XCTAssertFalse(router.isPaymentReportPending)
    }

    func testPaymentReminderPlansDailyAggregateAtEachTriggerDate() throws {
        let repository = FakePaymentReminderRepository()
        let calendar = utcCalendar()
        let now = calendar.date(
            from: DateComponents(year: 2027, month: 2, day: 10, hour: 10)
        )!
        repository.configuration = try PaymentReminderConfiguration(hour: 14, minute: 30)
        repository.orders = [
            makePaymentOrder(
                id: "eligible-part-paid",
                status: .completed,
                dueAt: calendar.date(byAdding: .hour, value: -1, to: now)!,
                quotedPrice: 100,
                depositPaid: 20,
                now: now
            ),
            makePaymentOrder(
                id: "eligible-unpaid",
                status: .completed,
                dueAt: calendar.date(byAdding: .day, value: -1, to: now)!,
                quotedPrice: 50,
                depositPaid: nil,
                now: now
            ),
            makePaymentOrder(
                id: "ready",
                status: .ready,
                dueAt: calendar.date(byAdding: .day, value: -1, to: now)!,
                quotedPrice: 500,
                depositPaid: nil,
                now: now
            ),
            makePaymentOrder(
                id: "future",
                status: .completed,
                dueAt: calendar.date(byAdding: .day, value: 1, to: now)!,
                quotedPrice: 500,
                depositPaid: nil,
                now: now
            ),
            makePaymentOrder(
                id: "paid",
                status: .completed,
                dueAt: calendar.date(byAdding: .day, value: -1, to: now)!,
                quotedPrice: 100,
                depositPaid: 100,
                now: now
            )
        ]
        let scheduler = PaymentPendingReminderScheduler(
            repository: repository,
            notificationCenter: FakeOrderReminderNotificationCenter(),
            dateProvider: { now },
            calendar: calendar
        )

        let requests = try scheduler.makeReminderRequests()
        let request = try XCTUnwrap(requests.first)

        XCTAssertEqual(requests.count, 14)
        XCTAssertEqual(request.identifier, "payment-pending-2027-02-10")
        XCTAssertEqual(request.content.title, "Payments pending")
        XCTAssertEqual(
            request.content.body,
            "2 completed orders have \(MoneyDisplay.formatted(130)) outstanding."
        )
        XCTAssertEqual(
            request.content.userInfo[
                PaymentPendingReminderScheduler.notificationDestinationKey
            ] as? String,
            PaymentPendingReminderScheduler.notificationDestination
        )
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.year, 2027)
        XCTAssertEqual(trigger.dateComponents.month, 2)
        XCTAssertEqual(trigger.dateComponents.day, 10)
        XCTAssertEqual(trigger.dateComponents.hour, 14)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(
            requests[1].content.body,
            "3 completed orders have \(MoneyDisplay.formatted(630)) outstanding."
        )
    }

    func testPaymentReminderStartsTodayBeforeConfiguredTimeAndTomorrowAfterIt() throws {
        let repository = FakePaymentReminderRepository()
        let calendar = utcCalendar()
        let dueAt = calendar.date(
            from: DateComponents(year: 2027, month: 2, day: 10, hour: 7)
        )!
        repository.configuration = try PaymentReminderConfiguration(hour: 9, minute: 0)
        repository.orders = [
            makePaymentOrder(
                id: "unpaid",
                status: .completed,
                dueAt: dueAt,
                quotedPrice: 100,
                depositPaid: nil,
                now: dueAt
            )
        ]
        let beforeTime = calendar.date(
            from: DateComponents(year: 2027, month: 2, day: 10, hour: 8)
        )!
        let afterTime = calendar.date(
            from: DateComponents(year: 2027, month: 2, day: 10, hour: 10)
        )!

        let beforeRequests = try PaymentPendingReminderScheduler(
            repository: repository,
            notificationCenter: FakeOrderReminderNotificationCenter(),
            dateProvider: { beforeTime },
            calendar: calendar
        ).makeReminderRequests()
        let afterRequests = try PaymentPendingReminderScheduler(
            repository: repository,
            notificationCenter: FakeOrderReminderNotificationCenter(),
            dateProvider: { afterTime },
            calendar: calendar
        ).makeReminderRequests()

        XCTAssertEqual(beforeRequests.first?.identifier, "payment-pending-2027-02-10")
        XCTAssertEqual(afterRequests.first?.identifier, "payment-pending-2027-02-11")
    }

    func testPaymentReminderRefreshRemovesRequestWhenNoOrderIsEligible() async {
        let repository = FakePaymentReminderRepository()
        let notificationCenter = FakeOrderReminderNotificationCenter()
        notificationCenter.pendingRequests = [
            UNNotificationRequest(
                identifier: "payment-pending-2027-02-10",
                content: UNNotificationContent(),
                trigger: nil
            ),
            UNNotificationRequest(
                identifier: "payment-pending-summary",
                content: UNNotificationContent(),
                trigger: nil
            ),
            UNNotificationRequest(
                identifier: "order-reminder-other",
                content: UNNotificationContent(),
                trigger: nil
            )
        ]
        let scheduler = PaymentPendingReminderScheduler(
            repository: repository,
            notificationCenter: notificationCenter,
            dateProvider: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        await scheduler.refreshReminder()

        XCTAssertEqual(
            notificationCenter.removedIdentifiers,
            ["payment-pending-2027-02-10", "payment-pending-summary"]
        )
        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
    }

    func testPaymentReminderKeepsExistingRequestsWhenRepositoryReadFails() async {
        let repository = FakePaymentReminderRepository()
        repository.fetchError = TestFailure()
        let notificationCenter = FakeOrderReminderNotificationCenter()
        notificationCenter.pendingRequests = [
            UNNotificationRequest(
                identifier: "payment-pending-2027-02-10",
                content: UNNotificationContent(),
                trigger: nil
            )
        ]
        let scheduler = PaymentPendingReminderScheduler(
            repository: repository,
            notificationCenter: notificationCenter
        )

        await scheduler.refreshReminder()

        XCTAssertTrue(notificationCenter.removedIdentifiers.isEmpty)
        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
    }

    func testPaymentReminderKeepsExistingHorizonWhenAddingReplacementFails() async throws {
        let repository = FakePaymentReminderRepository()
        let calendar = utcCalendar()
        let now = calendar.date(
            from: DateComponents(year: 2027, month: 2, day: 10, hour: 8)
        )!
        repository.configuration = try PaymentReminderConfiguration(hour: 9, minute: 0)
        repository.orders = [
            makePaymentOrder(
                id: "unpaid",
                status: .completed,
                dueAt: calendar.date(byAdding: .day, value: -1, to: now)!,
                quotedPrice: 100,
                depositPaid: nil,
                now: now
            )
        ]
        let notificationCenter = FakeOrderReminderNotificationCenter()
        notificationCenter.pendingRequests = [
            UNNotificationRequest(
                identifier: "payment-pending-2027-02-10",
                content: UNNotificationContent(),
                trigger: nil
            ),
            UNNotificationRequest(
                identifier: "payment-pending-2027-02-11",
                content: UNNotificationContent(),
                trigger: nil
            )
        ]
        notificationCenter.addFailureIndex = 1
        let scheduler = PaymentPendingReminderScheduler(
            repository: repository,
            notificationCenter: notificationCenter,
            dateProvider: { now },
            calendar: calendar
        )

        await scheduler.refreshReminder()

        XCTAssertEqual(
            notificationCenter.addedRequests.map(\.identifier),
            ["payment-pending-2027-02-10"]
        )
        XCTAssertTrue(notificationCenter.removedIdentifiers.isEmpty)
    }

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

    func testMakeReminderRequestsUsesCustomAndDisabledOrderPlans() throws {
        let repository = FakeOrderReminderRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(
            from: DateComponents(year: 2027, month: 2, day: 10, hour: 9)
        )!
        let dueAt = calendar.date(
            from: DateComponents(year: 2027, month: 2, day: 25, hour: 15)
        )!
        let customOrder = makeOrder(
            id: "order-custom",
            status: .confirmed,
            dueAt: dueAt,
            now: now
        )
        let disabledOrder = makeOrder(
            id: "order-disabled",
            status: .confirmed,
            dueAt: dueAt,
            now: now
        )
        repository.orders = [customOrder, disabledOrder]
        repository.configurations = [
            customOrder.id: try OrderReminderConfiguration(
                mode: .custom,
                dayOffsets: [14, 2],
                includesDueTime: false
            ),
            disabledOrder.id: .disabled
        ]
        let scheduler = OrderReminderScheduler(
            repository: repository,
            notificationCenter: FakeOrderReminderNotificationCenter(),
            dateProvider: { now }
        )

        let requests = try scheduler.makeReminderRequests()

        XCTAssertEqual(
            requests.map(\.identifier),
            [
                "order-reminder-order-custom-14d",
                "order-reminder-order-custom-2d"
            ]
        )
        XCTAssertEqual(repository.configurationFetchCount, 1)
        XCTAssertEqual(
            Set(repository.lastConfigurationOrderIds),
            [customOrder.id, disabledOrder.id]
        )
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

    private func waitUntil(
        _ condition: @escaping () async -> Bool
    ) async {
        for _ in 0..<1_000 {
            if await condition() {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for asynchronous test state.")
    }

    private func makePaymentOrder(
        id: String,
        status: OrderStatus,
        dueAt: Date,
        quotedPrice: Decimal,
        depositPaid: Decimal?,
        now: Date
    ) -> Order {
        Order(
            id: id,
            customerId: nil,
            cakeDesignId: nil,
            title: id,
            customerName: "Customer",
            status: status,
            dueAt: dueAt,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            quotedPrice: quotedPrice,
            depositPaid: depositPaid,
            completedAt: status == .completed ? now : nil,
            createdAt: now,
            updatedAt: now
        )
    }
}

private final class FakePaymentReminderRepository:
    OrderRepository,
    PaymentReminderConfigurationRepository {
    var orders: [Order] = []
    var configuration = PaymentReminderConfiguration.initialDefault
    var fetchError: Error?

    func save(_ order: Order) throws {}

    func fetchOrder(id: String) throws -> Order? {
        orders.first { $0.id == id }
    }

    func fetchOrders() throws -> [Order] {
        if let fetchError {
            throw fetchError
        }
        return orders
    }

    func fetchPaymentReminderConfiguration() throws -> PaymentReminderConfiguration {
        configuration
    }

    func savePaymentReminderConfiguration(
        _ configuration: PaymentReminderConfiguration,
        updatedAt _: Date
    ) throws {
        self.configuration = configuration
    }
}

private struct TestFailure: Error {}

private actor AsyncTestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pendingWaiters = waiters
        waiters = []
        pendingWaiters.forEach { $0.resume() }
    }
}

private actor RefreshEventRecorder {
    private(set) var values: [String] = []

    func record(_ value: String) {
        values.append(value)
    }
}

private final class FakeOrderReminderRepository:
    OrderRepository,
    OrderReminderConfigurationRepository {
    var orders: [Order] = []
    var configurations: [String: OrderReminderConfiguration] = [:]
    var configurationFetchCount = 0
    var lastConfigurationOrderIds: [String] = []

    func save(_ order: Order) throws {}

    func fetchOrder(id: String) throws -> Order? {
        orders.first { $0.id == id }
    }

    func fetchOrders() throws -> [Order] {
        orders
    }

    func fetchDefaultOrderReminderConfiguration() throws -> OrderReminderConfiguration {
        .initialDefault
    }

    func saveDefaultOrderReminderConfiguration(
        _ configuration: OrderReminderConfiguration,
        updatedAt _: Date
    ) throws {}

    func fetchOrderReminderConfiguration(
        orderId: String
    ) throws -> OrderReminderConfiguration? {
        configurations[orderId]
    }

    func fetchOrderReminderConfigurations(
        orderIds: [String]
    ) throws -> [String: OrderReminderConfiguration] {
        configurationFetchCount += 1
        lastConfigurationOrderIds = orderIds
        return configurations.filter { orderIds.contains($0.key) }
    }

    func saveOrderReminderConfiguration(
        _ configuration: OrderReminderConfiguration,
        orderId: String,
        updatedAt _: Date
    ) throws {
        configurations[orderId] = configuration
    }
}

private final class FakeOrderReminderNotificationCenter: LocalNotificationCenter {
    var requestedAuthorizationOptions: UNAuthorizationOptions?
    var pendingRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var addedRequests: [UNNotificationRequest] = []
    var allowsAuthorization = true
    var addFailureIndex: Int?
    private var addAttemptCount = 0

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
        defer { addAttemptCount += 1 }
        if addAttemptCount == addFailureIndex {
            throw TestFailure()
        }
        addedRequests.append(request)
    }
}
