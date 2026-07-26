import Foundation
import Photos
import XCTest
@testable import CloudBakeOwner

final class PhotoKitBackupAssetResolverTests: XCTestCase {
    func testResolverRejectsMalformedReferenceInsteadOfTreatingItAsMissing() async {
        do {
            _ = try await PhotoKitBackupAssetResolver().resolve(
                reference: "photos://"
            )
            XCTFail("Expected malformed reference to fail")
        } catch let error as BackupExternalAssetResolverError {
            XCTAssertEqual(error, .invalidReference)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPhotoReferenceParserRejectsEmptyIdentifiers() {
        XCTAssertNil(PhotoKitDesignPhotoLibrary.assetIdentifier(from: "photos://"))
        XCTAssertNil(PhotoKitDesignPhotoLibrary.assetIdentifier(from: "photos://   "))
        XCTAssertNil(PhotoKitDesignPhotoLibrary.assetIdentifier(from: "not-a-photo-reference"))
        XCTAssertEqual(
            PhotoKitDesignPhotoLibrary.assetIdentifier(from: "photos://valid-id"),
            "valid-id"
        )
    }

    func testNilPhotoKitImageIsRetryableRatherThanMissing() {
        let result = PhotoKitBackupAssetResolver.terminalImageResult(
            image: nil,
            info: nil
        )

        guard case .failure(let error) = result else {
            return XCTFail("Expected a terminal image failure")
        }
        XCTAssertEqual(
            error as? BackupExternalAssetResolverError,
            .imageUnavailable
        )
    }

    func testLimitedPhotoAccessIsNotTreatedAsProofOfDeletion() {
        for status in [
            PHAuthorizationStatus.limited,
            .denied,
            .restricted,
            .notDetermined
        ] {
            XCTAssertThrowsError(
                try PhotoKitBackupAssetResolver.requireFullAuthorization(status)
            ) { error in
                XCTAssertEqual(
                    error as? BackupExternalAssetResolverError,
                    .accessDenied
                )
            }
        }
        XCTAssertNoThrow(
            try PhotoKitBackupAssetResolver.requireFullAuthorization(.authorized)
        )
    }

    func testVersionDatePrefersModificationDate() throws {
        let creationDate = Date(timeIntervalSince1970: 100)
        let modificationDate = Date(timeIntervalSince1970: 200)

        XCTAssertEqual(
            try PhotoKitBackupAssetResolver.versionDate(
                modificationDate: modificationDate,
                creationDate: creationDate
            ),
            modificationDate
        )
    }

    func testVersionDateRejectsMissingMetadata() {
        XCTAssertThrowsError(
            try PhotoKitBackupAssetResolver.versionDate(
                modificationDate: nil,
                creationDate: nil
            )
        ) { error in
            XCTAssertEqual(
                error as? BackupExternalAssetResolverError,
                .missingVersionMetadata
            )
        }
    }
}
