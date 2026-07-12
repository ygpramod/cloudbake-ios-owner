import Foundation
import GRDB

protocol BackupDatabaseSnapshotSource {
    func writeBackupSnapshot(to destinationURL: URL) throws
}

protocol AppSnapshotCreating {
    func createSnapshot() async throws -> AppSnapshotPackage
}

protocol AppSnapshotValidating {
    func validatePackage(at packageURL: URL) async throws
}

extension AppDatabase: BackupDatabaseSnapshotSource {}

struct AppSnapshotPackage: Equatable, Sendable {
    let generationID: String
    let directoryURL: URL
    let manifestURL: URL
    let databaseURL: URL
}

enum AppSnapshotError: Error, Equatable {
    case invalidGenerationID
    case invalidAssetPath(String)
    case assetMissing(String)
    case assetChanged(String)
    case invalidManifestPath(String)
    case missingPayload(String)
    case payloadSizeMismatch(String)
    case payloadChecksumMismatch(String)
    case totalSizeMismatch
    case incompatibleManifest(BackupManifestCompatibility)
    case missingDatabaseSchemaVersion
}

actor AppSnapshotService: AppSnapshotCreating, AppSnapshotValidating {
    static let manifestFilename = "manifest.json"
    static let databaseFilename = "database.sqlite"

    private let database: any BackupDatabaseSnapshotSource
    private let appStorageRoot: URL
    private let stagingRoot: URL
    private let minimumCompatibleAppVersion: String
    private let currentAppVersion: String
    private let now: @Sendable () -> Date
    private let makeGenerationID: @Sendable () -> String
    private let didCaptureDatabase: @Sendable () throws -> Void
    private let didCopyAsset: @Sendable (String) throws -> Void
    private let fileManager: FileManager

    init(
        database: any BackupDatabaseSnapshotSource,
        appStorageRoot: URL,
        stagingRoot: URL,
        minimumCompatibleAppVersion: String,
        currentAppVersion: String,
        now: @escaping @Sendable () -> Date = Date.init,
        makeGenerationID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
        didCaptureDatabase: @escaping @Sendable () throws -> Void = {},
        didCopyAsset: @escaping @Sendable (String) throws -> Void = { _ in },
        fileManager: FileManager = .default
    ) {
        self.database = database
        self.appStorageRoot = appStorageRoot.standardizedFileURL
        self.stagingRoot = stagingRoot.standardizedFileURL
        self.minimumCompatibleAppVersion = minimumCompatibleAppVersion
        self.currentAppVersion = currentAppVersion
        self.now = now
        self.makeGenerationID = makeGenerationID
        self.didCaptureDatabase = didCaptureDatabase
        self.didCopyAsset = didCopyAsset
        self.fileManager = fileManager
    }

    func createSnapshot() async throws -> AppSnapshotPackage {
        try cleanAbandonedStagingDirectories()

        let generationID = makeGenerationID()
        guard BackupPath.isSafeRelativePath(generationID),
              !generationID.contains("/") else {
            throw AppSnapshotError.invalidGenerationID
        }

        try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        let buildingURL = stagingRoot.appendingPathComponent("\(generationID).building", isDirectory: true)
        let finalURL = stagingRoot.appendingPathComponent(generationID, isDirectory: true)
        try removeIfPresent(buildingURL)
        guard !fileManager.fileExists(atPath: finalURL.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        try fileManager.createDirectory(at: buildingURL, withIntermediateDirectories: false)

        do {
            let databaseURL = buildingURL.appendingPathComponent(Self.databaseFilename)
            try database.writeBackupSnapshot(to: databaseURL)
            try didCaptureDatabase()

            let snapshotDatabase = try DatabaseQueue(path: databaseURL.path)
            let schemaVersion = try readSchemaVersion(from: snapshotDatabase)
            let assetPaths = try readManagedAssetPaths(from: snapshotDatabase)
            let assets = try stageAssets(assetPaths, in: buildingURL)
            let databaseDescriptor = try describeFile(
                at: databaseURL,
                relativePath: Self.databaseFilename
            )
            let manifest = BackupManifest(
                databaseSchemaVersion: schemaVersion,
                minimumCompatibleAppVersion: minimumCompatibleAppVersion,
                generationID: generationID,
                createdAt: now(),
                database: databaseDescriptor,
                assets: assets
            )
            let manifestURL = buildingURL.appendingPathComponent(Self.manifestFilename)
            try Self.encoder.encode(manifest).write(to: manifestURL, options: .atomic)
            try validatePackageContents(at: buildingURL)
            try fileManager.moveItem(at: buildingURL, to: finalURL)

            return AppSnapshotPackage(
                generationID: generationID,
                directoryURL: finalURL,
                manifestURL: finalURL.appendingPathComponent(Self.manifestFilename),
                databaseURL: finalURL.appendingPathComponent(Self.databaseFilename)
            )
        } catch {
            try? fileManager.removeItem(at: buildingURL)
            throw error
        }
    }

    func validatePackage(at packageURL: URL) async throws {
        try validatePackageContents(at: packageURL)
    }

    private func validatePackageContents(at packageURL: URL) throws {
        let manifestURL = packageURL.appendingPathComponent(Self.manifestFilename)
        let manifest = try Self.decoder.decode(
            BackupManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        let compatibility = manifest.compatibility(currentAppVersion: currentAppVersion)
        guard compatibility == .compatible else {
            throw AppSnapshotError.incompatibleManifest(compatibility)
        }
        let calculatedTotal = manifest.database.byteCount
            + manifest.assets.reduce(0) { $0 + $1.file.byteCount }
        guard manifest.totalByteCount == calculatedTotal else {
            throw AppSnapshotError.totalSizeMismatch
        }

        try validate(manifest.database, in: packageURL)
        for asset in manifest.assets {
            guard BackupPath.isSafeRelativePath(asset.originalRelativePath) else {
                throw AppSnapshotError.invalidManifestPath(asset.originalRelativePath)
            }
            try validate(asset.file, in: packageURL)
        }
    }

    func cleanAbandonedStagingDirectories() throws {
        guard fileManager.fileExists(atPath: stagingRoot.path) else { return }
        for child in try fileManager.contentsOfDirectory(
            at: stagingRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) where child.lastPathComponent.hasSuffix(".building") {
            try fileManager.removeItem(at: child)
        }
    }

    private func readSchemaVersion(from database: DatabaseQueue) throws -> String {
        let version = try database.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid DESC LIMIT 1"
            )
        }
        guard let version else { throw AppSnapshotError.missingDatabaseSchemaVersion }
        return version
    }

    private func readManagedAssetPaths(from database: DatabaseQueue) throws -> [String] {
        var paths = try database.read { db in
            let designPaths = try String.fetchAll(
                db,
                sql: "SELECT photo_reference FROM cake_designs WHERE photo_reference IS NOT NULL"
            )
            let orderPaths = try String.fetchAll(
                db,
                sql: "SELECT local_photo_path FROM order_photos WHERE local_photo_path IS NOT NULL"
            )
            return designPaths + orderPaths
        }
        let logoPath = "Branding/custom-logo.jpg"
        if fileManager.fileExists(atPath: appStorageRoot.appendingPathComponent(logoPath).path) {
            paths.append(logoPath)
        }
        return Array(Set(paths.filter { !$0.hasPrefix("photos://") })).sorted()
    }

    private func stageAssets(
        _ paths: [String],
        in buildingURL: URL
    ) throws -> [BackupAssetDescriptor] {
        var descriptors: [BackupAssetDescriptor] = []
        for path in paths {
            guard BackupPath.isSafeRelativePath(path) else {
                throw AppSnapshotError.invalidAssetPath(path)
            }
            let sourceURL = appStorageRoot.appendingPathComponent(path).standardizedFileURL
            let resolvedSourceURL = sourceURL.resolvingSymlinksInPath()
            let resolvedStorageRoot = appStorageRoot.resolvingSymlinksInPath()
            let sourceValues = try? sourceURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard isContained(resolvedSourceURL, in: resolvedStorageRoot),
                  sourceValues?.isRegularFile == true,
                  sourceValues?.isSymbolicLink != true,
                  fileManager.fileExists(atPath: sourceURL.path) else {
                throw AppSnapshotError.assetMissing(path)
            }

            let stagedPath = "Assets/\(path)"
            let destinationURL = buildingURL.appendingPathComponent(stagedPath)
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let sourceChecksumBefore = try BackupChecksum.sha256(of: sourceURL)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            try didCopyAsset(path)
            let sourceChecksumAfter = try BackupChecksum.sha256(of: sourceURL)
            let descriptor = try describeFile(at: destinationURL, relativePath: stagedPath)
            guard sourceChecksumBefore == sourceChecksumAfter,
                  descriptor.sha256 == sourceChecksumBefore else {
                throw AppSnapshotError.assetChanged(path)
            }
            descriptors.append(
                BackupAssetDescriptor(originalRelativePath: path, file: descriptor)
            )
        }
        return descriptors
    }

    private func describeFile(at url: URL, relativePath: String) throws -> BackupFileDescriptor {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        return BackupFileDescriptor(
            relativePath: relativePath,
            byteCount: byteCount,
            sha256: try BackupChecksum.sha256(of: url)
        )
    }

    private func validate(_ descriptor: BackupFileDescriptor, in packageURL: URL) throws {
        guard BackupPath.isSafeRelativePath(descriptor.relativePath) else {
            throw AppSnapshotError.invalidManifestPath(descriptor.relativePath)
        }
        let fileURL = packageURL.appendingPathComponent(descriptor.relativePath).standardizedFileURL
        guard isContained(fileURL, in: packageURL.standardizedFileURL),
              fileManager.fileExists(atPath: fileURL.path) else {
            throw AppSnapshotError.missingPayload(descriptor.relativePath)
        }
        let actual = try describeFile(at: fileURL, relativePath: descriptor.relativePath)
        guard actual.byteCount == descriptor.byteCount else {
            throw AppSnapshotError.payloadSizeMismatch(descriptor.relativePath)
        }
        guard actual.sha256 == descriptor.sha256 else {
            throw AppSnapshotError.payloadChecksumMismatch(descriptor.relativePath)
        }
    }

    private func isContained(_ child: URL, in parent: URL) -> Bool {
        child.path.hasPrefix(parent.path + "/")
    }

    private func removeIfPresent(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
