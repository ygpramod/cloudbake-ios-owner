import Foundation
import XCTest
@testable import CloudBakeOwner

final class CloudBackupSystemAdaptersTests: XCTestCase {
    func testPowerPolicyRejectsLowPowerAndElevatedThermalStates() {
        XCTAssertTrue(
            SystemBackupPowerChecker.isEligible(
                isLowPowerModeEnabled: false,
                thermalState: .nominal
            )
        )
        XCTAssertFalse(
            SystemBackupPowerChecker.isEligible(
                isLowPowerModeEnabled: true,
                thermalState: .nominal
            )
        )
        XCTAssertFalse(
            SystemBackupPowerChecker.isEligible(
                isLowPowerModeEnabled: false,
                thermalState: .serious
            )
        )
    }

    func testStoragePolicyUsesMinimumAllowanceAndLargerKnownPayload() {
        let minimum = VolumeBackupStorageChecker.minimumWorkingByteCount
        XCTAssertFalse(
            VolumeBackupStorageChecker.hasSufficientStorage(
                availableByteCount: minimum - 1,
                appStorageByteCount: 1,
                estimatedUploadByteCount: nil
            )
        )
        XCTAssertTrue(
            VolumeBackupStorageChecker.hasSufficientStorage(
                availableByteCount: minimum,
                appStorageByteCount: 1,
                estimatedUploadByteCount: nil
            )
        )
        let knownPayload = minimum * 2
        XCTAssertFalse(
            VolumeBackupStorageChecker.hasSufficientStorage(
                availableByteCount: knownPayload * 2 - 1,
                appStorageByteCount: 100,
                estimatedUploadByteCount: knownPayload
            )
        )
        XCTAssertTrue(
            VolumeBackupStorageChecker.hasSufficientStorage(
                availableByteCount: knownPayload * 2,
                appStorageByteCount: 100,
                estimatedUploadByteCount: knownPayload
            )
        )
    }

    func testStoragePolicyFailsClosedOnOverflow() {
        XCTAssertFalse(
            VolumeBackupStorageChecker.hasSufficientStorage(
                availableByteCount: Int64.max,
                appStorageByteCount: Int64.max,
                estimatedUploadByteCount: Int64.max
            )
        )
    }
}
