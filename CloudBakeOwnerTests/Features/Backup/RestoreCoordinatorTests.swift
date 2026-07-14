import XCTest
@testable import CloudBakeOwner

final class RestoreCoordinatorTests: XCTestCase {
    func testEmptyInstallationOffersRestoreWithoutStartingAutomatically() async {
        let fixture = RestoreCoordinatorFixture()

        let result = await fixture.coordinator.inspect()

        XCTAssertEqual(result, .ready(fixture.proposal(replacesExistingData: false)))
        let downloadCount = await fixture.cloud.downloadCount
        let stage = await fixture.coordinator.stage
        XCTAssertEqual(downloadCount, 0)
        XCTAssertEqual(stage, .awaitingConfirmation)
    }

    func testPopulatedInstallationRequiresReplacementBeforeDownload() async {
        let fixture = RestoreCoordinatorFixture(hasOwnerData: true)

        let inspected = await fixture.coordinator.inspect()
        XCTAssertEqual(inspected, .requiresReplacementConfirmation(fixture.proposal(replacesExistingData: true)))
        let downloadCountBeforeApproval = await fixture.cloud.downloadCount
        XCTAssertEqual(downloadCountBeforeApproval, 0)

        let restored = await fixture.coordinator.proceed(
            proposalID: fixture.proposalID,
            approval: .replaceExistingData
        )
        XCTAssertEqual(restored, .completed)
        let rollbackCount = await fixture.local.rollbackCount
        let activationCount = await fixture.local.activationCount
        XCTAssertEqual(rollbackCount, 1)
        XCTAssertEqual(activationCount, 1)
    }

    func testCellularRestoreRequiresExactDisplayedSizeApproval() async {
        let fixture = RestoreCoordinatorFixture(connection: .cellular)
        _ = await fixture.coordinator.inspect()

        let invalid = await fixture.coordinator.proceed(
            proposalID: fixture.proposalID,
            approval: .useCellular(displayedByteCount: fixture.snapshot.totalByteCount - 1)
        )
        XCTAssertEqual(invalid, .invalidApproval)
        let downloadCount = await fixture.cloud.downloadCount
        XCTAssertEqual(downloadCount, 0)

        let restored = await fixture.coordinator.proceed(
            proposalID: fixture.proposalID,
            approval: .useCellular(displayedByteCount: fixture.snapshot.totalByteCount)
        )
        XCTAssertEqual(restored, .completed)
        let transferPolicies = await fixture.cloud.transferPolicies
        XCTAssertEqual(transferPolicies, [.cellularAllowed])
        let appVersions = await fixture.cloud.downloadAppVersions
        XCTAssertEqual(appVersions, ["1.0"])
    }

    func testReplacementConfirmationPrecedesCellularConfirmation() async {
        let fixture = RestoreCoordinatorFixture(hasOwnerData: true, connection: .cellular)
        _ = await fixture.coordinator.inspect()

        let cellularPrompt = await fixture.coordinator.proceed(
            proposalID: fixture.proposalID,
            approval: .replaceExistingData
        )

        XCTAssertEqual(cellularPrompt, .requiresCellularConfirmation(fixture.proposal(replacesExistingData: true)))
        let rollbackCount = await fixture.local.rollbackCount
        XCTAssertEqual(rollbackCount, 0)
    }

    func testBrokenAssetsPauseBeforeActivationAndHonorOwnerDecision() async {
        let brokenAsset = BrokenRestoreAsset(originalRelativePath: "OrderPhotos/missing.jpg")
        let fixture = RestoreCoordinatorFixture(brokenAssets: [brokenAsset])
        _ = await fixture.coordinator.inspect()

        let decision = await fixture.coordinator.proceed(
            proposalID: fixture.proposalID,
            approval: .start
        )
        XCTAssertEqual(
            decision,
            .requiresBrokenAssetDecision(
                BrokenRestoreAssetProposal(
                    restoreProposalID: fixture.proposalID,
                    assets: [brokenAsset]
                )
            )
        )
        let activationCountBeforeDecision = await fixture.local.activationCount
        XCTAssertEqual(activationCountBeforeDecision, 0)

        let restored = await fixture.coordinator.proceed(
            proposalID: fixture.proposalID,
            approval: .brokenAssets(.removeReferences)
        )
        XCTAssertEqual(restored, .completed)
        let assetDecisions = await fixture.local.assetDecisions
        let activationCount = await fixture.local.activationCount
        XCTAssertEqual(assetDecisions, [.removeReferences])
        XCTAssertEqual(activationCount, 1)
    }

    func testIncompatibleBackupStopsBeforeLocalInspection() async {
        let fixture = RestoreCoordinatorFixture(
            compatibility: .appUpdateRequired(minimumVersion: "2.0")
        )

        let result = await fixture.coordinator.inspect()

        XCTAssertEqual(
            result,
            .failed(RestoreFailure(category: .updateRequired(minimumVersion: "2.0"), didRollBack: false))
        )
        let ownerDataCheckCount = await fixture.local.ownerDataCheckCount
        XCTAssertEqual(ownerDataCheckCount, 0)
    }

    func testActivationFailureReportsGuaranteedRollbackAndCleansStaging() async {
        let fixture = RestoreCoordinatorFixture(
            hasOwnerData: true,
            activationError: RestoreOperationError(category: .activationFailed, didRollBack: true)
        )
        _ = await fixture.coordinator.inspect()

        let result = await fixture.coordinator.proceed(
            proposalID: fixture.proposalID,
            approval: .replaceExistingData
        )

        XCTAssertEqual(
            result,
            .failed(RestoreFailure(category: .activationFailed, didRollBack: true))
        )
        let removedRestoreCount = await fixture.local.removedRestoreCount
        let removedRollbackCount = await fixture.local.removedRollbackCount
        XCTAssertEqual(removedRestoreCount, 1)
        XCTAssertEqual(removedRollbackCount, 1)
    }

    func testCancellationWaitsForDownloadToStopBeforeReleasingRestore() async {
        let fixture = RestoreCoordinatorFixture(suspendDownload: true)
        _ = await fixture.coordinator.inspect()

        let restore = Task {
            await fixture.coordinator.proceed(
                proposalID: fixture.proposalID,
                approval: .start
            )
        }
        await fixture.cloud.waitForDownloadStart()

        let cancellation = Task {
            await fixture.coordinator.cancel(proposalID: fixture.proposalID)
        }
        await Task.yield()

        let inspectionDuringCancellation = await fixture.coordinator.inspect()
        let cleanupCountDuringCancellation = await fixture.local.removedRestoreCount
        XCTAssertEqual(inspectionDuringCancellation, .busy)
        XCTAssertEqual(cleanupCountDuringCancellation, 0)

        await fixture.cloud.releaseDownload()

        let restoreResult = await restore.value
        let didCancel = await cancellation.value
        let activationCount = await fixture.local.activationCount
        let cleanupCount = await fixture.local.removedRestoreCount
        let nextInspection = await fixture.coordinator.inspect()
        XCTAssertEqual(
            restoreResult,
            .failed(RestoreFailure(category: .cancelled, didRollBack: false))
        )
        XCTAssertTrue(didCancel)
        XCTAssertEqual(activationCount, 0)
        XCTAssertEqual(cleanupCount, 1)
        XCTAssertEqual(
            nextInspection,
            .ready(fixture.proposal(replacesExistingData: false))
        )
    }

    func testCancellationDuringActivationWaitsForCommittedRestore() async {
        let fixture = RestoreCoordinatorFixture(suspendActivation: true)
        _ = await fixture.coordinator.inspect()

        let restore = Task {
            await fixture.coordinator.proceed(
                proposalID: fixture.proposalID,
                approval: .start
            )
        }
        await fixture.local.waitForActivationStart()

        let cancellation = Task {
            await fixture.coordinator.cancel(proposalID: fixture.proposalID)
        }
        await Task.yield()

        let inspectionDuringCancellation = await fixture.coordinator.inspect()
        let cleanupCountDuringCancellation = await fixture.local.removedRestoreCount
        XCTAssertEqual(inspectionDuringCancellation, .busy)
        XCTAssertEqual(cleanupCountDuringCancellation, 0)

        await fixture.local.releaseActivation()

        let restoreResult = await restore.value
        let didCancel = await cancellation.value
        let activationCount = await fixture.local.activationCount
        let cleanupCount = await fixture.local.removedRestoreCount
        XCTAssertEqual(restoreResult, .completed)
        XCTAssertTrue(didCancel)
        XCTAssertEqual(activationCount, 1)
        XCTAssertEqual(cleanupCount, 1)
    }
}

private final class RestoreCoordinatorFixture: @unchecked Sendable {
    let proposalID = "restore-proposal"
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let snapshot: CloudRestoreSnapshot
    let cloud: FakeCloudRestoreService
    let local: FakeLocalRestoreService
    let coordinator: RestoreCoordinator

    init(
        hasOwnerData: Bool = false,
        connection: BackupConnection = .wifi,
        compatibility: BackupManifestCompatibility = .compatible,
        brokenAssets: [BrokenRestoreAsset] = [],
        activationError: Error? = nil,
        suspendDownload: Bool = false,
        suspendActivation: Bool = false
    ) {
        snapshot = CloudRestoreSnapshot(
            generationID: "generation-1",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            totalByteCount: 4_096,
            assetCount: 2,
            compatibility: compatibility,
            integrity: .verified
        )
        cloud = FakeCloudRestoreService(
            snapshot: snapshot,
            root: root,
            suspendDownload: suspendDownload
        )
        local = FakeLocalRestoreService(
            hasOwnerData: hasOwnerData,
            brokenAssets: brokenAssets,
            activationError: activationError,
            root: root,
            suspendActivation: suspendActivation
        )
        coordinator = RestoreCoordinator(
            cloud: cloud,
            local: local,
            connectivity: FixedRestoreConnectivity(connection: connection),
            stagingRoot: root.appendingPathComponent("staging"),
            currentAppVersion: "1.0",
            makeProposalID: { "restore-proposal" }
        )
    }

    func proposal(replacesExistingData: Bool) -> RestoreProposal {
        RestoreProposal(
            id: proposalID,
            snapshot: snapshot,
            replacesExistingData: replacesExistingData
        )
    }
}

private actor FakeCloudRestoreService: CloudRestoreServing {
    let snapshot: CloudRestoreSnapshot
    let root: URL
    private(set) var downloadCount = 0
    private(set) var transferPolicies: [CloudBackupTransferPolicy] = []
    private(set) var downloadAppVersions: [String] = []
    private let downloadGate: RestoreTestGate

    init(snapshot: CloudRestoreSnapshot, root: URL, suspendDownload: Bool) {
        self.snapshot = snapshot
        self.root = root
        downloadGate = RestoreTestGate(isClosed: suspendDownload)
    }

    func inspectCurrentSnapshot(currentAppVersion: String) async throws -> CloudRestoreSnapshot? {
        snapshot
    }

    func downloadCurrentSnapshot(
        _ snapshot: CloudRestoreSnapshot,
        to directoryURL: URL,
        currentAppVersion: String,
        transferPolicy: CloudBackupTransferPolicy
    ) async throws -> DownloadedRestoreSnapshot {
        downloadCount += 1
        transferPolicies.append(transferPolicy)
        downloadAppVersions.append(currentAppVersion)
        await downloadGate.waitIfClosed()
        return DownloadedRestoreSnapshot(
            directoryURL: directoryURL,
            manifest: Self.manifest(generationID: snapshot.generationID),
            brokenAssets: []
        )
    }

    func waitForDownloadStart() async {
        while downloadCount == 0 { await Task.yield() }
    }

    func releaseDownload() async {
        await downloadGate.open()
    }

    nonisolated static func manifest(generationID: String) -> BackupManifest {
        BackupManifest(
            databaseSchemaVersion: "0027_add_order_ingredient_costs",
            minimumCompatibleAppVersion: "1.0",
            generationID: generationID,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            database: BackupFileDescriptor(relativePath: "database.sqlite", byteCount: 1, sha256: "db"),
            assets: []
        )
    }
}

private actor FakeLocalRestoreService: LocalRestoreServing {
    let ownerData: Bool
    let brokenAssets: [BrokenRestoreAsset]
    let activationError: Error?
    let root: URL
    private(set) var ownerDataCheckCount = 0
    private(set) var rollbackCount = 0
    private(set) var activationCount = 0
    private(set) var assetDecisions: [BrokenRestoreAssetDecision] = []
    private(set) var removedRestoreCount = 0
    private(set) var removedRollbackCount = 0
    private let activationGate: RestoreTestGate

    init(
        hasOwnerData: Bool,
        brokenAssets: [BrokenRestoreAsset],
        activationError: Error?,
        root: URL,
        suspendActivation: Bool
    ) {
        ownerData = hasOwnerData
        self.brokenAssets = brokenAssets
        self.activationError = activationError
        self.root = root
        activationGate = RestoreTestGate(isClosed: suspendActivation)
    }

    func hasOwnerData() async throws -> Bool {
        ownerDataCheckCount += 1
        return ownerData
    }

    func createRollbackSnapshot() async throws -> AppSnapshotPackage {
        rollbackCount += 1
        let manifest = FakeCloudRestoreService.manifest(generationID: "rollback")
        let directory = root.appendingPathComponent("rollback")
        return AppSnapshotPackage(
            generationID: "rollback",
            directoryURL: directory,
            manifestURL: directory.appendingPathComponent("manifest.json"),
            databaseURL: directory.appendingPathComponent("database.sqlite"),
            manifest: manifest
        )
    }

    func prepare(_ snapshot: DownloadedRestoreSnapshot) async throws -> PreparedRestoreSnapshot {
        PreparedRestoreSnapshot(
            directoryURL: snapshot.directoryURL,
            manifest: snapshot.manifest,
            brokenAssets: brokenAssets,
            ignoredBrokenAssets: []
        )
    }

    func applyBrokenAssetDecision(
        _ decision: BrokenRestoreAssetDecision,
        to snapshot: PreparedRestoreSnapshot
    ) async throws -> PreparedRestoreSnapshot {
        assetDecisions.append(decision)
        return PreparedRestoreSnapshot(
            directoryURL: snapshot.directoryURL,
            manifest: snapshot.manifest,
            brokenAssets: [],
            ignoredBrokenAssets: decision == .ignore ? snapshot.brokenAssets : []
        )
    }

    func activate(
        _ snapshot: PreparedRestoreSnapshot,
        rollbackSnapshot: AppSnapshotPackage?
    ) async throws {
        activationCount += 1
        await activationGate.waitIfClosed()
        if let activationError { throw activationError }
    }

    func waitForActivationStart() async {
        while activationCount == 0 { await Task.yield() }
    }

    func releaseActivation() async {
        await activationGate.open()
    }

    func removeStagedRestore(at directoryURL: URL) async {
        removedRestoreCount += 1
    }

    func removeRollbackSnapshot(_ snapshot: AppSnapshotPackage) async {
        removedRollbackCount += 1
    }
}

private actor RestoreTestGate {
    private var isClosed: Bool
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(isClosed: Bool) {
        self.isClosed = isClosed
    }

    func waitIfClosed() async {
        guard isClosed else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isClosed = false
        let continuations = waiters
        waiters.removeAll()
        continuations.forEach { $0.resume() }
    }
}

private struct FixedRestoreConnectivity: BackupConnectivityChecking {
    let connection: BackupConnection

    func currentConnection() async -> BackupConnection { connection }
}
