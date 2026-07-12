import Foundation
import UserNotifications

struct ManualBackupPreferences {
    static let reminderEnabledKey = "cloudbake.manualBackupReminderEnabled"
    static let lastSuccessfulExportKey = "cloudbake.manualBackupLastSuccessfulExport"
    static let nextReminderDateKey = "cloudbake.manualBackupNextReminderDate"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isReminderEnabled: Bool {
        get {
            defaults.object(forKey: Self.reminderEnabledKey) as? Bool ?? true
        }
        nonmutating set {
            defaults.set(newValue, forKey: Self.reminderEnabledKey)
        }
    }

    var lastSuccessfulExport: Date? {
        defaults.object(forKey: Self.lastSuccessfulExportKey) as? Date
    }

    var nextReminderDate: Date? {
        defaults.object(forKey: Self.nextReminderDateKey) as? Date
    }

    func recordSuccessfulExport(at date: Date, calendar: Calendar = .current) {
        defaults.set(date, forKey: Self.lastSuccessfulExportKey)
        defaults.set(
            calendar.date(byAdding: .day, value: 7, to: date)
                ?? date.addingTimeInterval(7 * 24 * 60 * 60),
            forKey: Self.nextReminderDateKey
        )
    }

    func ensureNextReminderDate(from date: Date, calendar: Calendar = .current) -> Date {
        if let nextReminderDate { return nextReminderDate }
        let scheduledDate = calendar.date(byAdding: .day, value: 7, to: date)
            ?? date.addingTimeInterval(7 * 24 * 60 * 60)
        defaults.set(scheduledDate, forKey: Self.nextReminderDateKey)
        return scheduledDate
    }
}

struct ManualBackupReminderScheduler {
    static let notificationIdentifier = "manual-backup-reminder"

    private let preferences: ManualBackupPreferences
    private let notificationCenter: any LocalNotificationCenter
    private let dateProvider: () -> Date
    private let calendar: Calendar

    init(
        preferences: ManualBackupPreferences = ManualBackupPreferences(),
        notificationCenter: any LocalNotificationCenter = UNUserNotificationCenter.current(),
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.preferences = preferences
        self.notificationCenter = notificationCenter
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func refreshReminder() async {
        let pendingIdentifiers = await notificationCenter.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0 == Self.notificationIdentifier }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)

        guard preferences.isReminderEnabled else { return }

        do {
            guard try await notificationCenter.requestAuthorization(options: [.alert, .sound]) else {
                return
            }
            let now = dateProvider()
            let dueAt = preferences.ensureNextReminderDate(from: now, calendar: calendar)
            let interval = max(60, dueAt.timeIntervalSince(now))
            let content = UNMutableNotificationContent()
            content.title = "Back up CloudBake"
            content.body = "Save a current CloudBake backup from Settings."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: Self.notificationIdentifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: interval,
                    repeats: false
                )
            )
            try await notificationCenter.add(request)
        } catch {
            // Backup reminders must never block normal owner workflows.
        }
    }
}

