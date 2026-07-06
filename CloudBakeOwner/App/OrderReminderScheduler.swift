import Foundation
import UserNotifications

struct OrderReminderScheduler {
    private static let notificationPrefix = "order-reminder-"
    private static let calendar = Calendar(identifier: .gregorian)

    private let repository: OrderRepository
    private let notificationCenter: LocalNotificationCenter
    private let dateProvider: () -> Date

    init(
        repository: OrderRepository,
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
        return try repository.fetchOrders()
            .filter(\.hasScheduledReminderState)
            .filter { $0.dueAt > now }
            .flatMap { order in
                reminderOffsets.compactMap { offsetDays in
                    guard let remindAt = Self.calendar.date(byAdding: .day, value: -offsetDays, to: order.dueAt),
                          remindAt > now else {
                        return nil
                    }

                    return makeReminderRequest(order: order, offsetDays: offsetDays, remindAt: remindAt)
                }
            }
    }

    private var reminderOffsets: [Int] {
        [3, 2, 1]
    }

    private func makeReminderRequest(
        order: Order,
        offsetDays: Int,
        remindAt: Date
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Order reminder"
        content.body = "\(order.title) for \(order.customerName) is due \(order.dueAt.formatted(date: .abbreviated, time: .shortened))."
        content.sound = .default

        let components = Self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: remindAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: "\(Self.notificationPrefix)\(order.id)-\(offsetDays)d",
            content: content,
            trigger: trigger
        )
    }
}
