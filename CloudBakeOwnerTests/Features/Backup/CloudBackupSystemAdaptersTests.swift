import Foundation
import XCTest
@testable import CloudBakeOwner

final class CloudBackupSystemAdaptersTests: XCTestCase {
    func testAccountProtectionGateKeepsPublicationDormantUntilConfirmationShips() async {
        let isAuthorized = await PendingCloudBackupAccountProtectionGate().isPublicationAuthorized()
        XCTAssertFalse(isAuthorized)
    }

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

    func testStagingReconciliationRemovesBuildingAndFinalizedCrashArtifacts() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("interrupted.building", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("finalized-before-metadata", isDirectory: true),
            withIntermediateDirectories: true
        )

        await StagedBackupPackageCleaner(stagingRoot: root).removeAllPackages()

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }
}
