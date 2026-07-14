import CloudKit
import Foundation

actor CloudKitBackupStore: CloudBackupStoring, CloudRestoreServing, CloudBackupDeleting {
    static let containerIdentifier = "iCloud.com.cloudbake.owner"

    private enum Schema {
        static let zoneName = "CloudBakeBackup"
        static let pointerRecordType = "CBBackupPointer"
        static let pointerRecordName = "current"
        static let generationRecordType = "CBBackupGeneration"
        static let fileRecordType = "CBBackupFile"

        static let generationID = "generationID"
        static let generationReference = "generationReference"
        static let createdAt = "createdAt"
        static let formatVersion = "formatVersion"
        static let databaseSchemaVersion = "databaseSchemaVersion"
        static let minimumCompatibleAppVersion = "minimumCompatibleAppVersion"
        static let payloadByteCount = "payloadByteCount"
        static let uploadByteCount = "uploadByteCount"
        static let fileCount = "fileCount"
        static let lifecycleState = "lifecycleState"
        static let role = "role"
        static let relativePath = "relativePath"
        static let byteCount = "byteCount"
        static let sha256 = "sha256"
        static let payload = "payload"
        static let updatedAt = "updatedAt"

        static let uploadingState = "uploading"
        static let deletingState = "deleting"
    }

    static let recordFetchLimit = 400

    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID
    private var didPrepareZone = false
    private var transferPolicy = CloudBackupTransferPolicy.wifiOnly

    init(container: CKContainer = CKContainer(identifier: containerIdentifier)) {
        database = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: Schema.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    func configureTransferPolicy(_ policy: CloudBackupTransferPolicy) {
        transferPolicy = policy
    }

    func currentGenerationID() async throws -> String? {
        try await mappedOperation {
            let pointer = try await ensureZoneAndPointer()
            return nonEmptyString(pointer[Schema.generationID])
        }
    }

    func generationIDs() async throws -> Set<String> {
        try await mappedOperation {
            _ = try await ensureZoneAndPointer()
            let query = CKQuery(
                recordType: Schema.generationRecordType,
                predicate: NSPredicate(value: true)
            )
            var result = try await queryRecords(
                matching: query,
                desiredKeys: [Schema.generationID]
            )
            var generationIDs: Set<String> = []
            while true {
                for (_, recordResult) in result.matchResults {
                    let record = try recordResult.get()
                    guard let generationID = nonEmptyString(record[Schema.generationID]),
                          BackupPath.isSafeIdentifier(generationID) else {
                        throw CloudKitBackupStoreInternalError.corruptRecord
                    }
                    generationIDs.insert(generationID)
                }
                guard let cursor = result.queryCursor else { break }
                result = try await queryRecords(
                    continuingMatchFrom: cursor,
                    desiredKeys: [Schema.generationID]
                )
            }
            return generationIDs
        }
    }

    func prepareGeneration(_ plan: CloudBackupGenerationPlan) async throws {
        try await mappedOperation {
            _ = try await ensureZoneAndPointer()
            let record = CKRecord(
                recordType: Schema.generationRecordType,
                recordID: generationRecordID(plan.generationID)
            )
            record[Schema.generationID] = plan.generationID as CKRecordValue
            record[Schema.createdAt] = plan.createdAt as CKRecordValue
            record[Schema.formatVersion] = NSNumber(value: plan.formatVersion)
            record[Schema.databaseSchemaVersion] = plan.databaseSchemaVersion as CKRecordValue
            record[Schema.minimumCompatibleAppVersion] = plan.minimumCompatibleAppVersion as CKRecordValue
            record[Schema.payloadByteCount] = NSNumber(value: plan.payloadByteCount)
            record[Schema.uploadByteCount] = NSNumber(value: plan.uploadByteCount)
            record[Schema.fileCount] = NSNumber(value: plan.files.count)
            record[Schema.lifecycleState] = Schema.uploadingState as CKRecordValue
            _ = try await saveRecords([record], atomically: true)
        }
    }

    func uploadFile(_ file: CloudBackupFileUpload, generationID: String) async throws {
        try await mappedOperation {
            _ = try await ensureZoneAndPointer()
            guard BackupPath.isSafeIdentifier(generationID),
                  CloudBackupRecordName.isSafe(file.recordName) else {
                throw CloudKitBackupStoreInternalError.invalidPlan
            }
            let record = CKRecord(
                recordType: Schema.fileRecordType,
                recordID: CKRecord.ID(recordName: file.recordName, zoneID: zoneID)
            )
            record[Schema.generationID] = generationID as CKRecordValue
            record[Schema.generationReference] = CKRecord.Reference(
                recordID: generationRecordID(generationID),
                action: .deleteSelf
            )
            record[Schema.role] = file.role.rawValue as CKRecordValue
            record[Schema.relativePath] = file.relativePath as CKRecordValue
            record[Schema.byteCount] = NSNumber(value: file.byteCount)
            record[Schema.sha256] = file.sha256 as CKRecordValue
            record[Schema.payload] = CKAsset(fileURL: file.localFileURL)
            _ = try await saveRecords([record], atomically: true)
        }
    }

    func verifyGeneration(_ plan: CloudBackupGenerationPlan) async throws {
        try await mappedOperation {
            _ = try await ensureZoneAndPointer()
            let generation = try await requiredRecord(generationRecordID(plan.generationID))
            guard generationMatches(generation, plan: plan) else {
                throw CloudKitBackupStoreInternalError.corruptRecord
            }

            for files in CloudKitBackupBatching.chunks(
                plan.files,
                maximumCount: Self.recordFetchLimit
            ) {
                let fileIDs = files.map {
                    CKRecord.ID(recordName: $0.recordName, zoneID: zoneID)
                }
                let records = try await fetchRecords(fileIDs)
                for file in files {
                    let recordID = CKRecord.ID(recordName: file.recordName, zoneID: zoneID)
                    guard let result = records[recordID] else {
                        throw CloudKitBackupStoreInternalError.corruptRecord
                    }
                    let record = try result.get()
                    try verifyFileRecord(record, expected: file, generationID: plan.generationID)
                }
            }
        }
    }

    func publishCurrentGeneration(
        _ generationID: String,
        replacing expectedGenerationID: String?
    ) async throws {
        try await mappedOperation {
            let pointer = try await ensureZoneAndPointer()
            guard nonEmptyString(pointer[Schema.generationID]) == expectedGenerationID else {
                throw CloudKitBackupStoreInternalError.pointerConflict
            }
            let generation = try await requiredRecord(generationRecordID(generationID))
            guard nonEmptyString(generation[Schema.lifecycleState]) == Schema.uploadingState else {
                throw CloudKitBackupStoreInternalError.pointerConflict
            }
            pointer[Schema.generationID] = generationID as CKRecordValue
            pointer[Schema.updatedAt] = Date() as CKRecordValue
            _ = try await saveRecords([pointer, generation], atomically: true)
        }
    }

    func deleteGenerationIfNotCurrent(_ generationID: String) async throws -> Bool {
        try await mappedOperation {
            var pointer = try await ensureZoneAndPointer()
            guard nonEmptyString(pointer[Schema.generationID]) != generationID else {
                return false
            }
            guard let generation = try await optionalRecord(generationRecordID(generationID)) else {
                return true
            }
            let lifecycleState = nonEmptyString(generation[Schema.lifecycleState])
            guard lifecycleState == Schema.uploadingState || lifecycleState == Schema.deletingState else {
                throw CloudKitBackupStoreInternalError.corruptRecord
            }

            if lifecycleState != Schema.deletingState {
                generation[Schema.lifecycleState] = Schema.deletingState as CKRecordValue
                let claimed = try await saveRecords([pointer, generation], atomically: true)
                guard let savedPointer = claimed[pointer.recordID],
                      claimed[generation.recordID] != nil else {
                    throw CloudKitBackupStoreInternalError.corruptResponse
                }
                pointer = savedPointer
            }

            _ = try await deleteRecords([generation.recordID], preserving: pointer)
            return true
        }
    }

    func deleteAllBackupData() async throws {
        transferPolicy = .cellularAllowed
        try await mappedOperation {
            do {
                _ = try await database.deleteRecordZone(withID: zoneID)
            } catch let error as CKError where Self.isMissingZone(error) {
                didPrepareZone = false
                return
            }
            didPrepareZone = false
            do {
                _ = try await database.recordZone(for: zoneID)
                throw CloudKitBackupStoreInternalError.deletionNotVerified
            } catch let error as CKError where Self.isMissingZone(error) {
                return
            }
        }
    }

    func inspectCurrentSnapshot(currentAppVersion: String) async throws -> CloudRestoreSnapshot? {
        transferPolicy = .cellularAllowed
        return try await mappedOperation {
            try await inspectCurrentSnapshotDetails(currentAppVersion: currentAppVersion)?.snapshot
        }
    }

    func downloadCurrentSnapshot(
        _ snapshot: CloudRestoreSnapshot,
        to directoryURL: URL,
        currentAppVersion: String,
        transferPolicy: CloudBackupTransferPolicy
    ) async throws -> DownloadedRestoreSnapshot {
        self.transferPolicy = transferPolicy
        return try await mappedOperation {
            guard let details = try await inspectCurrentSnapshotDetails(
                currentAppVersion: currentAppVersion
            ), CloudRestoreDownloadApproval.matches(
                approved: snapshot,
                current: details.snapshot
            ) else {
                throw CloudKitBackupStoreInternalError.pointerConflict
            }

            let fileManager = FileManager.default
            let buildingURL = directoryURL
                .deletingLastPathComponent()
                .appendingPathComponent("\(directoryURL.lastPathComponent).downloading", isDirectory: true)
            do {
                try removeIfPresent(buildingURL, fileManager: fileManager)
                try removeIfPresent(directoryURL, fileManager: fileManager)
                try fileManager.createDirectory(at: buildingURL, withIntermediateDirectories: true)
                var brokenAssets: [BrokenRestoreAsset] = []
                for files in CloudKitBackupBatching.chunks(
                    details.files,
                    maximumCount: Self.recordFetchLimit
                ) {
                    let recordIDs = files.map { restoreFileRecordID($0.recordName) }
                    let records = try await fetchRecords(recordIDs)
                    for file in files {
                        do {
                            let recordID = restoreFileRecordID(file.recordName)
                            guard let result = records[recordID] else {
                                throw CloudKitBackupStoreInternalError.corruptRecord
                            }
                            let record = try result.get()
                            let sourceURL = try verifiedPayloadURL(
                                record,
                                expected: file,
                                generationID: details.snapshot.generationID
                            )
                            let destinationURL = buildingURL
                                .appendingPathComponent(file.relativePath)
                                .standardizedFileURL
                            guard destinationURL.path.hasPrefix(buildingURL.standardizedFileURL.path + "/") else {
                                throw CloudKitBackupStoreInternalError.invalidPlan
                            }
                            try fileManager.createDirectory(
                                at: destinationURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true
                            )
                            try fileManager.copyItem(at: sourceURL, to: destinationURL)
                        } catch where CloudRestoreAssetFailureClassifier.isBrokenAsset(error) {
                            guard file.role == .asset, let originalPath = file.originalAssetPath else {
                                throw error
                            }
                            brokenAssets.append(BrokenRestoreAsset(originalRelativePath: originalPath))
                        }
                    }
                }
                try fileManager.moveItem(at: buildingURL, to: directoryURL)
                return DownloadedRestoreSnapshot(
                    directoryURL: directoryURL,
                    manifest: details.manifest,
                    brokenAssets: brokenAssets.sorted { $0.originalRelativePath < $1.originalRelativePath }
                )
            } catch {
                try? fileManager.removeItem(at: buildingURL)
                if RestoreLocalFileErrorMapper.category(for: error) == .insufficientStorage {
                    throw RestoreOperationError(category: .insufficientStorage, didRollBack: false)
                }
                throw error
            }
        }
    }

    private func inspectCurrentSnapshotDetails(
        currentAppVersion: String
    ) async throws -> CloudRestoreSnapshotDetails? {
        let pointer = try await ensureZoneAndPointer()
        guard let generationID = nonEmptyString(pointer[Schema.generationID]) else { return nil }
        guard BackupPath.isSafeIdentifier(generationID) else {
            throw CloudKitBackupStoreInternalError.corruptRecord
        }

        let generation = try await requiredRecord(generationRecordID(generationID))
        let manifestRecordName = "\(generationID)-manifest"
        let manifestRecord = try await requiredRecord(restoreFileRecordID(manifestRecordName))
        let manifestFile = try restoreManifestFilePlan(
            from: manifestRecord,
            generationID: generationID,
            recordName: manifestRecordName
        )
        let manifestURL = try verifiedPayloadURL(
            manifestRecord,
            expected: manifestFile,
            generationID: generationID
        )
        let manifest = try decodeManifest(at: manifestURL)
        let files = try CloudRestoreFilePlan.make(
            manifest: manifest,
            manifestFile: manifestFile
        )
        guard let uploadByteCount = CloudRestoreFilePlan.totalByteCount(files),
              generationMatches(
                generation,
                manifest: manifest,
                fileCount: files.count,
                uploadByteCount: uploadByteCount
              ) else {
            throw CloudKitBackupStoreInternalError.corruptRecord
        }

        var brokenAssetCount = 0
        for batch in CloudKitBackupBatching.chunks(
            Array(files.dropFirst()),
            maximumCount: Self.recordFetchLimit
        ) {
            let recordIDs = batch.map { restoreFileRecordID($0.recordName) }
            let records = try await fetchRecords(
                recordIDs,
                desiredKeys: CloudRestoreFilePlan.metadataKeys
            )
            for file in batch {
                let recordID = restoreFileRecordID(file.recordName)
                do {
                    guard let result = records[recordID] else {
                        throw CloudKitBackupStoreInternalError.corruptRecord
                    }
                    try verifyFileMetadata(
                        try result.get(),
                        expected: file,
                        generationID: generationID
                    )
                } catch where CloudRestoreAssetFailureClassifier.isBrokenAsset(error) {
                    guard file.role == .asset else { throw error }
                    brokenAssetCount += 1
                }
            }
        }

        return CloudRestoreSnapshotDetails(
            snapshot: CloudRestoreSnapshot(
                generationID: generationID,
                createdAt: manifest.createdAt,
                totalByteCount: manifest.totalByteCount,
                assetCount: manifest.assets.count,
                compatibility: manifest.compatibility(currentAppVersion: currentAppVersion),
                integrity: brokenAssetCount == 0
                    ? .verified
                    : .brokenAssets(count: brokenAssetCount)
            ),
            manifest: manifest,
            files: files
        )
    }

    private func decodeManifest(at fileURL: URL) throws -> BackupManifest {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(BackupManifest.self, from: Data(contentsOf: fileURL))
        } catch {
            throw CloudKitBackupStoreInternalError.corruptRecord
        }
    }

    private func generationMatches(
        _ record: CKRecord,
        manifest: BackupManifest,
        fileCount: Int,
        uploadByteCount: Int64
    ) -> Bool {
        guard let createdAt = record[Schema.createdAt] as? Date else { return false }
        return nonEmptyString(record[Schema.generationID]) == manifest.generationID
            && abs(createdAt.timeIntervalSince(manifest.createdAt)) < 1
            && integer(record[Schema.formatVersion]) == Int64(manifest.formatVersion)
            && nonEmptyString(record[Schema.databaseSchemaVersion]) == manifest.databaseSchemaVersion
            && nonEmptyString(record[Schema.minimumCompatibleAppVersion]) == manifest.minimumCompatibleAppVersion
            && integer(record[Schema.payloadByteCount]) == manifest.totalByteCount
            && integer(record[Schema.uploadByteCount]) == uploadByteCount
            && integer(record[Schema.fileCount]) == Int64(fileCount)
            && nonEmptyString(record[Schema.lifecycleState]) == Schema.uploadingState
    }

    private func verifyFileMetadata(
        _ record: CKRecord,
        expected: CloudRestoreFilePlan,
        generationID: String
    ) throws {
        guard nonEmptyString(record[Schema.generationID]) == generationID,
              nonEmptyString(record[Schema.role]) == expected.role.rawValue,
              nonEmptyString(record[Schema.relativePath]) == expected.relativePath,
              integer(record[Schema.byteCount]) == expected.byteCount,
              nonEmptyString(record[Schema.sha256]) == expected.sha256,
              let generationReference = record[Schema.generationReference] as? CKRecord.Reference,
              generationReference.recordID == generationRecordID(generationID),
              generationReference.action == .deleteSelf else {
            throw CloudKitBackupStoreInternalError.corruptRecord
        }
    }

    private func verifiedPayloadURL(
        _ record: CKRecord,
        expected: CloudRestoreFilePlan,
        generationID: String
    ) throws -> URL {
        try verifyFileMetadata(record, expected: expected, generationID: generationID)
        guard let asset = record[Schema.payload] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw CloudKitBackupStoreInternalError.corruptRecord
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard (attributes[.size] as? NSNumber)?.int64Value == expected.byteCount,
              try BackupChecksum.sha256(of: fileURL) == expected.sha256 else {
            throw CloudKitBackupStoreInternalError.corruptRecord
        }
        return fileURL
    }

    private func restoreManifestFilePlan(
        from record: CKRecord,
        generationID: String,
        recordName: String
    ) throws -> CloudRestoreFilePlan {
        guard nonEmptyString(record[Schema.generationID]) == generationID,
              nonEmptyString(record[Schema.role]) == CloudBackupFileRole.manifest.rawValue,
              nonEmptyString(record[Schema.relativePath]) == AppSnapshotService.manifestFilename,
              let byteCount = integer(record[Schema.byteCount]), byteCount >= 0,
              let sha256 = nonEmptyString(record[Schema.sha256]),
              let generationReference = record[Schema.generationReference] as? CKRecord.Reference,
              generationReference.recordID == generationRecordID(generationID),
              generationReference.action == .deleteSelf else {
            throw CloudKitBackupStoreInternalError.corruptRecord
        }
        return CloudRestoreFilePlan(
            recordName: recordName,
            role: .manifest,
            relativePath: AppSnapshotService.manifestFilename,
            byteCount: byteCount,
            sha256: sha256,
            originalAssetPath: nil
        )
    }

    private func restoreFileRecordID(_ recordName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: recordName, zoneID: zoneID)
    }

    private func removeIfPresent(_ url: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func ensureZoneAndPointer() async throws -> CKRecord {
        if !didPrepareZone {
            let zone = CKRecordZone(zoneID: zoneID)
            let result = try await modifyRecordZones(saving: [zone])
            guard let saveResult = result.saveResults[zoneID] else {
                throw CloudKitBackupStoreInternalError.corruptResponse
            }
            _ = try saveResult.get()
            didPrepareZone = true
        }
        let pointerID = CKRecord.ID(recordName: Schema.pointerRecordName, zoneID: zoneID)
        if let pointer = try await optionalRecord(pointerID) {
            return pointer
        }

        let pointer = CKRecord(recordType: Schema.pointerRecordType, recordID: pointerID)
        pointer[Schema.generationID] = "" as CKRecordValue
        pointer[Schema.updatedAt] = Date(timeIntervalSince1970: 0) as CKRecordValue
        do {
            _ = try await saveRecords([pointer], atomically: true)
            return pointer
        } catch let error as CKError where error.code == .serverRecordChanged {
            return try await requiredRecord(pointerID)
        }
    }

    private static func isMissingZone(_ error: CKError) -> Bool {
        error.code == .zoneNotFound || error.code == .unknownItem
    }

    private func saveRecords(_ records: [CKRecord], atomically: Bool) async throws -> [CKRecord.ID: CKRecord] {
        let result = try await modifyRecords(
            saving: records,
            deleting: [],
            atomically: atomically
        )
        var saved: [CKRecord.ID: CKRecord] = [:]
        for record in records {
            guard let saveResult = result.saveResults[record.recordID] else {
                throw CloudKitBackupStoreInternalError.corruptResponse
            }
            saved[record.recordID] = try saveResult.get()
        }
        return saved
    }

    private func optionalRecord(_ recordID: CKRecord.ID) async throws -> CKRecord? {
        do {
            let results = try await fetchRecords([recordID])
            guard let result = results[recordID] else {
                throw CloudKitBackupStoreInternalError.corruptResponse
            }
            return try result.get()
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func requiredRecord(_ recordID: CKRecord.ID) async throws -> CKRecord {
        guard let record = try await optionalRecord(recordID) else {
            throw CloudKitBackupStoreInternalError.corruptRecord
        }
        return record
    }

    private func generationRecordID(_ generationID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "generation-\(generationID)", zoneID: zoneID)
    }

    private func generationMatches(_ record: CKRecord, plan: CloudBackupGenerationPlan) -> Bool {
        nonEmptyString(record[Schema.generationID]) == plan.generationID
            && record[Schema.createdAt] as? Date == plan.createdAt
            && integer(record[Schema.formatVersion]) == Int64(plan.formatVersion)
            && nonEmptyString(record[Schema.databaseSchemaVersion]) == plan.databaseSchemaVersion
            && nonEmptyString(record[Schema.minimumCompatibleAppVersion]) == plan.minimumCompatibleAppVersion
            && integer(record[Schema.payloadByteCount]) == plan.payloadByteCount
            && integer(record[Schema.uploadByteCount]) == plan.uploadByteCount
            && integer(record[Schema.fileCount]) == Int64(plan.files.count)
            && nonEmptyString(record[Schema.lifecycleState]) == Schema.uploadingState
    }

    private func verifyFileRecord(
        _ record: CKRecord,
        expected: CloudBackupFileUpload,
        generationID: String
    ) throws {
        guard nonEmptyString(record[Schema.generationID]) == generationID,
              nonEmptyString(record[Schema.role]) == expected.role.rawValue,
              nonEmptyString(record[Schema.relativePath]) == expected.relativePath,
              integer(record[Schema.byteCount]) == expected.byteCount,
              nonEmptyString(record[Schema.sha256]) == expected.sha256,
              let generationReference = record[Schema.generationReference] as? CKRecord.Reference,
              generationReference.recordID == generationRecordID(generationID),
              generationReference.action == .deleteSelf,
              let asset = record[Schema.payload] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw CloudKitBackupStoreInternalError.corruptRecord
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value
        guard byteCount == expected.byteCount,
              try BackupChecksum.sha256(of: fileURL) == expected.sha256 else {
            throw CloudKitBackupStoreInternalError.corruptRecord
        }
    }

    private func nonEmptyString(_ value: CKRecordValue?) -> String? {
        guard let value = value as? String, !value.isEmpty else { return nil }
        return value
    }

    private func integer(_ value: CKRecordValue?) -> Int64? {
        (value as? NSNumber)?.int64Value
    }

    private func requireSaved(
        _ recordID: CKRecord.ID,
        from results: [CKRecord.ID: Result<CKRecord, Error>]
    ) throws {
        guard let result = results[recordID] else {
            throw CloudKitBackupStoreInternalError.corruptResponse
        }
        _ = try result.get()
    }

    private func deleteRecords(
        _ recordIDs: [CKRecord.ID],
        preserving pointer: CKRecord
    ) async throws -> CKRecord {
        let result = try await modifyRecords(
            saving: [pointer],
            deleting: recordIDs,
            atomically: true
        )
        try requireSaved(pointer.recordID, from: result.saveResults)
        for recordID in recordIDs {
            guard let deletion = result.deleteResults[recordID] else {
                throw CloudKitBackupStoreInternalError.corruptResponse
            }
            try deletion.get()
        }
        guard let savedPointer = try result.saveResults[pointer.recordID]?.get() else {
            throw CloudKitBackupStoreInternalError.corruptResponse
        }
        return savedPointer
    }

    private func queryRecords(
        matching query: CKQuery,
        desiredKeys: [CKRecord.FieldKey]
    ) async throws -> CloudKitQueryResult {
        let operation = CKQueryOperation(query: query)
        operation.zoneID = zoneID
        operation.desiredKeys = desiredKeys
        return try await runQueryOperation(operation)
    }

    private func queryRecords(
        continuingMatchFrom cursor: CKQueryOperation.Cursor,
        desiredKeys: [CKRecord.FieldKey]
    ) async throws -> CloudKitQueryResult {
        let operation = CKQueryOperation(cursor: cursor)
        operation.desiredKeys = desiredKeys
        return try await runQueryOperation(operation)
    }

    private func runQueryOperation(
        _ operation: CKQueryOperation
    ) async throws -> CloudKitQueryResult {
        let collector = CloudKitQueryResultCollector()
        operation.configuration = CloudKitBackupOperationPolicy.configuration(for: transferPolicy)
        operation.recordMatchedBlock = { recordID, result in
            collector.record(recordID, result: result)
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                operation.queryResultBlock = { result in
                    continuation.resume(with: result.map { cursor in
                        CloudKitQueryResult(
                            matchResults: collector.results,
                            queryCursor: cursor
                        )
                    })
                }
                database.add(operation)
            }
        } onCancel: {
            operation.cancel()
        }
    }

    private func fetchRecords(
        _ recordIDs: [CKRecord.ID],
        desiredKeys: [CKRecord.FieldKey]? = nil
    ) async throws -> [CKRecord.ID: Result<CKRecord, Error>] {
        let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
        operation.desiredKeys = desiredKeys
        let collector = CloudKitRecordResultCollector()
        operation.configuration = CloudKitBackupOperationPolicy.configuration(for: transferPolicy)
        operation.perRecordResultBlock = { recordID, result in
            collector.record(recordID, result: result)
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                operation.fetchRecordsResultBlock = { result in
                    continuation.resume(with: result.map { collector.results })
                }
                database.add(operation)
            }
        } onCancel: {
            operation.cancel()
        }
    }

    private func modifyRecordZones(
        saving zones: [CKRecordZone]
    ) async throws -> CloudKitModifyZonesResult {
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: zones,
            recordZoneIDsToDelete: []
        )
        let collector = CloudKitZoneResultCollector()
        operation.configuration = CloudKitBackupOperationPolicy.configuration(for: transferPolicy)
        operation.perRecordZoneSaveBlock = { zoneID, result in
            collector.record(zoneID, result: result)
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                operation.modifyRecordZonesResultBlock = { result in
                    continuation.resume(with: result.map {
                        CloudKitModifyZonesResult(saveResults: collector.results)
                    })
                }
                database.add(operation)
            }
        } onCancel: {
            operation.cancel()
        }
    }

    private func modifyRecords(
        saving records: [CKRecord],
        deleting recordIDs: [CKRecord.ID],
        atomically: Bool
    ) async throws -> CloudKitModifyRecordsResult {
        let operation = CKModifyRecordsOperation(
            recordsToSave: records,
            recordIDsToDelete: recordIDs
        )
        let collector = CloudKitModifyRecordsResultCollector()
        operation.savePolicy = .ifServerRecordUnchanged
        operation.isAtomic = atomically
        operation.configuration = CloudKitBackupOperationPolicy.configuration(for: transferPolicy)
        operation.perRecordSaveBlock = { recordID, result in
            collector.recordSave(recordID, result: result)
        }
        operation.perRecordDeleteBlock = { recordID, result in
            collector.recordDeletion(recordID, result: result)
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                operation.modifyRecordsResultBlock = { result in
                    continuation.resume(with: result.map {
                        CloudKitModifyRecordsResult(
                            saveResults: collector.saveResults,
                            deleteResults: collector.deleteResults
                        )
                    })
                }
                database.add(operation)
            }
        } onCancel: {
            operation.cancel()
        }
    }

    private func mappedOperation<T>(_ operation: () async throws -> T) async throws -> T {
        let operationID = UUID().uuidString.lowercased()
        do {
            return try await operation()
        } catch let error as CloudBackupStoreError {
            throw error
        } catch let error as RestoreOperationError {
            throw error
        } catch {
            throw CloudKitBackupErrorMapper.storeError(error, operationID: operationID)
        }
    }
}

enum CloudRestoreDownloadApproval {
    static func matches(
        approved: CloudRestoreSnapshot,
        current: CloudRestoreSnapshot
    ) -> Bool {
        approved == current
    }
}

enum CloudRestoreAssetFailureClassifier {
    static func isBrokenAsset(_ error: Error) -> Bool {
        if let internalError = error as? CloudKitBackupStoreInternalError {
            switch internalError {
            case .corruptRecord, .corruptResponse, .deletionNotVerified:
                return true
            case .pointerConflict, .invalidPlan:
                return false
            }
        }
        if let storeError = error as? CloudBackupStoreError {
            return storeError.category == .corruptRemoteData
        }
        return CloudKitBackupErrorMapper.category(for: error) == .corruptRemoteData
    }
}

private struct CloudRestoreSnapshotDetails {
    let snapshot: CloudRestoreSnapshot
    let manifest: BackupManifest
    let files: [CloudRestoreFilePlan]
}

struct CloudRestoreFilePlan: Equatable, Sendable {
    let recordName: String
    let role: CloudBackupFileRole
    let relativePath: String
    let byteCount: Int64
    let sha256: String
    let originalAssetPath: String?

    static func make(
        manifest: BackupManifest,
        manifestFile: CloudRestoreFilePlan
    ) throws -> [CloudRestoreFilePlan] {
        guard BackupPath.isSafeIdentifier(manifest.generationID),
              manifestFile.recordName == "\(manifest.generationID)-manifest",
              manifestFile.role == .manifest,
              manifestFile.relativePath == AppSnapshotService.manifestFilename,
              manifestFile.byteCount >= 0,
              !manifestFile.sha256.isEmpty,
              BackupManifest.calculatedTotalByteCount(
                database: manifest.database,
                assets: manifest.assets
              ) == manifest.totalByteCount else {
            throw CloudBackupPlanError.manifestMismatch
        }
        let databasePlan = try make(
            recordName: "\(manifest.generationID)-database",
            role: .database,
            descriptor: manifest.database,
            originalAssetPath: nil
        )
        let assets = try manifest.assets.enumerated().map { index, asset in
            guard BackupPath.isSafeRelativePath(asset.originalRelativePath) else {
                throw CloudBackupPlanError.unsafeFilePath(asset.originalRelativePath)
            }
            return try make(
                recordName: String(format: "%@-asset-%06d", manifest.generationID, index),
                role: .asset,
                descriptor: asset.file,
                originalAssetPath: asset.originalRelativePath
            )
        }
        return [manifestFile, databasePlan] + assets
    }

    static func totalByteCount(_ files: [CloudRestoreFilePlan]) -> Int64? {
        var total: Int64 = 0
        for file in files {
            let addition = total.addingReportingOverflow(file.byteCount)
            guard file.byteCount >= 0, !addition.overflow else { return nil }
            total = addition.partialValue
        }
        return total
    }

    static let metadataKeys: [CKRecord.FieldKey] = [
        "generationID", "generationReference", "role", "relativePath", "byteCount", "sha256"
    ]

    private static func make(
        recordName: String,
        role: CloudBackupFileRole,
        descriptor: BackupFileDescriptor,
        originalAssetPath: String?
    ) throws -> CloudRestoreFilePlan {
        guard CloudBackupRecordName.isSafe(recordName),
              BackupPath.isSafeRelativePath(descriptor.relativePath),
              descriptor.byteCount >= 0 else {
            throw CloudBackupPlanError.invalidRecordName
        }
        return CloudRestoreFilePlan(
            recordName: recordName,
            role: role,
            relativePath: descriptor.relativePath,
            byteCount: descriptor.byteCount,
            sha256: descriptor.sha256,
            originalAssetPath: originalAssetPath
        )
    }
}

enum CloudKitBackupOperationPolicy {
    static func configuration(for policy: CloudBackupTransferPolicy) -> CKOperation.Configuration {
        let configuration = CKOperation.Configuration()
        configuration.allowsCellularAccess = policy == .cellularAllowed
        configuration.qualityOfService = .utility
        return configuration
    }
}

private struct CloudKitQueryResult {
    let matchResults: [(CKRecord.ID, Result<CKRecord, Error>)]
    let queryCursor: CKQueryOperation.Cursor?
}

private struct CloudKitModifyZonesResult {
    let saveResults: [CKRecordZone.ID: Result<CKRecordZone, Error>]
}

private struct CloudKitModifyRecordsResult {
    let saveResults: [CKRecord.ID: Result<CKRecord, Error>]
    let deleteResults: [CKRecord.ID: Result<Void, Error>]
}

private final class CloudKitQueryResultCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [(CKRecord.ID, Result<CKRecord, Error>)] = []

    var results: [(CKRecord.ID, Result<CKRecord, Error>)] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ recordID: CKRecord.ID, result: Result<CKRecord, Error>) {
        lock.lock()
        storage.append((recordID, result))
        lock.unlock()
    }
}

private final class CloudKitRecordResultCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [CKRecord.ID: Result<CKRecord, Error>] = [:]

    var results: [CKRecord.ID: Result<CKRecord, Error>] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ recordID: CKRecord.ID, result: Result<CKRecord, Error>) {
        lock.lock()
        storage[recordID] = result
        lock.unlock()
    }
}

private final class CloudKitZoneResultCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [CKRecordZone.ID: Result<CKRecordZone, Error>] = [:]

    var results: [CKRecordZone.ID: Result<CKRecordZone, Error>] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ zoneID: CKRecordZone.ID, result: Result<CKRecordZone, Error>) {
        lock.lock()
        storage[zoneID] = result
        lock.unlock()
    }
}

private final class CloudKitModifyRecordsResultCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var saved: [CKRecord.ID: Result<CKRecord, Error>] = [:]
    private var deleted: [CKRecord.ID: Result<Void, Error>] = [:]

    var saveResults: [CKRecord.ID: Result<CKRecord, Error>] {
        lock.lock()
        defer { lock.unlock() }
        return saved
    }

    var deleteResults: [CKRecord.ID: Result<Void, Error>] {
        lock.lock()
        defer { lock.unlock() }
        return deleted
    }

    func recordSave(_ recordID: CKRecord.ID, result: Result<CKRecord, Error>) {
        lock.lock()
        saved[recordID] = result
        lock.unlock()
    }

    func recordDeletion(_ recordID: CKRecord.ID, result: Result<Void, Error>) {
        lock.lock()
        deleted[recordID] = result
        lock.unlock()
    }
}

enum CloudKitBackupErrorMapper {
    static func storeError(_ error: Error, operationID: String) -> CloudBackupStoreError {
        CloudBackupStoreError(
            category: category(for: error),
            operationID: BackupPath.isSafeIdentifier(operationID) ? operationID : "operation"
        )
    }

    static func category(for error: Error) -> CloudBackupErrorCategory {
        if error is CancellationError { return .cancelled }
        if let internalError = error as? CloudKitBackupStoreInternalError {
            switch internalError {
            case .pointerConflict:
                return .conflict
            case .corruptRecord, .corruptResponse, .deletionNotVerified:
                return .corruptRemoteData
            case .invalidPlan:
                return .unknown
            }
        }
        guard let cloudError = error as? CKError else { return .unknown }
        if cloudError.code == .partialFailure,
           let partialErrors = cloudError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
           !partialErrors.isEmpty {
            return partialErrors.values
                .map(category(for:))
                .min(by: { priority($0) < priority($1) }) ?? .unknown
        }
        switch cloudError.code {
        case .notAuthenticated:
            return .authenticationRequired
        case .accountTemporarilyUnavailable:
            return .iCloudUnavailable
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .quotaExceeded:
            return .quotaExceeded
        case .permissionFailure, .managedAccountRestricted:
            return .permissionDenied
        case .serverRecordChanged, .assetFileModified:
            return .conflict
        case .operationCancelled:
            return .cancelled
        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return .temporarilyUnavailable
        case .unknownItem:
            return .corruptRemoteData
        default:
            return .unknown
        }
    }

    private static func priority(_ category: CloudBackupErrorCategory) -> Int {
        switch category {
        case .authenticationRequired, .iCloudUnavailable: return 0
        case .permissionDenied: return 1
        case .quotaExceeded: return 2
        case .conflict: return 3
        case .networkUnavailable: return 4
        case .temporarilyUnavailable: return 5
        case .corruptRemoteData: return 6
        case .cancelled: return 7
        case .unknown: return 8
        }
    }
}

private enum CloudKitBackupStoreInternalError: Error {
    case pointerConflict
    case corruptRecord
    case corruptResponse
    case invalidPlan
    case deletionNotVerified
}

enum CloudKitBackupBatching {
    static func chunks<Element>(
        _ values: [Element],
        maximumCount: Int
    ) -> [ArraySlice<Element>] {
        precondition(maximumCount > 0)
        var chunks: [ArraySlice<Element>] = []
        var start = values.startIndex
        while start < values.endIndex {
            let end = values.index(
                start,
                offsetBy: maximumCount,
                limitedBy: values.endIndex
            ) ?? values.endIndex
            chunks.append(values[start..<end])
            start = end
        }
        return chunks
    }
}
