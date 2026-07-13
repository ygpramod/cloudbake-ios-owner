import BackgroundTasks
import Foundation

final class CloudBackupRuntime: @unchecked Sendable {
    private let coordinator: BackupCoordinator
    private let lock = NSLock()
    private var didStartLaunchCatchUp = false

    init(coordinator: BackupCoordinator) {
        self.coordinator = coordinator
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
            _ = await coordinator.startAndCatchUp()
        }
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
        let coordinator = BackupCoordinator(
            snapshotCreator: snapshotService,
            publisher: publisher,
            scheduleStore: UserDefaultsBackupScheduleStore(),
            connectivity: NetworkBackupConnectivityChecker(),
            account: CloudKitBackupAccountChecker(),
            power: SystemBackupPowerChecker(),
            storage: VolumeBackupStorageChecker(
                volumeURL: applicationSupport,
                appStorageRoot: appStorageRoot
            ),
            backgroundScheduler: SystemBackupBackgroundScheduler(),
            packageCleaner: StagedBackupPackageCleaner(stagingRoot: stagingRoot)
        )
        return CloudBackupRuntime(coordinator: coordinator)
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
            backgroundTask.setTaskCompleted(success: result.completedBackgroundTaskSuccessfully)
        }
        backgroundTask.expirationHandler = {
            operation.cancel()
        }
    }
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
    BackupPowerChecking,
    BackupStorageChecking {
    func currentConnection() async -> BackupConnection { .cellular }
    func currentAvailability() async -> BackupAccountAvailability { .available }
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
        transferPolicy: CloudBackupTransferPolicy
    ) async throws -> CloudBackupPublicationResult {
        fatalError("Automatic backup published on the cellular-only UI test fixture")
    }
}

private struct CellularBackupUITestNoOp: BackupBackgroundScheduling,
    BackupSnapshotPackageCleaning {
    func schedule(earliestBeginDate: Date) async -> Bool { true }
    func removePackage(generationID: String) async {}
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
