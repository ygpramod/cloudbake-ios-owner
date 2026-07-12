import Foundation
import Photos
import UIKit

struct BackupResolvedExternalAsset: Sendable {
    let data: Data
    let modificationDate: Date?
}

protocol BackupExternalAssetResolving: Sendable {
    func resolve(reference: String) async throws -> BackupResolvedExternalAsset
}

enum BackupExternalAssetResolverError: Error, Equatable {
    case accessDenied
    case assetUnavailable
    case imageEncodingFailed
}

struct PhotoKitBackupAssetResolver: BackupExternalAssetResolving {
    private static let maximumDimension: CGFloat = 2_048

    func resolve(reference: String) async throws -> BackupResolvedExternalAsset {
        guard let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(from: reference) else {
            throw BackupExternalAssetResolverError.assetUnavailable
        }
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard authorization == .authorized || authorization == .limited else {
            throw BackupExternalAssetResolverError.accessDenied
        }
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        ).firstObject else {
            throw BackupExternalAssetResolverError.assetUnavailable
        }

        let image = try await requestLightweightImage(for: asset)
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw BackupExternalAssetResolverError.imageEncodingFailed
        }
        return BackupResolvedExternalAsset(
            data: data,
            modificationDate: asset.modificationDate ?? asset.creationDate
        )
    }

    private func requestLightweightImage(for asset: PHAsset) async throws -> UIImage {
        let scale = min(
            1,
            Self.maximumDimension / CGFloat(max(max(asset.pixelWidth, asset.pixelHeight), 1))
        )
        let targetSize = CGSize(
            width: max(1, CGFloat(asset.pixelWidth) * scale),
            height: max(1, CGFloat(asset.pixelHeight) * scale)
        )
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            let gate = PhotoRequestContinuationGate(continuation: continuation)
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
                if let error = info?[PHImageErrorKey] as? Error {
                    gate.resume(.failure(error))
                } else if (info?[PHImageCancelledKey] as? Bool) == true {
                    gate.resume(.failure(CancellationError()))
                } else if let image {
                    gate.resume(.success(image))
                } else {
                    gate.resume(.failure(BackupExternalAssetResolverError.assetUnavailable))
                }
            }
        }
    }
}

private final class PhotoRequestContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<UIImage, Error>?

    init(continuation: CheckedContinuation<UIImage, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<UIImage, Error>) {
        lock.lock()
        let pendingContinuation = continuation
        continuation = nil
        lock.unlock()
        pendingContinuation?.resume(with: result)
    }
}
