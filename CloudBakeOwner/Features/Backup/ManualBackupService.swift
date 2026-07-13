import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

extension UTType {
    static let cloudBakeBackup = UTType(
        exportedAs: "com.cloudbake.owner.backup",
        conformingTo: .archive
    )
}

struct ManualBackupExport: Sendable {
    let packageURL: URL
    let stagingDirectoryURL: URL
    let filename: String

    func removeStagedFiles(fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: packageURL)
        try? fileManager.removeItem(at: stagingDirectoryURL)
    }
}

protocol ManualBackupPreparing: Sendable {
    func prepareBackup() async throws -> ManualBackupExport
}

protocol ManualBackupArchiving: Sendable {
    func archivePackage(at sourceURL: URL, to destinationURL: URL) throws
}

struct ZIPManualBackupArchiver: ManualBackupArchiving {
    func archivePackage(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.zipItem(
            at: sourceURL,
            to: destinationURL,
            shouldKeepParent: false,
            compressionMethod: .deflate
        )
    }

    func extractArchive(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)
    }
}

actor ManualBackupService: ManualBackupPreparing {
    private let snapshotCreator: any AppSnapshotCreating
    private let dateProvider: @Sendable () -> Date
    private let completedPackageRoot: URL?
    private let fileManager: FileManager
    private let archiver: any ManualBackupArchiving

    init(
        snapshotCreator: any AppSnapshotCreating,
        dateProvider: @escaping @Sendable () -> Date = Date.init,
        completedPackageRoot: URL? = nil,
        fileManager: FileManager = .default,
        archiver: any ManualBackupArchiving = ZIPManualBackupArchiver()
    ) {
        self.snapshotCreator = snapshotCreator
        self.dateProvider = dateProvider
        self.completedPackageRoot = completedPackageRoot
        self.fileManager = fileManager
        self.archiver = archiver
    }

    func prepareBackup() async throws -> ManualBackupExport {
        try removeCompletedStagingPackages()
        let package = try await snapshotCreator.createSnapshot()
        let filename = Self.filename(for: dateProvider())
        let archiveURL = package.directoryURL
            .deletingLastPathComponent()
            .appendingPathComponent(filename)
        do {
            try archiver.archivePackage(at: package.directoryURL, to: archiveURL)
        } catch {
            try? fileManager.removeItem(at: archiveURL)
            try? fileManager.removeItem(at: package.directoryURL)
            throw error
        }
        return ManualBackupExport(
            packageURL: archiveURL,
            stagingDirectoryURL: package.directoryURL,
            filename: filename
        )
    }

    static func live(database: AppDatabase) throws -> ManualBackupService {
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
            .appendingPathComponent("ManualBackupStaging", isDirectory: true)
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
        return ManualBackupService(
            snapshotCreator: snapshotService,
            completedPackageRoot: stagingRoot
        )
    }

    static func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "cloudbake-backup-\(formatter.string(from: date)).cloudbakebackup"
    }

    private func removeCompletedStagingPackages() throws {
        guard let completedPackageRoot,
              fileManager.fileExists(atPath: completedPackageRoot.path) else { return }
        for child in try fileManager.contentsOfDirectory(
            at: completedPackageRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) where !child.lastPathComponent.hasSuffix(".building") {
            try fileManager.removeItem(at: child)
        }
    }
}
