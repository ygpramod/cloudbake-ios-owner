import UserNotifications
import XCTest
@testable import CloudBakeOwner

final class ManualBackupReminderSchedulerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ManualBackupReminderSchedulerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testReminderDefaultsToEnabledAndSchedulesSevenDaysFromFirstRefresh() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let center = ManualBackupNotificationCenter()
        let preferences = ManualBackupPreferences(defaults: defaults)
        let scheduler = ManualBackupReminderScheduler(
            preferences: preferences,
            notificationCenter: center,
            dateProvider: { now },
            calendar: Calendar(identifier: .gregorian)
        )

        await scheduler.refreshReminder()

        XCTAssertTrue(preferences.isReminderEnabled)
        XCTAssertEqual(center.requests.count, 1)
        let trigger = try XCTUnwrap(
            center.requests.first?.trigger as? UNTimeIntervalNotificationTrigger
        )
        XCTAssertEqual(trigger.timeInterval, 7 * 24 * 60 * 60, accuracy: 0.01)
        XCTAssertEqual(preferences.reminderDeliveryStatus, .scheduled)
    }

    func testDisabledReminderRemovesPendingRequestWithoutRequestingPermission() async {
        let center = ManualBackupNotificationCenter()
        center.requests = [makeRequest()]
        let preferences = ManualBackupPreferences(defaults: defaults)
        preferences.isReminderEnabled = false
        let scheduler = ManualBackupReminderScheduler(
            preferences: preferences,
            notificationCenter: center
        )

        await scheduler.refreshReminder()

        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertNil(center.requestedAuthorizationOptions)
        XCTAssertEqual(preferences.reminderDeliveryStatus, .disabled)
    }

    func testSuccessfulExportResetsReminderAndRecordsLastSuccess() async throws {
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let refreshAt = exportedAt.addingTimeInterval(24 * 60 * 60)
        let center = ManualBackupNotificationCenter()
        let preferences = ManualBackupPreferences(defaults: defaults)
        preferences.recordSuccessfulExport(
            at: exportedAt,
            calendar: Calendar(identifier: .gregorian)
        )
        let scheduler = ManualBackupReminderScheduler(
            preferences: preferences,
            notificationCenter: center,
            dateProvider: { refreshAt },
            calendar: Calendar(identifier: .gregorian)
        )

        await scheduler.refreshReminder()

        XCTAssertEqual(preferences.lastSuccessfulExport, exportedAt)
        let trigger = try XCTUnwrap(
            center.requests.first?.trigger as? UNTimeIntervalNotificationTrigger
        )
        XCTAssertEqual(trigger.timeInterval, 6 * 24 * 60 * 60, accuracy: 0.01)
    }

    func testOverdueReminderSchedulesPromptlyWithoutMovingStoredDueDate() async throws {
        let dueAt = Date(timeIntervalSince1970: 1_800_000_000)
        defaults.set(dueAt, forKey: ManualBackupPreferences.nextReminderDateKey)
        let center = ManualBackupNotificationCenter()
        let preferences = ManualBackupPreferences(defaults: defaults)
        let scheduler = ManualBackupReminderScheduler(
            preferences: preferences,
            notificationCenter: center,
            dateProvider: { dueAt.addingTimeInterval(3_600) }
        )

        await scheduler.refreshReminder()

        let trigger = try XCTUnwrap(
            center.requests.first?.trigger as? UNTimeIntervalNotificationTrigger
        )
        XCTAssertEqual(trigger.timeInterval, 60, accuracy: 0.01)
        XCTAssertEqual(preferences.nextReminderDate, dueAt)
    }

    func testAuthorizationDenialIsPersistedForTruthfulSettingsStatus() async {
        let center = ManualBackupNotificationCenter()
        center.authorizationGranted = false
        let preferences = ManualBackupPreferences(defaults: defaults)
        let scheduler = ManualBackupReminderScheduler(
            preferences: preferences,
            notificationCenter: center
        )

        let status = await scheduler.refreshReminder()

        XCTAssertEqual(status, .authorizationDenied)
        XCTAssertEqual(preferences.reminderDeliveryStatus, .authorizationDenied)
        XCTAssertTrue(center.requests.isEmpty)
    }

    func testSchedulingFailureIsPersistedForTruthfulSettingsStatus() async {
        let center = ManualBackupNotificationCenter()
        center.addError = ReminderTestError.failed
        let preferences = ManualBackupPreferences(defaults: defaults)
        let scheduler = ManualBackupReminderScheduler(
            preferences: preferences,
            notificationCenter: center
        )

        let status = await scheduler.refreshReminder()

        XCTAssertEqual(status, .failed)
        XCTAssertEqual(preferences.reminderDeliveryStatus, .failed)
        XCTAssertTrue(center.requests.isEmpty)
    }

    private func makeRequest() -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: ManualBackupReminderScheduler.notificationIdentifier,
            content: UNMutableNotificationContent(),
            trigger: nil
        )
    }
}

private final class ManualBackupNotificationCenter: LocalNotificationCenter {
    var requestedAuthorizationOptions: UNAuthorizationOptions?
    var requests: [UNNotificationRequest] = []
    var authorizationGranted = true
    var addError: Error?

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedAuthorizationOptions = options
        return authorizationGranted
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        requests
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        requests.removeAll { identifiers.contains($0.identifier) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let addError { throw addError }
        requests.append(request)
    }
}

private enum ReminderTestError: Error {
    case failed
}
