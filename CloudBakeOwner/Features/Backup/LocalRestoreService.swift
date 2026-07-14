import Foundation
import GRDB

private struct BrokenLocalRestoreAssetError: Error {}

enum RestoreLocalFileErrorMapper {
    static func category(for error: Error) -> RestoreFailureCategory {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == CocoaError.fileWriteOutOfSpace.rawValue {
            return .insufficientStorage
        }
        if nsError.domain == NSPOSIXErrorDomain,
           nsError.code == Int(POSIXErrorCode.ENOSPC.rawValue) {
            return .insufficientStorage
        }
        return .unknown
    }

    static func isMissingFile(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            return nsError.code == CocoaError.fileNoSuchFile.rawValue
                || nsError.code == CocoaError.fileReadNoSuchFile.rawValue
        }
        return nsError.domain == NSPOSIXErrorDomain
            && nsError.code == Int(POSIXErrorCode.ENOENT.rawValue)
    }
}

actor LocalRestoreService: LocalRestoreServing {
    static let preparedDirectoryName = "Prepared"
    static let preparedDatabaseName = "database.sqlite"
    static let preparedAssetsDirectoryName = "Assets"

    private let database: AppDatabase
    private let snapshotCreator: any AppSnapshotCreating
    private let appStorageRoot: URL
    private let activationRoot: URL
    private let didReplaceDatabase: @Sendable () throws -> Void
    private let activationCheckpoint: @Sendable (RestoreActivationCheckpoint) throws -> Void
    private let fileManager: FileManager

    init(
        database: AppDatabase,
        snapshotCreator: any AppSnapshotCreating,
        appStorageRoot: URL,
        activationRoot: URL,
        didReplaceDatabase: @escaping @Sendable () throws -> Void = {},
        activationCheckpoint: @escaping @Sendable (RestoreActivationCheckpoint) throws -> Void = { _ in },
        fileManager: FileManager = .default
    ) {
        self.database = database
        self.snapshotCreator = snapshotCreator
        self.appStorageRoot = appStorageRoot.standardizedFileURL
        self.activationRoot = activationRoot.standardizedFileURL
        self.didReplaceDatabase = didReplaceDatabase
        self.activationCheckpoint = activationCheckpoint
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
        do {
            try removeIfPresent(preparedRoot)
            try fileManager.createDirectory(at: preparedRoot, withIntermediateDirectories: true)
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
                } catch is BrokenLocalRestoreAssetError {
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
            throw RestoreOperationError(
                category: RestoreLocalFileErrorMapper.category(for: error),
                didRollBack: false
            )
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
            try activationCheckpoint(.rollbackDatabasePrepared)
            var journal = RestoreActivationJournal(
                phase: .preparingAssets,
                directories: InterruptedRestoreRecovery.managedAssetDirectories.map { directoryName in
                    RestoreActivationDirectoryState(
                        name: directoryName,
                        originallyExisted: fileManager.fileExists(
                            atPath: appStorageRoot
                                .appendingPathComponent(directoryName, isDirectory: true).path
                        ),
                        phase: .untouched
                    )
                }
            )
            try InterruptedRestoreRecovery.writeJournal(
                journal,
                in: activationRoot,
                fileManager: fileManager
            )
            try activationCheckpoint(.journalPrepared)
            try moveActiveAssets(to: rollbackAssetsRoot, journal: &journal)
            try installPreparedAssets(from: snapshot.directoryURL, journal: &journal)

            journal.phase = .replacingDatabase
            try InterruptedRestoreRecovery.writeJournal(
                journal,
                in: activationRoot,
                fileManager: fileManager
            )
            try database.replaceContents(
                from: snapshot.directoryURL.appendingPathComponent(Self.preparedDatabaseName)
            )
            journal.phase = .databaseReplaced
            try InterruptedRestoreRecovery.writeJournal(
                journal,
                in: activationRoot,
                fileManager: fileManager
            )
            try activationCheckpoint(.databaseReplaced)
            try didReplaceDatabase()
            failureCategory = .verificationFailed
            try database.verifyIntegrity()
            try verifyActiveAssetReferences(allowing: Set(snapshot.ignoredBrokenAssets))
            try activationCheckpoint(.committed)
            journal.phase = .committed
            try InterruptedRestoreRecovery.writeJournal(
                journal,
                in: activationRoot,
                fileManager: fileManager
            )
            try? fileManager.removeItem(at: activationRoot)
        } catch {
            let didRollBack = rollbackActivation(databaseURL: rollbackDatabaseURL)
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
        try validateAssetFile(asset.file, in: packageRoot)
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
        do {
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
        } catch {
            throw RestoreOperationError(category: .corruptBackup, didRollBack: false)
        }
    }

    private func validateAssetFile(
        _ descriptor: BackupFileDescriptor,
        in root: URL
    ) throws {
        guard descriptor.byteCount >= 0,
              BackupPath.isSafeRelativePath(descriptor.relativePath) else {
            throw RestoreOperationError(category: .corruptBackup, didRollBack: false)
        }
        let fileURL = root.appendingPathComponent(descriptor.relativePath).standardizedFileURL
        guard fileURL.path.hasPrefix(root.standardizedFileURL.path + "/") else {
            throw RestoreOperationError(category: .corruptBackup, didRollBack: false)
        }
        do {
            let values = try fileURL.resourceValues(
                forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
            )
            guard values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  Int64(values.fileSize ?? -1) == descriptor.byteCount,
                  try BackupChecksum.sha256(of: fileURL) == descriptor.sha256 else {
                throw BrokenLocalRestoreAssetError()
            }
        } catch let error as BrokenLocalRestoreAssetError {
            throw error
        } catch {
            if RestoreLocalFileErrorMapper.isMissingFile(error) {
                throw BrokenLocalRestoreAssetError()
            }
            throw error
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

    private func moveActiveAssets(
        to rollbackAssetsRoot: URL,
        journal: inout RestoreActivationJournal
    ) throws {
        try fileManager.createDirectory(at: rollbackAssetsRoot, withIntermediateDirectories: true)
        for index in journal.directories.indices {
            let directoryName = journal.directories[index].name
            let activeURL = appStorageRoot.appendingPathComponent(directoryName, isDirectory: true)
            journal.directories[index].phase = .movingOriginal
            try InterruptedRestoreRecovery.writeJournal(
                journal,
                in: activationRoot,
                fileManager: fileManager
            )
            if journal.directories[index].originallyExisted {
                try fileManager.moveItem(
                    at: activeURL,
                    to: rollbackAssetsRoot.appendingPathComponent(directoryName, isDirectory: true)
                )
            }
            journal.directories[index].phase = .originalMoved
            try InterruptedRestoreRecovery.writeJournal(
                journal,
                in: activationRoot,
                fileManager: fileManager
            )
            try activationCheckpoint(.originalAssetMoved(directoryName))
        }
    }

    private func installPreparedAssets(
        from preparedRoot: URL,
        journal: inout RestoreActivationJournal
    ) throws {
        let assetsRoot = preparedRoot.appendingPathComponent(
            Self.preparedAssetsDirectoryName,
            isDirectory: true
        )
        for index in journal.directories.indices {
            let directoryName = journal.directories[index].name
            let source = assetsRoot.appendingPathComponent(directoryName, isDirectory: true)
            journal.directories[index].phase = .installingReplacement
            try InterruptedRestoreRecovery.writeJournal(
                journal,
                in: activationRoot,
                fileManager: fileManager
            )
            if fileManager.fileExists(atPath: source.path) {
                try fileManager.copyItem(
                    at: source,
                    to: appStorageRoot.appendingPathComponent(directoryName, isDirectory: true)
                )
            }
            journal.directories[index].phase = .replacementInstalled
            try InterruptedRestoreRecovery.writeJournal(
                journal,
                in: activationRoot,
                fileManager: fileManager
            )
            try activationCheckpoint(.replacementAssetInstalled(directoryName))
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

    private func rollbackActivation(databaseURL: URL) -> Bool {
        do {
            guard let journal = try InterruptedRestoreRecovery.readJournalIfPresent(
                in: activationRoot,
                fileManager: fileManager
            ) else {
                try removeIfPresent(activationRoot)
                try database.verifyIntegrity()
                return true
            }
            if journal.phase == .committed {
                try removeIfPresent(activationRoot)
                return true
            }
            if journal.phase.requiresDatabaseRollback,
               fileManager.fileExists(atPath: databaseURL.path) {
                try database.replaceContents(from: databaseURL)
            }
            try InterruptedRestoreRecovery.restoreAssets(
                journal: journal,
                appStorageRoot: appStorageRoot,
                activationRoot: activationRoot,
                fileManager: fileManager
            )
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

enum RestoreActivationCheckpoint: Equatable, Sendable {
    case rollbackDatabasePrepared
    case journalPrepared
    case originalAssetMoved(String)
    case replacementAssetInstalled(String)
    case databaseReplaced
    case committed
}

struct RestoreActivationJournal: Codable, Equatable, Sendable {
    static let currentVersion = 2

    let version: Int
    var phase: RestoreActivationPhase
    var directories: [RestoreActivationDirectoryState]

    init(
        phase: RestoreActivationPhase,
        directories: [RestoreActivationDirectoryState],
        version: Int = currentVersion
    ) {
        self.version = version
        self.phase = phase
        self.directories = directories
    }
}

enum RestoreActivationPhase: String, Codable, Equatable, Sendable {
    case preparingAssets
    case replacingDatabase
    case databaseReplaced
    case committed

    var requiresDatabaseRollback: Bool {
        self == .replacingDatabase || self == .databaseReplaced
    }
}

struct RestoreActivationDirectoryState: Codable, Equatable, Sendable {
    let name: String
    let originallyExisted: Bool
    var phase: RestoreActivationDirectoryPhase
}

enum RestoreActivationDirectoryPhase: String, Codable, Equatable, Sendable {
    case untouched
    case movingOriginal
    case originalMoved
    case installingReplacement
    case replacementInstalled

    var mayContainReplacement: Bool {
        self == .installingReplacement || self == .replacementInstalled
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
        guard let journal = try readJournalIfPresent(
            in: activationRoot,
            fileManager: fileManager
        ) else {
            if fileManager.fileExists(atPath: activationRoot.path) {
                try fileManager.removeItem(at: activationRoot)
            }
            return
        }
        guard journal.version == RestoreActivationJournal.currentVersion else {
            throw RestoreOperationError(category: .activationFailed, didRollBack: false)
        }
        if journal.phase == .committed {
            try fileManager.removeItem(at: activationRoot)
            return
        }

        let rollbackDatabaseURL = activationRoot.appendingPathComponent(rollbackDatabaseName)
        guard !journal.phase.requiresDatabaseRollback
                || fileManager.fileExists(atPath: rollbackDatabaseURL.path) else {
            throw RestoreOperationError(category: .activationFailed, didRollBack: false)
        }
        if journal.phase.requiresDatabaseRollback {
            for suffix in ["", "-wal", "-shm"] {
                let activeFile = URL(fileURLWithPath: databaseURL.path + suffix)
                if fileManager.fileExists(atPath: activeFile.path) {
                    try fileManager.removeItem(at: activeFile)
                }
            }
            try fileManager.copyItem(at: rollbackDatabaseURL, to: databaseURL)
        }
        try restoreAssets(
            journal: journal,
            appStorageRoot: appStorageRoot,
            activationRoot: activationRoot,
            fileManager: fileManager
        )
        try fileManager.removeItem(at: activationRoot)
    }

    static func writeJournal(
        _ journal: RestoreActivationJournal,
        in activationRoot: URL,
        fileManager _: FileManager
    ) throws {
        let data = try JSONEncoder().encode(journal)
        try data.write(
            to: activationRoot.appendingPathComponent(journalName),
            options: .atomic
        )
    }

    static func readJournalIfPresent(
        in activationRoot: URL,
        fileManager: FileManager
    ) throws -> RestoreActivationJournal? {
        let journalURL = activationRoot.appendingPathComponent(journalName)
        guard fileManager.fileExists(atPath: journalURL.path) else { return nil }
        return try JSONDecoder().decode(
            RestoreActivationJournal.self,
            from: Data(contentsOf: journalURL)
        )
    }

    static func restoreAssets(
        journal: RestoreActivationJournal,
        appStorageRoot: URL,
        activationRoot: URL,
        fileManager: FileManager
    ) throws {
        let rollbackAssetsRoot = activationRoot.appendingPathComponent(
            rollbackAssetsDirectoryName,
            isDirectory: true
        )
        for state in journal.directories {
            guard managedAssetDirectories.contains(state.name) else {
                throw RestoreOperationError(category: .activationFailed, didRollBack: false)
            }
            let activeURL = appStorageRoot.appendingPathComponent(state.name, isDirectory: true)
            let rollbackURL = rollbackAssetsRoot.appendingPathComponent(state.name, isDirectory: true)
            let hasRollback = fileManager.fileExists(atPath: rollbackURL.path)

            if state.originallyExisted {
                if hasRollback {
                    if fileManager.fileExists(atPath: activeURL.path) {
                        try fileManager.removeItem(at: activeURL)
                    }
                    try fileManager.copyItem(at: rollbackURL, to: activeURL)
                } else if state.phase != .untouched && state.phase != .movingOriginal {
                    throw RestoreOperationError(category: .activationFailed, didRollBack: false)
                }
            } else if state.phase.mayContainReplacement,
                      fileManager.fileExists(atPath: activeURL.path) {
                try fileManager.removeItem(at: activeURL)
            }
        }
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
