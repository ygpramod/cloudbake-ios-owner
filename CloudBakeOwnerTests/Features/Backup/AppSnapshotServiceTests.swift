import Foundation
import GRDB
import XCTest
@testable import CloudBakeOwner

final class AppSnapshotServiceTests: XCTestCase {
    func testSnapshotCapturesConsistentDatabaseAndManagedAssets() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let repository = fixture.database.makeCoreDataRepository()
        try fixture.write(Data("design".utf8), to: "OrderPhotos/design.jpg")
        try fixture.write(Data("logo".utf8), to: "Branding/custom-logo.jpg")
        try repository.save(fixture.design(id: "captured", photoReference: "OrderPhotos/design.jpg"))
        try repository.save(fixture.design(id: "external", photoReference: "photos://asset-id"))

        let service = fixture.service(didCaptureDatabase: {
            try repository.save(fixture.design(id: "created-later", photoReference: nil))
        })
        let package = try await service.createSnapshot()

        let snapshotQueue = try DatabaseQueue(path: package.databaseURL.path)
        let designIDs = try await snapshotQueue.read { db in
            try String.fetchAll(db, sql: "SELECT id FROM cake_designs ORDER BY id")
        }
        XCTAssertEqual(designIDs, ["captured", "external"])
        let recoveredExternalReference = try await snapshotQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT photo_reference FROM cake_designs WHERE id = 'external'"
            )
        }
        XCTAssertNotNil(recoveredExternalReference)
        XCTAssertFalse(try XCTUnwrap(recoveredExternalReference).hasPrefix("photos://"))

        let manifest = try fixture.decodeManifest(at: package.manifestURL)
        XCTAssertEqual(manifest.databaseSchemaVersion, "0027_add_order_ingredient_costs")
        XCTAssertEqual(
            manifest.assets.map(\.originalRelativePath),
            [
                "Branding/custom-logo.jpg",
                "OrderPhotos/design.jpg",
                try XCTUnwrap(recoveredExternalReference)
            ].sorted()
        )
        let designAsset = try XCTUnwrap(
            manifest.assets.first { $0.originalRelativePath == "OrderPhotos/design.jpg" }
        )
        XCTAssertFalse(designAsset.file.relativePath.contains("design"))
        XCTAssertEqual(
            try Data(contentsOf: package.directoryURL.appendingPathComponent(designAsset.file.relativePath)),
            Data("design".utf8)
        )
        try await service.validatePackage(at: package.directoryURL)
    }

    func testValidationDetectsPayloadCorruption() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let package = try await fixture.service().createSnapshot()
        try Data("corrupt".utf8).write(to: package.databaseURL)

        do {
            try await fixture.service().validatePackage(at: package.directoryURL)
            XCTFail("Expected package validation to fail")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .payloadSizeMismatch("database.sqlite"))
        }
    }

    func testValidationDetectsSameSizePayloadModification() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let package = try await fixture.service().createSnapshot()
        let manifest = try fixture.decodeManifest(at: package.manifestURL)
        try Data(repeating: 0xA5, count: Int(manifest.database.byteCount)).write(to: package.databaseURL)

        do {
            try await fixture.service().validatePackage(at: package.directoryURL)
            XCTFail("Expected package validation to fail")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .payloadChecksumMismatch("database.sqlite"))
        }
    }

    func testValidationRejectsOverflowingManifestSizesWithoutReadingPayloads() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let packageURL = fixture.root.appendingPathComponent("HostilePackage", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        let json = """
            {
              "formatVersion": 1,
              "databaseSchemaVersion": "0027_add_order_ingredient_costs",
              "minimumCompatibleAppVersion": "1.0",
              "generationID": "hostile",
              "createdAt": "2027-01-15T08:00:00Z",
              "database": {"relativePath":"database.sqlite","byteCount":9223372036854775807,"sha256":"db"},
              "assets": [{"originalRelativePath":"asset.jpg","file":{"relativePath":"Assets/a.asset","byteCount":1,"sha256":"asset"}}],
              "totalByteCount": 0
            }
            """
        try Data(json.utf8).write(
            to: packageURL.appendingPathComponent(AppSnapshotService.manifestFilename)
        )

        do {
            try await fixture.service().validatePackage(at: packageURL)
            XCTFail("Expected invalid sizes to fail validation")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .invalidPayloadSize("manifest.json"))
        }
    }

    func testValidationRejectsSymlinkPayload() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let package = try await fixture.service().createSnapshot()
        let externalFile = fixture.root.appendingPathComponent("external.sqlite")
        try FileManager.default.copyItem(at: package.databaseURL, to: externalFile)
        try FileManager.default.removeItem(at: package.databaseURL)
        try FileManager.default.createSymbolicLink(
            at: package.databaseURL,
            withDestinationURL: externalFile
        )

        do {
            try await fixture.service().validatePackage(at: package.directoryURL)
            XCTFail("Expected symlink payload to fail validation")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .missingPayload("database.sqlite"))
        }
    }

    func testUnavailableExternalPhotoFailsSnapshotAndCleansStaging() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.database.makeCoreDataRepository().save(
            fixture.design(id: "external", photoReference: "photos://missing")
        )

        do {
            _ = try await fixture.service(
                externalAssetResolver: UnavailableExternalAssetResolver()
            ).createSnapshot()
            XCTFail("Expected missing PhotoKit asset to fail snapshot creation")
        } catch let error as BackupExternalAssetResolverError {
            XCTAssertEqual(error, .assetUnavailable)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.stagingRoot.path), [])
    }

    func testMissingReferencedAssetFailsAndRemovesBuildingDirectory() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.database.makeCoreDataRepository().save(
            fixture.design(id: "missing", photoReference: "OrderPhotos/missing.jpg")
        )

        do {
            _ = try await fixture.service().createSnapshot()
            XCTFail("Expected missing asset to fail snapshot creation")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .assetMissing("OrderPhotos/missing.jpg"))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.stagingRoot.path), [])
    }

    func testAssetChangedDuringStagingFailsAndRemovesBuildingDirectory() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.write(Data("before".utf8), to: "OrderPhotos/design.jpg")
        try fixture.database.makeCoreDataRepository().save(
            fixture.design(id: "changing", photoReference: "OrderPhotos/design.jpg")
        )
        let service = fixture.service(didCopyAsset: { _ in
            try fixture.write(Data("after".utf8), to: "OrderPhotos/design.jpg")
        })

        do {
            _ = try await service.createSnapshot()
            XCTFail("Expected changing asset to fail snapshot creation")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .assetChanged("OrderPhotos/design.jpg"))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.stagingRoot.path), [])
    }

    func testCleanupOnlyRemovesAbandonedBuildingDirectories() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let abandoned = fixture.stagingRoot.appendingPathComponent("old.building")
        let finalized = fixture.stagingRoot.appendingPathComponent("published")
        try FileManager.default.createDirectory(at: abandoned, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: finalized, withIntermediateDirectories: true)

        try await fixture.service().cleanAbandonedStagingDirectories()

        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalized.path))
    }
}

private final class Fixture: @unchecked Sendable {
    let root: URL
    let appStorageRoot: URL
    let stagingRoot: URL
    let database: AppDatabase

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        appStorageRoot = root.appendingPathComponent("ApplicationSupport/CloudBakeOwner", isDirectory: true)
        stagingRoot = root.appendingPathComponent("BackupStaging", isDirectory: true)
        try FileManager.default.createDirectory(at: appStorageRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        database = try AppDatabase.makeInMemory()
    }

    func service(
        didCaptureDatabase: @escaping @Sendable () throws -> Void = {},
        didCopyAsset: @escaping @Sendable (String) throws -> Void = { _ in },
        externalAssetResolver: any BackupExternalAssetResolving = FakeExternalAssetResolver()
    ) -> AppSnapshotService {
        AppSnapshotService(
            database: database,
            appStorageRoot: appStorageRoot,
            stagingRoot: stagingRoot,
            minimumCompatibleAppVersion: "1.0",
            currentAppVersion: "1.0",
            externalAssetResolver: externalAssetResolver,
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            makeGenerationID: { "generation-1" },
            didCaptureDatabase: didCaptureDatabase,
            didCopyAsset: didCopyAsset
        )
    }

    func design(id: String, photoReference: String?) -> CakeDesign {
        CakeDesign(
            id: id,
            name: id,
            notes: nil,
            photoReference: photoReference,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    func write(_ data: Data, to relativePath: String) throws {
        let url = appStorageRoot.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }

    func decodeManifest(at url: URL) throws -> BackupManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupManifest.self, from: Data(contentsOf: url))
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private struct FakeExternalAssetResolver: BackupExternalAssetResolving {
    func resolve(reference: String) async throws -> BackupResolvedExternalAsset {
        guard reference == "photos://asset-id" else {
            throw BackupExternalAssetResolverError.assetUnavailable
        }
        return BackupResolvedExternalAsset(
            data: Data("external-photo".utf8),
            modificationDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

private struct UnavailableExternalAssetResolver: BackupExternalAssetResolving {
    func resolve(reference: String) async throws -> BackupResolvedExternalAsset {
        throw BackupExternalAssetResolverError.assetUnavailable
    }
}
