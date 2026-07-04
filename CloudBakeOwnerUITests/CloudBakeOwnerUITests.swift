import XCTest

final class CloudBakeOwnerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesToDashboard() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.navigationBars["CloudBake"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Upcoming orders"].exists)
        XCTAssertTrue(app.staticTexts["Low inventory"].exists)
    }

    func testPrimaryNavigationDestinationsAreReachable() throws {
        let app = makeApp()
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
        let app = makeApp()
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

    func testInventoryDuplicateNameShowsWarningBeforeAdding() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)
        app.buttons["inventory.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Item"].waitForExistence(timeout: 5))

        app.textFields["inventory.form.name"].tap()
        app.textFields["inventory.form.name"].typeText("cake flours")
        app.textFields["inventory.form.currentQuantity"].tap()
        app.textFields["inventory.form.currentQuantity"].typeText("100")
        app.textFields["inventory.form.minimumQuantity"].tap()
        app.textFields["inventory.form.minimumQuantity"].typeText("250")
        app.buttons["inventory.form.save"].tap()

        XCTAssertTrue(app.staticTexts["Possible duplicate: Cake flour already exists. Tap Save again to add a separate item."].waitForExistence(timeout: 5))
    }

    func testInventoryItemCanBeEdited() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "50", minimumQuantity: "5000", in: app)

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.edit."))
            .firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            .tap()
        XCTAssertTrue(app.navigationBars["Edit Item"].waitForExistence(timeout: 5))

        let currentQuantityField = app.textFields["inventory.form.currentQuantity"]
        currentQuantityField.tap()
        currentQuantityField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
        currentQuantityField.typeText("500")
        app.buttons["inventory.form.save"].tap()

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current 500 g"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Minimum 5,000 g"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Current 50 g"].exists)
    }

    func testInventoryItemCanBeArchived() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)

        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.edit.")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Archive"].tap()

        XCTAssertTrue(app.staticTexts["No inventory yet"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["CloudBake"].tap()
        XCTAssertTrue(app.navigationBars["CloudBake"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No alerts yet"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Cake flour"].exists)
    }

    func testArchivedInventoryItemCanBeRestored() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)

        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.edit.")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["No inventory yet"].waitForExistence(timeout: 5))

        app.buttons["inventory.archived"].tap()
        XCTAssertTrue(app.navigationBars["Archived"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))

        let archivedItemName = app.staticTexts["Cake flour"]
        XCTAssertTrue(archivedItemName.waitForExistence(timeout: 5))
        archivedItemName.swipeLeft()
        app.buttons["Restore"].tap()
        XCTAssertTrue(app.staticTexts["No archived inventory"].waitForExistence(timeout: 5))
        app.buttons["inventory.archived.done"].tap()

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current 250 g"].waitForExistence(timeout: 5))
    }

    func testInventoryStockCanBeAdjusted() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)

        adjustFirstInventoryItem(by: "100", in: app)

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current 350 g"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Current 250 g"].exists)
    }

    func testInventoryItemCanBeArchivedAfterStockAdjustment() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)
        adjustFirstInventoryItem(by: "100", in: app)

        let row = firstEditableInventoryRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.archive."))
            .firstMatch
            .tap()

        XCTAssertTrue(app.staticTexts["No inventory yet"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Cake flour"].exists)
    }

    func testInventoryStockCanBeConsumed() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "350", minimumQuantity: "500", in: app)

        consumeFirstInventoryItem(by: "100", in: app)

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current 250 g"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Current 350 g"].exists)
    }

    func testInventoryStockConsumptionCannotExceedCurrentStock() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)

        let row = firstEditableInventoryRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeRight()
        app.buttons["Use"].tap()
        XCTAssertTrue(app.navigationBars["Use Stock"].waitForExistence(timeout: 5))
        app.textFields["inventory.consume.quantity"].tap()
        app.textFields["inventory.consume.quantity"].typeText("251")
        app.buttons["inventory.consume.save"].tap()

        XCTAssertTrue(app.staticTexts["Consumption quantity cannot be greater than current stock."].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Current 250 g"].waitForExistence(timeout: 5))
    }

    func testDashboardShowsLowInventoryItems() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)
        app.navigationBars.buttons["CloudBake"].tap()

        XCTAssertTrue(app.navigationBars["CloudBake"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Low inventory"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["250 / 500 g"].waitForExistence(timeout: 5))
    }

    func testDashboardShowsOverflowCountForMoreThanThreeLowInventoryItems() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "1", minimumQuantity: "10", in: app)
        addInventoryItem(named: "Butter", currentQuantity: "2", minimumQuantity: "10", in: app)
        addInventoryItem(named: "Sugar", currentQuantity: "3", minimumQuantity: "10", in: app)
        addInventoryItem(named: "Cocoa", currentQuantity: "4", minimumQuantity: "10", in: app)
        app.navigationBars.buttons["CloudBake"].tap()

        XCTAssertTrue(app.navigationBars["CloudBake"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["+ 1 more"].waitForExistence(timeout: 5))
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] = "1"
        return app
    }

    private func addInventoryItem(
        named name: String,
        currentQuantity: String,
        minimumQuantity: String,
        in app: XCUIApplication
    ) {
        app.buttons["inventory.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Item"].waitForExistence(timeout: 5))
        app.textFields["inventory.form.name"].tap()
        app.textFields["inventory.form.name"].typeText(name)
        app.textFields["inventory.form.currentQuantity"].tap()
        app.textFields["inventory.form.currentQuantity"].typeText(currentQuantity)
        app.textFields["inventory.form.minimumQuantity"].tap()
        app.textFields["inventory.form.minimumQuantity"].typeText(minimumQuantity)
        app.buttons["inventory.form.save"].tap()
    }

    private func adjustFirstInventoryItem(by quantity: String, in app: XCUIApplication) {
        let row = firstEditableInventoryRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeRight()
        app.buttons["Adjust"].tap()
        XCTAssertTrue(app.navigationBars["Adjust Stock"].waitForExistence(timeout: 5))
        app.textFields["inventory.adjust.quantity"].tap()
        app.textFields["inventory.adjust.quantity"].typeText(quantity)
        app.buttons["inventory.adjust.save"].tap()
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 5))
    }

    private func consumeFirstInventoryItem(by quantity: String, in app: XCUIApplication) {
        let row = firstEditableInventoryRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeRight()
        app.buttons["Use"].tap()
        XCTAssertTrue(app.navigationBars["Use Stock"].waitForExistence(timeout: 5))
        app.textFields["inventory.consume.quantity"].tap()
        app.textFields["inventory.consume.quantity"].typeText(quantity)
        app.buttons["inventory.consume.save"].tap()
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 5))
    }

    private func firstEditableInventoryRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.edit.")).firstMatch
    }
}
