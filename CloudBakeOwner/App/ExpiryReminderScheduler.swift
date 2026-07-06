import Foundation
import UserNotifications

protocol LocalNotificationCenter {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: LocalNotificationCenter {}

struct ExpiryReminderScheduler {
    private static let notificationPrefix = "inventory-expiry-"
    private static let calendar = Calendar(identifier: .gregorian)

    private let repository: any InventoryItemRepository & InventoryStockBatchRepository
    private let notificationCenter: LocalNotificationCenter
    private let dateProvider: () -> Date

    init(
        repository: any InventoryItemRepository & InventoryStockBatchRepository,
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
            notificationCenter.removePendingNotificationRequests(
                withIdentifiers: staleReminderIdentifiers
            )

            for reminder in reminders {
                try await notificationCenter.add(reminder)
            }
        } catch {
            // Notification scheduling should never block the owner from using the app.
        }
    }

    func makeReminderRequests() throws -> [UNNotificationRequest] {
        let now = dateProvider()
        let threshold = Self.calendar.date(byAdding: .month, value: 1, to: now)
            ?? now.addingTimeInterval(30 * 24 * 60 * 60)
        let items = try repository.fetchInventoryItems()
        var requests: [UNNotificationRequest] = []

        for item in items {
            let batches = try repository.fetchInventoryStockBatches(inventoryItemId: item.id)
            for batch in batches where batch.remainingQuantity > 0 {
                guard let expiresAt = batch.expiresAt,
                      expiresAt >= now,
                      expiresAt <= threshold else {
                    continue
                }

                requests.append(makeReminderRequest(item: item, batch: batch, now: now, expiresAt: expiresAt))
            }
        }

        return requests
    }

    private func makeReminderRequest(
        item: InventoryItem,
        batch: InventoryStockBatch,
        now: Date,
        expiresAt: Date
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Inventory expiring soon"
        content.body = "\(item.name) has \(batch.remainingQuantity.formatted()) \(item.unit.displayName) expiring on \(expiresAt.formatted(date: .abbreviated, time: .omitted))."
        content.sound = .default

        let triggerDate = scheduledReminderDate(for: expiresAt, now: now)
        let components = Self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: Self.notificationPrefix + batch.id,
            content: content,
            trigger: trigger
        )
    }

    private func scheduledReminderDate(for expiresAt: Date, now: Date) -> Date {
        let preferredDate = Self.calendar.date(byAdding: .month, value: -1, to: expiresAt)
            ?? expiresAt.addingTimeInterval(-30 * 24 * 60 * 60)
        let reminderDay = max(preferredDate, now)
        let morningComponents = Self.calendar.dateComponents([.year, .month, .day], from: reminderDay)
        let morning = Self.calendar.date(
            from: DateComponents(
                calendar: Self.calendar,
                year: morningComponents.year,
                month: morningComponents.month,
                day: morningComponents.day,
                hour: 9,
                minute: 0
            )
        ) ?? reminderDay

        if morning > now {
            return morning
        }

        return now.addingTimeInterval(60)
    }
}
