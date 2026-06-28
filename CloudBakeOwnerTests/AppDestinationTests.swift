import XCTest
@testable import CloudBakeOwner

final class AppDestinationTests: XCTestCase {
    func testPrimaryNavigationDestinationsAreInExpectedOrder() {
        XCTAssertEqual(
            AppDestination.allCases.map(\.title),
            ["Dashboard", "Orders", "Inventory", "Recipes", "Designs", "Customers", "Settings"]
        )
    }

    func testDestinationsHaveStableAccessibilityIdentifiers() {
        for destination in AppDestination.allCases {
            XCTAssertEqual(destination.accessibilityIdentifier, "navigation.\(destination.rawValue)")
            XCTAssertEqual(destination.screenAccessibilityIdentifier, "screen.\(destination.rawValue)")
        }
    }
}
