import Foundation
import os

struct BackupScheduleMetadata: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var lastAttemptAt: Date?
    var lastSuccessAt: Date?
    var nextEligibleAt: Date?
    var isOverdue: Bool
    var activeGenerationID: String?
    var retryCount: Int
    var estimatedUploadByteCount: Int64?

    static let initial = BackupScheduleMetadata(
        isEnabled: true,
        lastAttemptAt: nil,
        lastSuccessAt: nil,
        nextEligibleAt: nil,
        isOverdue: true,
        activeGenerationID: nil,
        retryCount: 0,
        estimatedUploadByteCount: nil
    )
}

protocol BackupScheduleStoring: Sendable {
    func load() -> BackupScheduleMetadata
    func save(_ metadata: BackupScheduleMetadata)
}

final class UserDefaultsBackupScheduleStore: BackupScheduleStoring, @unchecked Sendable {
    static let metadataKey = "cloudbake.cloudBackupSchedule"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private let logger = Logger(subsystem: "com.cloudbake.owner", category: "CloudBackup")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> BackupScheduleMetadata {
        lock.withLock {
            guard let data = defaults.data(forKey: Self.metadataKey) else {
                return .initial
            }
            do {
                return try decoder.decode(BackupScheduleMetadata.self, from: data)
            } catch {
                logger.error("Cloud backup schedule metadata is invalid; backup is disabled")
                var safeMetadata = BackupScheduleMetadata.initial
                safeMetadata.isEnabled = false
                return safeMetadata
            }
        }
    }

    func save(_ metadata: BackupScheduleMetadata) {
        lock.withLock {
            do {
                defaults.set(try encoder.encode(metadata), forKey: Self.metadataKey)
            } catch {
                assertionFailure("Cloud backup schedule metadata could not be encoded: \(error)")
            }
        }
    }
}

struct BackupSchedulePolicy: Sendable {
    let calendar: Calendar
    let nightlyHour: Int
    let initialRetryDelay: TimeInterval
    let maximumRetryDelay: TimeInterval
    let maximumClockSkew: TimeInterval

    init(
        calendar: Calendar = .current,
        nightlyHour: Int = 2,
        initialRetryDelay: TimeInterval = 15 * 60,
        maximumRetryDelay: TimeInterval = 6 * 60 * 60,
        maximumClockSkew: TimeInterval = 48 * 60 * 60
    ) {
        self.calendar = calendar
        self.nightlyHour = nightlyHour
        self.initialRetryDelay = initialRetryDelay
        self.maximumRetryDelay = maximumRetryDelay
        self.maximumClockSkew = maximumClockSkew
    }

    func nextNight(after date: Date) -> Date {
        let nextDayStart = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: date)
        ) ?? date.addingTimeInterval(24 * 60 * 60)
        return calendar.nextDate(
            after: nextDayStart.addingTimeInterval(-1),
            matching: DateComponents(hour: nightlyHour, minute: 0, second: 0),
            matchingPolicy: .nextTime,
            direction: .forward
        ) ?? nextDayStart
    }

    func retryDate(after date: Date, retryCount: Int) -> Date {
        let boundedExponent = min(max(retryCount - 1, 0), 20)
        let multiplier = pow(2.0, Double(boundedExponent))
        let delay = min(initialRetryDelay * multiplier, maximumRetryDelay)
        return date.addingTimeInterval(delay)
    }

    func isAutomaticBackupDue(_ metadata: BackupScheduleMetadata, at date: Date) -> Bool {
        guard metadata.isEnabled else { return false }
        if let nextEligibleAt = metadata.nextEligibleAt, date < nextEligibleAt {
            return false
        }
        if metadata.isOverdue || metadata.lastSuccessAt == nil { return true }
        return true
    }

    func reconcilingClock(
        in metadata: BackupScheduleMetadata,
        now: Date
    ) -> BackupScheduleMetadata {
        let dates = [metadata.lastAttemptAt, metadata.lastSuccessAt, metadata.nextEligibleAt]
            .compactMap { $0 }
        guard dates.contains(where: { $0.timeIntervalSince(now) > maximumClockSkew }) else {
            return metadata
        }

        var reconciled = metadata
        reconciled.isOverdue = true
        reconciled.nextEligibleAt = now
        return reconciled
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
