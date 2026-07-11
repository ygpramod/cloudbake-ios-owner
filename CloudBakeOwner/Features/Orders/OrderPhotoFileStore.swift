import Foundation
import Photos

protocol OrderPhotoFileStore {
    func saveOrderPhoto(data: Data, orderId: String, photoId: String) throws -> String
    func deleteOrderPhoto(relativePath: String) throws
    func fileURL(for relativePath: String) -> URL
}

protocol DesignPhotoLibrary {
    func savePhoto(at fileURL: URL) async throws -> String
    func containsAsset(identifier: String) -> Bool
}

enum DesignPhotoLibraryError: Error, Equatable {
    case accessDenied
    case assetCreationFailed
}

final class PhotoKitDesignPhotoLibrary: DesignPhotoLibrary {
    static let referencePrefix = "photos://"

    func savePhoto(at fileURL: URL) async throws -> String {
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authorization == .authorized || authorization == .limited else {
            throw DesignPhotoLibraryError.accessDenied
        }

        var localIdentifier: String?
        try await PHPhotoLibrary.shared().performChanges {
            localIdentifier = PHAssetChangeRequest
                .creationRequestForAssetFromImage(atFileURL: fileURL)?
                .placeholderForCreatedAsset?
                .localIdentifier
        }
        guard let localIdentifier else {
            throw DesignPhotoLibraryError.assetCreationFailed
        }
        return Self.referencePrefix + localIdentifier
    }

    func containsAsset(identifier: String) -> Bool {
        PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject != nil
    }

    static func assetIdentifier(from reference: String) -> String? {
        guard reference.hasPrefix(referencePrefix) else { return nil }
        return String(reference.dropFirst(referencePrefix.count))
    }
}

final class LocalOrderPhotoFileStore: OrderPhotoFileStore {
    private let rootDirectoryURL: URL
    private let fileManager: FileManager

    init(rootDirectoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let rootDirectoryURL {
            self.rootDirectoryURL = rootDirectoryURL
        } else {
            let applicationSupportURL = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.rootDirectoryURL = applicationSupportURL.appendingPathComponent(
                "CloudBakeOwner",
                isDirectory: true
            )
        }
    }

    func saveOrderPhoto(data: Data, orderId: String, photoId: String) throws -> String {
        let relativePath = [
            "OrderPhotos",
            sanitizedPathComponent(orderId),
            "\(sanitizedPathComponent(photoId)).jpg"
        ].joined(separator: "/")
        let fileURL = fileURL(for: relativePath)

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)

        return relativePath
    }

    func deleteOrderPhoto(relativePath: String) throws {
        let fileURL = fileURL(for: relativePath)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        try fileManager.removeItem(at: fileURL)
    }

    func fileURL(for relativePath: String) -> URL {
        rootDirectoryURL.appendingPathComponent(relativePath)
    }

    private func sanitizedPathComponent(_ value: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalars)
            .split(separator: "-")
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return sanitized.isEmpty ? "photo" : sanitized
    }
}
