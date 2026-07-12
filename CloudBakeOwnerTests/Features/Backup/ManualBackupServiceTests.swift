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
        defer {
            try? FileManager.default.removeItem(at: directory)
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
    }

    @MainActor
    func testSettingsPreparationPublishesExportOnlyAfterServiceSucceeds() async throws {
        let database = try AppDatabase.makeInMemory()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let export = ManualBackupExport(
            packageURL: directory,
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
