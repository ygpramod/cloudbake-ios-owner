import Foundation
import UserNotifications

struct OrderReminderScheduler {
    private static let notificationPrefix = "order-reminder-"
    static let orderNotificationOrderIdKey = "cloudbake.orderId"
    static let orderNotificationDestinationKey = "cloudbake.destination"
    static let orderNotificationDestinationOrder = "order"

    private static let calendar = Calendar(identifier: .gregorian)

    private let repository: any OrderRepository & OrderReminderConfigurationRepository
    private let notificationCenter: LocalNotificationCenter
    private let dateProvider: () -> Date

    init(
        repository: any OrderRepository & OrderReminderConfigurationRepository,
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

    func makeReminderRequests() throws -> [UNNotificationRequest] {
        let now = dateProvider()
        let orders = try repository.fetchOrders()
            .filter(\.hasScheduledReminderState)
            .filter { $0.dueAt > now }
        let configurations = try repository.fetchOrderReminderConfigurations(
            orderIds: orders.map(\.id)
        )
        return orders
            .flatMap { order -> [UNNotificationRequest] in
                let configuration = configurations[order.id] ?? .initialDefault
                guard configuration.isEnabled else {
                    return []
                }
                let offsets = configuration.dayOffsets
                    + (configuration.includesDueTime ? [0] : [])
                return offsets.compactMap { offsetDays in
                    guard let remindAt = Self.calendar.date(byAdding: .day, value: -offsetDays, to: order.dueAt),
                          remindAt > now else {
                        return nil
                    }

                    return makeReminderRequest(order: order, offsetDays: offsetDays, remindAt: remindAt)
                }
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
            Self.orderNotificationOrderIdKey: order.id
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
    static let notificationIdentifier = "payment-pending-summary"
    static let notificationDestinationKey = "cloudbake.destination"
    static let notificationDestination = "payment-report"

    private let repository: any OrderRepository & PaymentReminderConfigurationRepository
    private let notificationCenter: LocalNotificationCenter
    private let dateProvider: () -> Date

    init(
        repository: any OrderRepository & PaymentReminderConfigurationRepository,
        notificationCenter: LocalNotificationCenter = UNUserNotificationCenter.current(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.notificationCenter = notificationCenter
        self.dateProvider = dateProvider
    }

    func refreshReminder() async {
        do {
            guard try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            ) else {
                return
            }

            let pendingIdentifiers = await notificationCenter.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0 == Self.notificationIdentifier }
            notificationCenter.removePendingNotificationRequests(
                withIdentifiers: pendingIdentifiers
            )
            if let request = try makeReminderRequest() {
                try await notificationCenter.add(request)
            }
        } catch {
            // Payment follow-up must never block order or payment workflows.
        }
    }

    func makeReminderRequest() throws -> UNNotificationRequest? {
        let now = dateProvider()
        let eligibleOrders = try repository.fetchOrders().filter {
            $0.hasPaymentPending(at: now)
        }
        guard !eligibleOrders.isEmpty else {
            return nil
        }

        let totalBalance = eligibleOrders.reduce(Decimal.zero) {
            $0 + max($1.balanceDue ?? 0, 0)
        }
        let configuration = try repository.fetchPaymentReminderConfiguration()
        let content = UNMutableNotificationContent()
        content.title = "Payments pending"
        content.body = paymentSummaryBody(
            orderCount: eligibleOrders.count,
            totalBalance: totalBalance
        )
        content.sound = .default
        content.userInfo = [
            Self.notificationDestinationKey: Self.notificationDestination
        ]
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(
                hour: configuration.hour,
                minute: configuration.minute
            ),
            repeats: true
        )
        return UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
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
