import XCTest

final class CloudBakeOwnerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesToDashboard() throws {
        let app = makeApp()
        app.launch()

        assertDashboardVisible(in: app, timeout: 5)
        XCTAssertTrue(app.staticTexts["Upcoming orders"].exists)
        XCTAssertTrue(app.staticTexts["Low inventory"].exists)
    }

    func testOverdueAutomaticBackupOnCellularDoesNotDelayLaunchOrStartTransfer() throws {
        let app = makeApp()
        app.launchEnvironment["CLOUDBAKE_TEST_CELLULAR_BACKUP_CATCH_UP"] = "1"
        app.launch()

        assertDashboardVisible(in: app, timeout: 5)
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.staticTexts["Upcoming orders"].exists)
    }

    func testDashboardDesignsShortcutOpensDesigns() throws {
        let app = makeApp()
        app.launch()

        let designs = app.buttons["dashboard.quickAction.designs"]
        XCTAssertTrue(designs.waitForExistence(timeout: 5))
        tapWhenReady(designs)

        assertScreenVisible("screen.designs", in: app, timeout: 5)
    }

    func testPrimaryNavigationDestinationsAreReachable() throws {
        let destinations = [
            ("Orders", "screen.orders"),
            ("Inventory", "screen.inventory"),
            ("More", "screen.more"),
            ("Recipes", "screen.recipes"),
            ("Customers", "screen.customers"),
            ("Designs", "screen.designs"),
        ]

        for destination in destinations {
            let app = makeApp()
            app.launch()

            openDashboardDestination(destination.0, in: app)
            assertScreenVisible(destination.1, in: app, timeout: 5)
            app.terminate()
        }
    }

    func testReportsOpenOnOutstandingPaymentLedger() {
        let app = makeApp(initialDestination: "reports")
        app.launch()

        assertScreenVisible("screen.reports", in: app, timeout: 10)
        XCTAssertTrue(
            app.segmentedControls["reports.payment.scope"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["reports.filters"].exists
        )
        XCTAssertEqual(
            app.buttons["reports.kind"].value as? String,
            "Payment Ledger"
        )
        XCTAssertTrue(app.buttons["Outstanding"].isSelected)
    }

    func testMoreTabReturnsFromGroupedDestinationToMore() {
        let app = makeApp(initialDestination: "reminders")
        app.launch()

        assertScreenVisible("screen.reminders", in: app, timeout: 10)
        tapWhenReady(app.buttons["bottom.navigation.more"])

        assertScreenVisible("screen.more", in: app, timeout: 5)
    }
}
