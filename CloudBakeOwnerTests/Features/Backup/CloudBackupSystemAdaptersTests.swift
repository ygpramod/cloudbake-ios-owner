import Foundation
import XCTest
@testable import CloudBakeOwner

final class CloudBackupSystemAdaptersTests: XCTestCase {
    func testAccountProtectionGateAuthorizesOnlyTheConfirmedCurrentAccount() async {
        let suiteName = "CloudBackupAccountProtectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let account = MutableBackupAccount(fingerprint: "account-a")
        let gate = CloudBackupAccountProtectionGate(account: account, defaults: defaults)

        let initialAuthorization = await gate.isPublicationAuthorized()
        let didAuthorize = await gate.authorizePublication(for: "account-a")
        let confirmedAuthorization = await gate.isPublicationAuthorized()
        XCTAssertFalse(initialAuthorization)
        XCTAssertTrue(didAuthorize)
        XCTAssertTrue(confirmedAuthorization)

        await account.setFingerprint("account-b")
        let changedAccountAuthorization = await gate.isPublicationAuthorized()
        let staleAuthorization = await gate.authorizePublication(for: "account-a")
        XCTAssertFalse(changedAccountAuthorization)
        XCTAssertFalse(staleAuthorization)
        XCTAssertEqual(
            defaults.string(forKey: CloudBackupAccountProtectionGate.confirmedFingerprintKey),
            "account-a"
        )
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

private actor MutableBackupAccount: BackupAccountChecking {
    private var fingerprint: String?

    init(fingerprint: String?) {
        self.fingerprint = fingerprint
    }

    func currentAvailability() async -> BackupAccountAvailability {
        fingerprint == nil ? .unavailable : .available
    }

    func currentFingerprint() async -> String? { fingerprint }

    func setFingerprint(_ fingerprint: String?) {
        self.fingerprint = fingerprint
    }
}
