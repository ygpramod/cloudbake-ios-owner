import XCTest
@testable import CloudBakeOwner

final class AppDestinationTests: XCTestCase {
    func testPrimaryNavigationDestinationsAreInExpectedOrder() {
        XCTAssertEqual(
            AppDestination.allCases.map(\.title),
            ["Dashboard", "Orders", "Inventory", "More", "Recipes", "Designs", "Reminders", "Customers", "Settings"]
        )
    }

    func testDestinationsHaveStableAccessibilityIdentifiers() {
        for destination in AppDestination.allCases {
            XCTAssertEqual(destination.accessibilityIdentifier, "navigation.\(destination.rawValue)")
            XCTAssertEqual(destination.screenAccessibilityIdentifier, "screen.\(destination.rawValue)")
        }
    }

    func testSecondaryDestinationsAreGroupedUnderMore() {
        XCTAssertEqual(
            AppDestination.allCases.filter(\.isGroupedUnderMore).map(\.title),
            ["Recipes", "Designs", "Reminders", "Customers", "Settings"]
        )
    }
}
