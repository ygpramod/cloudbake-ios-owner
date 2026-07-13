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
}

private final class CoordinatorFixture {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduleStore: InMemoryBackupScheduleStore
    let snapshotCreator = FakeSnapshotCreator()
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
        holdsEligibility: Bool = false
    ) {
        scheduleStore = InMemoryBackupScheduleStore(metadata: metadata)
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
    private(set) var creationCount = 0

    func createSnapshot() async throws -> AppSnapshotPackage {
        creationCount += 1
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
}

private actor FakeBackupPublisher: CloudBackupPublishing {
    private let holdsPublication: Bool
    private var continuation: CheckedContinuation<Void, Error>?
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
        transferPolicy: CloudBackupTransferPolicy
    ) async throws -> CloudBackupPublicationResult {
        publicationCount += 1
        transferPolicies.append(transferPolicy)
        if holdsPublication {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        }
        try Task.checkCancellation()
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
    let isAuthorized: Bool
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
    func isPublicationAuthorized() async -> Bool { isAuthorized }
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
