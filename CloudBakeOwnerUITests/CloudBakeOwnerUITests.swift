import XCTest

final class CloudBakeOwnerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesToDashboard() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["CloudBake"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Upcoming orders"].exists)
        XCTAssertTrue(app.staticTexts["Low inventory"].exists)
    }

    func testPrimaryNavigationDestinationsAreReachable() throws {
        let app = XCUIApplication()
        app.launch()

        for title in ["Orders", "Inventory", "Recipes", "Designs", "Customers", "Settings"] {
            let navigationLink = app.staticTexts[title]
            if !navigationLink.waitForExistence(timeout: 2) {
                app.swipeUp()
            }
            XCTAssertTrue(navigationLink.waitForExistence(timeout: 5), "Missing navigation link for \(title)")
            navigationLink.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), "Missing screen for \(title)")
            app.navigationBars.buttons["CloudBake"].tap()
        }
    }

    func testInventoryItemCanBeAdded() throws {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Inventory"].tap()
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 5))

        app.buttons["inventory.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Item"].waitForExistence(timeout: 5))

        app.textFields["inventory.form.name"].tap()
        app.textFields["inventory.form.name"].typeText("Cake flour")
        app.textFields["inventory.form.currentQuantity"].tap()
        app.textFields["inventory.form.currentQuantity"].typeText("250")
        app.textFields["inventory.form.minimumQuantity"].tap()
        app.textFields["inventory.form.minimumQuantity"].typeText("500")
        app.buttons["inventory.form.save"].tap()

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current 250 g"].exists)
        XCTAssertTrue(app.staticTexts["Minimum 500 g"].exists)
    }
}
