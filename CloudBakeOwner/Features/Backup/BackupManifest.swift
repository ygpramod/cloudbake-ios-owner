import CryptoKit
import Foundation

struct BackupManifest: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let databaseSchemaVersion: String
    let minimumCompatibleAppVersion: String
    let generationID: String
    let createdAt: Date
    let database: BackupFileDescriptor
    let assets: [BackupAssetDescriptor]
    let totalByteCount: Int64

    init(
        formatVersion: Int = currentFormatVersion,
        databaseSchemaVersion: String,
        minimumCompatibleAppVersion: String,
        generationID: String,
        createdAt: Date,
        database: BackupFileDescriptor,
        assets: [BackupAssetDescriptor]
    ) {
        self.formatVersion = formatVersion
        self.databaseSchemaVersion = databaseSchemaVersion
        self.minimumCompatibleAppVersion = minimumCompatibleAppVersion
        self.generationID = generationID
        self.createdAt = createdAt
        self.database = database
        self.assets = assets.sorted { $0.originalRelativePath < $1.originalRelativePath }
        totalByteCount = Self.calculatedTotalByteCount(
            database: database,
            assets: assets
        ) ?? -1
    }

    static func calculatedTotalByteCount(
        database: BackupFileDescriptor,
        assets: [BackupAssetDescriptor]
    ) -> Int64? {
        guard database.byteCount >= 0 else { return nil }
        var total = database.byteCount
        for asset in assets {
            guard asset.file.byteCount >= 0 else { return nil }
            let addition = total.addingReportingOverflow(asset.file.byteCount)
            guard !addition.overflow else { return nil }
            total = addition.partialValue
        }
        return total
    }
}

struct BackupFileDescriptor: Codable, Equatable, Sendable {
    let relativePath: String
    let byteCount: Int64
    let sha256: String
}

struct BackupAssetDescriptor: Codable, Equatable, Sendable {
    let originalRelativePath: String
    let file: BackupFileDescriptor
}

enum BackupManifestCompatibility: Equatable {
    case compatible
    case unsupportedFormat(found: Int, supported: Int)
    case appUpdateRequired(minimumVersion: String)
}

extension BackupManifest {
    func compatibility(currentAppVersion: String) -> BackupManifestCompatibility {
        guard formatVersion == Self.currentFormatVersion else {
            return .unsupportedFormat(found: formatVersion, supported: Self.currentFormatVersion)
        }
        guard currentAppVersion.compare(
            minimumCompatibleAppVersion,
            options: .numeric
        ) != .orderedAscending else {
            return .appUpdateRequired(minimumVersion: minimumCompatibleAppVersion)
        }
        return .compatible
    }
}

enum BackupPath {
    static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("~") else {
            return false
        }
        let components = NSString(string: path).pathComponents
        return !components.contains("..") && !components.contains(".")
    }

    static func isSafeIdentifier(_ value: String) -> Bool {
        guard (1...64).contains(value.utf8.count) else { return false }
        return value.utf8.allSatisfy { byte in
            (48...57).contains(byte)
                || (65...90).contains(byte)
                || (97...122).contains(byte)
                || byte == 45
        }
    }
}

enum BackupChecksum {
    static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            guard !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
