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
