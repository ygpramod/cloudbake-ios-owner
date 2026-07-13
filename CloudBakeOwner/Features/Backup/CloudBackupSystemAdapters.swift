import BackgroundTasks
import CloudKit
import Foundation
import Network
import os

final class NetworkBackupConnectivityChecker: BackupConnectivityChecking, @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let lock = NSLock()
    private var connection = BackupConnection.unavailable

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateConnection(for: path)
        }
        monitor.start(queue: DispatchQueue(label: "com.cloudbake.owner.backup-connectivity"))
    }

    deinit {
        monitor.cancel()
    }

    func currentConnection() async -> BackupConnection {
        lock.withBackupLock { connection }
    }

    private func updateConnection(for path: NWPath) {
        let updatedConnection: BackupConnection
        if path.status != .satisfied {
            updatedConnection = .unavailable
        } else if path.usesInterfaceType(.wifi) {
            updatedConnection = .wifi
        } else if path.usesInterfaceType(.cellular) {
            updatedConnection = .cellular
        } else {
            updatedConnection = .unavailable
        }
        lock.withBackupLock {
            connection = updatedConnection
        }
    }
}

struct CloudKitBackupAccountChecker: BackupAccountChecking {
    let container: CKContainer

    init(container: CKContainer = CKContainer(identifier: CloudKitBackupStore.containerIdentifier)) {
        self.container = container
    }

    func currentAvailability() async -> BackupAccountAvailability {
        do {
            return try await container.accountStatus() == .available ? .available : .unavailable
        } catch {
            return .unavailable
        }
    }
}

struct PendingCloudBackupAccountProtectionGate: BackupPublicationAuthorizing {
    func isPublicationAuthorized() async -> Bool { false }
}

struct SystemBackupPowerChecker: BackupPowerChecking {
    private let processInfo: ProcessInfo

    init(processInfo: ProcessInfo = .processInfo) {
        self.processInfo = processInfo
    }

    func hasEligiblePowerState() async -> Bool {
        Self.isEligible(
            isLowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
            thermalState: processInfo.thermalState
        )
    }

    static func isEligible(
        isLowPowerModeEnabled: Bool,
        thermalState: ProcessInfo.ThermalState
    ) -> Bool {
        guard !isLowPowerModeEnabled else { return false }
        return thermalState == .nominal || thermalState == .fair
    }
}

final class VolumeBackupStorageChecker: BackupStorageChecking, @unchecked Sendable {
    static let minimumWorkingByteCount: Int64 = 256 * 1_024 * 1_024

    private let volumeURL: URL
    private let appStorageRoot: URL
    private let fileManager: FileManager

    init(
        volumeURL: URL,
        appStorageRoot: URL,
        fileManager: FileManager = .default
    ) {
        self.volumeURL = volumeURL
        self.appStorageRoot = appStorageRoot
        self.fileManager = fileManager
    }

    func hasSufficientWorkingStorage(estimatedUploadByteCount: Int64?) async -> Bool {
        do {
            let availableBytes = try volumeURL.resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey]
            ).volumeAvailableCapacityForImportantUsage ?? 0
            let localBytes = try allocatedByteCount(in: appStorageRoot)
            return Self.hasSufficientStorage(
                availableByteCount: availableBytes,
                appStorageByteCount: localBytes,
                estimatedUploadByteCount: estimatedUploadByteCount
            )
        } catch {
            return false
        }
    }

    static func hasSufficientStorage(
        availableByteCount: Int64,
        appStorageByteCount: Int64,
        estimatedUploadByteCount: Int64?
    ) -> Bool {
        let priorEstimate = max(estimatedUploadByteCount ?? 0, 0)
        let localEstimate = max(appStorageByteCount, 0)
        let payloadEstimate = max(priorEstimate, localEstimate)
        let doubledPayload = payloadEstimate.multipliedReportingOverflow(by: 2)
        guard !doubledPayload.overflow else { return false }
        let requiredBytes = max(minimumWorkingByteCount, doubledPayload.partialValue)
        return availableByteCount >= requiredBytes
    }

    private func allocatedByteCount(in root: URL) throws -> Int64 {
        guard fileManager.fileExists(atPath: root.path) else { return 0 }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: keys)
            guard values.isRegularFile == true else { continue }
            let byteCount = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            let addition = total.addingReportingOverflow(byteCount)
            total = addition.overflow ? Int64.max : addition.partialValue
        }
        return total
    }
}

struct SystemBackupBackgroundScheduler: BackupBackgroundScheduling {
    static let taskIdentifier = "com.cloudbake.owner.cloud-backup"

    private let scheduler: BGTaskScheduler
    private let logger = Logger(subsystem: "com.cloudbake.owner", category: "CloudBackup")

    init(scheduler: BGTaskScheduler = .shared) {
        self.scheduler = scheduler
    }

    func schedule(earliestBeginDate: Date) async -> Bool {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = earliestBeginDate
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        scheduler.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        do {
            try scheduler.submit(request)
            return true
        } catch {
            logger.error("Cloud backup background scheduling failed")
            return false
        }
    }
}

final class StagedBackupPackageCleaner: BackupSnapshotPackageCleaning, @unchecked Sendable {
    private let stagingRoot: URL
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.cloudbake.owner", category: "CloudBackup")

    init(stagingRoot: URL, fileManager: FileManager = .default) {
        self.stagingRoot = stagingRoot.standardizedFileURL
        self.fileManager = fileManager
    }

    func removePackage(generationID: String) async {
        guard BackupPath.isSafeIdentifier(generationID) else {
            logger.error("Rejected unsafe cloud backup staging identifier")
            return
        }
        let packageURL = stagingRoot.appendingPathComponent(generationID, isDirectory: true)
        guard fileManager.fileExists(atPath: packageURL.path) else { return }
        do {
            try fileManager.removeItem(at: packageURL)
        } catch {
            logger.error("Cloud backup staging cleanup failed")
        }
    }

    func removeAllPackages() async {
        guard fileManager.fileExists(atPath: stagingRoot.path) else { return }
        do {
            let children = try fileManager.contentsOfDirectory(
                at: stagingRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for child in children {
                try fileManager.removeItem(at: child)
            }
        } catch {
            logger.error("Cloud backup staging reconciliation failed")
        }
    }
}

private extension NSLock {
    func withBackupLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
