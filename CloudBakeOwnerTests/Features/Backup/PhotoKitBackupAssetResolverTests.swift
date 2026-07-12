import Foundation
import XCTest
@testable import CloudBakeOwner

final class PhotoKitBackupAssetResolverTests: XCTestCase {
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
