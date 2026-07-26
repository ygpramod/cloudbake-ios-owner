import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

extension UTType {
    static let cloudBakeBackup = UTType(
        exportedAs: "com.cloudbake.owner.backup",
        conformingTo: .archive
    )
}

struct ManualBackupExport: Sendable {
    let packageURL: URL
    let stagingDirectoryURL: URL
    let filename: String
    let omittedAssetCount: Int

    func removeStagedFiles(fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: packageURL)
        try? fileManager.removeItem(at: stagingDirectoryURL)
    }
}

struct ManualBackupUnavailablePhotoProposal: Equatable, Sendable {
    let id: String
    let unavailablePhotoCount: Int
    let didRemoveUnavailablePhotoReferences: Bool

    init(
        id: String,
        unavailablePhotoCount: Int,
        didRemoveUnavailablePhotoReferences: Bool = false
    ) {
        self.id = id
        self.unavailablePhotoCount = unavailablePhotoCount
        self.didRemoveUnavailablePhotoReferences =
            didRemoveUnavailablePhotoReferences
    }
}

enum ManualBackupPreparationResult: Sendable {
    case ready(ManualBackupExport)
    case requiresUnavailablePhotoDecision(ManualBackupUnavailablePhotoProposal)
}

enum ManualBackupServiceError: Error, Equatable {
    case invalidUnavailablePhotoDecision
    case unavailablePhotoRemovalNotConfigured
    case backupFailedAfterPhotoRemoval
    case photosAccessDeniedAfterPhotoRemoval
}

protocol ManualBackupPreparing: Sendable {
    func prepareBackup() async throws -> ManualBackupPreparationResult
    func approveUnavailablePhotoOmissions(
        proposalID: String
    ) async throws -> ManualBackupPreparationResult
    func removeUnavailablePhotos(
        proposalID: String
    ) async throws -> ManualBackupPreparationResult
    func cancelUnavailablePhotoDecision(
        proposalID: String
    ) async -> ManualBackupCancellationResult
}

protocol ManualBackupArchiving: Sendable {
    func archivePackage(at sourceURL: URL, to destinationURL: URL) throws
}

struct ZIPManualBackupArchiver: ManualBackupArchiving {
    func archivePackage(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.zipItem(
            at: sourceURL,
            to: destinationURL,
            shouldKeepParent: false,
            compressionMethod: .deflate
        )
    }

    func extractArchive(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)
    }
}

actor ManualBackupService: ManualBackupPreparing {
    private struct PendingUnavailablePhotoDecision {
        let proposal: ManualBackupUnavailablePhotoProposal
        let sourceReferences: Set<String>
    }

    private let snapshotCreator: any RecoverableAppSnapshotCreating
    private let omissionStore: any BackupAssetOmissionStoring
    private let unavailablePhotoRevalidator: any BackupUnavailablePhotoRevalidating
    private let unavailableAssetRemover: (any BackupUnavailableAssetRemoving)?
    private let dateProvider: @Sendable () -> Date
    private let makeProposalID: @Sendable () -> String
    private let completedPackageRoot: URL?
    private let fileManager: FileManager
    private let archiver: any ManualBackupArchiving
    private var pendingUnavailablePhotoDecision: PendingUnavailablePhotoDecision?

    init(
        snapshotCreator: any RecoverableAppSnapshotCreating,
        omissionStore: any BackupAssetOmissionStoring,
        unavailablePhotoRevalidator: any BackupUnavailablePhotoRevalidating,
        unavailableAssetRemover: (any BackupUnavailableAssetRemoving)? = nil,
        dateProvider: @escaping @Sendable () -> Date = { Date() },
        makeProposalID: @escaping @Sendable () -> String = {
            UUID().uuidString.lowercased()
        },
        completedPackageRoot: URL? = nil,
        fileManager: FileManager = .default,
        archiver: any ManualBackupArchiving = ZIPManualBackupArchiver()
    ) {
        self.snapshotCreator = snapshotCreator
        self.omissionStore = omissionStore
        self.unavailablePhotoRevalidator = unavailablePhotoRevalidator
        self.unavailableAssetRemover = unavailableAssetRemover
        self.dateProvider = dateProvider
        self.makeProposalID = makeProposalID
        self.completedPackageRoot = completedPackageRoot
        self.fileManager = fileManager
        self.archiver = archiver
    }

    func prepareBackup() async throws -> ManualBackupPreparationResult {
        if let pendingUnavailablePhotoDecision {
            return .requiresUnavailablePhotoDecision(
                pendingUnavailablePhotoDecision.proposal
            )
        }
        return try await prepareFreshBackup()
    }

    func approveUnavailablePhotoOmissions(
        proposalID: String
    ) async throws -> ManualBackupPreparationResult {
        let decision = try pendingDecision(matching: proposalID)
        omissionStore.approve(sourceReferences: decision.sourceReferences)
        pendingUnavailablePhotoDecision = nil
        return try await prepareFreshBackup(
            didRemoveUnavailablePhotoReferences:
                decision.proposal.didRemoveUnavailablePhotoReferences
        )
    }

    func removeUnavailablePhotos(
        proposalID: String
    ) async throws -> ManualBackupPreparationResult {
        let decision = try pendingDecision(matching: proposalID)
        guard let unavailableAssetRemover else {
            throw ManualBackupServiceError.unavailablePhotoRemovalNotConfigured
        }
        pendingUnavailablePhotoDecision = nil
        let confirmedReferences =
            try await unavailablePhotoRevalidator.confirmedUnavailableReferences(
                among: decision.sourceReferences
            )
        if !confirmedReferences.isEmpty {
            try unavailableAssetRemover.removeUnavailablePhotoReferences(
                confirmedReferences
            )
        }
        let didRemoveUnavailablePhotoReferences =
            decision.proposal.didRemoveUnavailablePhotoReferences
            || !confirmedReferences.isEmpty
        do {
            return try await prepareFreshBackup(
                didRemoveUnavailablePhotoReferences:
                    didRemoveUnavailablePhotoReferences
            )
        } catch {
            if !didRemoveUnavailablePhotoReferences {
                throw error
            }
            if error as? BackupExternalAssetResolverError == .accessDenied {
                throw ManualBackupServiceError.photosAccessDeniedAfterPhotoRemoval
            }
            throw ManualBackupServiceError.backupFailedAfterPhotoRemoval
        }
    }

    func cancelUnavailablePhotoDecision(
        proposalID: String
    ) -> ManualBackupCancellationResult {
        guard let decision = pendingUnavailablePhotoDecision,
              decision.proposal.id == proposalID else { return .ignored }
        pendingUnavailablePhotoDecision = nil
        return decision.proposal.didRemoveUnavailablePhotoReferences
            ? .cancelledAfterPhotoRemoval
            : .cancelled
    }

    private func prepareFreshBackup(
        didRemoveUnavailablePhotoReferences: Bool = false
    ) async throws -> ManualBackupPreparationResult {
        try removeCompletedStagingPackages()
        let package: AppSnapshotPackage
        do {
            package = try await snapshotCreator.createSnapshot(
                approvedOmissionDigests: omissionStore.loadApprovedDigests()
            )
        } catch let error as BackupUnavailableExternalAssetsError {
            let sourceReferences = Set(error.assets.map(\.sourceReference))
            let proposal = ManualBackupUnavailablePhotoProposal(
                id: makeProposalID(),
                unavailablePhotoCount: sourceReferences.count,
                didRemoveUnavailablePhotoReferences:
                    didRemoveUnavailablePhotoReferences
            )
            pendingUnavailablePhotoDecision = PendingUnavailablePhotoDecision(
                proposal: proposal,
                sourceReferences: sourceReferences
            )
            return .requiresUnavailablePhotoDecision(proposal)
        }
        let filename = Self.filename(for: dateProvider())
        let archiveURL = package.directoryURL
            .deletingLastPathComponent()
            .appendingPathComponent(filename)
        do {
            try archiver.archivePackage(at: package.directoryURL, to: archiveURL)
        } catch {
            try? fileManager.removeItem(at: archiveURL)
            try? fileManager.removeItem(at: package.directoryURL)
            throw error
        }
        return .ready(
            ManualBackupExport(
                packageURL: archiveURL,
                stagingDirectoryURL: package.directoryURL,
                filename: filename,
                omittedAssetCount: package.manifest.omittedAssetCount
            )
        )
    }

    static func live(database: AppDatabase) throws -> ManualBackupService {
        let fileManager = FileManager.default
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let caches = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appStorageRoot = applicationSupport.appendingPathComponent(
            "CloudBakeOwner",
            isDirectory: true
        )
        let stagingRoot = caches
            .appendingPathComponent("CloudBakeOwner", isDirectory: true)
            .appendingPathComponent("ManualBackupStaging", isDirectory: true)
        let currentVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
        let snapshotService = AppSnapshotService(
            database: database,
            appStorageRoot: appStorageRoot,
            stagingRoot: stagingRoot,
            minimumCompatibleAppVersion: "1.0",
            currentAppVersion: currentVersion
        )
        return ManualBackupService(
            snapshotCreator: snapshotService,
            omissionStore: UserDefaultsBackupAssetOmissionStore(),
            unavailablePhotoRevalidator: PhotoKitBackupUnavailablePhotoRevalidator(),
            unavailableAssetRemover: database,
            completedPackageRoot: stagingRoot
        )
    }

    static func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "cloudbake-backup-\(formatter.string(from: date)).cloudbakebackup"
    }

    private func removeCompletedStagingPackages() throws {
        guard let completedPackageRoot,
              fileManager.fileExists(atPath: completedPackageRoot.path) else { return }
        for child in try fileManager.contentsOfDirectory(
            at: completedPackageRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) where !child.lastPathComponent.hasSuffix(".building") {
            try fileManager.removeItem(at: child)
        }
    }

    private func pendingDecision(
        matching proposalID: String
    ) throws -> PendingUnavailablePhotoDecision {
        guard let pendingUnavailablePhotoDecision,
              pendingUnavailablePhotoDecision.proposal.id == proposalID else {
            throw ManualBackupServiceError.invalidUnavailablePhotoDecision
        }
        return pendingUnavailablePhotoDecision
    }
}
