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
    static let notificationIdentifierPrefix = "payment-pending-"
    static let notificationDestinationKey = "cloudbake.destination"
    static let notificationDestination = "payment-report"
    private static let legacyNotificationIdentifier = "payment-pending-summary"
    private static let schedulingHorizonDays = 14

    private let repository: any OrderRepository & PaymentReminderConfigurationRepository
    private let notificationCenter: LocalNotificationCenter
    private let dateProvider: () -> Date
    private let calendar: Calendar

    init(
        repository: any OrderRepository & PaymentReminderConfigurationRepository,
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
            notificationCenter.removePendingNotificationRequests(
                withIdentifiers: pendingIdentifiers
            )
            for request in requests {
                try await notificationCenter.add(request)
            }
        } catch {
            // Payment follow-up must never block order or payment workflows.
        }
    }

    func makeReminderRequests() throws -> [UNNotificationRequest] {
        let now = dateProvider()
        let candidateOrders = try repository.fetchOrders().filter {
            $0.status == .completed && ($0.balanceDue ?? 0) > 0
        }
        guard !candidateOrders.isEmpty else {
            return []
        }

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

            let eligibleOrders = candidateOrders.filter {
                $0.hasPaymentPending(at: triggerDate)
            }
            guard !eligibleOrders.isEmpty else {
                continue
            }
            requests.append(
                makeReminderRequest(
                    eligibleOrders: eligibleOrders,
                    triggerDate: triggerDate
                )
            )
        }

        return requests
    }

    private func makeReminderRequest(
        eligibleOrders: [Order],
        triggerDate: Date
    ) -> UNNotificationRequest {
        let totalBalance = eligibleOrders.reduce(Decimal.zero) {
            $0 + max($1.balanceDue ?? 0, 0)
        }
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
