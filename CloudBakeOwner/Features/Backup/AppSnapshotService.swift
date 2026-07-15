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
    let manifest: BackupManifest
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
    case invalidPayloadSize(String)
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
    private let externalAssetResolver: any BackupExternalAssetResolving
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
        externalAssetResolver: any BackupExternalAssetResolving = PhotoKitBackupAssetResolver(),
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
        self.externalAssetResolver = externalAssetResolver
        self.now = now
        self.makeGenerationID = makeGenerationID
        self.didCaptureDatabase = didCaptureDatabase
        self.didCopyAsset = didCopyAsset
        self.fileManager = fileManager
    }

    func createSnapshot() async throws -> AppSnapshotPackage {
        try cleanAbandonedStagingDirectories()

        let generationID = makeGenerationID()
        guard BackupPath.isSafeIdentifier(generationID) else {
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
            let databaseCapturedAt = Date()
            try didCaptureDatabase()

            let snapshotDatabase = try DatabaseQueue(path: databaseURL.path)
            let schemaVersion = try readSchemaVersion(from: snapshotDatabase)
            let assetSources = try readAssetSources(from: snapshotDatabase)
            let assets = try await stageAssets(
                assetSources,
                capturedAt: databaseCapturedAt,
                snapshotDatabase: snapshotDatabase,
                in: buildingURL
            )
            try snapshotDatabase.close()
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
            let manifestData = try Self.makeEncoder().encode(manifest)
            try manifestData.write(to: manifestURL, options: .atomic)
            let persistedManifest = try Self.makeDecoder().decode(
                BackupManifest.self,
                from: manifestData
            )
            try validatePackageContents(at: buildingURL)
            try fileManager.moveItem(at: buildingURL, to: finalURL)

            return AppSnapshotPackage(
                generationID: generationID,
                directoryURL: finalURL,
                manifestURL: finalURL.appendingPathComponent(Self.manifestFilename),
                databaseURL: finalURL.appendingPathComponent(Self.databaseFilename),
                manifest: persistedManifest
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
        guard isRegularContainedFile(manifestURL, in: packageURL) else {
            throw AppSnapshotError.missingPayload(Self.manifestFilename)
        }
        let manifest = try Self.makeDecoder().decode(
            BackupManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        let compatibility = manifest.compatibility(currentAppVersion: currentAppVersion)
        guard compatibility == .compatible else {
            throw AppSnapshotError.incompatibleManifest(compatibility)
        }
        guard let calculatedTotal = BackupManifest.calculatedTotalByteCount(
            database: manifest.database,
            assets: manifest.assets
        ) else {
            throw AppSnapshotError.invalidPayloadSize(Self.manifestFilename)
        }
        guard manifest.totalByteCount >= 0,
              manifest.totalByteCount == calculatedTotal else {
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
            options: []
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

    private func readAssetSources(from database: DatabaseQueue) throws -> [SnapshotAssetSource] {
        var references = try database.read { db in
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
            references.append(logoPath)
        }
        return Array(Set(references)).sorted().map { reference in
            if reference.hasPrefix(PhotoKitDesignPhotoLibrary.referencePrefix) {
                let referenceHash = BackupChecksum.sha256(of: Data(reference.utf8))
                return SnapshotAssetSource(
                    sourceReference: reference,
                    recoveryRelativePath: "RecoveredPhotos/\(referenceHash).jpg",
                    isExternal: true
                )
            }
            return SnapshotAssetSource(
                sourceReference: reference,
                recoveryRelativePath: reference,
                isExternal: false
            )
        }
    }

    private func stageAssets(
        _ sources: [SnapshotAssetSource],
        capturedAt: Date,
        snapshotDatabase: DatabaseQueue,
        in buildingURL: URL
    ) async throws -> [BackupAssetDescriptor] {
        var descriptors: [BackupAssetDescriptor] = []
        for source in sources {
            let path = source.recoveryRelativePath
            guard BackupPath.isSafeRelativePath(path) else {
                throw AppSnapshotError.invalidAssetPath(path)
            }
            let opaqueFilename = BackupChecksum.sha256(of: Data(path.utf8))
            let stagedPath = "Assets/\(opaqueFilename).asset"
            let destinationURL = buildingURL.appendingPathComponent(stagedPath)
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if source.isExternal {
                let resolved = try await externalAssetResolver.resolve(reference: source.sourceReference)
                try Task.checkCancellation()
                guard resolved.modificationDate <= capturedAt else {
                    throw AppSnapshotError.assetChanged(path)
                }
                try resolved.data.write(to: destinationURL, options: .atomic)
                try rewriteExternalReference(
                    source.sourceReference,
                    to: path,
                    in: snapshotDatabase
                )
            } else {
                try stageLocalAsset(
                    sourceReference: source.sourceReference,
                    recoveryRelativePath: path,
                    capturedAt: capturedAt,
                    destinationURL: destinationURL
                )
            }
            let descriptor = try describeFile(at: destinationURL, relativePath: stagedPath)
            descriptors.append(
                BackupAssetDescriptor(originalRelativePath: path, file: descriptor)
            )
        }
        return descriptors
    }

    private func stageLocalAsset(
        sourceReference: String,
        recoveryRelativePath: String,
        capturedAt: Date,
        destinationURL: URL
    ) throws {
        let sourceURL = appStorageRoot.appendingPathComponent(sourceReference).standardizedFileURL
        let resolvedSourceURL = sourceURL.resolvingSymlinksInPath()
        let resolvedStorageRoot = appStorageRoot.resolvingSymlinksInPath()
        let sourceValues = try? sourceURL.resourceValues(
            forKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey]
        )
        guard isContained(resolvedSourceURL, in: resolvedStorageRoot),
              sourceValues?.isRegularFile == true,
              sourceValues?.isSymbolicLink != true,
              fileManager.fileExists(atPath: sourceURL.path) else {
            throw AppSnapshotError.assetMissing(recoveryRelativePath)
        }
        guard sourceValues?.contentModificationDate.map({ $0 <= capturedAt }) ?? false else {
            throw AppSnapshotError.assetChanged(recoveryRelativePath)
        }

        let sourceChecksumBefore = try BackupChecksum.sha256(of: sourceURL)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        try didCopyAsset(recoveryRelativePath)
        let sourceChecksumAfter = try BackupChecksum.sha256(of: sourceURL)
        let destinationChecksum = try BackupChecksum.sha256(of: destinationURL)
        guard sourceChecksumBefore == sourceChecksumAfter,
              destinationChecksum == sourceChecksumBefore else {
            throw AppSnapshotError.assetChanged(recoveryRelativePath)
        }
    }

    private func rewriteExternalReference(
        _ externalReference: String,
        to recoveryRelativePath: String,
        in database: DatabaseQueue
    ) throws {
        try database.write { db in
            try db.execute(
                sql: "UPDATE cake_designs SET photo_reference = ? WHERE photo_reference = ?",
                arguments: [recoveryRelativePath, externalReference]
            )
            try db.execute(
                sql: "UPDATE order_photos SET local_photo_path = ? WHERE local_photo_path = ?",
                arguments: [recoveryRelativePath, externalReference]
            )
        }
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
        guard descriptor.byteCount >= 0 else {
            throw AppSnapshotError.invalidPayloadSize(descriptor.relativePath)
        }
        guard isRegularContainedFile(fileURL, in: packageURL) else {
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

    private func isRegularContainedFile(_ fileURL: URL, in directoryURL: URL) -> Bool {
        let standardizedFileURL = fileURL.standardizedFileURL
        let resolvedFileURL = standardizedFileURL.resolvingSymlinksInPath()
        let resolvedDirectoryURL = directoryURL.standardizedFileURL.resolvingSymlinksInPath()
        let values = try? standardizedFileURL.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        return isContained(resolvedFileURL, in: resolvedDirectoryURL)
            && values?.isRegularFile == true
            && values?.isSymbolicLink != true
            && fileManager.fileExists(atPath: standardizedFileURL.path)
    }

    private func removeIfPresent(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct SnapshotAssetSource {
    let sourceReference: String
    let recoveryRelativePath: String
    let isExternal: Bool
}
