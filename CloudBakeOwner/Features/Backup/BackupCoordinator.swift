import Foundation

enum BackupConnection: Equatable, Sendable {
    case wifi
    case cellular
    case unavailable
}

enum BackupAccountAvailability: Equatable, Sendable {
    case available
    case unavailable
}

struct ManualAccountBackupProposal: Equatable, Sendable {
    let id: String
    fileprivate let accountFingerprint: String

    init(id: String, accountFingerprint: String) {
        self.id = id
        self.accountFingerprint = accountFingerprint
    }
}

enum BackupDeferralReason: Equatable, Sendable {
    case disabled
    case accountConfirmationRequired
    case waitingForWiFi
    case networkUnavailable
    case iCloudUnavailable
    case powerRestricted
    case insufficientStorage
}

enum AutomaticBackupTrigger: Equatable, Sendable {
    case background
    case launchCatchUp
}

enum AutomaticBackupResult: Equatable, Sendable {
    case published(CloudBackupPublicationResult)
    case notDue
    case coalesced
    case deferred(BackupDeferralReason)
    case failed(CloudBackupErrorCategory)
}

struct ManualCellularBackupProposal: Equatable, Sendable {
    let id: String
    let generationID: String
    let estimatedUploadByteCount: Int64
}

struct ManualUnavailablePhotoBackupProposal: Equatable, Sendable {
    let id: String
    let unavailablePhotoCount: Int
    fileprivate let assets: [BackupUnavailableExternalAsset]
    fileprivate let startedAt: Date
    fileprivate let didRemoveUnavailablePhotoReferences: Bool

    init(id: String, unavailablePhotoCount: Int) {
        self.id = id
        self.unavailablePhotoCount = unavailablePhotoCount
        assets = []
        startedAt = .distantPast
        didRemoveUnavailablePhotoReferences = false
    }

    fileprivate init(
        id: String,
        assets: [BackupUnavailableExternalAsset],
        startedAt: Date,
        didRemoveUnavailablePhotoReferences: Bool
    ) {
        self.id = id
        unavailablePhotoCount = assets.count
        self.assets = assets
        self.startedAt = startedAt
        self.didRemoveUnavailablePhotoReferences = didRemoveUnavailablePhotoReferences
    }
}

enum ManualBackupResult: Equatable, Sendable {
    case published(CloudBackupPublicationResult)
    case requiresAccountConfirmation(ManualAccountBackupProposal)
    case requiresCellularConfirmation(ManualCellularBackupProposal)
    case requiresUnavailablePhotoDecision(ManualUnavailablePhotoBackupProposal)
    case busy
    case deferred(BackupDeferralReason)
    case deferredAfterPhotoRemoval(BackupDeferralReason)
    case invalidCellularApproval
    case failed(CloudBackupErrorCategory)
    case failedAfterPhotoRemoval(CloudBackupErrorCategory)
}

enum CloudBackupDeletionResult: Equatable, Sendable {
    case deleted
    case busy
    case failed(CloudBackupErrorCategory)
}

protocol BackupConnectivityChecking: Sendable {
    func currentConnection() async -> BackupConnection
}

protocol BackupAccountChecking: Sendable {
    func currentAvailability() async -> BackupAccountAvailability
    func currentFingerprint() async -> String?
}

extension BackupAccountChecking {
    func currentFingerprint() async -> String? { nil }
}

protocol BackupPublicationAuthorizing: Sendable {
    func isPublicationAuthorized() async -> Bool
    func authorizePublication(for accountFingerprint: String) async -> Bool
}

extension BackupPublicationAuthorizing {
    func authorizePublication(for accountFingerprint: String) async -> Bool { false }
}

protocol CloudBackupDeleting: Sendable {
    func deleteAllBackupData() async throws
}

protocol BackupPowerChecking: Sendable {
    func hasEligiblePowerState() async -> Bool
}

protocol BackupStorageChecking: Sendable {
    func hasSufficientWorkingStorage(estimatedUploadByteCount: Int64?) async -> Bool
}

protocol BackupBackgroundScheduling: Sendable {
    @discardableResult
    func schedule(earliestBeginDate: Date) async -> Bool
}

protocol BackupSnapshotPackageCleaning: Sendable {
    func removePackage(generationID: String) async
    func removeAllPackages() async
}

protocol CloudBackupPublishing: Sendable {
    func estimatedUploadByteCount(for package: AppSnapshotPackage) async throws -> Int64
    func publish(
        _ package: AppSnapshotPackage,
        transferPolicy: CloudBackupTransferPolicy,
        publicationGate: @escaping @Sendable () async -> Bool,
        stageHandler: @escaping @Sendable (CloudBackupPublicationStage) async -> Void
    ) async throws -> CloudBackupPublicationResult
}

extension CloudBackupPublisher: CloudBackupPublishing {
    func estimatedUploadByteCount(for package: AppSnapshotPackage) throws -> Int64 {
        try CloudBackupGenerationPlan.make(package: package).uploadByteCount
    }
}

actor BackupCoordinator {
    private enum ActiveOperation {
        case automatic
        case preparingManual
        case awaitingManualCellularApproval
        case awaitingManualAccountApproval
        case awaitingManualUnavailablePhotoDecision
        case publishingManual
        case cancellingManual
        case deletingCloudBackup
    }

    private struct PreparedManualBackup {
        let proposal: ManualCellularBackupProposal
        let package: AppSnapshotPackage
        let didRemoveUnavailablePhotoReferences: Bool
    }

    private let snapshotCreator: any RecoverableAppSnapshotCreating
    private let publisher: any CloudBackupPublishing
    private let scheduleStore: any BackupScheduleStoring
    private let omissionStore: any BackupAssetOmissionStoring
    private let unavailablePhotoRevalidator: any BackupUnavailablePhotoRevalidating
    private let unavailableAssetRemover: any BackupUnavailableAssetRemoving
    private let connectivity: any BackupConnectivityChecking
    private let account: any BackupAccountChecking
    private let publicationAuthorization: any BackupPublicationAuthorizing
    private let power: any BackupPowerChecking
    private let storage: any BackupStorageChecking
    private let backgroundScheduler: any BackupBackgroundScheduling
    private let packageCleaner: any BackupSnapshotPackageCleaning
    private let deleter: (any CloudBackupDeleting)?
    private let schedulePolicy: BackupSchedulePolicy
    private let now: @Sendable () -> Date
    private let makeProposalID: @Sendable () -> String

    private var activeOperation: ActiveOperation?
    private var isRestoreSessionActive = false
    private var activePublicationStage: CloudBackupPublicationStage?
    private var didRecoverStaging = false
    private var preparedManualBackup: PreparedManualBackup?
    private var pendingAccountProposal: ManualAccountBackupProposal?
    private var pendingUnavailablePhotoProposal: ManualUnavailablePhotoBackupProposal?

    init(
        snapshotCreator: any RecoverableAppSnapshotCreating,
        publisher: any CloudBackupPublishing,
        scheduleStore: any BackupScheduleStoring,
        omissionStore: any BackupAssetOmissionStoring,
        unavailablePhotoRevalidator: any BackupUnavailablePhotoRevalidating,
        unavailableAssetRemover: any BackupUnavailableAssetRemoving,
        connectivity: any BackupConnectivityChecking,
        account: any BackupAccountChecking,
        publicationAuthorization: any BackupPublicationAuthorizing,
        power: any BackupPowerChecking,
        storage: any BackupStorageChecking,
        backgroundScheduler: any BackupBackgroundScheduling,
        packageCleaner: any BackupSnapshotPackageCleaning,
        deleter: (any CloudBackupDeleting)? = nil,
        schedulePolicy: BackupSchedulePolicy = BackupSchedulePolicy(),
        now: @escaping @Sendable () -> Date = { Date() },
        makeProposalID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.snapshotCreator = snapshotCreator
        self.publisher = publisher
        self.scheduleStore = scheduleStore
        self.omissionStore = omissionStore
        self.unavailablePhotoRevalidator = unavailablePhotoRevalidator
        self.unavailableAssetRemover = unavailableAssetRemover
        self.connectivity = connectivity
        self.account = account
        self.publicationAuthorization = publicationAuthorization
        self.power = power
        self.storage = storage
        self.backgroundScheduler = backgroundScheduler
        self.packageCleaner = packageCleaner
        self.deleter = deleter
        self.schedulePolicy = schedulePolicy
        self.now = now
        self.makeProposalID = makeProposalID
    }

    func startAndCatchUp() async -> AutomaticBackupResult {
        return await requestAutomaticBackup(trigger: .launchCatchUp)
    }

    func requestAutomaticBackup(
        trigger _: AutomaticBackupTrigger
    ) async -> AutomaticBackupResult {
        guard activeOperation == nil, !isRestoreSessionActive else { return .coalesced }
        activeOperation = .automatic
        await recoverInterruptedOperationIfNeeded()

        let date = now()
        var metadata = schedulePolicy.reconcilingClock(in: scheduleStore.load(), now: date)
        scheduleStore.save(metadata)
        guard metadata.isEnabled else {
            finishOperation()
            return .deferred(.disabled)
        }
        guard schedulePolicy.isAutomaticBackupDue(metadata, at: date) else {
            await scheduleNextAttempt(from: metadata, fallbackDate: date)
            finishOperation()
            return .notDue
        }

        if let reason = await automaticDeferralReason() {
            metadata = recordDeferral(in: metadata, at: date)
            scheduleStore.save(metadata)
            await scheduleNextAttempt(from: metadata, fallbackDate: date)
            finishOperation()
            return .deferred(reason)
        }

        metadata.lastAttemptAt = date
        scheduleStore.save(metadata)
        return await createAndPublishAutomaticBackup(startedAt: date)
    }

    func prepareManualBackup() async -> ManualBackupResult {
        guard activeOperation == nil, !isRestoreSessionActive else { return .busy }
        activeOperation = .preparingManual
        await recoverInterruptedOperationIfNeeded()

        let date = now()
        var metadata = schedulePolicy.reconcilingClock(in: scheduleStore.load(), now: date)
        scheduleStore.save(metadata)
        guard metadata.isEnabled else {
            finishOperation()
            return .deferred(.disabled)
        }

        let environment = await currentEnvironment(
            estimatedUploadByteCount: metadata.estimatedUploadByteCount
        )
        if !environment.isPublicationAuthorized,
           environment.account == .available,
           let fingerprint = await account.currentFingerprint() {
            let proposal = ManualAccountBackupProposal(
                id: makeProposalID(),
                accountFingerprint: fingerprint
            )
            pendingAccountProposal = proposal
            activeOperation = .awaitingManualAccountApproval
            return .requiresAccountConfirmation(proposal)
        }
        if let reason = manualDeferralReason(for: environment) {
            finishOperation()
            return .deferred(reason)
        }

        metadata.lastAttemptAt = date
        scheduleStore.save(metadata)

        return await createManualSnapshotAndContinue(
            connection: environment.connection,
            startedAt: date,
            didRemoveUnavailablePhotoReferences: false
        )
    }

    func confirmManualAccountBackup(proposalID: String) async -> ManualBackupResult {
        guard case .awaitingManualAccountApproval = activeOperation,
              let proposal = pendingAccountProposal,
              proposal.id == proposalID else {
            return .deferred(.accountConfirmationRequired)
        }
        guard await account.currentFingerprint() == proposal.accountFingerprint,
              await publicationAuthorization.authorizePublication(
                for: proposal.accountFingerprint
              ) else {
            pendingAccountProposal = nil
            finishOperation()
            return .deferred(.accountConfirmationRequired)
        }
        pendingAccountProposal = nil
        finishOperation()
        return await prepareManualBackup()
    }

    func cancelManualAccountBackup(proposalID: String) {
        guard case .awaitingManualAccountApproval = activeOperation,
              pendingAccountProposal?.id == proposalID else { return }
        pendingAccountProposal = nil
        finishOperation()
    }

    func approveManualUnavailablePhotoOmissions(
        proposalID: String
    ) async -> ManualBackupResult {
        guard case .awaitingManualUnavailablePhotoDecision = activeOperation,
              let proposal = pendingUnavailablePhotoProposal,
              proposal.id == proposalID else {
            return .failed(.photoUnavailable)
        }
        omissionStore.approve(
            sourceReferences: Set(proposal.assets.map(\.sourceReference))
        )
        return await retryManualBackup(
            after: proposal,
            didRemoveUnavailablePhotoReferences:
                proposal.didRemoveUnavailablePhotoReferences
        )
    }

    func removeManualUnavailablePhotos(
        proposalID: String
    ) async -> ManualBackupResult {
        guard case .awaitingManualUnavailablePhotoDecision = activeOperation,
              let proposal = pendingUnavailablePhotoProposal,
              proposal.id == proposalID else {
            return .failed(.photoUnavailable)
        }
        pendingUnavailablePhotoProposal = nil
        activeOperation = .preparingManual
        let didRemoveUnavailablePhotoReferences: Bool
        do {
            let confirmedReferences =
                try await unavailablePhotoRevalidator.confirmedUnavailableReferences(
                    among: Set(proposal.assets.map(\.sourceReference))
                )
            if !confirmedReferences.isEmpty {
                try unavailableAssetRemover.removeUnavailablePhotoReferences(
                    confirmedReferences
                )
            }
            didRemoveUnavailablePhotoReferences =
                proposal.didRemoveUnavailablePhotoReferences
                || !confirmedReferences.isEmpty
        } catch {
            return await finishManualFailure(
                error,
                startedAt: proposal.startedAt,
                didRemoveUnavailablePhotoReferences:
                    proposal.didRemoveUnavailablePhotoReferences
            )
        }
        return await retryManualBackup(
            after: proposal,
            didRemoveUnavailablePhotoReferences:
                didRemoveUnavailablePhotoReferences
        )
    }

    func cancelManualUnavailablePhotoDecision(proposalID: String) {
        guard case .awaitingManualUnavailablePhotoDecision = activeOperation,
              pendingUnavailablePhotoProposal?.id == proposalID else { return }
        pendingUnavailablePhotoProposal = nil
        finishOperation()
    }

    func deleteCloudBackup() async -> CloudBackupDeletionResult {
        guard activeOperation == nil, !isRestoreSessionActive else { return .busy }
        guard let deleter else { return .failed(.unknown) }
        activeOperation = .deletingCloudBackup
        var deletionMetadata = scheduleStore.load()
        deletionMetadata.isEnabled = false
        deletionMetadata.deletionNeedsRetryCategory = CloudBackupErrorCategory.unknown.rawValue
        scheduleStore.save(deletionMetadata)
        do {
            try await deleter.deleteAllBackupData()
            var metadata = scheduleStore.load()
            metadata.isEnabled = false
            metadata.lastSuccessAt = nil
            metadata.nextEligibleAt = nil
            metadata.isOverdue = false
            metadata.activeGenerationID = nil
            metadata.retryCount = 0
            metadata.estimatedUploadByteCount = nil
            metadata.lastFailureCategory = nil
            metadata.deletionNeedsRetryCategory = nil
            metadata.lastSuccessfulOmittedAssetCount = nil
            scheduleStore.save(metadata)
            finishOperation()
            return .deleted
        } catch {
            let category = errorCategory(for: error)
            var metadata = scheduleStore.load()
            metadata.deletionNeedsRetryCategory = category.rawValue
            scheduleStore.save(metadata)
            finishOperation()
            return .failed(category)
        }
    }

    func confirmManualCellularBackup(
        proposalID: String,
        displayedByteCount: Int64
    ) async -> ManualBackupResult {
        guard case .awaitingManualCellularApproval = activeOperation,
              let preparedManualBackup,
              preparedManualBackup.proposal.id == proposalID,
              preparedManualBackup.proposal.estimatedUploadByteCount == displayedByteCount else {
            return .invalidCellularApproval
        }
        activeOperation = .publishingManual

        let environment = await currentEnvironment(
            estimatedUploadByteCount: scheduleStore.load().estimatedUploadByteCount
        )
        if let reason = manualDeferralReason(for: environment) {
            return await finishPreparedManualDeferral(reason)
        }
        return await publishManualPackage(
            preparedManualBackup.package,
            transferPolicy: .cellularAllowed,
            startedAt: now(),
            didRemoveUnavailablePhotoReferences:
                preparedManualBackup.didRemoveUnavailablePhotoReferences
        )
    }

    func cancelManualCellularBackup(proposalID: String) async {
        guard case .awaitingManualCellularApproval = activeOperation,
              let preparedManualBackup,
              preparedManualBackup.proposal.id == proposalID else { return }
        activeOperation = .cancellingManual
        await packageCleaner.removePackage(generationID: preparedManualBackup.package.generationID)
        self.preparedManualBackup = nil
        clearActiveOperationMetadata()
        finishOperation()
        await scheduleNextAttempt(from: scheduleStore.load(), fallbackDate: now())
    }

    func currentScheduleMetadata() -> BackupScheduleMetadata {
        scheduleStore.load()
    }

    func beginRestoreSession() -> Bool {
        guard activeOperation == nil, !isRestoreSessionActive else { return false }
        isRestoreSessionActive = true
        return true
    }

    func endRestoreSession() {
        isRestoreSessionActive = false
    }

    func currentSettings(
        areNotificationsEnabled: Bool
    ) async -> CloudBackupSettingsSnapshot {
        let metadata = scheduleStore.load()
        let accountAvailability = await account.currentAvailability()
        let connection = await connectivity.currentConnection()
        let state = settingsState(
            metadata: metadata,
            accountAvailability: accountAvailability,
            connection: connection
        )
        return CloudBackupSettingsSnapshot(
            isEnabled: metadata.isEnabled,
            areNotificationsEnabled: areNotificationsEnabled,
            accountAvailability: accountAvailability,
            state: state,
            lastSuccessAt: metadata.lastSuccessAt,
            estimatedUploadByteCount: metadata.estimatedUploadByteCount,
            omittedAssetCount: metadata.lastSuccessfulOmittedAssetCount ?? 0
        )
    }

    func setBackupEnabled(_ isEnabled: Bool) async {
        if case .deletingCloudBackup? = activeOperation { return }
        var metadata = scheduleStore.load()
        guard metadata.isEnabled != isEnabled else { return }
        metadata.isEnabled = isEnabled
        if isEnabled {
            metadata.deletionNeedsRetryCategory = nil
            metadata.isOverdue = true
            metadata.nextEligibleAt = now()
        } else if case .awaitingManualAccountApproval = activeOperation {
            pendingAccountProposal = nil
            finishOperation()
        } else if case .awaitingManualUnavailablePhotoDecision = activeOperation {
            pendingUnavailablePhotoProposal = nil
            finishOperation()
        } else if case .awaitingManualCellularApproval = activeOperation,
                  let preparedManualBackup {
            activeOperation = .cancellingManual
            self.preparedManualBackup = nil
            metadata.activeGenerationID = nil
            scheduleStore.save(metadata)
            await packageCleaner.removePackage(
                generationID: preparedManualBackup.package.generationID
            )
            finishOperation()
            return
        }
        scheduleStore.save(metadata)
        if isEnabled {
            await scheduleNextAttempt(from: metadata, fallbackDate: now())
        }
    }

    private func createAndPublishAutomaticBackup(startedAt: Date) async -> AutomaticBackupResult {
        var package: AppSnapshotPackage?
        do {
            let createdPackage = try await createSnapshotUsingApprovedOmissions()
            package = createdPackage
            try Task.checkCancellation()
            let byteCount = try await publisher.estimatedUploadByteCount(for: createdPackage)

            var metadata = scheduleStore.load()
            metadata.activeGenerationID = createdPackage.generationID
            metadata.estimatedUploadByteCount = byteCount
            scheduleStore.save(metadata)

            guard await connectivity.currentConnection() == .wifi else {
                throw BackupCoordinatorError.wifiBecameUnavailable
            }
            guard scheduleStore.load().isEnabled else {
                throw BackupCoordinatorError.backupDisabled
            }
            let result = try await publisher.publish(
                createdPackage,
                transferPolicy: .wifiOnly,
                publicationGate: { [weak self] in
                    await self?.isPublicationEnabled() ?? false
                },
                stageHandler: { [weak self] stage in
                    await self?.setPublicationStage(stage)
                }
            )
            await packageCleaner.removePackage(generationID: createdPackage.generationID)
            recordSuccess(
                at: now(),
                estimatedUploadByteCount: byteCount,
                omittedAssetCount: createdPackage.manifest.omittedAssetCount
            )
            finishOperation()
            await scheduleNextAttempt(from: scheduleStore.load(), fallbackDate: startedAt)
            return .published(result)
        } catch {
            if let package {
                await packageCleaner.removePackage(generationID: package.generationID)
            }
            let category = errorCategory(for: error)
            recordFailure(at: now(), category: category)
            finishOperation()
            await scheduleNextAttempt(from: scheduleStore.load(), fallbackDate: startedAt)
            return .failed(category)
        }
    }

    private func publishManualPackage(
        _ package: AppSnapshotPackage,
        transferPolicy: CloudBackupTransferPolicy,
        startedAt: Date,
        didRemoveUnavailablePhotoReferences: Bool
    ) async -> ManualBackupResult {
        do {
            try Task.checkCancellation()
            guard scheduleStore.load().isEnabled else {
                throw BackupCoordinatorError.backupDisabled
            }
            let result = try await publisher.publish(
                package,
                transferPolicy: transferPolicy,
                publicationGate: { [weak self] in
                    await self?.isPublicationEnabled() ?? false
                },
                stageHandler: { [weak self] stage in
                    await self?.setPublicationStage(stage)
                }
            )
            let byteCount = preparedManualBackup?.proposal.estimatedUploadByteCount
                ?? scheduleStore.load().estimatedUploadByteCount
                ?? package.manifest.totalByteCount
            await packageCleaner.removePackage(generationID: package.generationID)
            preparedManualBackup = nil
            recordSuccess(
                at: now(),
                estimatedUploadByteCount: byteCount,
                omittedAssetCount: package.manifest.omittedAssetCount
            )
            finishOperation()
            await scheduleNextAttempt(from: scheduleStore.load(), fallbackDate: startedAt)
            return .published(result)
        } catch {
            await packageCleaner.removePackage(generationID: package.generationID)
            preparedManualBackup = nil
            return await finishManualFailure(
                error,
                startedAt: startedAt,
                didRemoveUnavailablePhotoReferences:
                    didRemoveUnavailablePhotoReferences
            )
        }
    }

    private func finishManualFailure(
        _ error: Error,
        startedAt: Date,
        didRemoveUnavailablePhotoReferences: Bool = false
    ) async -> ManualBackupResult {
        let category = errorCategory(for: error)
        recordFailure(at: now(), category: category)
        finishOperation()
        await scheduleNextAttempt(from: scheduleStore.load(), fallbackDate: startedAt)
        return didRemoveUnavailablePhotoReferences
            ? .failedAfterPhotoRemoval(category)
            : .failed(category)
    }

    private func createManualSnapshotAndContinue(
        connection: BackupConnection,
        startedAt: Date,
        didRemoveUnavailablePhotoReferences: Bool
    ) async -> ManualBackupResult {
        var package: AppSnapshotPackage?
        do {
            let createdPackage = try await createSnapshotUsingApprovedOmissions()
            package = createdPackage
            try Task.checkCancellation()
            let byteCount = try await publisher.estimatedUploadByteCount(for: createdPackage)
            var metadata = scheduleStore.load()
            metadata.activeGenerationID = createdPackage.generationID
            metadata.estimatedUploadByteCount = byteCount
            scheduleStore.save(metadata)

            if connection == .cellular {
                let proposal = ManualCellularBackupProposal(
                    id: makeProposalID(),
                    generationID: createdPackage.generationID,
                    estimatedUploadByteCount: byteCount
                )
                preparedManualBackup = PreparedManualBackup(
                    proposal: proposal,
                    package: createdPackage,
                    didRemoveUnavailablePhotoReferences:
                        didRemoveUnavailablePhotoReferences
                )
                activeOperation = .awaitingManualCellularApproval
                return .requiresCellularConfirmation(proposal)
            }

            activeOperation = .publishingManual
            return await publishManualPackage(
                createdPackage,
                transferPolicy: .wifiOnly,
                startedAt: startedAt,
                didRemoveUnavailablePhotoReferences:
                    didRemoveUnavailablePhotoReferences
            )
        } catch let error as BackupUnavailableExternalAssetsError {
            if let package {
                await packageCleaner.removePackage(generationID: package.generationID)
            }
            let proposal = ManualUnavailablePhotoBackupProposal(
                id: makeProposalID(),
                assets: error.assets,
                startedAt: startedAt,
                didRemoveUnavailablePhotoReferences:
                    didRemoveUnavailablePhotoReferences
            )
            pendingUnavailablePhotoProposal = proposal
            activeOperation = .awaitingManualUnavailablePhotoDecision
            return .requiresUnavailablePhotoDecision(proposal)
        } catch {
            if let package {
                await packageCleaner.removePackage(generationID: package.generationID)
            }
            return await finishManualFailure(
                error,
                startedAt: startedAt,
                didRemoveUnavailablePhotoReferences:
                    didRemoveUnavailablePhotoReferences
            )
        }
    }

    private func retryManualBackup(
        after proposal: ManualUnavailablePhotoBackupProposal,
        didRemoveUnavailablePhotoReferences: Bool
    ) async -> ManualBackupResult {
        pendingUnavailablePhotoProposal = nil
        activeOperation = .preparingManual
        let environment = await currentEnvironment(
            estimatedUploadByteCount: scheduleStore.load().estimatedUploadByteCount
        )
        if let reason = manualDeferralReason(for: environment) {
            finishOperation()
            return didRemoveUnavailablePhotoReferences
                ? .deferredAfterPhotoRemoval(reason)
                : .deferred(reason)
        }
        return await createManualSnapshotAndContinue(
            connection: environment.connection,
            startedAt: proposal.startedAt,
            didRemoveUnavailablePhotoReferences:
                didRemoveUnavailablePhotoReferences
        )
    }

    private func createSnapshotUsingApprovedOmissions() async throws -> AppSnapshotPackage {
        try await snapshotCreator.createSnapshot(
            approvedOmissionDigests: omissionStore.loadApprovedDigests()
        )
    }

    private func finishPreparedManualDeferral(
        _ reason: BackupDeferralReason
    ) async -> ManualBackupResult {
        let didRemoveUnavailablePhotoReferences =
            preparedManualBackup?.didRemoveUnavailablePhotoReferences ?? false
        if let preparedManualBackup {
            await packageCleaner.removePackage(generationID: preparedManualBackup.package.generationID)
        }
        preparedManualBackup = nil
        var metadata = scheduleStore.load()
        metadata = recordDeferral(in: metadata, at: now())
        metadata.activeGenerationID = nil
        scheduleStore.save(metadata)
        finishOperation()
        await scheduleNextAttempt(from: metadata, fallbackDate: now())
        return didRemoveUnavailablePhotoReferences
            ? .deferredAfterPhotoRemoval(reason)
            : .deferred(reason)
    }

    private func recoverInterruptedOperationIfNeeded() async {
        guard !didRecoverStaging else { return }
        didRecoverStaging = true
        await packageCleaner.removeAllPackages()

        var metadata = schedulePolicy.reconcilingClock(in: scheduleStore.load(), now: now())
        guard metadata.activeGenerationID != nil else {
            scheduleStore.save(metadata)
            return
        }
        metadata.activeGenerationID = nil
        metadata.isOverdue = true
        metadata.retryCount = incrementedRetryCount(metadata.retryCount)
        metadata.nextEligibleAt = now()
        scheduleStore.save(metadata)
    }

    private func currentEnvironment(
        estimatedUploadByteCount: Int64?
    ) async -> (
        connection: BackupConnection,
        account: BackupAccountAvailability,
        hasEligiblePower: Bool,
        hasSufficientStorage: Bool,
        isPublicationAuthorized: Bool
    ) {
        async let connection = connectivity.currentConnection()
        async let accountAvailability = account.currentAvailability()
        async let hasEligiblePower = power.hasEligiblePowerState()
        async let hasSufficientStorage = storage.hasSufficientWorkingStorage(
            estimatedUploadByteCount: estimatedUploadByteCount
        )
        async let isPublicationAuthorized = publicationAuthorization.isPublicationAuthorized()
        return await (
            connection,
            accountAvailability,
            hasEligiblePower,
            hasSufficientStorage,
            isPublicationAuthorized
        )
    }

    private func automaticDeferralReason() async -> BackupDeferralReason? {
        let environment = await currentEnvironment(
            estimatedUploadByteCount: scheduleStore.load().estimatedUploadByteCount
        )
        guard environment.account == .available else { return .iCloudUnavailable }
        guard environment.isPublicationAuthorized else { return .accountConfirmationRequired }
        guard environment.hasEligiblePower else { return .powerRestricted }
        guard environment.hasSufficientStorage else { return .insufficientStorage }
        switch environment.connection {
        case .wifi: return nil
        case .cellular: return .waitingForWiFi
        case .unavailable: return .networkUnavailable
        }
    }

    private func manualDeferralReason(
        for environment: (
            connection: BackupConnection,
            account: BackupAccountAvailability,
            hasEligiblePower: Bool,
            hasSufficientStorage: Bool,
            isPublicationAuthorized: Bool
        )
    ) -> BackupDeferralReason? {
        guard environment.account == .available else { return .iCloudUnavailable }
        guard environment.isPublicationAuthorized else { return .accountConfirmationRequired }
        guard environment.hasEligiblePower else { return .powerRestricted }
        guard environment.hasSufficientStorage else { return .insufficientStorage }
        return environment.connection == .unavailable ? .networkUnavailable : nil
    }

    private func recordSuccess(
        at date: Date,
        estimatedUploadByteCount: Int64,
        omittedAssetCount: Int
    ) {
        var metadata = scheduleStore.load()
        metadata.lastSuccessAt = date
        metadata.nextEligibleAt = schedulePolicy.nextNight(after: date)
        metadata.isOverdue = false
        metadata.activeGenerationID = nil
        metadata.retryCount = 0
        metadata.estimatedUploadByteCount = estimatedUploadByteCount
        metadata.lastFailureCategory = nil
        metadata.lastSuccessfulOmittedAssetCount = omittedAssetCount
        scheduleStore.save(metadata)
    }

    private func recordFailure(at date: Date, category: CloudBackupErrorCategory) {
        var metadata = scheduleStore.load()
        metadata.activeGenerationID = nil
        metadata.isOverdue = true
        metadata.retryCount = incrementedRetryCount(metadata.retryCount)
        metadata.nextEligibleAt = schedulePolicy.retryDate(after: date, retryCount: metadata.retryCount)
        metadata.lastFailureCategory = category.rawValue
        scheduleStore.save(metadata)
    }

    private func settingsState(
        metadata: BackupScheduleMetadata,
        accountAvailability: BackupAccountAvailability,
        connection: BackupConnection
    ) -> CloudBackupSettingsState {
        switch activeOperation {
        case .preparingManual:
            return .preparing
        case .automatic where activePublicationStage == nil:
            return .preparing
        case .automatic, .publishingManual:
            return activePublicationStage == .verifying ? .verifying : .uploading
        case .cancellingManual:
            return .uploading
        case .awaitingManualCellularApproval:
            return .awaitingCellularConfirmation
        case .awaitingManualAccountApproval:
            return .awaitingAccountConfirmation
        case .awaitingManualUnavailablePhotoDecision:
            return .awaitingUnavailablePhotoDecision
        case .deletingCloudBackup:
            return .deleting
        case nil:
            break
        }
        if let rawCategory = metadata.deletionNeedsRetryCategory {
            return .deletionNeedsRetry(CloudBackupErrorCategory(rawValue: rawCategory))
        }
        guard metadata.isEnabled else { return .disabled }
        guard accountAvailability == .available else { return .unavailable }
        if metadata.isOverdue, connection == .cellular {
            return .waitingForWiFi
        }
        if let rawCategory = metadata.lastFailureCategory,
           let category = CloudBackupErrorCategory(rawValue: rawCategory) {
            return .failed(category)
        }
        return metadata.lastSuccessAt == nil ? .enabled : .successful
    }

    private func recordDeferral(
        in metadata: BackupScheduleMetadata,
        at date: Date
    ) -> BackupScheduleMetadata {
        var updated = metadata
        updated.isOverdue = true
        updated.retryCount = incrementedRetryCount(updated.retryCount)
        updated.nextEligibleAt = schedulePolicy.retryDate(after: date, retryCount: updated.retryCount)
        return updated
    }

    private func clearActiveOperationMetadata() {
        var metadata = scheduleStore.load()
        metadata.activeGenerationID = nil
        scheduleStore.save(metadata)
    }

    private func finishOperation() {
        activeOperation = nil
        activePublicationStage = nil
    }

    private func setPublicationStage(_ stage: CloudBackupPublicationStage) {
        activePublicationStage = stage
    }

    private func isPublicationEnabled() async -> Bool {
        guard scheduleStore.load().isEnabled else { return false }
        return await publicationAuthorization.isPublicationAuthorized()
    }

    private func scheduleNextAttempt(
        from metadata: BackupScheduleMetadata,
        fallbackDate: Date
    ) async {
        guard metadata.isEnabled else { return }
        let earliestDate = metadata.nextEligibleAt ?? fallbackDate
        _ = await backgroundScheduler.schedule(earliestBeginDate: earliestDate)
    }

    private func errorCategory(for error: Error) -> CloudBackupErrorCategory {
        if error is CancellationError { return .cancelled }
        if let error = error as? BackupCoordinatorError {
            return error == .backupDisabled ? .cancelled : .networkUnavailable
        }
        if error as? CloudBackupPublicationError == .publicationNotAuthorized {
            return .cancelled
        }
        if let error = error as? CloudBackupStoreError { return error.category }
        if error is BackupUnavailableExternalAssetsError { return .photoUnavailable }
        if let error = error as? BackupExternalAssetResolverError {
            switch error {
            case .accessDenied:
                return .photosPermissionDenied
            case .assetUnavailable:
                return .photoUnavailable
            case .assetChangedDuringRead, .imageUnavailable:
                return .temporarilyUnavailable
            case .invalidReference, .missingVersionMetadata, .imageEncodingFailed:
                return .unknown
            }
        }
        return .unknown
    }

    private func incrementedRetryCount(_ retryCount: Int) -> Int {
        retryCount == Int.max ? Int.max : retryCount + 1
    }
}

private enum BackupCoordinatorError: Error, Equatable {
    case wifiBecameUnavailable
    case backupDisabled
}
