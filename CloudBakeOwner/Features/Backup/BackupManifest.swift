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
        totalByteCount = database.byteCount + assets.reduce(0) { $0 + $1.file.byteCount }
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
