import Foundation
import PhotosUI
import SwiftUI
import UIKit

enum PhotoPickerImageLoader {
    static func image(from item: PhotosPickerItem) async throws -> UIImage {
        guard let data = try await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            throw PhotoPickerImageLoaderError.unreadableImage
        }

        return image
    }
}

enum PhotoPickerImageLoaderError: Error {
    case unreadableImage
}

struct AppLogoStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
    }

    func load() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func save(_ image: UIImage) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storedImage = image.preparingThumbnail(of: CGSize(width: 1_024, height: 1_024)) ?? image
        guard let data = storedImage.jpegData(compressionQuality: 0.88) else {
            throw AppLogoStoreError.couldNotEncodeImage
        }
        try data.write(to: fileURL, options: .atomic)
    }

    func remove() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private static var defaultFileURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport
            .appendingPathComponent("CloudBake", isDirectory: true)
            .appendingPathComponent("custom-logo.jpg")
    }
}

enum AppLogoStoreError: Error {
    case couldNotEncodeImage
}
