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

        let manifest = try fixture.decodeManifest(at: package.manifestURL)
        XCTAssertEqual(manifest.databaseSchemaVersion, "0027_add_order_ingredient_costs")
        XCTAssertEqual(
            manifest.assets.map(\.originalRelativePath),
            ["Branding/custom-logo.jpg", "OrderPhotos/design.jpg"]
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
        let service = fixture.service { _ in
            try fixture.write(Data("after".utf8), to: "OrderPhotos/design.jpg")
        }

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
        didCopyAsset: @escaping @Sendable (String) throws -> Void = { _ in }
    ) -> AppSnapshotService {
        AppSnapshotService(
            database: database,
            appStorageRoot: appStorageRoot,
            stagingRoot: stagingRoot,
            minimumCompatibleAppVersion: "1.0",
            currentAppVersion: "1.0",
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
