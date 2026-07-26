import XCTest
@testable import CloudBakeOwner

final class BackupScheduleTests: XCTestCase {
    func testApprovedPhotoOmissionsPersistAsOpaqueUniqueDigests() {
        let suiteName = "BackupAssetOmissionStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsBackupAssetOmissionStore(defaults: defaults)

        let firstReference = "photos://asset-a"
        let secondReference = "photos://asset-b"
        store.approve(sourceReferences: [firstReference, secondReference])
        store.approve(sourceReferences: [firstReference])

        XCTAssertEqual(
            UserDefaultsBackupAssetOmissionStore(defaults: defaults).loadApprovedDigests(),
            [
                BackupChecksum.sha256(of: Data(firstReference.utf8)),
                BackupChecksum.sha256(of: Data(secondReference.utf8))
            ]
        )
        let persisted = defaults.stringArray(
            forKey: UserDefaultsBackupAssetOmissionStore.approvedDigestsKey
        ) ?? []
        XCTAssertFalse(persisted.contains(where: { $0.hasPrefix("photos://") }))
    }

    func testConcurrentOmissionStoreInstancesPreserveEveryApproval() {
        let suiteName = "BackupAssetOmissionStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let stores = [
            UserDefaultsBackupAssetOmissionStore(defaults: defaults),
            UserDefaultsBackupAssetOmissionStore(defaults: defaults)
        ]
        let references = (0..<100).map { "photos://asset-\($0)" }

        DispatchQueue.concurrentPerform(iterations: references.count) { index in
            stores[index % stores.count].approve(
                sourceReferences: [references[index]]
            )
        }

        XCTAssertEqual(
            Set(stores[0].loadApprovedDigests()),
            Set(references.map { BackupChecksum.sha256(of: Data($0.utf8)) })
        )
    }

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

    func testCorruptPersistedMetadataFailsClosedWithoutStartingBackup() {
        defaults.set(Data("not-json".utf8), forKey: UserDefaultsBackupScheduleStore.metadataKey)

        let metadata = UserDefaultsBackupScheduleStore(defaults: defaults).load()

        XCTAssertFalse(metadata.isEnabled)
        XCTAssertTrue(metadata.isOverdue)
        XCTAssertNil(metadata.lastSuccessAt)
    }

    func testScheduleStoreReadsMetadataWrittenBeforeFailureStatusWasAdded() {
        let legacyJSON = """
        {
          "isEnabled": true,
          "isOverdue": true,
          "retryCount": 0
        }
        """
        defaults.set(
            Data(legacyJSON.utf8),
            forKey: UserDefaultsBackupScheduleStore.metadataKey
        )

        let metadata = UserDefaultsBackupScheduleStore(defaults: defaults).load()

        XCTAssertTrue(metadata.isEnabled)
        XCTAssertTrue(metadata.isOverdue)
        XCTAssertNil(metadata.lastFailureCategory)
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

    func testSuccessBeforeNightlyHourDoesNotScheduleAgainTheSameMorning() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Singapore"))
        let policy = BackupSchedulePolicy(calendar: calendar, nightlyHour: 2)
        let success = try date(2026, 7, 13, 1, calendar: calendar)

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
        metadata.nextEligibleAt = now
        XCTAssertTrue(policy.isAutomaticBackupDue(metadata, at: now))
    }

    func testOverdueScheduleWaitsForItsFutureRetryDate() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var metadata = BackupScheduleMetadata.initial
        metadata.nextEligibleAt = now.addingTimeInterval(60)

        XCTAssertFalse(BackupSchedulePolicy().isAutomaticBackupDue(metadata, at: now))
        XCTAssertTrue(
            BackupSchedulePolicy().isAutomaticBackupDue(
                metadata,
                at: now.addingTimeInterval(60)
            )
        )
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
