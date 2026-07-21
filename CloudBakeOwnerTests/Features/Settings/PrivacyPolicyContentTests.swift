import XCTest
@testable import CloudBakeOwner

final class PrivacyPolicyContentTests: XCTestCase {
    func testPolicyExplainsStorageBackupPermissionsRetentionAndSharing() {
        XCTAssertEqual(
            PrivacyPolicyContent.sections.map(\.id),
            ["stored-data", "cloud-backup", "device-access", "retention", "sharing"]
        )
    }

    func testOnlinePolicyUsesPublicMainBranchSource() {
        XCTAssertEqual(
            PrivacyPolicyContent.onlinePolicyURL?.absoluteString,
            "https://github.com/ygpramod/cloudbake-ios-owner/blob/main/wiki/Privacy-Policy.md"
        )
    }
}
