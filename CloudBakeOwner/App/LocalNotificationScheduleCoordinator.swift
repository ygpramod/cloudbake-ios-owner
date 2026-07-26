import Foundation
import UserNotifications

enum CloudBakeNotificationCategory: Int, Equatable {
    case backup
    case payment
    case order
    case inventoryExpiry

    var priorityGroup: Int {
        switch self {
        case .backup, .payment:
            return 0
        case .order, .inventoryExpiry:
            return 1
        }
    }
}

struct CloudBakeNotificationCandidate {
    let request: UNNotificationRequest
    let category: CloudBakeNotificationCategory
    let triggerAt: Date
}

struct CloudBakeNotificationCapacityPolicy {
    static let scheduledRequestLimit = 60

    func select(
        _ candidates: [CloudBakeNotificationCandidate],
        limit: Int = Self.scheduledRequestLimit
    ) -> [UNNotificationRequest] {
        guard limit > 0 else {
            return []
        }
        var candidatesByIdentifier: [String: CloudBakeNotificationCandidate] = [:]
        for candidate in candidates {
            if let existing = candidatesByIdentifier[candidate.request.identifier],
               !isOrderedBefore(candidate, existing) {
                continue
            }
            candidatesByIdentifier[candidate.request.identifier] = candidate
        }
        return candidatesByIdentifier.values
            .sorted(by: isOrderedBefore)
            .prefix(limit)
            .map(\.request)
    }

    private func isOrderedBefore(
        _ lhs: CloudBakeNotificationCandidate,
        _ rhs: CloudBakeNotificationCandidate
    ) -> Bool {
        if lhs.category.priorityGroup != rhs.category.priorityGroup {
            return lhs.category.priorityGroup < rhs.category.priorityGroup
        }
        if lhs.triggerAt != rhs.triggerAt {
            return lhs.triggerAt < rhs.triggerAt
        }
        if lhs.category.rawValue != rhs.category.rawValue {
            return lhs.category.rawValue < rhs.category.rawValue
        }
        return lhs.request.identifier < rhs.request.identifier
    }
}

struct LocalNotificationScheduleCoordinator {
    private static let managedPrefixes = [
        "order-reminder-",
        "payment-pending-",
        "inventory-expiry-"
    ]

    private let repository: any InventoryItemRepository
        & InventoryStockBatchRepository
        & ScheduledOrderReminderRepository
        & PaymentReminderConfigurationRepository
        & PaymentPendingSummaryRepository
    private let notificationCenter: any LocalNotificationCenter
    private let manualBackupPreferences: ManualBackupPreferences
    private let dateProvider: () -> Date
    private let calendar: Calendar
    private let capacityPolicy: CloudBakeNotificationCapacityPolicy

    init(
        repository: any InventoryItemRepository
            & InventoryStockBatchRepository
            & ScheduledOrderReminderRepository
            & PaymentReminderConfigurationRepository
            & PaymentPendingSummaryRepository,
        notificationCenter: any LocalNotificationCenter = UNUserNotificationCenter.current(),
        manualBackupPreferences: ManualBackupPreferences = ManualBackupPreferences(),
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        capacityPolicy: CloudBakeNotificationCapacityPolicy = CloudBakeNotificationCapacityPolicy()
    ) {
        self.repository = repository
        self.notificationCenter = notificationCenter
        self.manualBackupPreferences = manualBackupPreferences
        self.dateProvider = dateProvider
        self.calendar = calendar
        self.capacityPolicy = capacityPolicy
    }

    func refreshReminders() async {
        do {
            guard try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            ) else {
                manualBackupPreferences.reminderDeliveryStatus = .authorizationDenied
                return
            }

            let now = dateProvider()
            let desiredRequests = capacityPolicy.select(
                try makeCandidates(at: now)
            )
            let pendingRequests = await notificationCenter.pendingNotificationRequests()
            let previousManagedRequests = pendingRequests.filter {
                Self.isManaged(identifier: $0.identifier)
            }
            notificationCenter.removePendingNotificationRequests(
                withIdentifiers: previousManagedRequests.map(\.identifier)
            )
            do {
                for request in desiredRequests {
                    try await notificationCenter.add(request)
                }
                manualBackupPreferences.reminderDeliveryStatus =
                    manualBackupPreferences.isReminderEnabled ? .scheduled : .disabled
            } catch {
                notificationCenter.removePendingNotificationRequests(
                    withIdentifiers: desiredRequests.map(\.identifier)
                )
                for request in previousManagedRequests {
                    try? await notificationCenter.add(request)
                }
                manualBackupPreferences.reminderDeliveryStatus = .failed
            }
        } catch {
            // Local reminders must never block owner workflows.
        }
    }

    func makeCandidates(at date: Date) throws -> [CloudBakeNotificationCandidate] {
        var candidates: [CloudBakeNotificationCandidate] = []

        let paymentRequests = try PaymentPendingReminderScheduler(
            repository: repository,
            notificationCenter: notificationCenter,
            dateProvider: { date },
            calendar: calendar
        ).makeReminderRequests()
        candidates.append(
            contentsOf: paymentRequests.compactMap {
                candidate(for: $0, category: .payment, relativeTo: date)
            }
        )

        if manualBackupPreferences.isReminderEnabled {
            let backupRequest = ManualBackupReminderScheduler(
                preferences: manualBackupPreferences,
                notificationCenter: notificationCenter,
                dateProvider: { date },
                calendar: calendar
            ).makeReminderRequest()
            if let backupCandidate = candidate(
                for: backupRequest,
                category: .backup,
                relativeTo: date
            ) {
                candidates.append(backupCandidate)
            }
        }

        let orderRequests = try OrderReminderScheduler(
            repository: repository,
            notificationCenter: notificationCenter,
            dateProvider: { date }
        ).makeReminderRequests()
        candidates.append(
            contentsOf: orderRequests.compactMap {
                candidate(for: $0, category: .order, relativeTo: date)
            }
        )

        let expiryRequests = try ExpiryReminderScheduler(
            repository: repository,
            notificationCenter: notificationCenter,
            dateProvider: { date }
        ).makeReminderRequests()
        candidates.append(
            contentsOf: expiryRequests.compactMap {
                candidate(for: $0, category: .inventoryExpiry, relativeTo: date)
            }
        )

        return candidates
    }

    private func candidate(
        for request: UNNotificationRequest,
        category: CloudBakeNotificationCategory,
        relativeTo date: Date
    ) -> CloudBakeNotificationCandidate? {
        let triggerAt: Date?
        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            triggerAt = calendar.date(from: trigger.dateComponents)
        } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            triggerAt = date.addingTimeInterval(trigger.timeInterval)
        } else {
            triggerAt = nil
        }
        guard let triggerAt else {
            return nil
        }
        return CloudBakeNotificationCandidate(
            request: request,
            category: category,
            triggerAt: triggerAt
        )
    }

    private static func isManaged(identifier: String) -> Bool {
        identifier == ManualBackupReminderScheduler.notificationIdentifier
            || managedPrefixes.contains {
                identifier.hasPrefix($0)
            }
    }
}
