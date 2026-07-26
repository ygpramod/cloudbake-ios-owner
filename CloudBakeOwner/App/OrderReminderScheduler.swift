import Foundation
import UserNotifications

actor LocalReminderRefreshCoordinator {
    static let shared = LocalReminderRefreshCoordinator()

    typealias RefreshOperation = @Sendable () async -> Void

    private struct PendingRefresh {
        var operation: RefreshOperation
        var continuations: [CheckedContinuation<Void, Never>]
    }

    private var pendingRefresh: PendingRefresh?
    private var isRefreshing = false

    func refresh(
        _ operation: @escaping RefreshOperation
    ) async {
        await withCheckedContinuation { continuation in
            if pendingRefresh == nil {
                pendingRefresh = PendingRefresh(
                    operation: operation,
                    continuations: [continuation]
                )
            } else {
                pendingRefresh?.operation = operation
                pendingRefresh?.continuations.append(continuation)
            }

            guard !isRefreshing else {
                return
            }
            isRefreshing = true
            Task {
                await drain()
            }
        }
    }

    var pendingRequestCount: Int {
        pendingRefresh?.continuations.count ?? 0
    }

    private func drain() async {
        while let refresh = pendingRefresh {
            pendingRefresh = nil
            await refresh.operation()
            refresh.continuations.forEach { $0.resume() }
        }
        isRefreshing = false
    }
}

struct OrderReminderScheduler {
    private static let notificationPrefix = "order-reminder-"
    static let orderNotificationOrderIdKey = "cloudbake.orderId"
    static let orderNotificationDestinationKey = "cloudbake.destination"
    static let orderNotificationDestinationOrder = "order"

    private static let calendar = Calendar(identifier: .gregorian)

    private let repository: any ScheduledOrderReminderRepository
    private let notificationCenter: LocalNotificationCenter
    private let dateProvider: () -> Date

    init(
        repository: any ScheduledOrderReminderRepository,
        notificationCenter: LocalNotificationCenter = UNUserNotificationCenter.current(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.notificationCenter = notificationCenter
        self.dateProvider = dateProvider
    }

    func refreshReminders() async {
        do {
            guard try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) else {
                return
            }

            let reminders = try makeReminderRequests()
            let staleReminderIdentifiers = await notificationCenter.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.notificationPrefix) }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: staleReminderIdentifiers)

            for reminder in reminders {
                try await notificationCenter.add(reminder)
            }
        } catch {
            // Notification scheduling should never block the owner from using the app.
        }
    }

    func makeReminderRequests(limit: Int = 60) throws -> [UNNotificationRequest] {
        let now = dateProvider()
        return try repository.fetchScheduledOrderReminderOccurrences(
            after: now,
            limit: limit
        )
            .map { occurrence in
                makeReminderRequest(
                    order: occurrence.order,
                    offsetDays: occurrence.offsetDays,
                    remindAt: occurrence.remindAt
                )
            }
    }

    private func makeReminderRequest(
        order: Order,
        offsetDays: Int,
        remindAt: Date
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = offsetDays == 0 ? "Order due" : "Order reminder"
        content.body = notificationBody(for: order, offsetDays: offsetDays)
        content.sound = .default
        content.userInfo = [
            Self.orderNotificationDestinationKey: Self.orderNotificationDestinationOrder,
            Self.orderNotificationOrderIdKey: order.id,
            CloudBakeNotificationCapacityPolicy.businessDateUserInfoKey:
                order.dueAt.timeIntervalSince1970
        ]

        let components = Self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: remindAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: "\(Self.notificationPrefix)\(order.id)-\(offsetDays)d",
            content: content,
            trigger: trigger
        )
    }

    private func notificationBody(for order: Order, offsetDays: Int) -> String {
        if offsetDays == 0 {
            return "\(order.title) was due at \(order.dueAt.formatted(date: .omitted, time: .shortened)), update status?"
        }

        return "\(order.title) for \(order.customerName) is due \(order.dueAt.formatted(date: .abbreviated, time: .shortened))."
    }
}

struct PaymentPendingReminderScheduler {
    static let notificationIdentifierPrefix = "payment-pending-"
    static let notificationDestinationKey = "cloudbake.destination"
    static let notificationDestination = "payment-report"
    private static let legacyNotificationIdentifier = "payment-pending-summary"
    private static let schedulingHorizonDays = 14

    private let repository: any PaymentReminderConfigurationRepository & PaymentPendingSummaryRepository
    private let notificationCenter: LocalNotificationCenter
    private let dateProvider: () -> Date
    private let calendar: Calendar

    init(
        repository: any PaymentReminderConfigurationRepository & PaymentPendingSummaryRepository,
        notificationCenter: LocalNotificationCenter = UNUserNotificationCenter.current(),
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.notificationCenter = notificationCenter
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func refreshReminder() async {
        do {
            guard try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            ) else {
                return
            }

            let requests = try makeReminderRequests()
            let pendingIdentifiers = await notificationCenter.pendingNotificationRequests()
                .map(\.identifier)
                .filter {
                    $0 == Self.legacyNotificationIdentifier
                        || $0.hasPrefix(Self.notificationIdentifierPrefix)
                }
            for request in requests {
                try await notificationCenter.add(request)
            }
            let desiredIdentifiers = Set(requests.map(\.identifier))
            let staleIdentifiers = pendingIdentifiers.filter {
                !desiredIdentifiers.contains($0)
            }
            notificationCenter.removePendingNotificationRequests(
                withIdentifiers: staleIdentifiers
            )
        } catch {
            // Payment follow-up must never block order or payment workflows.
        }
    }

    func makeReminderRequests() throws -> [UNNotificationRequest] {
        let now = dateProvider()
        let configuration = try repository.fetchPaymentReminderConfiguration()
        let startOfToday = calendar.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []

        for dayOffset in 0...Self.schedulingHorizonDays {
            guard requests.count < Self.schedulingHorizonDays,
                  let day = calendar.date(
                      byAdding: .day,
                      value: dayOffset,
                      to: startOfToday
                  ),
                  let triggerDate = calendar.date(
                      bySettingHour: configuration.hour,
                      minute: configuration.minute,
                      second: 0,
                      of: day
                  ),
                  triggerDate > now else {
                continue
            }

            let summary = try repository.fetchPaymentPendingSummary(at: triggerDate)
            guard summary.orderCount > 0 else {
                continue
            }
            requests.append(
                makeReminderRequest(
                    summary: summary,
                    triggerDate: triggerDate
                )
            )
        }

        return requests
    }

    private func makeReminderRequest(
        summary: PaymentPendingSummary,
        triggerDate: Date
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Payments pending"
        content.body = paymentSummaryBody(
            orderCount: summary.orderCount,
            totalBalance: summary.totalBalance
        )
        content.sound = .default
        content.userInfo = [
            Self.notificationDestinationKey: Self.notificationDestination
        ]
        let triggerComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerComponents,
            repeats: false
        )
        return UNNotificationRequest(
            identifier: notificationIdentifier(for: triggerComponents),
            content: content,
            trigger: trigger
        )
    }

    private func notificationIdentifier(
        for components: DateComponents
    ) -> String {
        String(
            format: "%@%04d-%02d-%02d",
            Self.notificationIdentifierPrefix,
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func paymentSummaryBody(
        orderCount: Int,
        totalBalance: Decimal
    ) -> String {
        let orderText = orderCount == 1 ? "order has" : "orders have"
        return "\(orderCount) completed \(orderText) \(MoneyDisplay.formatted(totalBalance)) outstanding."
    }
}
