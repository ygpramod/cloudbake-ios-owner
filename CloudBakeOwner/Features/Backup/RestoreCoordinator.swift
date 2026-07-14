import Foundation

enum CloudRestoreIntegrity: Equatable, Sendable {
    case verified
    case brokenAssets(count: Int)
}

struct CloudRestoreSnapshot: Equatable, Sendable {
    let generationID: String
    let createdAt: Date
    let totalByteCount: Int64
    let assetCount: Int
    let compatibility: BackupManifestCompatibility
    let integrity: CloudRestoreIntegrity
}

struct DownloadedRestoreSnapshot: Equatable, Sendable {
    let directoryURL: URL
    let manifest: BackupManifest
    let brokenAssets: [BrokenRestoreAsset]
}

struct BrokenRestoreAsset: Equatable, Hashable, Sendable {
    let originalRelativePath: String
}

struct PreparedRestoreSnapshot: Equatable, Sendable {
    let directoryURL: URL
    let manifest: BackupManifest
    let brokenAssets: [BrokenRestoreAsset]
    let ignoredBrokenAssets: [BrokenRestoreAsset]
}

enum BrokenRestoreAssetDecision: Equatable, Sendable {
    case ignore
    case removeReferences
}

struct RestoreProposal: Equatable, Sendable {
    let id: String
    let snapshot: CloudRestoreSnapshot
    let replacesExistingData: Bool
}

struct BrokenRestoreAssetProposal: Equatable, Sendable {
    let restoreProposalID: String
    let assets: [BrokenRestoreAsset]
}

enum RestoreFailureCategory: Equatable, Sendable {
    case iCloudUnavailable
    case networkUnavailable
    case noBackup
    case updateRequired(minimumVersion: String)
    case unsupportedFormat
    case corruptBackup
    case insufficientStorage
    case migrationFailed
    case activationFailed
    case verificationFailed
    case cancelled
    case unknown
}

struct RestoreFailure: Equatable, Sendable {
    let category: RestoreFailureCategory
    let didRollBack: Bool
}

enum RestoreResult: Equatable, Sendable {
    case ready(RestoreProposal)
    case requiresReplacementConfirmation(RestoreProposal)
    case requiresCellularConfirmation(RestoreProposal)
    case requiresBrokenAssetDecision(BrokenRestoreAssetProposal)
    case completed
    case noBackup
    case busy
    case invalidApproval
    case failed(RestoreFailure)
}

enum RestoreApproval: Equatable, Sendable {
    case start
    case replaceExistingData
    case useCellular(displayedByteCount: Int64)
    case brokenAssets(BrokenRestoreAssetDecision)
}

enum RestoreStage: Equatable, Sendable {
    case idle
    case inspecting
    case awaitingConfirmation
    case creatingRollback
    case downloading
    case validating
    case awaitingBrokenAssetDecision
    case activating
    case verifying
    case completed
    case failed(RestoreFailure)
}

protocol CloudRestoreServing: Sendable {
    func inspectCurrentSnapshot(currentAppVersion: String) async throws -> CloudRestoreSnapshot?
    func downloadCurrentSnapshot(
        _ snapshot: CloudRestoreSnapshot,
        to directoryURL: URL,
        transferPolicy: CloudBackupTransferPolicy
    ) async throws -> DownloadedRestoreSnapshot
}

protocol LocalRestoreServing: Sendable {
    func hasOwnerData() async throws -> Bool
    func createRollbackSnapshot() async throws -> AppSnapshotPackage
    func prepare(_ snapshot: DownloadedRestoreSnapshot) async throws -> PreparedRestoreSnapshot
    func applyBrokenAssetDecision(
        _ decision: BrokenRestoreAssetDecision,
        to snapshot: PreparedRestoreSnapshot
    ) async throws -> PreparedRestoreSnapshot
    /// Activates the prepared snapshot and guarantees rollback before throwing after activation starts.
    func activate(
        _ snapshot: PreparedRestoreSnapshot,
        rollbackSnapshot: AppSnapshotPackage?
    ) async throws
    func removeStagedRestore(at directoryURL: URL) async
    func removeRollbackSnapshot(_ snapshot: AppSnapshotPackage) async
}

actor RestoreCoordinator {
    private enum PendingOperation: Sendable {
        case downloadAndPrepare
        case resolveBrokenAssets(BrokenRestoreAssetDecision)
    }

    private struct RunningOperation {
        let id: String
        let proposalID: String
        let task: Task<RestoreResult, Never>
    }

    private enum AwaitingApproval {
        case start
        case replacement
        case cellular
        case brokenAssets
    }

    private struct ActiveRestore {
        let proposal: RestoreProposal
        var awaiting: AwaitingApproval
        var replacementApproved: Bool
        var cellularApproved: Bool
        var downloaded: DownloadedRestoreSnapshot?
        var prepared: PreparedRestoreSnapshot?
        var rollback: AppSnapshotPackage?
    }

    private let cloud: any CloudRestoreServing
    private let local: any LocalRestoreServing
    private let connectivity: any BackupConnectivityChecking
    private let stagingRoot: URL
    private let currentAppVersion: String
    private let makeProposalID: @Sendable () -> String
    private let makeOperationID: @Sendable () -> String

    private var active: ActiveRestore?
    private var runningOperation: RunningOperation?
    private(set) var stage: RestoreStage = .idle

    init(
        cloud: any CloudRestoreServing,
        local: any LocalRestoreServing,
        connectivity: any BackupConnectivityChecking,
        stagingRoot: URL,
        currentAppVersion: String,
        makeProposalID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
        makeOperationID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.cloud = cloud
        self.local = local
        self.connectivity = connectivity
        self.stagingRoot = stagingRoot
        self.currentAppVersion = currentAppVersion
        self.makeProposalID = makeProposalID
        self.makeOperationID = makeOperationID
    }

    func inspect() async -> RestoreResult {
        guard active == nil, runningOperation == nil, stage != .inspecting else { return .busy }
        stage = .inspecting
        do {
            guard let snapshot = try await cloud.inspectCurrentSnapshot(
                currentAppVersion: currentAppVersion
            ) else {
                stage = .idle
                return .noBackup
            }
            if let incompatibility = failure(for: snapshot.compatibility) {
                return finishFailure(incompatibility)
            }

            let replacesExistingData = try await local.hasOwnerData()
            let proposal = RestoreProposal(
                id: makeProposalID(),
                snapshot: snapshot,
                replacesExistingData: replacesExistingData
            )
            let connection = await connectivity.currentConnection()
            let awaiting: AwaitingApproval
            let result: RestoreResult
            if replacesExistingData {
                awaiting = .replacement
                result = .requiresReplacementConfirmation(proposal)
            } else if connection == .cellular {
                awaiting = .cellular
                result = .requiresCellularConfirmation(proposal)
            } else {
                awaiting = .start
                result = .ready(proposal)
            }
            active = ActiveRestore(
                proposal: proposal,
                awaiting: awaiting,
                replacementApproved: false,
                cellularApproved: false
            )
            stage = .awaitingConfirmation
            return result
        } catch {
            return finishFailure(mappedFailure(error))
        }
    }

    func proceed(proposalID: String, approval: RestoreApproval) async -> RestoreResult {
        guard stage == .awaitingConfirmation || stage == .awaitingBrokenAssetDecision else {
            return .busy
        }
        guard var active, active.proposal.id == proposalID else {
            return .invalidApproval
        }

        switch (active.awaiting, approval) {
        case (.start, .start):
            self.active = active
            return await run(.downloadAndPrepare, proposalID: proposalID)
        case (.replacement, .replaceExistingData):
            active.replacementApproved = true
            if await connectivity.currentConnection() == .cellular {
                active.awaiting = .cellular
                self.active = active
                stage = .awaitingConfirmation
                return .requiresCellularConfirmation(active.proposal)
            }
            self.active = active
            return await run(.downloadAndPrepare, proposalID: proposalID)
        case (.cellular, .useCellular(let displayedByteCount))
            where displayedByteCount == active.proposal.snapshot.totalByteCount:
            guard !active.proposal.replacesExistingData || active.replacementApproved else {
                return .invalidApproval
            }
            active.cellularApproved = true
            self.active = active
            return await run(.downloadAndPrepare, proposalID: proposalID)
        case (.brokenAssets, .brokenAssets(let decision)):
            guard active.prepared != nil else { return .invalidApproval }
            self.active = active
            return await run(.resolveBrokenAssets(decision), proposalID: proposalID)
        default:
            return .invalidApproval
        }
    }

    @discardableResult
    func cancel(proposalID: String) async -> Bool {
        guard let active, active.proposal.id == proposalID else { return false }
        if let runningOperation, runningOperation.proposalID == proposalID {
            runningOperation.task.cancel()
            _ = await runningOperation.task.value
            if self.runningOperation?.id == runningOperation.id {
                self.runningOperation = nil
            }
            return true
        }
        await cleanUp(active)
        self.active = nil
        stage = .idle
        return true
    }

    private func run(
        _ operation: PendingOperation,
        proposalID: String
    ) async -> RestoreResult {
        guard runningOperation == nil else { return .busy }
        let operationID = makeOperationID()
        let task = Task { await self.execute(operation, proposalID: proposalID) }
        runningOperation = RunningOperation(
            id: operationID,
            proposalID: proposalID,
            task: task
        )
        let result = await task.value
        if runningOperation?.id == operationID {
            runningOperation = nil
        }
        return result
    }

    private func execute(
        _ operation: PendingOperation,
        proposalID: String
    ) async -> RestoreResult {
        guard active?.proposal.id == proposalID else { return .invalidApproval }
        switch operation {
        case .downloadAndPrepare:
            return await performDownloadAndPreparation()
        case .resolveBrokenAssets(let decision):
            return await resolveBrokenAssets(decision)
        }
    }

    private func performDownloadAndPreparation() async -> RestoreResult {
        guard var active else { return .invalidApproval }
        do {
            try Task.checkCancellation()
            if active.proposal.replacesExistingData {
                stage = .creatingRollback
                active.rollback = try await local.createRollbackSnapshot()
                self.active = active
                try Task.checkCancellation()
            }

            stage = .downloading
            let downloadDirectory = stagingRoot.appendingPathComponent(
                active.proposal.id,
                isDirectory: true
            )
            let transferPolicy: CloudBackupTransferPolicy = active.cellularApproved
                ? .cellularAllowed
                : .wifiOnly
            let downloaded = try await cloud.downloadCurrentSnapshot(
                active.proposal.snapshot,
                to: downloadDirectory,
                transferPolicy: transferPolicy
            )
            active.downloaded = downloaded
            self.active = active
            try Task.checkCancellation()

            stage = .validating
            let prepared = try await local.prepare(downloaded)
            try Task.checkCancellation()
            active.prepared = prepared
            if !prepared.brokenAssets.isEmpty {
                active.awaiting = .brokenAssets
                self.active = active
                stage = .awaitingBrokenAssetDecision
                return .requiresBrokenAssetDecision(
                    BrokenRestoreAssetProposal(
                        restoreProposalID: active.proposal.id,
                        assets: prepared.brokenAssets
                    )
                )
            }
            self.active = active
            return await activatePreparedSnapshot()
        } catch {
            return await failAndCleanUp(error)
        }
    }

    private func resolveBrokenAssets(
        _ decision: BrokenRestoreAssetDecision
    ) async -> RestoreResult {
        guard var active, let prepared = active.prepared else { return .invalidApproval }
        do {
            try Task.checkCancellation()
            stage = .validating
            active.prepared = try await local.applyBrokenAssetDecision(decision, to: prepared)
            self.active = active
            try Task.checkCancellation()
            return await activatePreparedSnapshot()
        } catch {
            return await failAndCleanUp(error)
        }
    }

    private func activatePreparedSnapshot() async -> RestoreResult {
        guard let active, let prepared = active.prepared else {
            return .invalidApproval
        }
        do {
            stage = .activating
            try await local.activate(prepared, rollbackSnapshot: active.rollback)
            stage = .verifying
            await cleanUp(active)
            self.active = nil
            stage = .completed
            return .completed
        } catch {
            return await failAndCleanUp(error)
        }
    }

    private func failAndCleanUp(_ error: Error) async -> RestoreResult {
        let current = active
        if let current { await cleanUp(current) }
        active = nil
        let failure = mappedFailure(error)
        stage = .failed(failure)
        return .failed(failure)
    }

    private func cleanUp(_ active: ActiveRestore) async {
        if let downloaded = active.downloaded {
            await local.removeStagedRestore(at: downloaded.directoryURL)
        }
        if let rollback = active.rollback {
            await local.removeRollbackSnapshot(rollback)
        }
    }

    private func failure(for compatibility: BackupManifestCompatibility) -> RestoreFailure? {
        switch compatibility {
        case .compatible:
            nil
        case .unsupportedFormat:
            RestoreFailure(category: .unsupportedFormat, didRollBack: false)
        case .appUpdateRequired(let minimumVersion):
            RestoreFailure(category: .updateRequired(minimumVersion: minimumVersion), didRollBack: false)
        }
    }

    private func mappedFailure(_ error: Error) -> RestoreFailure {
        if let failure = error as? RestoreOperationError {
            return RestoreFailure(category: failure.category, didRollBack: failure.didRollBack)
        }
        if let cloudError = error as? CloudBackupStoreError {
            return RestoreFailure(
                category: Self.restoreCategory(for: cloudError.category),
                didRollBack: false
            )
        }
        if error is CancellationError {
            return RestoreFailure(category: .cancelled, didRollBack: false)
        }
        return RestoreFailure(category: .unknown, didRollBack: false)
    }

    private func finishFailure(_ failure: RestoreFailure) -> RestoreResult {
        active = nil
        stage = .failed(failure)
        return .failed(failure)
    }

    private static func restoreCategory(for category: CloudBackupErrorCategory) -> RestoreFailureCategory {
        switch category {
        case .iCloudUnavailable, .authenticationRequired, .permissionDenied:
            .iCloudUnavailable
        case .networkUnavailable, .temporarilyUnavailable:
            .networkUnavailable
        case .corruptRemoteData:
            .corruptBackup
        case .cancelled:
            .cancelled
        default:
            .unknown
        }
    }
}

struct RestoreOperationError: Error, Equatable, Sendable {
    let category: RestoreFailureCategory
    let didRollBack: Bool
}
