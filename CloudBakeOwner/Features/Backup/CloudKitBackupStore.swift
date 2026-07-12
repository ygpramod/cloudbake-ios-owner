import CloudKit
import Foundation

actor CloudKitBackupStore: CloudBackupStoring {
    static let containerIdentifier = "iCloud.com.cloudbake.owner"

    private enum Schema {
        static let zoneName = "CloudBakeBackup"
        static let pointerRecordType = "CBBackupPointer"
        static let pointerRecordName = "current"
        static let generationRecordType = "CBBackupGeneration"
        static let fileRecordType = "CBBackupFile"

        static let generationID = "generationID"
        static let createdAt = "createdAt"
        static let formatVersion = "formatVersion"
        static let databaseSchemaVersion = "databaseSchemaVersion"
        static let minimumCompatibleAppVersion = "minimumCompatibleAppVersion"
        static let payloadByteCount = "payloadByteCount"
        static let uploadByteCount = "uploadByteCount"
        static let fileRecordNames = "fileRecordNames"
        static let fileCount = "fileCount"
        static let role = "role"
        static let relativePath = "relativePath"
        static let byteCount = "byteCount"
        static let sha256 = "sha256"
        static let payload = "payload"
        static let updatedAt = "updatedAt"
    }

    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID
    private var didPrepareZone = false

    init(container: CKContainer = CKContainer(identifier: containerIdentifier)) {
        database = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: Schema.zoneName, ownerName: CKCurrentUserDefaultName)
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
            var result = try await database.records(
                matching: query,
                inZoneWith: zoneID,
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
                result = try await database.records(
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
            record[Schema.fileRecordNames] = plan.files.map(\.recordName) as CKRecordValue
            record[Schema.fileCount] = NSNumber(value: plan.files.count)
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

            let fileIDs = plan.files.map {
                CKRecord.ID(recordName: $0.recordName, zoneID: zoneID)
            }
            let records = try await database.records(for: fileIDs)
            for file in plan.files {
                let recordID = CKRecord.ID(recordName: file.recordName, zoneID: zoneID)
                guard let result = records[recordID] else {
                    throw CloudKitBackupStoreInternalError.corruptRecord
                }
                let record = try result.get()
                try verifyFileRecord(record, expected: file, generationID: plan.generationID)
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
            pointer[Schema.generationID] = generationID as CKRecordValue
            pointer[Schema.updatedAt] = Date() as CKRecordValue
            _ = try await saveRecords([pointer], atomically: true)
        }
    }

    func deleteGenerationIfNotCurrent(_ generationID: String) async throws -> Bool {
        try await mappedOperation {
            let pointer = try await ensureZoneAndPointer()
            guard nonEmptyString(pointer[Schema.generationID]) != generationID else {
                return false
            }
            guard let generation = try await optionalRecord(generationRecordID(generationID)) else {
                return true
            }
            guard let fileRecordNames = generation[Schema.fileRecordNames] as? [String],
                  fileRecordNames.allSatisfy(CloudBackupRecordName.isSafe) else {
                throw CloudKitBackupStoreInternalError.corruptRecord
            }
            let deletionIDs = fileRecordNames.map {
                CKRecord.ID(recordName: $0, zoneID: zoneID)
            } + [generation.recordID]
            let result = try await database.modifyRecords(
                saving: [pointer],
                deleting: deletionIDs,
                savePolicy: .ifServerRecordUnchanged,
                atomically: true
            )
            try requireSaved(pointer.recordID, from: result.saveResults)
            for recordID in deletionIDs {
                guard let deletion = result.deleteResults[recordID] else {
                    throw CloudKitBackupStoreInternalError.corruptResponse
                }
                try deletion.get()
            }
            return true
        }
    }

    private func ensureZoneAndPointer() async throws -> CKRecord {
        if !didPrepareZone {
            let zone = CKRecordZone(zoneID: zoneID)
            let result = try await database.modifyRecordZones(saving: [zone], deleting: [])
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

    private func saveRecords(_ records: [CKRecord], atomically: Bool) async throws -> [CKRecord.ID: CKRecord] {
        let result = try await database.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: .ifServerRecordUnchanged,
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
            let results = try await database.records(for: [recordID])
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
            && record[Schema.fileRecordNames] as? [String] == plan.files.map(\.recordName)
            && integer(record[Schema.fileCount]) == Int64(plan.files.count)
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

    private func mappedOperation<T>(_ operation: () async throws -> T) async throws -> T {
        let operationID = UUID().uuidString.lowercased()
        do {
            return try await operation()
        } catch let error as CloudBackupStoreError {
            throw error
        } catch {
            throw CloudKitBackupErrorMapper.storeError(error, operationID: operationID)
        }
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
            case .corruptRecord, .corruptResponse:
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
}
