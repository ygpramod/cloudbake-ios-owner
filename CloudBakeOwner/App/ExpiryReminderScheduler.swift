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

    private let repository: any InventoryExpiryReminderRepository
    private let notificationCenter: LocalNotificationCenter
    private let dateProvider: () -> Date

    init(
        repository: any InventoryExpiryReminderRepository,
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

    func makeReminderRequests(limit: Int = 60) throws -> [UNNotificationRequest] {
        let now = dateProvider()
        let threshold = Self.calendar.date(byAdding: .month, value: 1, to: now)
            ?? now.addingTimeInterval(30 * 24 * 60 * 60)
        guard let nextReminderDate = nextReminderDate(after: now) else {
            return []
        }
        return try repository.fetchInventoryExpiryReminderCandidates(
            expiringFrom: nextReminderDate,
            through: threshold,
            limit: limit
        ).compactMap { candidate in
            guard let expiresAt = candidate.batch.expiresAt else {
                return nil
            }
            return makeReminderRequest(
                candidate: candidate,
                now: now,
                expiresAt: expiresAt
            )
        }
    }

    private func makeReminderRequest(
        candidate: InventoryExpiryReminderCandidate,
        now: Date,
        expiresAt: Date
    ) -> UNNotificationRequest? {
        let content = UNMutableNotificationContent()
        content.title = "Inventory expiring soon"
        content.body = "\(candidate.itemName) has \(candidate.batch.remainingQuantity.formatted()) \(candidate.unit.displayName) expiring on \(expiresAt.formatted(date: .abbreviated, time: .omitted))."
        content.sound = .default

        guard let triggerDate = scheduledReminderDate(for: expiresAt, now: now) else {
            return nil
        }

        let components = Self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: Self.notificationPrefix + candidate.batch.id,
            content: content,
            trigger: trigger
        )
    }

    private func scheduledReminderDate(for expiresAt: Date, now: Date) -> Date? {
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

        if morning > now, morning <= expiresAt {
            return morning
        }

        guard let nextMorning = Self.calendar.date(byAdding: .day, value: 1, to: morning),
              nextMorning <= expiresAt else {
            return nil
        }

        return nextMorning
    }

    private func nextReminderDate(after date: Date) -> Date? {
        let day = Self.calendar.dateComponents([.year, .month, .day], from: date)
        guard let morning = Self.calendar.date(
            from: DateComponents(
                calendar: Self.calendar,
                year: day.year,
                month: day.month,
                day: day.day,
                hour: 9,
                minute: 0
            )
        ) else {
            return nil
        }
        if morning > date {
            return morning
        }
        return Self.calendar.date(byAdding: .day, value: 1, to: morning)
    }
}
