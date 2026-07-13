import XCTest
@testable import CloudBakeOwner

final class BackupScheduleTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "BackupScheduleTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testScheduleStoreStartsEnabledAndPersistsRetrySafeMetadata() {
        let store = UserDefaultsBackupScheduleStore(defaults: defaults)
        XCTAssertEqual(store.load(), .initial)

        let metadata = BackupScheduleMetadata(
            isEnabled: true,
            lastAttemptAt: Date(timeIntervalSince1970: 1_800_000_000),
            lastSuccessAt: Date(timeIntervalSince1970: 1_799_000_000),
            nextEligibleAt: Date(timeIntervalSince1970: 1_800_003_600),
            isOverdue: true,
            activeGenerationID: "generation-1",
            retryCount: 3,
            estimatedUploadByteCount: 42_000
        )
        store.save(metadata)

        XCTAssertEqual(
            UserDefaultsBackupScheduleStore(defaults: defaults).load(),
            metadata
        )
    }

    func testSuccessfulBackupSchedulesTheNextLocalNight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Singapore"))
        let policy = BackupSchedulePolicy(calendar: calendar, nightlyHour: 2)
        let success = try date(2026, 7, 13, 22, calendar: calendar)

        XCTAssertEqual(
            policy.nextNight(after: success),
            try date(2026, 7, 14, 2, calendar: calendar)
        )
    }

    func testRetryDelayIsExponentiallyBounded() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let policy = BackupSchedulePolicy(
            initialRetryDelay: 15 * 60,
            maximumRetryDelay: 60 * 60
        )

        XCTAssertEqual(policy.retryDate(after: now, retryCount: 1), now.addingTimeInterval(15 * 60))
        XCTAssertEqual(policy.retryDate(after: now, retryCount: 2), now.addingTimeInterval(30 * 60))
        XCTAssertEqual(policy.retryDate(after: now, retryCount: 20), now.addingTimeInterval(60 * 60))
    }

    func testOverdueAndNeverBackedUpSchedulesAreDue() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let policy = BackupSchedulePolicy()

        XCTAssertTrue(policy.isAutomaticBackupDue(.initial, at: now))

        var metadata = BackupScheduleMetadata.initial
        metadata.lastSuccessAt = now
        metadata.isOverdue = false
        metadata.nextEligibleAt = now.addingTimeInterval(60)
        XCTAssertFalse(policy.isAutomaticBackupDue(metadata, at: now))

        metadata.isOverdue = true
        XCTAssertTrue(policy.isAutomaticBackupDue(metadata, at: now))
    }

    func testLargeBackwardClockChangeMakesScheduleOverdue() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var metadata = BackupScheduleMetadata.initial
        metadata.lastSuccessAt = now.addingTimeInterval(72 * 60 * 60)
        metadata.nextEligibleAt = now.addingTimeInterval(80 * 60 * 60)
        metadata.isOverdue = false

        let reconciled = BackupSchedulePolicy().reconcilingClock(in: metadata, now: now)

        XCTAssertTrue(reconciled.isOverdue)
        XCTAssertEqual(reconciled.nextEligibleAt, now)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )))
    }
}
