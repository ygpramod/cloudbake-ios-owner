import Foundation
import XCTest
@testable import CloudBakeOwner

final class ManualBackupServiceTests: XCTestCase {
    func testPrepareBackupExportsCreatedSnapshotWithPrivateSafeFilename() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("manifest".utf8).write(
            to: directory.appendingPathComponent("manifest.json")
        )
        try Data("database".utf8).write(
            to: directory.appendingPathComponent("database.sqlite")
        )
        let assets = directory.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try Data("photo-bytes".utf8).write(to: assets.appendingPathComponent("photo.asset"))
        try Data("logo-bytes".utf8).write(to: assets.appendingPathComponent("logo.asset"))
        let extraction = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: extraction)
            let parent = directory.deletingLastPathComponent()
            for child in (try? FileManager.default.contentsOfDirectory(
                at: parent,
                includingPropertiesForKeys: nil
            )) ?? [] where child.pathExtension == "cloudbakebackup" {
                try? FileManager.default.removeItem(at: child)
            }
        }
        let package = AppSnapshotPackage(
            generationID: "opaque-generation",
            directoryURL: directory,
            manifestURL: directory.appendingPathComponent("manifest.json"),
            databaseURL: directory.appendingPathComponent("database.sqlite")
        )
        let service = ManualBackupService(
            snapshotCreator: ManualBackupSnapshotCreator(package: package),
            dateProvider: { Date(timeIntervalSince1970: 1_783_800_000) }
        )

        let export = try await service.prepareBackup()

        XCTAssertTrue(FileManager.default.fileExists(atPath: export.packageURL.path))
        XCTAssertEqual(export.packageURL.pathExtension, "cloudbakebackup")
        XCTAssertTrue(export.filename.hasPrefix("cloudbake-backup-"))
        XCTAssertTrue(export.filename.hasSuffix(".cloudbakebackup"))
        XCTAssertFalse(export.filename.contains("opaque-generation"))

        try ZIPManualBackupArchiver().extractArchive(
            at: export.packageURL,
            to: extraction
        )
        XCTAssertEqual(
            Set(try FileManager.default.contentsOfDirectory(atPath: extraction.path)),
            ["Assets", "database.sqlite", "manifest.json"]
        )
        XCTAssertEqual(
            try Data(contentsOf: extraction.appendingPathComponent("manifest.json")),
            Data("manifest".utf8)
        )
        XCTAssertEqual(
            try Data(contentsOf: extraction.appendingPathComponent("database.sqlite")),
            Data("database".utf8)
        )
        XCTAssertEqual(
            try Data(contentsOf: extraction.appendingPathComponent("Assets/photo.asset")),
            Data("photo-bytes".utf8)
        )
        XCTAssertEqual(
            try Data(contentsOf: extraction.appendingPathComponent("Assets/logo.asset")),
            Data("logo-bytes".utf8)
        )
    }

    func testArchiveFailureRemovesPartialExport() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let directory = root.appendingPathComponent("generation", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let package = AppSnapshotPackage(
            generationID: "opaque-generation",
            directoryURL: directory,
            manifestURL: directory.appendingPathComponent("manifest.json"),
            databaseURL: directory.appendingPathComponent("database.sqlite")
        )
        let date = Date(timeIntervalSince1970: 1_783_800_000)
        let service = ManualBackupService(
            snapshotCreator: ManualBackupSnapshotCreator(package: package),
            dateProvider: { date },
            archiver: FailingManualBackupArchiver()
        )
        let expectedArchive = root.appendingPathComponent(
            ManualBackupService.filename(for: date)
        )

        do {
            _ = try await service.prepareBackup()
            XCTFail("Expected archive failure")
        } catch TestError.failed {
            XCTAssertFalse(FileManager.default.fileExists(atPath: expectedArchive.path))
        }
    }

    func testManualBackupExportRemovesArchiveAndSnapshotStaging() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let snapshot = root.appendingPathComponent("snapshot", isDirectory: true)
        let archive = root.appendingPathComponent("backup.cloudbakebackup")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        try Data("private backup".utf8).write(to: archive)
        let export = ManualBackupExport(
            packageURL: archive,
            stagingDirectoryURL: snapshot,
            filename: archive.lastPathComponent
        )

        export.removeStagedFiles()

        XCTAssertFalse(FileManager.default.fileExists(atPath: archive.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: snapshot.path))
        try? FileManager.default.removeItem(at: root)
    }

    @MainActor
    func testSettingsPreparationPublishesExportOnlyAfterServiceSucceeds() async throws {
        let database = try AppDatabase.makeInMemory()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let export = ManualBackupExport(
            packageURL: directory,
            stagingDirectoryURL: directory.appendingPathComponent("snapshot"),
            filename: "cloudbake-backup.cloudbakebackup"
        )
        let viewModel = SettingsViewModel(
            repository: database.makeCoreDataRepository(),
            manualBackupService: ManualBackupPreparingStub(result: .success(export))
        )

        let prepared = await viewModel.prepareManualBackup()

        XCTAssertEqual(prepared?.packageURL, directory)
        XCTAssertEqual(prepared?.filename, export.filename)
        XCTAssertEqual(
            viewModel.statusMessage,
            "Backup is ready. Choose a safe location to save it."
        )
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isPreparingBackup)
    }

    @MainActor
    func testSettingsPreparationFailureCannotClaimBackupSuccess() async throws {
        let database = try AppDatabase.makeInMemory()
        let viewModel = SettingsViewModel(
            repository: database.makeCoreDataRepository(),
            manualBackupService: ManualBackupPreparingStub(result: .failure(TestError.failed))
        )

        let prepared = await viewModel.prepareManualBackup()

        XCTAssertNil(prepared)
        XCTAssertNil(viewModel.statusMessage)
        XCTAssertEqual(
            viewModel.errorMessage,
            "CloudBake could not create a complete backup. No backup was saved."
        )
        XCTAssertFalse(viewModel.isPreparingBackup)
    }
}

private struct ManualBackupSnapshotCreator: AppSnapshotCreating {
    let package: AppSnapshotPackage

    func createSnapshot() async throws -> AppSnapshotPackage {
        package
    }
}

private struct ManualBackupPreparingStub: ManualBackupPreparing {
    let result: Result<ManualBackupExport, Error>

    func prepareBackup() async throws -> ManualBackupExport {
        try result.get()
    }
}

private enum TestError: Error {
    case failed
}

private struct FailingManualBackupArchiver: ManualBackupArchiving {
    func archivePackage(at sourceURL: URL, to destinationURL: URL) throws {
        try Data("partial".utf8).write(to: destinationURL)
        throw TestError.failed
    }
}
