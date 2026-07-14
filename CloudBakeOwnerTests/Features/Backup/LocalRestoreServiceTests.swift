import Foundation
import XCTest
@testable import CloudBakeOwner

final class LocalRestoreServiceTests: XCTestCase {
    func testLogoOnlyInstallationRequiresReplacementConfirmation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appStorageRoot = root.appendingPathComponent("CloudBakeOwner", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: appStorageRoot, withIntermediateDirectories: true)
        let database = try AppDatabase.open(
            at: appStorageRoot.appendingPathComponent("cloudbake-owner.sqlite")
        )
        defer { try? database.close() }
        let service = LocalRestoreService(
            database: database,
            snapshotCreator: UnusedRestoreSnapshotCreator(),
            appStorageRoot: appStorageRoot,
            activationRoot: root.appendingPathComponent("Activation", isDirectory: true)
        )

        let initiallyHasData = try await service.hasOwnerData()
        XCTAssertFalse(initiallyHasData)

        let logoURL = appStorageRoot.appendingPathComponent("Branding/custom-logo.jpg")
        try FileManager.default.createDirectory(
            at: logoURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("custom-logo".utf8).write(to: logoURL)

        let hasLogoData = try await service.hasOwnerData()
        XCTAssertTrue(hasLogoData)
    }

    func testPreparationErrorsKeepStorageAndTransientFailuresFatal() {
        let noSpace = NSError(
            domain: NSCocoaErrorDomain,
            code: CocoaError.fileWriteOutOfSpace.rawValue
        )
        XCTAssertEqual(
            RestoreLocalFileErrorMapper.category(for: noSpace),
            .insufficientStorage
        )
        XCTAssertEqual(
            RestoreLocalFileErrorMapper.category(for: CocoaError(.fileReadUnknown)),
            .unknown
        )
    }

    func testPreparedSnapshotAtomicallyReplacesDatabaseAndAssets() async throws {
        let fixture = try LocalRestoreFixture()
        defer { fixture.remove() }
        let downloaded = try fixture.makeDownloadedSnapshot(includeAsset: true)

        let prepared = try await fixture.service.prepare(downloaded)
        XCTAssertTrue(prepared.brokenAssets.isEmpty)
        try await fixture.service.activate(
            prepared,
            rollbackSnapshot: try fixture.makeRollbackSnapshot()
        )

        let customers = try fixture.activeDatabase.makeCoreDataRepository().fetchCustomers()
        XCTAssertEqual(customers.map(\.id), ["cloud-customer"])
        XCTAssertEqual(
            try Data(contentsOf: fixture.appStorageRoot.appendingPathComponent(fixture.photoPath)),
            Data("cloud-photo".utf8)
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.activationRoot.path))
    }

    func testBrokenAssetCanRemoveDatabaseReferencesBeforeActivation() async throws {
        let fixture = try LocalRestoreFixture()
        defer { fixture.remove() }
        let downloaded = try fixture.makeDownloadedSnapshot(includeAsset: false)

        let prepared = try await fixture.service.prepare(downloaded)
        XCTAssertEqual(
            prepared.brokenAssets,
            [BrokenRestoreAsset(originalRelativePath: fixture.photoPath)]
        )
        let repaired = try await fixture.service.applyBrokenAssetDecision(
            .removeReferences,
            to: prepared
        )
        try await fixture.service.activate(
            repaired,
            rollbackSnapshot: try fixture.makeRollbackSnapshot()
        )

        let design = try fixture.activeDatabase.makeCoreDataRepository().fetchCakeDesign(id: "cloud-design")
        XCTAssertNil(design?.photoReference)
    }

    func testUnreadableAssetFailsPreparationInsteadOfBeingReportedAsBroken() async throws {
        let fixture = try LocalRestoreFixture()
        defer { fixture.remove() }
        let downloaded = try fixture.makeDownloadedSnapshot(includeAsset: true)
        let assetURL = downloaded.directoryURL.appendingPathComponent("Assets/photo.asset")
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: assetURL.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: assetURL.path
            )
        }

        do {
            _ = try await fixture.service.prepare(downloaded)
            XCTFail("Expected unreadable local storage to stop preparation")
        } catch let error as RestoreOperationError {
            XCTAssertEqual(error.category, .unknown)
            XCTAssertFalse(error.didRollBack)
        }
    }

    func testActivationFailureRestoresPreviousDatabaseAndAssets() async throws {
        let fixture = try LocalRestoreFixture(failAfterDatabaseReplacement: true)
        defer { fixture.remove() }
        let downloaded = try fixture.makeDownloadedSnapshot(includeAsset: true)
        let prepared = try await fixture.service.prepare(downloaded)

        do {
            try await fixture.service.activate(
                prepared,
                rollbackSnapshot: try fixture.makeRollbackSnapshot()
            )
            XCTFail("Expected activation to fail")
        } catch let error as RestoreOperationError {
            XCTAssertEqual(error, RestoreOperationError(category: .activationFailed, didRollBack: true))
        }

        let customers = try fixture.activeDatabase.makeCoreDataRepository().fetchCustomers()
        XCTAssertEqual(customers.map(\.id), ["local-customer"])
        XCTAssertEqual(
            try Data(contentsOf: fixture.appStorageRoot.appendingPathComponent(fixture.photoPath)),
            Data("local-photo".utf8)
        )
    }

    func testStartupRecoveryRollsBackInterruptedActivationBeforeDatabaseOpen() throws {
        let fixture = try InterruptedRestoreFixture()
        defer { fixture.remove() }

        try InterruptedRestoreRecovery.recoverIfNeeded(
            appStorageRoot: fixture.appStorageRoot,
            databaseURL: fixture.activeDatabaseURL,
            activationRoot: fixture.activationRoot
        )

        let recovered = try AppDatabase.open(at: fixture.activeDatabaseURL)
        defer { try? recovered.close() }
        XCTAssertEqual(
            try recovered.makeCoreDataRepository().fetchCustomers().map(\.id),
            ["local-customer"]
        )
        XCTAssertEqual(
            try Data(contentsOf: fixture.appStorageRoot.appendingPathComponent("OrderPhotos/local.jpg")),
            Data("local-photo".utf8)
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.activationRoot.path))

        try InterruptedRestoreRecovery.recoverIfNeeded(
            appStorageRoot: fixture.appStorageRoot,
            databaseURL: fixture.activeDatabaseURL,
            activationRoot: fixture.activationRoot
        )
    }

    func testEveryActivationBoundaryPreservesPreviousDatabaseAndAssets() async throws {
        let checkpoints: [RestoreActivationCheckpoint] = [
            .rollbackDatabasePrepared,
            .journalPrepared,
            .originalAssetMoved("Branding"),
            .originalAssetMoved("OrderPhotos"),
            .originalAssetMoved("RecoveredPhotos"),
            .replacementAssetInstalled("Branding"),
            .replacementAssetInstalled("OrderPhotos"),
            .replacementAssetInstalled("RecoveredPhotos"),
            .databaseReplaced,
            .committed
        ]

        for checkpoint in checkpoints {
            let fixture = try LocalRestoreFixture(failAt: checkpoint)
            defer { fixture.remove() }
            let prepared = try await fixture.service.prepare(
                fixture.makeDownloadedSnapshot(includeAsset: true)
            )

            do {
                try await fixture.service.activate(
                    prepared,
                    rollbackSnapshot: try fixture.makeRollbackSnapshot()
                )
                XCTFail("Expected activation to fail at \(checkpoint)")
            } catch let error as RestoreOperationError {
                XCTAssertTrue(error.didRollBack, "Expected rollback at \(checkpoint)")
            }

            XCTAssertEqual(
                try fixture.activeDatabase.makeCoreDataRepository().fetchCustomers().map(\.id),
                ["local-customer"],
                "Database changed at \(checkpoint)"
            )
            XCTAssertEqual(
                try Data(contentsOf: fixture.appStorageRoot.appendingPathComponent(fixture.photoPath)),
                Data("local-photo".utf8),
                "Photo changed at \(checkpoint)"
            )
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: fixture.appStorageRoot.appendingPathComponent("Branding").path
                ),
                "Originally absent Branding directory appeared at \(checkpoint)"
            )
        }
    }

    func testAssetRecoveryIsRepeatableAndRemovesOriginallyAbsentReplacement() throws {
        let fixture = try InterruptedRestoreFixture(includeOriginallyAbsentReplacement: true)
        defer { fixture.remove() }

        try InterruptedRestoreRecovery.restoreAssets(
            journal: fixture.journal,
            appStorageRoot: fixture.appStorageRoot,
            activationRoot: fixture.activationRoot,
            fileManager: .default
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: fixture.appStorageRoot.appendingPathComponent("Branding").path
            )
        )

        let repeatedCloudPhoto = fixture.appStorageRoot.appendingPathComponent("OrderPhotos/cloud.jpg")
        try FileManager.default.removeItem(
            at: fixture.appStorageRoot.appendingPathComponent("OrderPhotos")
        )
        try FileManager.default.createDirectory(
            at: repeatedCloudPhoto.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("cloud-photo-again".utf8).write(to: repeatedCloudPhoto)

        try InterruptedRestoreRecovery.restoreAssets(
            journal: fixture.journal,
            appStorageRoot: fixture.appStorageRoot,
            activationRoot: fixture.activationRoot,
            fileManager: .default
        )
        XCTAssertEqual(
            try Data(contentsOf: fixture.appStorageRoot.appendingPathComponent("OrderPhotos/local.jpg")),
            Data("local-photo".utf8)
        )
    }

    func testStartupRecoveryKeepsCommittedStateAndOnlyRemovesRecoveryFiles() throws {
        let fixture = try InterruptedRestoreFixture(phase: .committed)
        defer { fixture.remove() }

        try InterruptedRestoreRecovery.recoverIfNeeded(
            appStorageRoot: fixture.appStorageRoot,
            databaseURL: fixture.activeDatabaseURL,
            activationRoot: fixture.activationRoot
        )

        let database = try AppDatabase.open(at: fixture.activeDatabaseURL)
        defer { try? database.close() }
        XCTAssertEqual(
            try database.makeCoreDataRepository().fetchCustomers().map(\.id),
            ["cloud-customer"]
        )
        XCTAssertEqual(
            try Data(contentsOf: fixture.appStorageRoot.appendingPathComponent("OrderPhotos/cloud.jpg")),
            Data("cloud-photo".utf8)
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.activationRoot.path))
    }
}

private final class LocalRestoreFixture: @unchecked Sendable {
    let root: URL
    let appStorageRoot: URL
    let activationRoot: URL
    let photoPath = "OrderPhotos/cloud/order.jpg"
    let activeDatabase: AppDatabase
    private(set) var service: LocalRestoreService!

    init(
        failAfterDatabaseReplacement: Bool = false,
        failAt checkpointToFail: RestoreActivationCheckpoint? = nil
    ) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        appStorageRoot = root.appendingPathComponent("CloudBakeOwner", isDirectory: true)
        activationRoot = root.appendingPathComponent("Activation", isDirectory: true)
        try FileManager.default.createDirectory(at: appStorageRoot, withIntermediateDirectories: true)
        activeDatabase = try AppDatabase.open(
            at: appStorageRoot.appendingPathComponent("cloudbake-owner.sqlite")
        )
        try activeDatabase.makeCoreDataRepository().save(customer(id: "local-customer"))
        try write(Data("local-photo".utf8), to: photoPath)
        let snapshotCreator = FixedSnapshotCreator(package: try makeRollbackSnapshot())
        service = LocalRestoreService(
            database: activeDatabase,
            snapshotCreator: snapshotCreator,
            appStorageRoot: appStorageRoot,
            activationRoot: activationRoot,
            didReplaceDatabase: {
                if failAfterDatabaseReplacement { throw InjectedRestoreFailure() }
            },
            activationCheckpoint: { checkpoint in
                if checkpoint == checkpointToFail { throw InjectedRestoreFailure() }
            }
        )
    }

    func makeDownloadedSnapshot(includeAsset: Bool) throws -> DownloadedRestoreSnapshot {
        let packageRoot = root.appendingPathComponent("Download", isDirectory: true)
        try? FileManager.default.removeItem(at: packageRoot)
        try FileManager.default.createDirectory(at: packageRoot, withIntermediateDirectories: true)

        let source = try AppDatabase.makeInMemory()
        let repository = source.makeCoreDataRepository()
        try repository.save(customer(id: "cloud-customer"))
        try repository.save(
            CakeDesign(
                id: "cloud-design",
                name: "Cloud design",
                notes: nil,
                photoReference: photoPath,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
        let databaseURL = packageRoot.appendingPathComponent("database.sqlite")
        try source.writeBackupSnapshot(to: databaseURL)
        let databaseDescriptor = try descriptor(at: databaseURL, relativePath: "database.sqlite")

        let opaquePath = "Assets/photo.asset"
        let opaqueURL = packageRoot.appendingPathComponent(opaquePath)
        let photoData = Data("cloud-photo".utf8)
        if includeAsset {
            try FileManager.default.createDirectory(
                at: opaqueURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try photoData.write(to: opaqueURL)
        }
        let assetDescriptor = BackupFileDescriptor(
            relativePath: opaquePath,
            byteCount: Int64(photoData.count),
            sha256: BackupChecksum.sha256(of: photoData)
        )
        let manifest = BackupManifest(
            databaseSchemaVersion: "0027_add_order_ingredient_costs",
            minimumCompatibleAppVersion: "1.0",
            generationID: "generation-1",
            createdAt: timestamp,
            database: databaseDescriptor,
            assets: [
                BackupAssetDescriptor(
                    originalRelativePath: photoPath,
                    file: assetDescriptor
                )
            ]
        )
        return DownloadedRestoreSnapshot(
            directoryURL: packageRoot,
            manifest: manifest,
            brokenAssets: includeAsset
                ? []
                : [BrokenRestoreAsset(originalRelativePath: photoPath)]
        )
    }

    func makeRollbackSnapshot() throws -> AppSnapshotPackage {
        let directory = root.appendingPathComponent("Rollback", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let databaseURL = directory.appendingPathComponent("database.sqlite")
        try activeDatabase.writeBackupSnapshot(to: databaseURL)
        let descriptor = try descriptor(at: databaseURL, relativePath: "database.sqlite")
        let manifest = BackupManifest(
            databaseSchemaVersion: "0027_add_order_ingredient_costs",
            minimumCompatibleAppVersion: "1.0",
            generationID: "rollback",
            createdAt: timestamp,
            database: descriptor,
            assets: []
        )
        return AppSnapshotPackage(
            generationID: "rollback",
            directoryURL: directory,
            manifestURL: directory.appendingPathComponent("manifest.json"),
            databaseURL: databaseURL,
            manifest: manifest
        )
    }

    func remove() {
        try? activeDatabase.close()
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ data: Data, to relativePath: String) throws {
        let url = appStorageRoot.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }
}

private final class InterruptedRestoreFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let appStorageRoot: URL
    let activationRoot: URL
    let activeDatabaseURL: URL
    let journal: RestoreActivationJournal

    init(
        includeOriginallyAbsentReplacement: Bool = false,
        phase: RestoreActivationPhase = .databaseReplaced
    ) throws {
        appStorageRoot = root.appendingPathComponent("CloudBakeOwner", isDirectory: true)
        activationRoot = root.appendingPathComponent("Activation", isDirectory: true)
        activeDatabaseURL = appStorageRoot.appendingPathComponent("cloudbake-owner.sqlite")
        try FileManager.default.createDirectory(at: appStorageRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: activationRoot, withIntermediateDirectories: true)

        try Self.writeDatabase(customerID: "cloud-customer", to: activeDatabaseURL)
        try Self.writeDatabase(
            customerID: "local-customer",
            to: activationRoot.appendingPathComponent(InterruptedRestoreRecovery.rollbackDatabaseName)
        )
        let activePhoto = appStorageRoot.appendingPathComponent("OrderPhotos/cloud.jpg")
        try FileManager.default.createDirectory(
            at: activePhoto.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("cloud-photo".utf8).write(to: activePhoto)
        let rollbackPhoto = activationRoot
            .appendingPathComponent(InterruptedRestoreRecovery.rollbackAssetsDirectoryName)
            .appendingPathComponent("OrderPhotos/local.jpg")
        try FileManager.default.createDirectory(
            at: rollbackPhoto.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("local-photo".utf8).write(to: rollbackPhoto)
        if includeOriginallyAbsentReplacement {
            let brandingPhoto = appStorageRoot.appendingPathComponent("Branding/cloud-logo.jpg")
            try FileManager.default.createDirectory(
                at: brandingPhoto.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("cloud-logo".utf8).write(to: brandingPhoto)
        }
        journal = RestoreActivationJournal(
            phase: phase,
            directories: [
                RestoreActivationDirectoryState(
                    name: "Branding",
                    originallyExisted: false,
                    phase: .replacementInstalled
                ),
                RestoreActivationDirectoryState(
                    name: "OrderPhotos",
                    originallyExisted: true,
                    phase: .replacementInstalled
                ),
                RestoreActivationDirectoryState(
                    name: "RecoveredPhotos",
                    originallyExisted: false,
                    phase: .replacementInstalled
                )
            ]
        )
        try InterruptedRestoreRecovery.writeJournal(
            journal,
            in: activationRoot,
            fileManager: .default
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    private static func writeDatabase(customerID: String, to url: URL) throws {
        let database = try AppDatabase.makeInMemory()
        try database.makeCoreDataRepository().save(customer(id: customerID))
        try database.writeBackupSnapshot(to: url)
    }
}

private struct FixedSnapshotCreator: AppSnapshotCreating {
    let package: AppSnapshotPackage

    func createSnapshot() async throws -> AppSnapshotPackage { package }
}

private struct UnusedRestoreSnapshotCreator: AppSnapshotCreating {
    func createSnapshot() async throws -> AppSnapshotPackage {
        fatalError("Snapshot creation is not expected in this test")
    }
}

private struct InjectedRestoreFailure: Error {}

private let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

private func customer(id: String) -> Customer {
    Customer(
        id: id,
        name: id,
        phone: "",
        email: nil,
        address: nil,
        likes: nil,
        dislikes: nil,
        allergies: nil,
        dietaryRestrictions: nil,
        notes: nil,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

private func descriptor(at url: URL, relativePath: String) throws -> BackupFileDescriptor {
    let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
    return BackupFileDescriptor(
        relativePath: relativePath,
        byteCount: size?.int64Value ?? -1,
        sha256: try BackupChecksum.sha256(of: url)
    )
}
