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
            databaseURL: directory.appendingPathComponent("database.sqlite"),
            manifest: makeManualBackupManifest()
        )
        let service = ManualBackupService(
            snapshotCreator: ManualBackupSnapshotCreator(package: package),
            omissionStore: ManualBackupOmissionStore(),
            unavailablePhotoRevalidator: ManualBackupPhotoRevalidator(),
            dateProvider: { Date(timeIntervalSince1970: 1_783_800_000) }
        )

        guard case .ready(let export) = try await service.prepareBackup() else {
            return XCTFail("Expected a ready manual backup")
        }

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
            databaseURL: directory.appendingPathComponent("database.sqlite"),
            manifest: makeManualBackupManifest()
        )
        let date = Date(timeIntervalSince1970: 1_783_800_000)
        let service = ManualBackupService(
            snapshotCreator: ManualBackupSnapshotCreator(package: package),
            omissionStore: ManualBackupOmissionStore(),
            unavailablePhotoRevalidator: ManualBackupPhotoRevalidator(),
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
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        }
    }

    func testUnavailablePhotosWaitForOneDecisionAndCancelChangesNothing() async throws {
        let root = try makeManualBackupRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let references = Set(["photos://missing-a", "photos://missing-b"])
        let snapshotCreator = RecoverableManualBackupSnapshotCreator(
            package: makeManualBackupPackage(at: root),
            unavailableReferences: references
        )
        let omissionStore = ManualBackupOmissionStore()
        let remover = ManualBackupAssetRemover(snapshotCreator: snapshotCreator)
        let service = ManualBackupService(
            snapshotCreator: snapshotCreator,
            omissionStore: omissionStore,
            unavailablePhotoRevalidator: ManualBackupPhotoRevalidator(),
            unavailableAssetRemover: remover,
            makeProposalID: { "photo-decision" },
            archiver: RecordingManualBackupArchiver()
        )

        guard case .requiresUnavailablePhotoDecision(let proposal) =
                try await service.prepareBackup() else {
            return XCTFail("Expected one unavailable-photo decision")
        }
        XCTAssertEqual(proposal.id, "photo-decision")
        XCTAssertEqual(proposal.unavailablePhotoCount, 2)

        await service.cancelUnavailablePhotoDecision(proposalID: proposal.id)

        XCTAssertTrue(omissionStore.loadApprovedDigests().isEmpty)
        XCTAssertTrue(remover.removedReferences.isEmpty)
        guard case .requiresUnavailablePhotoDecision =
                try await service.prepareBackup() else {
            return XCTFail("Expected cancellation to leave missing references unchanged")
        }
    }

    func testApprovedPhotoOmissionsCreateTruthfulManualExport() async throws {
        let root = try makeManualBackupRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let references = Set(["photos://missing-a", "photos://missing-b"])
        let snapshotCreator = RecoverableManualBackupSnapshotCreator(
            package: makeManualBackupPackage(at: root),
            unavailableReferences: references
        )
        let omissionStore = ManualBackupOmissionStore()
        let service = ManualBackupService(
            snapshotCreator: snapshotCreator,
            omissionStore: omissionStore,
            unavailablePhotoRevalidator: ManualBackupPhotoRevalidator(),
            makeProposalID: { "photo-decision" },
            archiver: RecordingManualBackupArchiver()
        )
        guard case .requiresUnavailablePhotoDecision(let proposal) =
                try await service.prepareBackup() else {
            return XCTFail("Expected an unavailable-photo decision")
        }

        guard case .ready(let export) =
                try await service.approveUnavailablePhotoOmissions(
                    proposalID: proposal.id
                ) else {
            return XCTFail("Expected approved omissions to create an export")
        }

        XCTAssertEqual(export.omittedAssetCount, 2)
        XCTAssertEqual(
            omissionStore.loadApprovedDigests(),
            Set(references.map {
                BackupChecksum.sha256(of: Data($0.utf8))
            })
        )
    }

    func testConfirmedPhotoRemovalDeletesExactReferencesBeforeRetry() async throws {
        let root = try makeManualBackupRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let references = Set(["photos://missing-a", "photos://missing-b"])
        let snapshotCreator = RecoverableManualBackupSnapshotCreator(
            package: makeManualBackupPackage(at: root),
            unavailableReferences: references
        )
        let omissionStore = ManualBackupOmissionStore()
        let remover = ManualBackupAssetRemover(snapshotCreator: snapshotCreator)
        let service = ManualBackupService(
            snapshotCreator: snapshotCreator,
            omissionStore: omissionStore,
            unavailablePhotoRevalidator: ManualBackupPhotoRevalidator(),
            unavailableAssetRemover: remover,
            makeProposalID: { "photo-decision" },
            archiver: RecordingManualBackupArchiver()
        )
        guard case .requiresUnavailablePhotoDecision(let proposal) =
                try await service.prepareBackup() else {
            return XCTFail("Expected an unavailable-photo decision")
        }

        guard case .ready(let export) = try await service.removeUnavailablePhotos(
            proposalID: proposal.id
        ) else {
            return XCTFail("Expected exact removal to create a fresh export")
        }

        XCTAssertEqual(remover.removedReferences, [references])
        XCTAssertTrue(omissionStore.loadApprovedDigests().isEmpty)
        XCTAssertEqual(export.omittedAssetCount, 0)
    }

    func testRestoredPhotoIsNotRemovedFromManualBackupReferences() async throws {
        let root = try makeManualBackupRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let references = Set(["photos://restored"])
        let snapshotCreator = RecoverableManualBackupSnapshotCreator(
            package: makeManualBackupPackage(at: root),
            unavailableReferences: references
        )
        let remover = ManualBackupAssetRemover(snapshotCreator: snapshotCreator)
        let service = ManualBackupService(
            snapshotCreator: snapshotCreator,
            omissionStore: ManualBackupOmissionStore(),
            unavailablePhotoRevalidator: ManualBackupPhotoRevalidator(
                availableReferences: references
            ),
            unavailableAssetRemover: remover,
            makeProposalID: { "photo-decision" },
            archiver: RecordingManualBackupArchiver()
        )
        guard case .requiresUnavailablePhotoDecision(let proposal) =
                try await service.prepareBackup() else {
            return XCTFail("Expected an unavailable-photo decision")
        }
        snapshotCreator.remove(references: references)

        guard case .ready = try await service.removeUnavailablePhotos(
            proposalID: proposal.id
        ) else {
            return XCTFail("Expected restored photo to remain linked")
        }

        XCTAssertTrue(remover.removedReferences.isEmpty)
    }

    func testPostRemovalPhotoAccessFailurePreservesSpecificGuidance() async throws {
        let root = try makeManualBackupRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let references = Set(["photos://missing"])
        let snapshotCreator = RecoverableManualBackupSnapshotCreator(
            package: makeManualBackupPackage(at: root),
            unavailableReferences: references,
            errorAfterRemoval: BackupExternalAssetResolverError.accessDenied
        )
        let service = ManualBackupService(
            snapshotCreator: snapshotCreator,
            omissionStore: ManualBackupOmissionStore(),
            unavailablePhotoRevalidator: ManualBackupPhotoRevalidator(),
            unavailableAssetRemover: ManualBackupAssetRemover(
                snapshotCreator: snapshotCreator
            ),
            makeProposalID: { "photo-decision" },
            archiver: RecordingManualBackupArchiver()
        )
        guard case .requiresUnavailablePhotoDecision(let proposal) =
                try await service.prepareBackup() else {
            return XCTFail("Expected an unavailable-photo decision")
        }

        do {
            _ = try await service.removeUnavailablePhotos(proposalID: proposal.id)
            XCTFail("Expected Photos access failure")
        } catch let error as ManualBackupServiceError {
            XCTAssertEqual(error, .photosAccessDeniedAfterPhotoRemoval)
        }
    }

    func testCancellingASecondManualPhotoDecisionReportsTheEarlierRemoval() async throws {
        let root = try makeManualBackupRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let firstReference = "photos://missing-first"
        let snapshotCreator = RecoverableManualBackupSnapshotCreator(
            package: makeManualBackupPackage(at: root),
            unavailableReferences: [firstReference],
            referencesAddedAfterRemoval: ["photos://missing-second"]
        )
        let service = ManualBackupService(
            snapshotCreator: snapshotCreator,
            omissionStore: ManualBackupOmissionStore(),
            unavailablePhotoRevalidator: ManualBackupPhotoRevalidator(),
            unavailableAssetRemover: ManualBackupAssetRemover(
                snapshotCreator: snapshotCreator
            ),
            makeProposalID: { UUID().uuidString },
            archiver: RecordingManualBackupArchiver()
        )
        guard case .requiresUnavailablePhotoDecision(let firstProposal) =
                try await service.prepareBackup() else {
            return XCTFail("Expected the first unavailable-photo decision")
        }
        guard case .requiresUnavailablePhotoDecision(let secondProposal) =
                try await service.removeUnavailablePhotos(
                    proposalID: firstProposal.id
                ) else {
            return XCTFail("Expected a second unavailable-photo decision")
        }

        let result = await service.cancelUnavailablePhotoDecision(
            proposalID: secondProposal.id
        )

        XCTAssertEqual(result, .cancelledAfterPhotoRemoval)
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
            filename: archive.lastPathComponent,
            omittedAssetCount: 0
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
            filename: "cloudbake-backup.cloudbakebackup",
            omittedAssetCount: 0
        )
        let viewModel = SettingsViewModel(
            repository: database.makeCoreDataRepository(),
            manualBackupService: ManualBackupPreparingStub(
                result: .success(.ready(export))
            )
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
    func testSettingsRefreshesSharedReminderScheduleAfterSuccessfulExport() async throws {
        let database = try AppDatabase.makeInMemory()
        let suiteName = "SettingsSharedReminderRefresh-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = ManualBackupPreferences(defaults: defaults)
        var refreshCount = 0
        let viewModel = SettingsViewModel(
            repository: database.makeCoreDataRepository(),
            manualBackupPreferences: preferences,
            refreshReminderSchedule: {
                refreshCount += 1
                preferences.reminderDeliveryStatus = .scheduled
            }
        )

        await viewModel.markManualBackupExported(
            at: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(viewModel.manualBackupReminderStatus, .scheduled)
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

    @MainActor
    func testSettingsPreparationDirectsRevokedPhotoAccessToPhotosSettings() async throws {
        let database = try AppDatabase.makeInMemory()
        let viewModel = SettingsViewModel(
            repository: database.makeCoreDataRepository(),
            manualBackupService: ManualBackupPreparingStub(
                result: .failure(BackupExternalAssetResolverError.accessDenied)
            )
        )

        let prepared = await viewModel.prepareManualBackup()

        XCTAssertNil(prepared)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Allow CloudBake full access to Photos in iPhone Settings, then try again."
        )
    }

    @MainActor
    func testSettingsReportsPhotoRemovalWhenLaterManualDecisionIsCancelled() async throws {
        let database = try AppDatabase.makeInMemory()
        let proposal = ManualBackupUnavailablePhotoProposal(
            id: "photo-decision",
            unavailablePhotoCount: 1,
            didRemoveUnavailablePhotoReferences: true
        )
        let service = ManualBackupPreparingSpy(
            initialResult: .requiresUnavailablePhotoDecision(proposal),
            decisionResult: .requiresUnavailablePhotoDecision(proposal),
            cancellationResult: .cancelledAfterPhotoRemoval
        )
        let viewModel = SettingsViewModel(
            repository: database.makeCoreDataRepository(),
            manualBackupService: service
        )
        _ = await viewModel.prepareManualBackup()

        await viewModel.cancelManualBackupPhotoDecision()

        XCTAssertEqual(
            viewModel.statusMessage,
            "The unavailable photo references were removed from CloudBake. The backup was cancelled."
        )
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testSettingsPreservesPhotoGuidanceAfterRemovalFailure() async throws {
        let database = try AppDatabase.makeInMemory()
        let viewModel = SettingsViewModel(
            repository: database.makeCoreDataRepository(),
            manualBackupService: ManualBackupPreparingStub(
                result: .failure(
                    ManualBackupServiceError.photosAccessDeniedAfterPhotoRemoval
                )
            )
        )

        _ = await viewModel.prepareManualBackup()

        XCTAssertEqual(
            viewModel.errorMessage,
            "The unavailable photo references were removed from CloudBake, but the backup did not complete. Allow CloudBake full access to Photos in iPhone Settings, then try again."
        )
    }

    @MainActor
    func testSettingsWaitsForPhotoDecisionAndReportsApprovedOmission() async throws {
        let database = try AppDatabase.makeInMemory()
        let proposal = ManualBackupUnavailablePhotoProposal(
            id: "photo-decision",
            unavailablePhotoCount: 2
        )
        let export = ManualBackupExport(
            packageURL: URL(fileURLWithPath: "/tmp/backup.cloudbakebackup"),
            stagingDirectoryURL: URL(fileURLWithPath: "/tmp/snapshot"),
            filename: "backup.cloudbakebackup",
            omittedAssetCount: 2
        )
        let service = ManualBackupPreparingSpy(
            initialResult: .requiresUnavailablePhotoDecision(proposal),
            decisionResult: .ready(export)
        )
        let viewModel = SettingsViewModel(
            repository: database.makeCoreDataRepository(),
            manualBackupService: service
        )

        let initialPreparation = await viewModel.prepareManualBackup()
        XCTAssertNil(initialPreparation)
        XCTAssertEqual(viewModel.pendingManualBackupPhotoProposal, proposal)
        XCTAssertNil(viewModel.errorMessage)

        let prepared = await viewModel.approveManualBackupPhotoOmissions()

        XCTAssertEqual(prepared?.omittedAssetCount, 2)
        XCTAssertNil(viewModel.pendingManualBackupPhotoProposal)
        XCTAssertEqual(
            viewModel.statusMessage,
            "Backup is ready without 2 unavailable photos. Choose a safe location to save it."
        )
        let approvedProposalIDs = await service.approvedProposalIDs
        XCTAssertEqual(approvedProposalIDs, [proposal.id])
    }

    @MainActor
    func testSettingsRequiresSecondConfirmationBeforePhotoRemoval() async throws {
        let database = try AppDatabase.makeInMemory()
        let proposal = ManualBackupUnavailablePhotoProposal(
            id: "photo-decision",
            unavailablePhotoCount: 1
        )
        let export = ManualBackupExport(
            packageURL: URL(fileURLWithPath: "/tmp/backup.cloudbakebackup"),
            stagingDirectoryURL: URL(fileURLWithPath: "/tmp/snapshot"),
            filename: "backup.cloudbakebackup",
            omittedAssetCount: 0
        )
        let service = ManualBackupPreparingSpy(
            initialResult: .requiresUnavailablePhotoDecision(proposal),
            decisionResult: .ready(export)
        )
        let viewModel = SettingsViewModel(
            repository: database.makeCoreDataRepository(),
            manualBackupService: service
        )
        _ = await viewModel.prepareManualBackup()

        viewModel.requestManualBackupPhotoRemoval()

        XCTAssertTrue(viewModel.isConfirmingManualBackupPhotoRemoval)
        let removedBeforeConfirmation = await service.removedProposalIDs
        XCTAssertTrue(removedBeforeConfirmation.isEmpty)

        _ = await viewModel.confirmManualBackupPhotoRemoval()

        XCTAssertFalse(viewModel.isConfirmingManualBackupPhotoRemoval)
        let removedProposalIDs = await service.removedProposalIDs
        XCTAssertEqual(removedProposalIDs, [proposal.id])
    }
}

private func makeManualBackupManifest(omittedAssetCount: Int = 0) -> BackupManifest {
    BackupManifest(
        databaseSchemaVersion: "test-schema",
        minimumCompatibleAppVersion: "1.0",
        generationID: "opaque-generation",
        createdAt: Date(timeIntervalSince1970: 1_783_800_000),
        database: BackupFileDescriptor(
            relativePath: "database.sqlite",
            byteCount: 8,
            sha256: BackupChecksum.sha256(of: Data("database".utf8))
        ),
        assets: [],
        omittedAssetCount: omittedAssetCount
    )
}

private func makeManualBackupRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeManualBackupPackage(at root: URL) -> AppSnapshotPackage {
    let directory = root.appendingPathComponent("snapshot", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return AppSnapshotPackage(
        generationID: "manual-generation",
        directoryURL: directory,
        manifestURL: directory.appendingPathComponent("manifest.json"),
        databaseURL: directory.appendingPathComponent("database.sqlite"),
        manifest: makeManualBackupManifest()
    )
}

private struct ManualBackupSnapshotCreator: RecoverableAppSnapshotCreating {
    let package: AppSnapshotPackage

    func createSnapshot() async throws -> AppSnapshotPackage {
        package
    }

    func createSnapshot(
        approvedOmissionDigests: Set<String>
    ) async throws -> AppSnapshotPackage {
        package
    }
}

private struct ManualBackupPreparingStub: ManualBackupPreparing {
    let result: Result<ManualBackupPreparationResult, Error>

    func prepareBackup() async throws -> ManualBackupPreparationResult {
        try result.get()
    }

    func approveUnavailablePhotoOmissions(
        proposalID: String
    ) async throws -> ManualBackupPreparationResult {
        try result.get()
    }

    func removeUnavailablePhotos(
        proposalID: String
    ) async throws -> ManualBackupPreparationResult {
        try result.get()
    }

    func cancelUnavailablePhotoDecision(
        proposalID: String
    ) async -> ManualBackupCancellationResult {
        .cancelled
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

private struct RecordingManualBackupArchiver: ManualBackupArchiving {
    func archivePackage(at sourceURL: URL, to destinationURL: URL) throws {
        try Data("manual-backup".utf8).write(to: destinationURL)
    }
}

private struct ManualBackupPhotoRevalidator: BackupUnavailablePhotoRevalidating {
    var availableReferences: Set<String> = []

    func confirmedUnavailableReferences(
        among sourceReferences: Set<String>
    ) async throws -> Set<String> {
        sourceReferences.subtracting(availableReferences)
    }
}

private final class RecoverableManualBackupSnapshotCreator: RecoverableAppSnapshotCreating,
    @unchecked Sendable {
    private let lock = NSLock()
    private let package: AppSnapshotPackage
    private var unavailableReferences: Set<String>
    private let errorAfterRemoval: Error?
    private let referencesAddedAfterRemoval: Set<String>
    private var didRemoveReferences = false

    init(
        package: AppSnapshotPackage,
        unavailableReferences: Set<String>,
        errorAfterRemoval: Error? = nil,
        referencesAddedAfterRemoval: Set<String> = []
    ) {
        self.package = package
        self.unavailableReferences = unavailableReferences
        self.errorAfterRemoval = errorAfterRemoval
        self.referencesAddedAfterRemoval = referencesAddedAfterRemoval
    }

    func createSnapshot() async throws -> AppSnapshotPackage {
        try await createSnapshot(approvedOmissionDigests: [])
    }

    func createSnapshot(
        approvedOmissionDigests: Set<String>
    ) async throws -> AppSnapshotPackage {
        try lock.withLock {
            if didRemoveReferences, let errorAfterRemoval {
                throw errorAfterRemoval
            }
            let unresolved = unavailableReferences.filter {
                !approvedOmissionDigests.contains(
                    BackupChecksum.sha256(of: Data($0.utf8))
                )
            }
            guard unresolved.isEmpty else {
                throw BackupUnavailableExternalAssetsError(
                    assets: unresolved.sorted().map {
                        BackupUnavailableExternalAsset(sourceReference: $0)
                    }
                )
            }
            let omittedCount = unavailableReferences.filter {
                approvedOmissionDigests.contains(
                    BackupChecksum.sha256(of: Data($0.utf8))
                )
            }.count
            return AppSnapshotPackage(
                generationID: package.generationID,
                directoryURL: package.directoryURL,
                manifestURL: package.manifestURL,
                databaseURL: package.databaseURL,
                manifest: makeManualBackupManifest(
                    omittedAssetCount: omittedCount
                )
            )
        }
    }

    func remove(references: Set<String>) {
        lock.withLock {
            unavailableReferences.subtract(references)
            unavailableReferences.formUnion(referencesAddedAfterRemoval)
            didRemoveReferences = true
        }
    }
}

private final class ManualBackupAssetRemover: BackupUnavailableAssetRemoving,
    @unchecked Sendable {
    private let lock = NSLock()
    private let snapshotCreator: RecoverableManualBackupSnapshotCreator
    private var recordedReferences: [Set<String>] = []

    init(snapshotCreator: RecoverableManualBackupSnapshotCreator) {
        self.snapshotCreator = snapshotCreator
    }

    var removedReferences: [Set<String>] {
        lock.withLock { recordedReferences }
    }

    func removeUnavailablePhotoReferences(_ references: Set<String>) throws {
        lock.withLock {
            recordedReferences.append(references)
        }
        snapshotCreator.remove(references: references)
    }
}

private final class ManualBackupOmissionStore: BackupAssetOmissionStoring,
    @unchecked Sendable {
    private let lock = NSLock()
    private var approvedDigests: Set<String> = []

    func loadApprovedDigests() -> Set<String> {
        lock.withLock { approvedDigests }
    }

    func approve(sourceReferences: Set<String>) {
        lock.withLock {
            approvedDigests.formUnion(
                sourceReferences.map {
                    BackupChecksum.sha256(of: Data($0.utf8))
                }
            )
        }
    }
}

private actor ManualBackupPreparingSpy: ManualBackupPreparing {
    private let initialResult: ManualBackupPreparationResult
    private let decisionResult: ManualBackupPreparationResult
    private let cancellationResult: ManualBackupCancellationResult
    private(set) var approvedProposalIDs: [String] = []
    private(set) var removedProposalIDs: [String] = []

    init(
        initialResult: ManualBackupPreparationResult,
        decisionResult: ManualBackupPreparationResult,
        cancellationResult: ManualBackupCancellationResult = .cancelled
    ) {
        self.initialResult = initialResult
        self.decisionResult = decisionResult
        self.cancellationResult = cancellationResult
    }

    func prepareBackup() async throws -> ManualBackupPreparationResult {
        initialResult
    }

    func approveUnavailablePhotoOmissions(
        proposalID: String
    ) async throws -> ManualBackupPreparationResult {
        approvedProposalIDs.append(proposalID)
        return decisionResult
    }

    func removeUnavailablePhotos(
        proposalID: String
    ) async throws -> ManualBackupPreparationResult {
        removedProposalIDs.append(proposalID)
        return decisionResult
    }

    func cancelUnavailablePhotoDecision(
        proposalID: String
    ) async -> ManualBackupCancellationResult {
        cancellationResult
    }
}
