import XCTest
@testable import CloudBakeOwner

final class BackupCoordinatorTests: XCTestCase {
    func testSettingsReflectOwnerPreferenceAndScheduleEnabledWork() async {
        let fixture = CoordinatorFixture()

        await fixture.coordinator.setBackupEnabled(false)
        let disabled = await fixture.coordinator.currentSettings(
            areNotificationsEnabled: false
        )

        XCTAssertFalse(disabled.isEnabled)
        XCTAssertFalse(disabled.areNotificationsEnabled)
        XCTAssertEqual(disabled.state, .disabled)

        await fixture.coordinator.setBackupEnabled(true)
        let enabled = await fixture.coordinator.currentSettings(
            areNotificationsEnabled: true
        )

        XCTAssertTrue(enabled.isEnabled)
        XCTAssertTrue(enabled.areNotificationsEnabled)
        XCTAssertEqual(enabled.state, .enabled)
        let scheduledDates = await fixture.scheduler.scheduledDates
        XCTAssertEqual(scheduledDates, [fixture.now])
    }

    func testSettingsReportsWaitingForWiFiWithoutStartingWork() async {
        let fixture = CoordinatorFixture(connection: .cellular)

        let settings = await fixture.coordinator.currentSettings(
            areNotificationsEnabled: true
        )

        XCTAssertEqual(settings.state, .waitingForWiFi)
        let creationCount = await fixture.snapshotCreator.creationCount
        XCTAssertEqual(creationCount, 0)
    }

    func testSettingsDistinguishesUploadingFromVerification() async throws {
        let fixture = CoordinatorFixture(holdsPublication: true)
        let operation = Task {
            await fixture.coordinator.prepareManualBackup()
        }
        try await fixture.publisher.waitUntilPublicationStarts()

        var settings = await fixture.coordinator.currentSettings(
            areNotificationsEnabled: true
        )
        XCTAssertEqual(settings.state, .uploading)

        await fixture.publisher.reportVerificationStarted()
        settings = await fixture.coordinator.currentSettings(
            areNotificationsEnabled: true
        )
        XCTAssertEqual(settings.state, .verifying)

        await fixture.publisher.releasePublication()
        _ = await operation.value
    }

    func testSettingsReportsPreparingDuringAutomaticSnapshotCreation() async throws {
        let fixture = CoordinatorFixture(holdsSnapshotCreation: true)
        let operation = Task {
            await fixture.coordinator.requestAutomaticBackup(trigger: .background)
        }
        try await fixture.snapshotCreator.waitUntilCreationStarts()

        let settings = await fixture.coordinator.currentSettings(
            areNotificationsEnabled: true
        )
        XCTAssertEqual(settings.state, .preparing)

        await fixture.snapshotCreator.releaseCreation()
        _ = await operation.value
    }

    func testDisablingBackupCancelsPendingCellularPublication() async {
        let fixture = CoordinatorFixture(connection: .cellular)
        guard case .requiresCellularConfirmation(let proposal) = await fixture.coordinator.prepareManualBackup() else {
            return XCTFail("Expected a cellular confirmation proposal")
        }

        await fixture.coordinator.setBackupEnabled(false)
        let confirmation = await fixture.coordinator.confirmManualCellularBackup(
            proposalID: proposal.id,
            displayedByteCount: proposal.estimatedUploadByteCount
        )

        XCTAssertEqual(confirmation, .invalidCellularApproval)
        XCTAssertFalse(fixture.scheduleStore.load().isEnabled)
        XCTAssertNil(fixture.scheduleStore.load().activeGenerationID)
        let removedGenerationIDs = await fixture.cleaner.removedGenerationIDs
        XCTAssertEqual(removedGenerationIDs, ["generation-1"])
        let publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(publicationCount, 0)
    }

    func testDisablingBackupWhileAutomaticUploadIsHeldPreventsPublication() async throws {
        let fixture = CoordinatorFixture(holdsPublication: true)
        let operation = Task {
            await fixture.coordinator.requestAutomaticBackup(trigger: .background)
        }
        try await fixture.publisher.waitUntilPublicationStarts()

        await fixture.coordinator.setBackupEnabled(false)
        await fixture.publisher.releasePublication()

        let result = await operation.value
        XCTAssertEqual(result, .failed(.cancelled))
        XCTAssertNil(fixture.scheduleStore.load().lastSuccessAt)
        XCTAssertFalse(fixture.scheduleStore.load().isEnabled)
    }

    func testDisablingBackupWhileManualUploadIsHeldPreventsPublication() async throws {
        let fixture = CoordinatorFixture(holdsPublication: true)
        let operation = Task {
            await fixture.coordinator.prepareManualBackup()
        }
        try await fixture.publisher.waitUntilPublicationStarts()

        await fixture.coordinator.setBackupEnabled(false)
        await fixture.publisher.releasePublication()

        let result = await operation.value
        XCTAssertEqual(result, .failed(.cancelled))
        XCTAssertNil(fixture.scheduleStore.load().lastSuccessAt)
        XCTAssertFalse(fixture.scheduleStore.load().isEnabled)
    }

    func testDisablingBackupWhileManualSnapshotIsHeldStopsBeforeUpload() async throws {
        let fixture = CoordinatorFixture(holdsSnapshotCreation: true)
        let operation = Task {
            await fixture.coordinator.prepareManualBackup()
        }
        try await fixture.snapshotCreator.waitUntilCreationStarts()

        await fixture.coordinator.setBackupEnabled(false)
        await fixture.snapshotCreator.releaseCreation()

        let result = await operation.value
        XCTAssertEqual(result, .failed(.cancelled))
        let publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(publicationCount, 0)
        XCTAssertNil(fixture.scheduleStore.load().lastSuccessAt)
    }

    func testEligibleAutomaticBackupPublishesOnceAndSchedulesNextNight() async throws {
        let fixture = CoordinatorFixture()

        let result = await fixture.coordinator.requestAutomaticBackup(trigger: .background)

        guard case .published(let publication) = result else {
            return XCTFail("Expected publication, got \(result)")
        }
        XCTAssertEqual(publication.generationID, "generation-1")
        let creationCount = await fixture.snapshotCreator.creationCount
        let publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(creationCount, 1)
        XCTAssertEqual(publicationCount, 1)
        let transferPolicies = await fixture.publisher.transferPolicies
        XCTAssertEqual(transferPolicies, [.wifiOnly])
        let metadata = fixture.scheduleStore.load()
        XCTAssertEqual(metadata.lastSuccessAt, fixture.now)
        XCTAssertFalse(metadata.isOverdue)
        XCTAssertNil(metadata.activeGenerationID)
        XCTAssertEqual(metadata.estimatedUploadByteCount, 4_096)
        let scheduledDates = await fixture.scheduler.scheduledDates
        XCTAssertEqual(scheduledDates.count, 1)
    }

    func testAutomaticBackupNeverStartsOnCellular() async {
        let fixture = CoordinatorFixture(connection: .cellular)

        let result = await fixture.coordinator.requestAutomaticBackup(trigger: .launchCatchUp)

        XCTAssertEqual(result, .deferred(.waitingForWiFi))
        let creationCount = await fixture.snapshotCreator.creationCount
        let publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(creationCount, 0)
        XCTAssertEqual(publicationCount, 0)
        XCTAssertTrue(fixture.scheduleStore.load().isOverdue)
    }

    func testAutomaticEligibilityDefersForAccountPowerAndStorage() async {
        let cases: [(CoordinatorFixture, BackupDeferralReason)] = [
            (CoordinatorFixture(account: .unavailable), .iCloudUnavailable),
            (CoordinatorFixture(hasEligiblePower: false), .powerRestricted),
            (CoordinatorFixture(hasSufficientStorage: false), .insufficientStorage)
        ]

        for (fixture, expectedReason) in cases {
            let result = await fixture.coordinator.requestAutomaticBackup(trigger: .background)
            XCTAssertEqual(result, .deferred(expectedReason))
            let creationCount = await fixture.snapshotCreator.creationCount
            XCTAssertEqual(creationCount, 0)
        }
    }

    func testAutomaticBackupDoesNotRepeatBeforeNextEligibility() async {
        var metadata = BackupScheduleMetadata.initial
        metadata.lastSuccessAt = Date(timeIntervalSince1970: 1_800_000_000)
        metadata.nextEligibleAt = Date(timeIntervalSince1970: 1_800_003_600)
        metadata.isOverdue = false
        let fixture = CoordinatorFixture(metadata: metadata)

        let result = await fixture.coordinator.requestAutomaticBackup(trigger: .background)

        XCTAssertEqual(result, .notDue)
        let publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(publicationCount, 0)
    }

    func testConcurrentAutomaticTriggersCoalesceIntoOnePublication() async throws {
        let fixture = CoordinatorFixture(holdsPublication: true)
        let first = Task {
            await fixture.coordinator.requestAutomaticBackup(trigger: .background)
        }
        try await fixture.publisher.waitUntilPublicationStarts()

        let second = await fixture.coordinator.requestAutomaticBackup(trigger: .launchCatchUp)
        XCTAssertEqual(second, .coalesced)

        await fixture.publisher.releasePublication()
        guard case .published = await first.value else {
            return XCTFail("The first request should publish")
        }
        let publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(publicationCount, 1)
    }

    func testConcurrentTriggersReserveOperationBeforeSuspendedEligibility() async throws {
        let fixture = CoordinatorFixture(holdsEligibility: true)
        let first = Task {
            await fixture.coordinator.requestAutomaticBackup(trigger: .background)
        }
        let didStartEligibilityCheck = await fixture.environment.waitUntilEligibilityCheckStarts()
        XCTAssertTrue(didStartEligibilityCheck, "Timed out waiting for eligibility check")

        let secondAutomatic = await fixture.coordinator.requestAutomaticBackup(trigger: .launchCatchUp)
        let manual = await fixture.coordinator.prepareManualBackup()

        XCTAssertEqual(secondAutomatic, .coalesced)
        XCTAssertEqual(manual, .busy)
        await fixture.environment.releaseEligibility()
        guard case .published = await first.value else {
            return XCTFail("The reserved automatic operation should publish")
        }
        let publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(publicationCount, 1)
    }

    func testPublicationWaitsForAccountLifecycleConfirmation() async {
        let fixture = CoordinatorFixture(isPublicationAuthorized: false)

        let result = await fixture.coordinator.requestAutomaticBackup(trigger: .background)

        XCTAssertEqual(result, .deferred(.accountConfirmationRequired))
        let creationCount = await fixture.snapshotCreator.creationCount
        XCTAssertEqual(creationCount, 0)
    }

    func testManualBackupPublishesOnlyAfterConfirmingCurrentAccount() async {
        let fixture = CoordinatorFixture(isPublicationAuthorized: false)

        guard case .requiresAccountConfirmation(let proposal) =
                await fixture.coordinator.prepareManualBackup() else {
            return XCTFail("Expected account confirmation")
        }
        let creationCountBeforeConfirmation = await fixture.snapshotCreator.creationCount
        XCTAssertEqual(creationCountBeforeConfirmation, 0)

        let result = await fixture.coordinator.confirmManualAccountBackup(
            proposalID: proposal.id
        )

        guard case .published = result else {
            return XCTFail("Expected publication after account confirmation, got \(result)")
        }
        let creationCountAfterConfirmation = await fixture.snapshotCreator.creationCount
        XCTAssertEqual(creationCountAfterConfirmation, 1)
    }

    func testChangedAccountInvalidatesPendingConfirmation() async {
        let fixture = CoordinatorFixture(isPublicationAuthorized: false)
        guard case .requiresAccountConfirmation(let proposal) =
                await fixture.coordinator.prepareManualBackup() else {
            return XCTFail("Expected account confirmation")
        }

        await fixture.environment.setAccountFingerprint("account-b")
        let result = await fixture.coordinator.confirmManualAccountBackup(
            proposalID: proposal.id
        )

        XCTAssertEqual(result, .deferred(.accountConfirmationRequired))
        let creationCount = await fixture.snapshotCreator.creationCount
        XCTAssertEqual(creationCount, 0)
    }

    func testVerifiedCloudDeletionDisablesBackupAndClearsRemoteMetadata() async {
        var metadata = BackupScheduleMetadata.initial
        metadata.lastSuccessAt = Date(timeIntervalSince1970: 1_800_000_000)
        metadata.estimatedUploadByteCount = 9_000
        let deleter = FakeCloudBackupDeleter()
        let fixture = CoordinatorFixture(metadata: metadata, deleter: deleter)

        let result = await fixture.coordinator.deleteCloudBackup()

        XCTAssertEqual(result, .deleted)
        let deletionCount = await deleter.deletionCount
        XCTAssertEqual(deletionCount, 1)
        XCTAssertFalse(fixture.scheduleStore.load().isEnabled)
        XCTAssertNil(fixture.scheduleStore.load().lastSuccessAt)
        XCTAssertNil(fixture.scheduleStore.load().estimatedUploadByteCount)
    }

    func testFailedCloudDeletionPreservesBackupStateAndCanBeRetried() async {
        var metadata = BackupScheduleMetadata.initial
        metadata.lastSuccessAt = Date(timeIntervalSince1970: 1_800_000_000)
        let deleter = FakeCloudBackupDeleter(failuresRemaining: 1)
        let fixture = CoordinatorFixture(metadata: metadata, deleter: deleter)

        let failure = await fixture.coordinator.deleteCloudBackup()
        XCTAssertEqual(failure, .failed(.temporarilyUnavailable))
        XCTAssertFalse(fixture.scheduleStore.load().isEnabled)
        XCTAssertNotNil(fixture.scheduleStore.load().lastSuccessAt)
        XCTAssertEqual(
            fixture.scheduleStore.load().deletionNeedsRetryCategory,
            CloudBackupErrorCategory.temporarilyUnavailable.rawValue
        )
        let failedSettings = await fixture.coordinator.currentSettings(
            areNotificationsEnabled: true
        )
        XCTAssertEqual(
            failedSettings.state,
            .deletionNeedsRetry(.temporarilyUnavailable)
        )

        let retry = await fixture.coordinator.deleteCloudBackup()
        XCTAssertEqual(retry, .deleted)
        XCTAssertFalse(fixture.scheduleStore.load().isEnabled)
        XCTAssertNil(fixture.scheduleStore.load().deletionNeedsRetryCategory)
        let deletionCount = await deleter.deletionCount
        XCTAssertEqual(deletionCount, 2)
    }

    func testCellularConfirmationIsConsumedBeforeEligibilitySuspends() async {
        let fixture = CoordinatorFixture(connection: .cellular)
        guard case .requiresCellularConfirmation(let proposal) = await fixture.coordinator.prepareManualBackup() else {
            return XCTFail("Expected a cellular confirmation proposal")
        }
        await fixture.environment.holdEligibilityChecks()
        let firstConfirmation = Task {
            await fixture.coordinator.confirmManualCellularBackup(
                proposalID: proposal.id,
                displayedByteCount: proposal.estimatedUploadByteCount
            )
        }
        let didStartEligibilityCheck = await fixture.environment.waitUntilEligibilityCheckStarts()
        XCTAssertTrue(didStartEligibilityCheck, "Timed out waiting for eligibility check")

        let duplicate = await fixture.coordinator.confirmManualCellularBackup(
            proposalID: proposal.id,
            displayedByteCount: proposal.estimatedUploadByteCount
        )

        XCTAssertEqual(duplicate, .invalidCellularApproval)
        await fixture.environment.releaseEligibility()
        guard case .published = await firstConfirmation.value else {
            return XCTFail("The first confirmation should publish")
        }
        let publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(publicationCount, 1)
    }

    func testCellularCancellationCannotDeletePackageAfterConfirmationStarts() async {
        let fixture = CoordinatorFixture(connection: .cellular)
        guard case .requiresCellularConfirmation(let proposal) = await fixture.coordinator.prepareManualBackup() else {
            return XCTFail("Expected a cellular confirmation proposal")
        }
        await fixture.environment.holdEligibilityChecks()
        let confirmation = Task {
            await fixture.coordinator.confirmManualCellularBackup(
                proposalID: proposal.id,
                displayedByteCount: proposal.estimatedUploadByteCount
            )
        }
        let didStartEligibilityCheck = await fixture.environment.waitUntilEligibilityCheckStarts()
        XCTAssertTrue(didStartEligibilityCheck, "Timed out waiting for eligibility check")

        await fixture.coordinator.cancelManualCellularBackup(proposalID: proposal.id)

        let removedBeforePublication = await fixture.cleaner.removedGenerationIDs
        XCTAssertTrue(removedBeforePublication.isEmpty)
        await fixture.environment.releaseEligibility()
        guard case .published = await confirmation.value else {
            return XCTFail("Confirmation should retain and publish its package")
        }
        let publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(publicationCount, 1)
    }

    func testCancellationClearsInterruptedStateAndSchedulesRetry() async throws {
        let fixture = CoordinatorFixture(holdsPublication: true)
        let operation = Task {
            await fixture.coordinator.requestAutomaticBackup(trigger: .background)
        }
        try await fixture.publisher.waitUntilPublicationStarts()

        operation.cancel()
        await fixture.publisher.releasePublication(throwing: CancellationError())

        let result = await operation.value
        XCTAssertEqual(result, .failed(.cancelled))
        let metadata = fixture.scheduleStore.load()
        XCTAssertNil(metadata.activeGenerationID)
        XCTAssertTrue(metadata.isOverdue)
        XCTAssertEqual(metadata.retryCount, 1)
        let removedGenerationIDs = await fixture.cleaner.removedGenerationIDs
        XCTAssertEqual(removedGenerationIDs, ["generation-1"])
    }

    func testLaunchRecoversInterruptedMetadataBeforePublishing() async {
        var metadata = BackupScheduleMetadata.initial
        metadata.activeGenerationID = "interrupted-generation"
        metadata.isOverdue = false
        let fixture = CoordinatorFixture(metadata: metadata)

        guard case .published = await fixture.coordinator.startAndCatchUp() else {
            return XCTFail("Expected overdue launch catch-up to publish")
        }

        let removeAllCallCount = await fixture.cleaner.removeAllCallCount
        XCTAssertEqual(removeAllCallCount, 1)
        let removedGenerationIDs = await fixture.cleaner.removedGenerationIDs
        XCTAssertEqual(removedGenerationIDs, ["generation-1"])
        XCTAssertNil(fixture.scheduleStore.load().activeGenerationID)
    }

    func testBackgroundRelaunchReconcilesInterruptedAndUntrackedStaging() async {
        var metadata = BackupScheduleMetadata.initial
        metadata.activeGenerationID = "interrupted-generation"
        let fixture = CoordinatorFixture(metadata: metadata)

        guard case .published = await fixture.coordinator.requestAutomaticBackup(trigger: .background) else {
            return XCTFail("Expected background relaunch to recover and publish")
        }

        let removeAllCallCount = await fixture.cleaner.removeAllCallCount
        XCTAssertEqual(removeAllCallCount, 1)
        XCTAssertNil(fixture.scheduleStore.load().activeGenerationID)
    }

    func testManualCellularBackupRequiresMatchingSizeAwareApproval() async {
        let fixture = CoordinatorFixture(connection: .cellular)

        let preparation = await fixture.coordinator.prepareManualBackup()
        guard case .requiresCellularConfirmation(let proposal) = preparation else {
            return XCTFail("Expected cellular confirmation, got \(preparation)")
        }
        XCTAssertEqual(proposal.estimatedUploadByteCount, 4_096)
        var publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(publicationCount, 0)

        let invalid = await fixture.coordinator.confirmManualCellularBackup(
            proposalID: proposal.id,
            displayedByteCount: proposal.estimatedUploadByteCount - 1
        )
        XCTAssertEqual(invalid, .invalidCellularApproval)
        publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(publicationCount, 0)

        guard case .published = await fixture.coordinator.confirmManualCellularBackup(
            proposalID: proposal.id,
            displayedByteCount: proposal.estimatedUploadByteCount
        ) else {
            return XCTFail("Expected approved cellular backup to publish")
        }
        publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(publicationCount, 1)
        let transferPolicies = await fixture.publisher.transferPolicies
        XCTAssertEqual(transferPolicies, [.cellularAllowed])
    }

    func testManualWiFiBackupPublishesWithoutCellularConfirmation() async {
        let fixture = CoordinatorFixture(connection: .wifi)

        guard case .published = await fixture.coordinator.prepareManualBackup() else {
            return XCTFail("Expected Wi-Fi manual backup to publish")
        }

        let publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(publicationCount, 1)
        let transferPolicies = await fixture.publisher.transferPolicies
        XCTAssertEqual(transferPolicies, [.wifiOnly])
    }

    func testRestoreSessionBlocksBackupUntilItEnds() async {
        let fixture = CoordinatorFixture()

        let beganRestore = await fixture.coordinator.beginRestoreSession()
        let automaticResult = await fixture.coordinator.requestAutomaticBackup(trigger: .background)
        let manualResult = await fixture.coordinator.prepareManualBackup()

        XCTAssertTrue(beganRestore)
        XCTAssertEqual(automaticResult, .coalesced)
        XCTAssertEqual(manualResult, .busy)

        await fixture.coordinator.endRestoreSession()

        guard case .published = await fixture.coordinator.prepareManualBackup() else {
            return XCTFail("Expected backup to resume after the restore session ended")
        }
    }

    func testSecondRestoreSessionCannotStartConcurrently() async {
        let fixture = CoordinatorFixture()

        let firstSession = await fixture.coordinator.beginRestoreSession()
        let secondSession = await fixture.coordinator.beginRestoreSession()

        XCTAssertTrue(firstSession)
        XCTAssertFalse(secondSession)
    }

    func testUnrecoveredRestoreFailureKeepsEveryBackupPathBlocked() async {
        let fixture = CoordinatorFixture()
        let runtime = CloudBackupRuntime(coordinator: fixture.coordinator)
        let beganRestore = await fixture.coordinator.beginRestoreSession()
        XCTAssertTrue(beganRestore)

        await runtime.finishRestoreSessionIfSafe(
            after: .failed(
                RestoreFailure(category: .activationFailed, didRollBack: false)
            )
        )

        let automaticResult = await fixture.coordinator.requestAutomaticBackup(trigger: .background)
        let manualResult = await fixture.coordinator.prepareManualBackup()
        let publicationCount = await fixture.publisher.publicationCount
        XCTAssertEqual(automaticResult, .coalesced)
        XCTAssertEqual(manualResult, .busy)
        XCTAssertEqual(publicationCount, 0)
    }

    func testRolledBackRestoreFailureReleasesBackupSession() async {
        let fixture = CoordinatorFixture()
        let runtime = CloudBackupRuntime(coordinator: fixture.coordinator)
        let beganRestore = await fixture.coordinator.beginRestoreSession()
        XCTAssertTrue(beganRestore)

        await runtime.finishRestoreSessionIfSafe(
            after: .failed(
                RestoreFailure(category: .activationFailed, didRollBack: true)
            )
        )

        guard case .published = await fixture.coordinator.prepareManualBackup() else {
            return XCTFail("Expected backup to resume after successful restore rollback")
        }
    }
}

private final class CoordinatorFixture {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduleStore: InMemoryBackupScheduleStore
    let snapshotCreator: FakeSnapshotCreator
    let publisher: FakeBackupPublisher
    let scheduler = FakeBackgroundScheduler()
    let cleaner = FakePackageCleaner()
    let environment: FakeBackupEnvironment
    let coordinator: BackupCoordinator

    init(
        metadata: BackupScheduleMetadata = .initial,
        connection: BackupConnection = .wifi,
        account: BackupAccountAvailability = .available,
        hasEligiblePower: Bool = true,
        hasSufficientStorage: Bool = true,
        isPublicationAuthorized: Bool = true,
        holdsPublication: Bool = false,
        holdsEligibility: Bool = false,
        holdsSnapshotCreation: Bool = false,
        deleter: (any CloudBackupDeleting)? = nil
    ) {
        scheduleStore = InMemoryBackupScheduleStore(metadata: metadata)
        snapshotCreator = FakeSnapshotCreator(holdsCreation: holdsSnapshotCreation)
        publisher = FakeBackupPublisher(holdsPublication: holdsPublication)
        environment = FakeBackupEnvironment(
            connection: connection,
            account: account,
            hasEligiblePower: hasEligiblePower,
            hasSufficientStorage: hasSufficientStorage,
            isPublicationAuthorized: isPublicationAuthorized,
            holdsEligibility: holdsEligibility
        )
        coordinator = BackupCoordinator(
            snapshotCreator: snapshotCreator,
            publisher: publisher,
            scheduleStore: scheduleStore,
            connectivity: environment,
            account: environment,
            publicationAuthorization: environment,
            power: environment,
            storage: environment,
            backgroundScheduler: scheduler,
            packageCleaner: cleaner,
            deleter: deleter,
            schedulePolicy: BackupSchedulePolicy(
                calendar: Calendar(identifier: .gregorian),
                nightlyHour: 2,
                initialRetryDelay: 60,
                maximumRetryDelay: 600
            ),
            now: { [now] in now },
            makeProposalID: { "proposal-1" }
        )
    }
}

private final class InMemoryBackupScheduleStore: BackupScheduleStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var metadata: BackupScheduleMetadata

    init(metadata: BackupScheduleMetadata) {
        self.metadata = metadata
    }

    func load() -> BackupScheduleMetadata {
        lock.lock()
        defer { lock.unlock() }
        return metadata
    }

    func save(_ metadata: BackupScheduleMetadata) {
        lock.lock()
        self.metadata = metadata
        lock.unlock()
    }
}

private actor FakeSnapshotCreator: AppSnapshotCreating {
    private let holdsCreation: Bool
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var creationCount = 0

    init(holdsCreation: Bool) {
        self.holdsCreation = holdsCreation
    }

    func createSnapshot() async throws -> AppSnapshotPackage {
        creationCount += 1
        if holdsCreation {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }
        let generationID = "generation-\(creationCount)"
        let root = URL(fileURLWithPath: "/tmp/\(generationID)", isDirectory: true)
        let manifest = BackupManifest(
            databaseSchemaVersion: "v1",
            minimumCompatibleAppVersion: "1.0",
            generationID: generationID,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            database: BackupFileDescriptor(
                relativePath: "database.sqlite",
                byteCount: 4_000,
                sha256: "database"
            ),
            assets: []
        )
        return AppSnapshotPackage(
            generationID: generationID,
            directoryURL: root,
            manifestURL: root.appendingPathComponent("manifest.json"),
            databaseURL: root.appendingPathComponent("database.sqlite"),
            manifest: manifest
        )
    }

    func waitUntilCreationStarts() async throws {
        for _ in 0..<1_000 where creationCount == 0 {
            await Task.yield()
        }
        if creationCount == 0 {
            throw XCTSkip("Timed out waiting for fake snapshot creation")
        }
    }

    func releaseCreation() {
        continuation?.resume()
        continuation = nil
    }
}

private actor FakeBackupPublisher: CloudBackupPublishing {
    private let holdsPublication: Bool
    private var continuation: CheckedContinuation<Void, Error>?
    private var stageHandler: (@Sendable (CloudBackupPublicationStage) async -> Void)?
    private(set) var publicationCount = 0
    private(set) var transferPolicies: [CloudBackupTransferPolicy] = []

    init(holdsPublication: Bool) {
        self.holdsPublication = holdsPublication
    }

    func estimatedUploadByteCount(for package: AppSnapshotPackage) async throws -> Int64 {
        4_096
    }

    func publish(
        _ package: AppSnapshotPackage,
        transferPolicy: CloudBackupTransferPolicy,
        publicationGate: @escaping @Sendable () async -> Bool,
        stageHandler: @escaping @Sendable (CloudBackupPublicationStage) async -> Void
    ) async throws -> CloudBackupPublicationResult {
        publicationCount += 1
        transferPolicies.append(transferPolicy)
        self.stageHandler = stageHandler
        await stageHandler(.uploading)
        if holdsPublication {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        }
        try Task.checkCancellation()
        guard await publicationGate() else {
            throw CloudBackupPublicationError.publicationNotAuthorized
        }
        return CloudBackupPublicationResult(
            generationID: package.generationID,
            replacedGenerationID: "previous-generation",
            wasAlreadyCurrent: false,
            cleanupPending: false
        )
    }

    func waitUntilPublicationStarts() async throws {
        for _ in 0..<1_000 where publicationCount == 0 {
            await Task.yield()
        }
        if publicationCount == 0 {
            throw XCTSkip("Timed out waiting for fake publication")
        }
    }

    func releasePublication(throwing error: Error? = nil) {
        let continuation = continuation
        self.continuation = nil
        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }

    func reportVerificationStarted() async {
        await stageHandler?(.verifying)
    }
}

private actor FakeBackupEnvironment: BackupConnectivityChecking,
    BackupAccountChecking,
    BackupPublicationAuthorizing,
    BackupPowerChecking,
    BackupStorageChecking {
    let connection: BackupConnection
    let account: BackupAccountAvailability
    let hasEligiblePower: Bool
    let hasSufficientStorage: Bool
    private var isAuthorized: Bool
    private var accountFingerprint: String? = "account-a"
    private var holdsEligibility: Bool
    private var didStartEligibilityCheck = false
    private var eligibilityContinuation: CheckedContinuation<Void, Never>?

    init(
        connection: BackupConnection,
        account: BackupAccountAvailability,
        hasEligiblePower: Bool,
        hasSufficientStorage: Bool,
        isPublicationAuthorized: Bool,
        holdsEligibility: Bool
    ) {
        self.connection = connection
        self.account = account
        self.hasEligiblePower = hasEligiblePower
        self.hasSufficientStorage = hasSufficientStorage
        isAuthorized = isPublicationAuthorized
        self.holdsEligibility = holdsEligibility
    }

    func currentConnection() async -> BackupConnection { connection }
    func currentAvailability() async -> BackupAccountAvailability {
        didStartEligibilityCheck = true
        if holdsEligibility {
            await withCheckedContinuation { continuation in
                eligibilityContinuation = continuation
            }
        }
        return account
    }
    func currentFingerprint() async -> String? {
        account == .available ? accountFingerprint : nil
    }
    func isPublicationAuthorized() async -> Bool { isAuthorized }
    func authorizePublication(for accountFingerprint: String) async -> Bool {
        guard self.accountFingerprint == accountFingerprint else { return false }
        isAuthorized = true
        return true
    }
    func setAccountFingerprint(_ fingerprint: String?) {
        accountFingerprint = fingerprint
        isAuthorized = false
    }
    func hasEligiblePowerState() async -> Bool { hasEligiblePower }
    func hasSufficientWorkingStorage(estimatedUploadByteCount: Int64?) async -> Bool {
        hasSufficientStorage
    }

    func waitUntilEligibilityCheckStarts() async -> Bool {
        for _ in 0..<1_000 where !didStartEligibilityCheck {
            await Task.yield()
        }
        return didStartEligibilityCheck
    }

    func holdEligibilityChecks() {
        holdsEligibility = true
        didStartEligibilityCheck = false
    }

    func releaseEligibility() {
        holdsEligibility = false
        eligibilityContinuation?.resume()
        eligibilityContinuation = nil
    }
}

private actor FakeCloudBackupDeleter: CloudBackupDeleting {
    private(set) var deletionCount = 0
    private var failuresRemaining: Int

    init(failuresRemaining: Int = 0) {
        self.failuresRemaining = failuresRemaining
    }

    func deleteAllBackupData() async throws {
        deletionCount += 1
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw CloudBackupStoreError(
                category: .temporarilyUnavailable,
                operationID: "delete"
            )
        }
    }
}

private actor FakeBackgroundScheduler: BackupBackgroundScheduling {
    private(set) var scheduledDates: [Date] = []

    func schedule(earliestBeginDate: Date) async -> Bool {
        scheduledDates.append(earliestBeginDate)
        return true
    }
}

private actor FakePackageCleaner: BackupSnapshotPackageCleaning {
    private(set) var removedGenerationIDs: [String] = []
    private(set) var removeAllCallCount = 0

    func removePackage(generationID: String) {
        removedGenerationIDs.append(generationID)
    }

    func removeAllPackages() {
        removeAllCallCount += 1
    }
}
