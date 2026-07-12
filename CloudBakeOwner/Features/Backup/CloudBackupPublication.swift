import Foundation

enum CloudBackupFileRole: String, Codable, Equatable, Sendable {
    case manifest
    case database
    case asset
}

struct CloudBackupFileUpload: Equatable, Sendable {
    let recordName: String
    let role: CloudBackupFileRole
    let relativePath: String
    let byteCount: Int64
    let sha256: String
    let localFileURL: URL
}

struct CloudBackupGenerationPlan: Equatable, Sendable {
    let generationID: String
    let createdAt: Date
    let formatVersion: Int
    let databaseSchemaVersion: String
    let minimumCompatibleAppVersion: String
    let payloadByteCount: Int64
    let uploadByteCount: Int64
    let files: [CloudBackupFileUpload]
}

enum CloudBackupPlanError: Error, Equatable {
    case generationMismatch
    case manifestMismatch
    case invalidGenerationID
    case unsafeFilePath(String)
    case missingFile(String)
    case fileSizeMismatch(String)
    case fileChecksumMismatch(String)
    case totalSizeOverflow
}

extension CloudBackupGenerationPlan {
    static func make(
        package: AppSnapshotPackage,
        fileManager: FileManager = .default
    ) throws -> CloudBackupGenerationPlan {
        let manifest = package.manifest
        guard package.generationID == manifest.generationID else {
            throw CloudBackupPlanError.generationMismatch
        }
        guard BackupPath.isSafeIdentifier(package.generationID) else {
            throw CloudBackupPlanError.invalidGenerationID
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let fileManifest = try? decoder.decode(
            BackupManifest.self,
            from: Data(contentsOf: package.manifestURL)
        ), fileManifest == manifest else {
            throw CloudBackupPlanError.manifestMismatch
        }

        let manifestFile = try makeFile(
            recordName: "\(package.generationID)-manifest",
            role: .manifest,
            relativePath: AppSnapshotService.manifestFilename,
            expected: nil,
            fileURL: package.manifestURL,
            packageDirectoryURL: package.directoryURL,
            fileManager: fileManager
        )
        let databaseFile = try makeFile(
            recordName: "\(package.generationID)-database",
            role: .database,
            relativePath: manifest.database.relativePath,
            expected: manifest.database,
            fileURL: package.databaseURL,
            packageDirectoryURL: package.directoryURL,
            fileManager: fileManager
        )
        let assetFiles = try manifest.assets.enumerated().map { index, asset in
            try makeFile(
                recordName: String(format: "%@-asset-%06d", package.generationID, index),
                role: .asset,
                relativePath: asset.file.relativePath,
                expected: asset.file,
                fileURL: package.directoryURL.appendingPathComponent(asset.file.relativePath),
                packageDirectoryURL: package.directoryURL,
                fileManager: fileManager
            )
        }
        let files = [manifestFile, databaseFile] + assetFiles
        var verifiedTotal: Int64 = 0
        for file in files {
            let addition = verifiedTotal.addingReportingOverflow(file.byteCount)
            guard !addition.overflow else { throw CloudBackupPlanError.totalSizeOverflow }
            verifiedTotal = addition.partialValue
        }

        return CloudBackupGenerationPlan(
            generationID: package.generationID,
            createdAt: manifest.createdAt,
            formatVersion: manifest.formatVersion,
            databaseSchemaVersion: manifest.databaseSchemaVersion,
            minimumCompatibleAppVersion: manifest.minimumCompatibleAppVersion,
            payloadByteCount: manifest.totalByteCount,
            uploadByteCount: verifiedTotal,
            files: files
        )
    }

    private static func makeFile(
        recordName: String,
        role: CloudBackupFileRole,
        relativePath: String,
        expected: BackupFileDescriptor?,
        fileURL: URL,
        packageDirectoryURL: URL,
        fileManager: FileManager
    ) throws -> CloudBackupFileUpload {
        guard BackupPath.isSafeRelativePath(relativePath) else {
            throw CloudBackupPlanError.unsafeFilePath(relativePath)
        }
        let standardizedURL = fileURL.standardizedFileURL
        let resolvedURL = standardizedURL.resolvingSymlinksInPath()
        let resolvedPackageURL = packageDirectoryURL.standardizedFileURL.resolvingSymlinksInPath()
        let values = try? standardizedURL.resourceValues(
            forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        )
        guard resolvedURL.path.hasPrefix(resolvedPackageURL.path + "/"),
              values?.isRegularFile == true,
              values?.isSymbolicLink != true,
              fileManager.fileExists(atPath: standardizedURL.path) else {
            throw CloudBackupPlanError.missingFile(relativePath)
        }
        let byteCount = Int64(values?.fileSize ?? 0)
        let checksum = try BackupChecksum.sha256(of: standardizedURL)
        if let expected {
            guard byteCount == expected.byteCount else {
                throw CloudBackupPlanError.fileSizeMismatch(relativePath)
            }
            guard checksum == expected.sha256 else {
                throw CloudBackupPlanError.fileChecksumMismatch(relativePath)
            }
        }
        return CloudBackupFileUpload(
            recordName: recordName,
            role: role,
            relativePath: relativePath,
            byteCount: byteCount,
            sha256: checksum,
            localFileURL: standardizedURL
        )
    }
}

enum CloudBackupErrorCategory: String, Equatable, Sendable {
    case iCloudUnavailable
    case networkUnavailable
    case quotaExceeded
    case authenticationRequired
    case permissionDenied
    case conflict
    case cancelled
    case corruptRemoteData
    case temporarilyUnavailable
    case unknown
}

struct CloudBackupStoreError: Error, Equatable, Sendable {
    let category: CloudBackupErrorCategory
    let operationID: String
}

protocol CloudBackupStoring: Sendable {
    func currentGenerationID() async throws -> String?
    func generationIDs() async throws -> Set<String>
    func prepareGeneration(_ plan: CloudBackupGenerationPlan) async throws
    func uploadFile(_ file: CloudBackupFileUpload, generationID: String) async throws
    func verifyGeneration(_ plan: CloudBackupGenerationPlan) async throws
    func publishCurrentGeneration(
        _ generationID: String,
        replacing expectedGenerationID: String?
    ) async throws
    @discardableResult
    func deleteGenerationIfNotCurrent(_ generationID: String) async throws -> Bool
}

enum CloudBackupPublicationError: Error, Equatable {
    case generationBecameCurrent
}

struct CloudBackupPublicationResult: Equatable, Sendable {
    let generationID: String
    let replacedGenerationID: String?
    let wasAlreadyCurrent: Bool
    let cleanupPending: Bool
}

actor CloudBackupPublisher {
    private let store: any CloudBackupStoring

    init(store: any CloudBackupStoring) {
        self.store = store
    }

    func publish(_ package: AppSnapshotPackage) async throws -> CloudBackupPublicationResult {
        let plan = try CloudBackupGenerationPlan.make(package: package)
        try Task.checkCancellation()
        let previousGenerationID = try await store.currentGenerationID()

        if previousGenerationID == plan.generationID {
            try await store.verifyGeneration(plan)
            let cleanupPending = await cleanGenerations(except: plan.generationID)
            return CloudBackupPublicationResult(
                generationID: plan.generationID,
                replacedGenerationID: nil,
                wasAlreadyCurrent: true,
                cleanupPending: cleanupPending
            )
        }

        let existingGenerationIDs = try await store.generationIDs()
        if existingGenerationIDs.contains(plan.generationID) {
            guard try await store.deleteGenerationIfNotCurrent(plan.generationID) else {
                throw CloudBackupPublicationError.generationBecameCurrent
            }
        }
        let prepublicationCleanupPending = await cleanGenerations(
            except: previousGenerationID,
            alsoKeeping: plan.generationID
        )

        try Task.checkCancellation()
        try await store.prepareGeneration(plan)
        for file in plan.files {
            try Task.checkCancellation()
            try await store.uploadFile(file, generationID: plan.generationID)
        }
        try Task.checkCancellation()
        try await store.verifyGeneration(plan)
        try Task.checkCancellation()
        try await store.publishCurrentGeneration(
            plan.generationID,
            replacing: previousGenerationID
        )

        let postpublicationCleanupPending = await cleanGenerations(except: plan.generationID)
        return CloudBackupPublicationResult(
            generationID: plan.generationID,
            replacedGenerationID: previousGenerationID,
            wasAlreadyCurrent: false,
            cleanupPending: prepublicationCleanupPending || postpublicationCleanupPending
        )
    }

    private func cleanGenerations(
        except generationID: String?,
        alsoKeeping secondaryGenerationID: String? = nil
    ) async -> Bool {
        do {
            let generationIDs = try await store.generationIDs()
            var cleanupPending = false
            for candidate in generationIDs.sorted()
            where candidate != generationID && candidate != secondaryGenerationID {
                do {
                    let deleted = try await store.deleteGenerationIfNotCurrent(candidate)
                    cleanupPending = cleanupPending || !deleted
                } catch {
                    cleanupPending = true
                }
            }
            return cleanupPending
        } catch {
            return true
        }
    }
}
