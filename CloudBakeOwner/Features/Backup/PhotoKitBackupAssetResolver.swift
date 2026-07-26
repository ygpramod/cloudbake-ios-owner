import Foundation
import Photos
import UIKit

struct BackupResolvedExternalAsset: Sendable {
    let data: Data
    let modificationDate: Date
}

protocol BackupExternalAssetResolving: Sendable {
    func resolve(reference: String) async throws -> BackupResolvedExternalAsset
}

enum BackupExternalAssetResolverError: Error, Equatable {
    case invalidReference
    case accessDenied
    case assetUnavailable
    case assetChangedDuringRead
    case missingVersionMetadata
    case imageUnavailable
    case imageEncodingFailed
}

struct PhotoKitBackupAssetResolver: BackupExternalAssetResolving {
    private static let maximumDimension: CGFloat = 2_048

    func resolve(reference: String) async throws -> BackupResolvedExternalAsset {
        guard let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(from: reference) else {
            throw BackupExternalAssetResolverError.invalidReference
        }
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        try Self.requireFullAuthorization(authorization)
        let fetchedAsset = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        ).firstObject
        guard let asset = fetchedAsset else {
            try Self.requireFullAuthorization(
                PHPhotoLibrary.authorizationStatus(for: .readWrite)
            )
            throw BackupExternalAssetResolverError.assetUnavailable
        }

        let initialVersionDate = try Self.versionDate(
            modificationDate: asset.modificationDate,
            creationDate: asset.creationDate
        )
        let image = try await requestLightweightImage(for: asset)
        try Task.checkCancellation()
        guard let refreshedAsset = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        ).firstObject else {
            throw BackupExternalAssetResolverError.assetChangedDuringRead
        }
        let finalVersionDate = try Self.versionDate(
            modificationDate: refreshedAsset.modificationDate,
            creationDate: refreshedAsset.creationDate
        )
        guard initialVersionDate == finalVersionDate else {
            throw BackupExternalAssetResolverError.assetChangedDuringRead
        }
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw BackupExternalAssetResolverError.imageEncodingFailed
        }
        return BackupResolvedExternalAsset(
            data: data,
            modificationDate: finalVersionDate
        )
    }

    static func versionDate(modificationDate: Date?, creationDate: Date?) throws -> Date {
        guard let versionDate = modificationDate ?? creationDate else {
            throw BackupExternalAssetResolverError.missingVersionMetadata
        }
        return versionDate
    }

    static func requireFullAuthorization(_ status: PHAuthorizationStatus) throws {
        guard status == .authorized else {
            throw BackupExternalAssetResolverError.accessDenied
        }
    }

    static func terminalImageResult(
        image: UIImage?,
        info: [AnyHashable: Any]?
    ) -> Result<UIImage, Error>? {
        guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else {
            return nil
        }
        if let error = info?[PHImageErrorKey] as? Error {
            return .failure(error)
        }
        if (info?[PHImageCancelledKey] as? Bool) == true {
            return .failure(CancellationError())
        }
        if let image {
            return .success(image)
        }
        return .failure(BackupExternalAssetResolverError.imageUnavailable)
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

        let request = PhotoImageRequest()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                request.start(
                    asset: asset,
                    targetSize: targetSize,
                    options: options,
                    continuation: continuation
                )
            }
        } onCancel: {
            request.cancel()
        }
    }
}

private final class PhotoImageRequest: @unchecked Sendable {
    private let lock = NSLock()
    private let imageManager = PHImageManager.default()
    private var continuation: CheckedContinuation<UIImage, Error>?
    private var requestID: PHImageRequestID?
    private var isCancelled = false

    func start(
        asset: PHAsset,
        targetSize: CGSize,
        options: PHImageRequestOptions,
        continuation: CheckedContinuation<UIImage, Error>
    ) {
        lock.lock()
        guard !isCancelled else {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        lock.unlock()

        let identifier = imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, info in
            guard let result = PhotoKitBackupAssetResolver.terminalImageResult(
                image: image,
                info: info
            ) else { return }
            self?.finish(result)
        }

        lock.lock()
        requestID = identifier
        let shouldCancel = isCancelled
        lock.unlock()
        if shouldCancel {
            imageManager.cancelImageRequest(identifier)
        }
    }

    func cancel() {
        lock.lock()
        let pendingContinuation = continuation
        continuation = nil
        isCancelled = true
        let identifier = requestID
        lock.unlock()
        if let identifier {
            imageManager.cancelImageRequest(identifier)
        }
        pendingContinuation?.resume(throwing: CancellationError())
    }

    private func finish(_ result: Result<UIImage, Error>) {
        lock.lock()
        let pendingContinuation = continuation
        continuation = nil
        lock.unlock()
        pendingContinuation?.resume(with: result)
    }
}
