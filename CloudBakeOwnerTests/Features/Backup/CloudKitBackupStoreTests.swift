import CloudKit
import XCTest
@testable import CloudBakeOwner

final class CloudKitBackupStoreTests: XCTestCase {
    func testCloudKitErrorsMapToOwnerSafeCategories() {
        let cases: [(CKError.Code, CloudBackupErrorCategory)] = [
            (.notAuthenticated, .authenticationRequired),
            (.accountTemporarilyUnavailable, .iCloudUnavailable),
            (.networkUnavailable, .networkUnavailable),
            (.networkFailure, .networkUnavailable),
            (.quotaExceeded, .quotaExceeded),
            (.permissionFailure, .permissionDenied),
            (.managedAccountRestricted, .permissionDenied),
            (.serverRecordChanged, .conflict),
            (.assetFileModified, .conflict),
            (.operationCancelled, .cancelled),
            (.serviceUnavailable, .temporarilyUnavailable),
            (.requestRateLimited, .temporarilyUnavailable),
            (.zoneBusy, .temporarilyUnavailable),
            (.unknownItem, .corruptRemoteData)
        ]

        for (code, expectedCategory) in cases {
            XCTAssertEqual(
                CloudKitBackupErrorMapper.category(for: CKError(code)),
                expectedCategory,
                "Unexpected mapping for \(code)"
            )
        }
    }

    func testPartialFailureSelectsDeterministicActionableCategory() {
        let partialFailure = NSError(
            domain: CKErrorDomain,
            code: CKError.partialFailure.rawValue,
            userInfo: [
                CKPartialErrorsByItemIDKey: [
                    "network": CKError(.networkFailure),
                    "account": CKError(.notAuthenticated)
                ]
            ]
        )

        XCTAssertEqual(
            CloudKitBackupErrorMapper.category(for: partialFailure),
            .authenticationRequired
        )
    }

    func testMappedErrorNeverExposesUnsafeOperationIdentifier() {
        let error = CloudKitBackupErrorMapper.storeError(
            CKError(.networkFailure),
            operationID: "customer@example.com"
        )

        XCTAssertEqual(error.category, .networkUnavailable)
        XCTAssertEqual(error.operationID, "operation")
    }

    func testCancellationMapsWithoutCloudKitError() {
        XCTAssertEqual(
            CloudKitBackupErrorMapper.category(for: CancellationError()),
            .cancelled
        )
    }
}
