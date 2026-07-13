import Foundation
import UserNotifications

final class CloudBackupNotificationPreferences: @unchecked Sendable {
    static let enabledKey = "cloudbake.cloudBackupNotificationsEnabled"

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get {
            lock.withCloudBackupNotificationLock {
                defaults.object(forKey: Self.enabledKey) as? Bool ?? true
            }
        }
        set {
            lock.withCloudBackupNotificationLock {
                defaults.set(newValue, forKey: Self.enabledKey)
            }
        }
    }
}

protocol CloudBackupNotificationSending: Sendable {
    func send(for result: CloudBackupNotificationResult) async
}

enum CloudBackupNotificationResult: Equatable, Sendable {
    case completed
    case failed(CloudBackupErrorCategory)
}

struct CloudBackupNotificationPolicy: Sendable {
    func result(for automaticResult: AutomaticBackupResult) -> CloudBackupNotificationResult? {
        switch automaticResult {
        case .published:
            return .completed
        case .failed(let category) where Self.isActionable(category):
            return .failed(category)
        case .failed, .notDue, .coalesced, .deferred:
            return nil
        }
    }

    func result(for manualResult: ManualBackupResult) -> CloudBackupNotificationResult? {
        switch manualResult {
        case .published:
            return .completed
        case .failed(let category) where Self.isActionable(category):
            return .failed(category)
        case .failed, .requiresCellularConfirmation, .busy, .deferred, .invalidCellularApproval:
            return nil
        }
    }

    private static func isActionable(_ category: CloudBackupErrorCategory) -> Bool {
        switch category {
        case .quotaExceeded, .authenticationRequired, .permissionDenied, .corruptRemoteData:
            true
        case .iCloudUnavailable, .networkUnavailable, .conflict, .cancelled,
             .temporarilyUnavailable, .unknown:
            false
        }
    }
}

struct CloudBackupNotificationDispatcher: Sendable {
    private let policy = CloudBackupNotificationPolicy()
    private let sender: any CloudBackupNotificationSending

    init(sender: any CloudBackupNotificationSending) {
        self.sender = sender
    }

    func send(for result: AutomaticBackupResult) async {
        guard let notification = policy.result(for: result) else { return }
        await sender.send(for: notification)
    }

    func send(for result: ManualBackupResult) async {
        guard let notification = policy.result(for: result) else { return }
        await sender.send(for: notification)
    }
}

final class SystemCloudBackupNotificationSender: CloudBackupNotificationSending, @unchecked Sendable {
    private let preferences: CloudBackupNotificationPreferences
    private let notificationCenter: any LocalNotificationCenter

    init(
        preferences: CloudBackupNotificationPreferences,
        notificationCenter: any LocalNotificationCenter = UNUserNotificationCenter.current()
    ) {
        self.preferences = preferences
        self.notificationCenter = notificationCenter
    }

    func send(for result: CloudBackupNotificationResult) async {
        guard preferences.isEnabled else { return }
        do {
            guard try await notificationCenter.requestAuthorization(options: [.alert, .sound]) else {
                return
            }
            let content = UNMutableNotificationContent()
            content.sound = .default
            switch result {
            case .completed:
                content.title = "CloudBake backup complete"
                content.body = "Your latest recovery backup is available in iCloud."
            case .failed:
                content.title = "CloudBake backup needs attention"
                content.body = "Open Backup in Settings for safe guidance and try again."
            }
            try await notificationCenter.add(
                UNNotificationRequest(
                    identifier: "cloud-backup-status-\(UUID().uuidString.lowercased())",
                    content: content,
                    trigger: nil
                )
            )
        } catch {
            // Backup success and failure handling must never depend on notification delivery.
        }
    }
}

private extension NSLock {
    func withCloudBackupNotificationLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
