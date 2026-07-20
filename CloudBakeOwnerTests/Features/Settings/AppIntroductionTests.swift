import XCTest
@testable import CloudBakeOwner

final class AppIntroductionTests: XCTestCase {
    func testPagesCoverTheFiveEssentialOwnerWorkflowsInOrder() {
        XCTAssertEqual(AppIntroductionPage.all.map(\.id), ["home", "orders", "inventory", "library", "backup"])
    }

    func testNormalNewInstallationPresentsIntroduction() {
        XCTAssertTrue(AppIntroductionPolicy.shouldPresent(hasCompleted: false, hasExistingOwnerData: false, isAutomatedTest: false, forcesPresentation: false))
        XCTAssertFalse(AppIntroductionPolicy.shouldPresent(hasCompleted: true, hasExistingOwnerData: false, isAutomatedTest: false, forcesPresentation: false))
    }

    func testAutomationOnlyPresentsIntroductionWhenExplicitlyRequested() {
        XCTAssertFalse(AppIntroductionPolicy.shouldPresent(hasCompleted: false, hasExistingOwnerData: false, isAutomatedTest: true, forcesPresentation: false))
        XCTAssertTrue(AppIntroductionPolicy.shouldPresent(hasCompleted: true, hasExistingOwnerData: true, isAutomatedTest: true, forcesPresentation: true))
    }

    func testExistingOwnerDataSuppressesIntroductionAfterUpgrade() {
        XCTAssertFalse(AppIntroductionPolicy.shouldPresent(hasCompleted: false, hasExistingOwnerData: true, isAutomatedTest: false, forcesPresentation: false))
    }
}
