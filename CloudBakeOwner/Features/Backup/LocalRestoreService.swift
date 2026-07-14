import Foundation
import GRDB

actor LocalRestoreService: LocalRestoreServing {
    static let preparedDirectoryName = "Prepared"
    static let preparedDatabaseName = "database.sqlite"
    static let preparedAssetsDirectoryName = "Assets"

    private let database: AppDatabase
    private let snapshotCreator: any AppSnapshotCreating
    private let appStorageRoot: URL
    private let activationRoot: URL
    private let didReplaceDatabase: @Sendable () throws -> Void
    private let fileManager: FileManager

    init(
        database: AppDatabase,
        snapshotCreator: any AppSnapshotCreating,
        appStorageRoot: URL,
        activationRoot: URL,
        didReplaceDatabase: @escaping @Sendable () throws -> Void = {},
        fileManager: FileManager = .default
    ) {
        self.database = database
        self.snapshotCreator = snapshotCreator
        self.appStorageRoot = appStorageRoot.standardizedFileURL
        self.activationRoot = activationRoot.standardizedFileURL
        self.didReplaceDatabase = didReplaceDatabase
        self.fileManager = fileManager
    }

    func hasOwnerData() async throws -> Bool {
        try database.hasOwnerData()
    }

    func createRollbackSnapshot() async throws -> AppSnapshotPackage {
        try await snapshotCreator.createSnapshot()
    }

    func prepare(_ snapshot: DownloadedRestoreSnapshot) async throws -> PreparedRestoreSnapshot {
        let preparedRoot = snapshot.directoryURL.appendingPathComponent(
            Self.preparedDirectoryName,
            isDirectory: true
        )
        try removeIfPresent(preparedRoot)
        try fileManager.createDirectory(at: preparedRoot, withIntermediateDirectories: true)

        do {
            try validateManifest(snapshot.manifest, in: snapshot.directoryURL)
            let preparedDatabaseURL = preparedRoot.appendingPathComponent(Self.preparedDatabaseName)
            try fileManager.copyItem(
                at: snapshot.directoryURL.appendingPathComponent(snapshot.manifest.database.relativePath),
                to: preparedDatabaseURL
            )
            try migrateAndValidateDatabase(at: preparedDatabaseURL)

            var broken = Set(snapshot.brokenAssets)
            let preparedAssetsRoot = preparedRoot.appendingPathComponent(
                Self.preparedAssetsDirectoryName,
                isDirectory: true
            )
            for asset in snapshot.manifest.assets {
                guard BackupPath.isSafeRelativePath(asset.originalRelativePath),
                      InterruptedRestoreRecovery.isManagedAssetPath(asset.originalRelativePath) else {
                    throw RestoreOperationError(category: .corruptBackup, didRollBack: false)
                }
                do {
                    try stageAsset(asset, from: snapshot.directoryURL, to: preparedAssetsRoot)
                } catch {
                    broken.insert(BrokenRestoreAsset(originalRelativePath: asset.originalRelativePath))
                }
            }
            return PreparedRestoreSnapshot(
                directoryURL: preparedRoot,
                manifest: snapshot.manifest,
                brokenAssets: broken.sorted { $0.originalRelativePath < $1.originalRelativePath },
                ignoredBrokenAssets: []
            )
        } catch {
            try? fileManager.removeItem(at: preparedRoot)
            if error is RestoreOperationError { throw error }
            throw RestoreOperationError(category: .corruptBackup, didRollBack: false)
        }
    }

    func applyBrokenAssetDecision(
        _ decision: BrokenRestoreAssetDecision,
        to snapshot: PreparedRestoreSnapshot
    ) async throws -> PreparedRestoreSnapshot {
        guard !snapshot.brokenAssets.isEmpty else { return snapshot }
        switch decision {
        case .ignore:
            return PreparedRestoreSnapshot(
                directoryURL: snapshot.directoryURL,
                manifest: snapshot.manifest,
                brokenAssets: [],
                ignoredBrokenAssets: snapshot.brokenAssets
            )
        case .removeReferences:
            do {
                let queue = try DatabaseQueue(
                    path: snapshot.directoryURL.appendingPathComponent(Self.preparedDatabaseName).path
                )
                let paths = snapshot.brokenAssets.map(\.originalRelativePath)
                try await queue.write { db in
                    try db.execute(
                        sql: "UPDATE cake_designs SET photo_reference = NULL WHERE photo_reference IN \(paths.databaseQuestionMarks)",
                        arguments: StatementArguments(paths)
                    )
                    try db.execute(
                        sql: "DELETE FROM order_photos WHERE local_photo_path IN \(paths.databaseQuestionMarks)",
                        arguments: StatementArguments(paths)
                    )
                }
                try queue.close()
                return PreparedRestoreSnapshot(
                    directoryURL: snapshot.directoryURL,
                    manifest: snapshot.manifest,
                    brokenAssets: [],
                    ignoredBrokenAssets: []
                )
            } catch {
                throw RestoreOperationError(category: .migrationFailed, didRollBack: false)
            }
        }
    }

    func activate(
        _ snapshot: PreparedRestoreSnapshot,
        rollbackSnapshot: AppSnapshotPackage?
    ) async throws {
        guard snapshot.brokenAssets.isEmpty else {
            throw RestoreOperationError(category: .corruptBackup, didRollBack: false)
        }
        let rollbackDatabaseURL = activationRoot.appendingPathComponent(
            InterruptedRestoreRecovery.rollbackDatabaseName
        )
        let rollbackAssetsRoot = activationRoot.appendingPathComponent(
            InterruptedRestoreRecovery.rollbackAssetsDirectoryName,
            isDirectory: true
        )
        var failureCategory = RestoreFailureCategory.activationFailed

        do {
            try removeIfPresent(activationRoot)
            try fileManager.createDirectory(at: activationRoot, withIntermediateDirectories: true)
            if let rollbackSnapshot {
                try fileManager.copyItem(at: rollbackSnapshot.databaseURL, to: rollbackDatabaseURL)
            } else {
                try database.writeBackupSnapshot(to: rollbackDatabaseURL)
            }
            try InterruptedRestoreRecovery.writeJournal(in: activationRoot, fileManager: fileManager)
            try moveActiveAssets(to: rollbackAssetsRoot)
            try installPreparedAssets(from: snapshot.directoryURL)

            try database.replaceContents(
                from: snapshot.directoryURL.appendingPathComponent(Self.preparedDatabaseName)
            )
            try didReplaceDatabase()
            failureCategory = .verificationFailed
            try database.verifyIntegrity()
            try verifyActiveAssetReferences(allowing: Set(snapshot.ignoredBrokenAssets))
            try fileManager.removeItem(at: activationRoot)
        } catch {
            let didRollBack = rollbackActivation(
                databaseURL: rollbackDatabaseURL,
                assetsRoot: rollbackAssetsRoot
            )
            throw RestoreOperationError(category: failureCategory, didRollBack: didRollBack)
        }
    }

    func removeStagedRestore(at directoryURL: URL) async {
        try? fileManager.removeItem(at: directoryURL)
    }

    func removeRollbackSnapshot(_ snapshot: AppSnapshotPackage) async {
        try? fileManager.removeItem(at: snapshot.directoryURL)
    }

    private func validateManifest(_ manifest: BackupManifest, in directoryURL: URL) throws {
        guard manifest.formatVersion == BackupManifest.currentFormatVersion,
              BackupManifest.calculatedTotalByteCount(
                database: manifest.database,
                assets: manifest.assets
              ) == manifest.totalByteCount else {
            throw RestoreOperationError(category: .corruptBackup, didRollBack: false)
        }
        try validateFile(manifest.database, in: directoryURL)
    }

    private func stageAsset(
        _ asset: BackupAssetDescriptor,
        from packageRoot: URL,
        to preparedAssetsRoot: URL
    ) throws {
        try validateFile(asset.file, in: packageRoot)
        let destination = preparedAssetsRoot
            .appendingPathComponent(asset.originalRelativePath)
            .standardizedFileURL
        guard destination.path.hasPrefix(preparedAssetsRoot.standardizedFileURL.path + "/") else {
            throw RestoreOperationError(category: .corruptBackup, didRollBack: false)
        }
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(
            at: packageRoot.appendingPathComponent(asset.file.relativePath),
            to: destination
        )
    }

    private func validateFile(_ descriptor: BackupFileDescriptor, in root: URL) throws {
        guard descriptor.byteCount >= 0,
              BackupPath.isSafeRelativePath(descriptor.relativePath) else {
            throw RestoreOperationError(category: .corruptBackup, didRollBack: false)
        }
        let fileURL = root.appendingPathComponent(descriptor.relativePath).standardizedFileURL
        let values = try fileURL.resourceValues(
            forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        )
        guard fileURL.path.hasPrefix(root.standardizedFileURL.path + "/"),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              Int64(values.fileSize ?? -1) == descriptor.byteCount,
              try BackupChecksum.sha256(of: fileURL) == descriptor.sha256 else {
            throw RestoreOperationError(category: .corruptBackup, didRollBack: false)
        }
    }

    private func migrateAndValidateDatabase(at databaseURL: URL) throws {
        do {
            let queue = try DatabaseQueue(path: databaseURL.path)
            try AppDatabaseMigrations.makeMigrator().migrate(queue)
            try Self.verifyIntegrity(of: queue)
            try queue.close()
        } catch {
            throw RestoreOperationError(category: .migrationFailed, didRollBack: false)
        }
    }

    private func moveActiveAssets(to rollbackAssetsRoot: URL) throws {
        try fileManager.createDirectory(at: rollbackAssetsRoot, withIntermediateDirectories: true)
        for directoryName in InterruptedRestoreRecovery.managedAssetDirectories {
            let activeURL = appStorageRoot.appendingPathComponent(directoryName, isDirectory: true)
            guard fileManager.fileExists(atPath: activeURL.path) else { continue }
            try fileManager.moveItem(
                at: activeURL,
                to: rollbackAssetsRoot.appendingPathComponent(directoryName, isDirectory: true)
            )
        }
    }

    private func installPreparedAssets(from preparedRoot: URL) throws {
        let assetsRoot = preparedRoot.appendingPathComponent(
            Self.preparedAssetsDirectoryName,
            isDirectory: true
        )
        for directoryName in InterruptedRestoreRecovery.managedAssetDirectories {
            let source = assetsRoot.appendingPathComponent(directoryName, isDirectory: true)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try fileManager.copyItem(
                at: source,
                to: appStorageRoot.appendingPathComponent(directoryName, isDirectory: true)
            )
        }
    }

    private func verifyActiveAssetReferences(allowing brokenAssets: Set<BrokenRestoreAsset>) throws {
        let allowedPaths = Set(brokenAssets.map(\.originalRelativePath))
        for path in try database.assetReferences() where !allowedPaths.contains(path) {
            guard BackupPath.isSafeRelativePath(path),
                  InterruptedRestoreRecovery.isManagedAssetPath(path) else {
                throw RestoreOperationError(category: .verificationFailed, didRollBack: false)
            }
            let values = try? appStorageRoot.appendingPathComponent(path).resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )
            guard values?.isRegularFile == true, values?.isSymbolicLink != true else {
                throw RestoreOperationError(category: .verificationFailed, didRollBack: false)
            }
        }
    }

    private func rollbackActivation(databaseURL: URL, assetsRoot: URL) -> Bool {
        do {
            if fileManager.fileExists(atPath: databaseURL.path) {
                try database.replaceContents(from: databaseURL)
            }
            for directoryName in InterruptedRestoreRecovery.managedAssetDirectories {
                let activeURL = appStorageRoot.appendingPathComponent(directoryName, isDirectory: true)
                try removeIfPresent(activeURL)
                let rollbackURL = assetsRoot.appendingPathComponent(directoryName, isDirectory: true)
                if fileManager.fileExists(atPath: rollbackURL.path) {
                    try fileManager.moveItem(at: rollbackURL, to: activeURL)
                }
            }
            try database.verifyIntegrity()
            try removeIfPresent(activationRoot)
            return true
        } catch {
            return false
        }
    }

    private func removeIfPresent(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    static func verifyIntegrity(of reader: any DatabaseReader) throws {
        try reader.read { db in
            let quickCheck = try String.fetchOne(db, sql: "PRAGMA quick_check")
            guard quickCheck == "ok" else { throw DatabaseError(resultCode: .SQLITE_CORRUPT) }
            let foreignKeyFailureCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM pragma_foreign_key_check"
            ) ?? 0
            guard foreignKeyFailureCount == 0 else {
                throw DatabaseError(resultCode: .SQLITE_CONSTRAINT_FOREIGNKEY)
            }
        }
    }
}

enum InterruptedRestoreRecovery {
    static let directoryName = "CloudBakeRestoreActivation"
    static let journalName = "activation.json"
    static let rollbackDatabaseName = "rollback.sqlite"
    static let rollbackAssetsDirectoryName = "Assets"
    static let managedAssetDirectories = ["Branding", "OrderPhotos", "RecoveredPhotos"]

    static func recoverIfNeeded(
        appStorageRoot: URL,
        databaseURL: URL,
        activationRoot: URL,
        fileManager: FileManager = .default
    ) throws {
        let journalURL = activationRoot.appendingPathComponent(journalName)
        guard fileManager.fileExists(atPath: journalURL.path) else {
            if fileManager.fileExists(atPath: activationRoot.path) {
                try fileManager.removeItem(at: activationRoot)
            }
            return
        }

        let rollbackDatabaseURL = activationRoot.appendingPathComponent(rollbackDatabaseName)
        guard fileManager.fileExists(atPath: rollbackDatabaseURL.path) else {
            throw RestoreOperationError(category: .activationFailed, didRollBack: false)
        }
        for suffix in ["", "-wal", "-shm"] {
            let activeFile = URL(fileURLWithPath: databaseURL.path + suffix)
            if fileManager.fileExists(atPath: activeFile.path) {
                try fileManager.removeItem(at: activeFile)
            }
        }
        try fileManager.copyItem(at: rollbackDatabaseURL, to: databaseURL)

        let rollbackAssetsRoot = activationRoot.appendingPathComponent(
            rollbackAssetsDirectoryName,
            isDirectory: true
        )
        for directoryName in managedAssetDirectories {
            let rollbackURL = rollbackAssetsRoot.appendingPathComponent(directoryName, isDirectory: true)
            guard fileManager.fileExists(atPath: rollbackURL.path) else { continue }
            let activeURL = appStorageRoot.appendingPathComponent(directoryName, isDirectory: true)
            if fileManager.fileExists(atPath: activeURL.path) {
                try fileManager.removeItem(at: activeURL)
            }
            try fileManager.moveItem(at: rollbackURL, to: activeURL)
        }
        try fileManager.removeItem(at: activationRoot)
    }

    static func writeJournal(in activationRoot: URL, fileManager: FileManager) throws {
        let journal = Data("{\"version\":1}".utf8)
        try journal.write(
            to: activationRoot.appendingPathComponent(journalName),
            options: .atomic
        )
    }

    static func isManagedAssetPath(_ relativePath: String) -> Bool {
        guard let first = NSString(string: relativePath).pathComponents.first else { return false }
        return managedAssetDirectories.contains(first)
    }
}

private extension Array where Element == String {
    var databaseQuestionMarks: String {
        "(" + Array(repeating: "?", count: count).joined(separator: ",") + ")"
    }
}
