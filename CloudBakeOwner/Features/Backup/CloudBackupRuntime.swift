import BackgroundTasks
import Foundation

final class CloudBackupRuntime: CloudBackupSettingsServing, CloudRestoreSettingsServing, @unchecked Sendable {
    private let coordinator: BackupCoordinator
    private let restoreCoordinator: RestoreCoordinator?
    private let notificationPreferences: CloudBackupNotificationPreferences
    private let notificationDispatcher: CloudBackupNotificationDispatcher
    private let lock = NSLock()
    private var didStartLaunchCatchUp = false

    init(
        coordinator: BackupCoordinator,
        restoreCoordinator: RestoreCoordinator? = nil,
        notificationPreferences: CloudBackupNotificationPreferences = CloudBackupNotificationPreferences(),
        notificationSender: (any CloudBackupNotificationSending)? = nil
    ) {
        self.coordinator = coordinator
        self.restoreCoordinator = restoreCoordinator
        self.notificationPreferences = notificationPreferences
        self.notificationDispatcher = CloudBackupNotificationDispatcher(
            sender: notificationSender
                ?? SystemCloudBackupNotificationSender(preferences: notificationPreferences)
        )
    }

    @discardableResult
    func registerBackgroundTask(scheduler: BGTaskScheduler = .shared) -> Bool {
        scheduler.register(
            forTaskWithIdentifier: SystemBackupBackgroundScheduler.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask,
                  let self else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(processingTask)
        }
    }

    func startLaunchCatchUpIfNeeded() {
        let shouldStart = lock.withCloudBackupLock {
            guard !didStartLaunchCatchUp else { return false }
            didStartLaunchCatchUp = true
            return true
        }
        guard shouldStart else { return }

        Task(priority: .utility) { [coordinator] in
            let result = await coordinator.startAndCatchUp()
            await self.notificationDispatcher.send(for: result)
        }
    }

    func currentSettings() async -> CloudBackupSettingsSnapshot {
        await coordinator.currentSettings(
            areNotificationsEnabled: notificationPreferences.isEnabled
        )
    }

    func setBackupEnabled(_ isEnabled: Bool) async -> CloudBackupSettingsSnapshot {
        await coordinator.setBackupEnabled(isEnabled)
        return await currentSettings()
    }

    func setNotificationsEnabled(_ isEnabled: Bool) async -> CloudBackupSettingsSnapshot {
        notificationPreferences.isEnabled = isEnabled
        return await currentSettings()
    }

    func backUpNow() async -> ManualBackupResult {
        let result = await coordinator.prepareManualBackup()
        await notificationDispatcher.send(for: result)
        return result
    }

    func confirmCellularBackup(_ proposal: ManualCellularBackupProposal) async -> ManualBackupResult {
        let result = await coordinator.confirmManualCellularBackup(
            proposalID: proposal.id,
            displayedByteCount: proposal.estimatedUploadByteCount
        )
        await notificationDispatcher.send(for: result)
        return result
    }

    func cancelCellularBackup(_ proposal: ManualCellularBackupProposal) async {
        await coordinator.cancelManualCellularBackup(proposalID: proposal.id)
    }

    func inspectRestore() async -> RestoreResult {
        guard let restoreCoordinator else {
            return .failed(RestoreFailure(category: .iCloudUnavailable, didRollBack: false))
        }
        guard await coordinator.beginRestoreSession() else { return .busy }
        let result = await restoreCoordinator.inspect()
        await releaseRestoreSessionIfTerminal(result)
        return result
    }

    func proceedRestore(proposalID: String, approval: RestoreApproval) async -> RestoreResult {
        guard let restoreCoordinator else {
            return .failed(RestoreFailure(category: .iCloudUnavailable, didRollBack: false))
        }
        let result = await restoreCoordinator.proceed(proposalID: proposalID, approval: approval)
        if result == .completed {
            await MainActor.run {
                NotificationCenter.default.post(name: .cloudBakeRestoreDidComplete, object: nil)
            }
        }
        await releaseRestoreSessionIfTerminal(result)
        return result
    }

    func cancelRestore(proposalID: String) async {
        await restoreCoordinator?.cancel(proposalID: proposalID)
        await coordinator.endRestoreSession()
    }

    static func live(database: AppDatabase) throws -> CloudBackupRuntime {
        let fileManager = FileManager.default
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let caches = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appStorageRoot = applicationSupport.appendingPathComponent(
            "CloudBakeOwner",
            isDirectory: true
        )
        let stagingRoot = caches
            .appendingPathComponent("CloudBakeOwner", isDirectory: true)
            .appendingPathComponent("CloudBackupStaging", isDirectory: true)
        try fileManager.createDirectory(at: appStorageRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)

        let currentVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
        let snapshotService = AppSnapshotService(
            database: database,
            appStorageRoot: appStorageRoot,
            stagingRoot: stagingRoot,
            minimumCompatibleAppVersion: "1.0",
            currentAppVersion: currentVersion
        )
        let cloudStore = CloudKitBackupStore()
        let publisher = CloudBackupPublisher(store: cloudStore)
        let connectivity = NetworkBackupConnectivityChecker()
        let coordinator = BackupCoordinator(
            snapshotCreator: snapshotService,
            publisher: publisher,
            scheduleStore: UserDefaultsBackupScheduleStore(),
            connectivity: connectivity,
            account: CloudKitBackupAccountChecker(),
            publicationAuthorization: PendingCloudBackupAccountProtectionGate(),
            power: SystemBackupPowerChecker(),
            storage: VolumeBackupStorageChecker(
                volumeURL: applicationSupport,
                appStorageRoot: appStorageRoot
            ),
            backgroundScheduler: SystemBackupBackgroundScheduler(),
            packageCleaner: StagedBackupPackageCleaner(stagingRoot: stagingRoot)
        )
        let localRestore = LocalRestoreService(
            database: database,
            snapshotCreator: snapshotService,
            appStorageRoot: appStorageRoot,
            activationRoot: applicationSupport.appendingPathComponent(
                InterruptedRestoreRecovery.directoryName,
                isDirectory: true
            )
        )
        let restoreCoordinator = RestoreCoordinator(
            cloud: cloudStore,
            local: localRestore,
            connectivity: connectivity,
            stagingRoot: caches
                .appendingPathComponent("CloudBakeOwner", isDirectory: true)
                .appendingPathComponent("CloudRestoreStaging", isDirectory: true),
            currentAppVersion: currentVersion
        )
        return CloudBackupRuntime(
            coordinator: coordinator,
            restoreCoordinator: restoreCoordinator
        )
    }

    #if DEBUG
    static func automaticCellularUITestFixture() -> CloudBackupRuntime {
        let environment = CellularBackupUITestEnvironment()
        let coordinator = BackupCoordinator(
            snapshotCreator: CellularBackupUITestTrap(),
            publisher: CellularBackupUITestTrap(),
            scheduleStore: CellularBackupUITestScheduleStore(),
            connectivity: environment,
            account: environment,
            publicationAuthorization: environment,
            power: environment,
            storage: environment,
            backgroundScheduler: CellularBackupUITestNoOp(),
            packageCleaner: CellularBackupUITestNoOp()
        )
        return CloudBackupRuntime(coordinator: coordinator)
    }
    #endif

    private func handle(_ backgroundTask: BGProcessingTask) {
        let operation = Task(priority: .utility) { [coordinator] in
            let result = await coordinator.requestAutomaticBackup(trigger: .background)
            await self.notificationDispatcher.send(for: result)
            backgroundTask.setTaskCompleted(success: result.completedBackgroundTaskSuccessfully)
        }
        backgroundTask.expirationHandler = {
            operation.cancel()
        }
    }

    private func releaseRestoreSessionIfTerminal(_ result: RestoreResult) async {
        switch result {
        case .completed, .noBackup, .invalidApproval, .failed:
            await coordinator.endRestoreSession()
        case .ready, .requiresReplacementConfirmation, .requiresCellularConfirmation,
             .requiresBrokenAssetDecision, .busy:
            break
        }
    }

}

extension Notification.Name {
    static let cloudBakeRestoreDidComplete = Notification.Name("CloudBakeRestoreDidComplete")
}

#if DEBUG
private final class CellularBackupUITestScheduleStore: BackupScheduleStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var metadata = BackupScheduleMetadata.initial

    func load() -> BackupScheduleMetadata {
        lock.withCloudBackupLock { metadata }
    }

    func save(_ metadata: BackupScheduleMetadata) {
        lock.withCloudBackupLock {
            self.metadata = metadata
        }
    }
}

private struct CellularBackupUITestEnvironment: BackupConnectivityChecking,
    BackupAccountChecking,
    BackupPublicationAuthorizing,
    BackupPowerChecking,
    BackupStorageChecking {
    func currentConnection() async -> BackupConnection { .cellular }
    func currentAvailability() async -> BackupAccountAvailability { .available }
    func isPublicationAuthorized() async -> Bool { true }
    func hasEligiblePowerState() async -> Bool { true }
    func hasSufficientWorkingStorage(estimatedUploadByteCount: Int64?) async -> Bool { true }
}

private struct CellularBackupUITestTrap: AppSnapshotCreating, CloudBackupPublishing {
    func createSnapshot() async throws -> AppSnapshotPackage {
        fatalError("Automatic backup started a snapshot on the cellular-only UI test fixture")
    }

    func estimatedUploadByteCount(for package: AppSnapshotPackage) async throws -> Int64 {
        fatalError("Automatic backup estimated an upload on the cellular-only UI test fixture")
    }

    func publish(
        _ package: AppSnapshotPackage,
        transferPolicy: CloudBackupTransferPolicy,
        publicationGate: @escaping @Sendable () async -> Bool,
        stageHandler: @escaping @Sendable (CloudBackupPublicationStage) async -> Void
    ) async throws -> CloudBackupPublicationResult {
        fatalError("Automatic backup published on the cellular-only UI test fixture")
    }
}

private struct CellularBackupUITestNoOp: BackupBackgroundScheduling,
    BackupSnapshotPackageCleaning {
    func schedule(earliestBeginDate: Date) async -> Bool { true }
    func removePackage(generationID: String) async {}
    func removeAllPackages() async {}
}
#endif

private extension AutomaticBackupResult {
    var completedBackgroundTaskSuccessfully: Bool {
        switch self {
        case .published, .notDue, .coalesced, .deferred:
            return true
        case .failed:
            return false
        }
    }
}

private extension NSLock {
    func withCloudBackupLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
