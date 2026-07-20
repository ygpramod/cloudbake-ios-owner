import XCTest
@testable import CloudBakeOwner

final class AppIntroductionTests: XCTestCase {
    func testPagesCoverTheFiveEssentialOwnerWorkflowsInOrder() {
        XCTAssertEqual(AppIntroductionPage.all.map(\.id), ["home", "orders", "inventory", "library", "backup"])
    }

    func testNormalNewInstallationPresentsIntroduction() {
        XCTAssertTrue(AppIntroductionPolicy.shouldPresent(hasCompleted: false, isAutomatedTest: false, forcesPresentation: false))
        XCTAssertFalse(AppIntroductionPolicy.shouldPresent(hasCompleted: true, isAutomatedTest: false, forcesPresentation: false))
    }

    func testAutomationOnlyPresentsIntroductionWhenExplicitlyRequested() {
        XCTAssertFalse(AppIntroductionPolicy.shouldPresent(hasCompleted: false, isAutomatedTest: true, forcesPresentation: false))
        XCTAssertTrue(AppIntroductionPolicy.shouldPresent(hasCompleted: true, isAutomatedTest: true, forcesPresentation: true))
    }
}
