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

enum BackupDeferralReason: Equatable, Sendable {
    case disabled
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

enum ManualBackupResult: Equatable, Sendable {
    case published(CloudBackupPublicationResult)
    case requiresCellularConfirmation(ManualCellularBackupProposal)
    case busy
    case deferred(BackupDeferralReason)
    case invalidCellularApproval
    case failed(CloudBackupErrorCategory)
}

protocol BackupConnectivityChecking: Sendable {
    func currentConnection() async -> BackupConnection
}

protocol BackupAccountChecking: Sendable {
    func currentAvailability() async -> BackupAccountAvailability
}

protocol BackupPowerChecking: Sendable {
    func hasEligiblePowerState() async -> Bool
}

protocol BackupStorageChecking: Sendable {
    func hasSufficientWorkingStorage() async -> Bool
}

protocol BackupBackgroundScheduling: Sendable {
    @discardableResult
    func schedule(earliestBeginDate: Date) async -> Bool
}

protocol BackupSnapshotPackageCleaning: Sendable {
    func removePackage(generationID: String) async
}

protocol CloudBackupPublishing: Sendable {
    func estimatedUploadByteCount(for package: AppSnapshotPackage) async throws -> Int64
    func publish(
        _ package: AppSnapshotPackage,
        transferPolicy: CloudBackupTransferPolicy
    ) async throws -> CloudBackupPublicationResult
}

extension CloudBackupPublisher: CloudBackupPublishing {
    func estimatedUploadByteCount(for package: AppSnapshotPackage) throws -> Int64 {
        try CloudBackupGenerationPlan.make(package: package).uploadByteCount
    }
}

actor BackupCoordinator {
    private struct PreparedManualBackup {
        let proposal: ManualCellularBackupProposal
        let package: AppSnapshotPackage
    }

    private let snapshotCreator: any AppSnapshotCreating
    private let publisher: any CloudBackupPublishing
    private let scheduleStore: any BackupScheduleStoring
    private let connectivity: any BackupConnectivityChecking
    private let account: any BackupAccountChecking
    private let power: any BackupPowerChecking
    private let storage: any BackupStorageChecking
    private let backgroundScheduler: any BackupBackgroundScheduling
    private let packageCleaner: any BackupSnapshotPackageCleaning
    private let schedulePolicy: BackupSchedulePolicy
    private let now: @Sendable () -> Date
    private let makeProposalID: @Sendable () -> String

    private var isOperationActive = false
    private var preparedManualBackup: PreparedManualBackup?

    init(
        snapshotCreator: any AppSnapshotCreating,
        publisher: any CloudBackupPublishing,
        scheduleStore: any BackupScheduleStoring,
        connectivity: any BackupConnectivityChecking,
        account: any BackupAccountChecking,
        power: any BackupPowerChecking,
        storage: any BackupStorageChecking,
        backgroundScheduler: any BackupBackgroundScheduling,
        packageCleaner: any BackupSnapshotPackageCleaning,
        schedulePolicy: BackupSchedulePolicy = BackupSchedulePolicy(),
        now: @escaping @Sendable () -> Date = { Date() },
        makeProposalID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.snapshotCreator = snapshotCreator
        self.publisher = publisher
        self.scheduleStore = scheduleStore
        self.connectivity = connectivity
        self.account = account
        self.power = power
        self.storage = storage
        self.backgroundScheduler = backgroundScheduler
        self.packageCleaner = packageCleaner
        self.schedulePolicy = schedulePolicy
        self.now = now
        self.makeProposalID = makeProposalID
    }

    func startAndCatchUp() async -> AutomaticBackupResult {
        await recoverInterruptedOperationIfNeeded()
        return await requestAutomaticBackup(trigger: .launchCatchUp)
    }

    func requestAutomaticBackup(
        trigger _: AutomaticBackupTrigger
    ) async -> AutomaticBackupResult {
        if isOperationActive {
            return .coalesced
        }

        let date = now()
        var metadata = schedulePolicy.reconcilingClock(in: scheduleStore.load(), now: date)
        scheduleStore.save(metadata)
        guard metadata.isEnabled else {
            return .deferred(.disabled)
        }
        guard schedulePolicy.isAutomaticBackupDue(metadata, at: date) else {
            await scheduleNextAttempt(from: metadata, fallbackDate: date)
            return .notDue
        }

        if let reason = await automaticDeferralReason() {
            metadata = recordDeferral(in: metadata, at: date)
            scheduleStore.save(metadata)
            await scheduleNextAttempt(from: metadata, fallbackDate: date)
            return .deferred(reason)
        }

        isOperationActive = true
        metadata.lastAttemptAt = date
        scheduleStore.save(metadata)
        return await createAndPublishAutomaticBackup(startedAt: date)
    }

    func prepareManualBackup() async -> ManualBackupResult {
        guard !isOperationActive else { return .busy }

        let date = now()
        var metadata = schedulePolicy.reconcilingClock(in: scheduleStore.load(), now: date)
        scheduleStore.save(metadata)
        guard metadata.isEnabled else { return .deferred(.disabled) }

        let environment = await currentEnvironment()
        if let reason = manualDeferralReason(for: environment) {
            return .deferred(reason)
        }

        isOperationActive = true
        metadata.lastAttemptAt = date
        scheduleStore.save(metadata)

        var package: AppSnapshotPackage?
        do {
            let createdPackage = try await snapshotCreator.createSnapshot()
            package = createdPackage
            try Task.checkCancellation()
            let byteCount = try await publisher.estimatedUploadByteCount(for: createdPackage)
            metadata = scheduleStore.load()
            metadata.activeGenerationID = createdPackage.generationID
            metadata.estimatedUploadByteCount = byteCount
            scheduleStore.save(metadata)

            if environment.connection == .cellular {
                let proposal = ManualCellularBackupProposal(
                    id: makeProposalID(),
                    generationID: createdPackage.generationID,
                    estimatedUploadByteCount: byteCount
                )
                preparedManualBackup = PreparedManualBackup(
                    proposal: proposal,
                    package: createdPackage
                )
                return .requiresCellularConfirmation(proposal)
            }

            return await publishManualPackage(
                createdPackage,
                transferPolicy: .wifiOnly,
                startedAt: date
            )
        } catch {
            if let package {
                await packageCleaner.removePackage(generationID: package.generationID)
            }
            return await finishManualFailure(error, startedAt: date)
        }
    }

    func confirmManualCellularBackup(
        proposalID: String,
        displayedByteCount: Int64
    ) async -> ManualBackupResult {
        guard let preparedManualBackup,
              preparedManualBackup.proposal.id == proposalID,
              preparedManualBackup.proposal.estimatedUploadByteCount == displayedByteCount else {
            return .invalidCellularApproval
        }

        let environment = await currentEnvironment()
        if let reason = manualDeferralReason(for: environment) {
            return await finishPreparedManualDeferral(reason)
        }
        return await publishManualPackage(
            preparedManualBackup.package,
            transferPolicy: .cellularAllowed,
            startedAt: now()
        )
    }

    func cancelManualCellularBackup(proposalID: String) async {
        guard let preparedManualBackup,
              preparedManualBackup.proposal.id == proposalID else { return }
        await packageCleaner.removePackage(generationID: preparedManualBackup.package.generationID)
        self.preparedManualBackup = nil
        clearActiveOperationMetadata()
        finishOperation()
        await scheduleNextAttempt(from: scheduleStore.load(), fallbackDate: now())
    }

    func currentScheduleMetadata() -> BackupScheduleMetadata {
        scheduleStore.load()
    }

    private func createAndPublishAutomaticBackup(startedAt: Date) async -> AutomaticBackupResult {
        var package: AppSnapshotPackage?
        do {
            let createdPackage = try await snapshotCreator.createSnapshot()
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
            let result = try await publisher.publish(
                createdPackage,
                transferPolicy: .wifiOnly
            )
            await packageCleaner.removePackage(generationID: createdPackage.generationID)
            recordSuccess(at: now(), estimatedUploadByteCount: byteCount)
            finishOperation()
            await scheduleNextAttempt(from: scheduleStore.load(), fallbackDate: startedAt)
            return .published(result)
        } catch {
            if let package {
                await packageCleaner.removePackage(generationID: package.generationID)
            }
            recordFailure(at: now())
            finishOperation()
            await scheduleNextAttempt(from: scheduleStore.load(), fallbackDate: startedAt)
            return .failed(errorCategory(for: error))
        }
    }

    private func publishManualPackage(
        _ package: AppSnapshotPackage,
        transferPolicy: CloudBackupTransferPolicy,
        startedAt: Date
    ) async -> ManualBackupResult {
        do {
            try Task.checkCancellation()
            let result = try await publisher.publish(
                package,
                transferPolicy: transferPolicy
            )
            let byteCount = preparedManualBackup?.proposal.estimatedUploadByteCount
                ?? scheduleStore.load().estimatedUploadByteCount
                ?? package.manifest.totalByteCount
            await packageCleaner.removePackage(generationID: package.generationID)
            preparedManualBackup = nil
            recordSuccess(at: now(), estimatedUploadByteCount: byteCount)
            finishOperation()
            await scheduleNextAttempt(from: scheduleStore.load(), fallbackDate: startedAt)
            return .published(result)
        } catch {
            await packageCleaner.removePackage(generationID: package.generationID)
            preparedManualBackup = nil
            return await finishManualFailure(error, startedAt: startedAt)
        }
    }

    private func finishManualFailure(
        _ error: Error,
        startedAt: Date
    ) async -> ManualBackupResult {
        recordFailure(at: now())
        finishOperation()
        await scheduleNextAttempt(from: scheduleStore.load(), fallbackDate: startedAt)
        return .failed(errorCategory(for: error))
    }

    private func finishPreparedManualDeferral(
        _ reason: BackupDeferralReason
    ) async -> ManualBackupResult {
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
        return .deferred(reason)
    }

    private func recoverInterruptedOperationIfNeeded() async {
        var metadata = schedulePolicy.reconcilingClock(in: scheduleStore.load(), now: now())
        guard let generationID = metadata.activeGenerationID else {
            scheduleStore.save(metadata)
            return
        }
        await packageCleaner.removePackage(generationID: generationID)
        metadata.activeGenerationID = nil
        metadata.isOverdue = true
        metadata.retryCount = incrementedRetryCount(metadata.retryCount)
        metadata.nextEligibleAt = now()
        scheduleStore.save(metadata)
    }

    private func currentEnvironment() async -> (
        connection: BackupConnection,
        account: BackupAccountAvailability,
        hasEligiblePower: Bool,
        hasSufficientStorage: Bool
    ) {
        async let connection = connectivity.currentConnection()
        async let accountAvailability = account.currentAvailability()
        async let hasEligiblePower = power.hasEligiblePowerState()
        async let hasSufficientStorage = storage.hasSufficientWorkingStorage()
        return await (
            connection,
            accountAvailability,
            hasEligiblePower,
            hasSufficientStorage
        )
    }

    private func automaticDeferralReason() async -> BackupDeferralReason? {
        let environment = await currentEnvironment()
        guard environment.account == .available else { return .iCloudUnavailable }
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
            hasSufficientStorage: Bool
        )
    ) -> BackupDeferralReason? {
        guard environment.account == .available else { return .iCloudUnavailable }
        guard environment.hasEligiblePower else { return .powerRestricted }
        guard environment.hasSufficientStorage else { return .insufficientStorage }
        return environment.connection == .unavailable ? .networkUnavailable : nil
    }

    private func recordSuccess(at date: Date, estimatedUploadByteCount: Int64) {
        var metadata = scheduleStore.load()
        metadata.lastSuccessAt = date
        metadata.nextEligibleAt = schedulePolicy.nextNight(after: date)
        metadata.isOverdue = false
        metadata.activeGenerationID = nil
        metadata.retryCount = 0
        metadata.estimatedUploadByteCount = estimatedUploadByteCount
        scheduleStore.save(metadata)
    }

    private func recordFailure(at date: Date) {
        var metadata = scheduleStore.load()
        metadata.activeGenerationID = nil
        metadata.isOverdue = true
        metadata.retryCount = incrementedRetryCount(metadata.retryCount)
        metadata.nextEligibleAt = schedulePolicy.retryDate(after: date, retryCount: metadata.retryCount)
        scheduleStore.save(metadata)
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
        isOperationActive = false
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
        if error is BackupCoordinatorError { return .networkUnavailable }
        if let error = error as? CloudBackupStoreError { return error.category }
        return .unknown
    }

    private func incrementedRetryCount(_ retryCount: Int) -> Int {
        retryCount == Int.max ? Int.max : retryCount + 1
    }
}

private enum BackupCoordinatorError: Error {
    case wifiBecameUnavailable
}
