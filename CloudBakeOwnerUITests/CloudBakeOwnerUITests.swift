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

    func testInventoryOwnerJourneyShowsDetailEditsStockHistoryAndDashboard() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.view."))
            .firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            .tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Unit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current Quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Minimum Quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Expiry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["250 g"].waitForExistence(timeout: 5))

        let batchExpiryRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.detail.batch.edit.")).firstMatch
        XCTAssertTrue(batchExpiryRow.waitForExistence(timeout: 5))
        batchExpiryRow.tap()
        XCTAssertTrue(app.navigationBars["Edit Expiry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["inventory.batchExpiry.expiryDate"].waitForExistence(timeout: 5))
        app.buttons["inventory.batchExpiry.save"].tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))

        app.buttons["inventory.detail.edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Item"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Minimum Quantity"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["inventory.form.currentQuantity"].exists)
        XCTAssertFalse(app.buttons["inventory.form.unit"].exists)

        let minimumQuantityField = app.textFields["inventory.form.minimumQuantity"]
        minimumQuantityField.tap()
        minimumQuantityField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        minimumQuantityField.typeText("600")
        app.buttons["inventory.form.save"].tap()

        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))
        app.buttons["inventory.detail.done"].tap()
        XCTAssertTrue(app.staticTexts["Minimum Quantity: 600 g"].waitForExistence(timeout: 5))

        adjustFirstInventoryItem(by: "100", in: app)
        XCTAssertTrue(app.staticTexts["Current Quantity: 350 g"].waitForExistence(timeout: 5))

        consumeFirstInventoryItem(by: "50", in: app)
        XCTAssertTrue(app.staticTexts["Current Quantity: 300 g"].waitForExistence(timeout: 5))

        let row = firstEditableInventoryRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeRight()
        app.buttons["History"].tap()

        XCTAssertTrue(app.navigationBars["Stock History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Used"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["-50 g"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Adjustment"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["+100 g"].waitForExistence(timeout: 5))
        app.buttons["inventory.history.done"].tap()
        app.navigationBars.buttons["CloudBake"].tap()

        XCTAssertTrue(app.navigationBars["CloudBake"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Low inventory"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Expiring soon"].waitForExistence(timeout: 5))
    }

    func testInventoryCanBeArchivedAndRestored() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)

        let row = firstEditableInventoryRow(in: app)
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
        XCTAssertTrue(app.staticTexts["Current Quantity: 250 g"].waitForExistence(timeout: 5))
    }

    func testInventoryPurchaseBillDraftImportCreatesInventoryItems() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        app.buttons["inventory.purchaseBill.import"].tap()
        XCTAssertTrue(app.navigationBars["Import Bill"].waitForExistence(timeout: 5))

        let billText = app.textViews["inventory.purchaseBill.text"]
        XCTAssertTrue(billText.waitForExistence(timeout: 5))
        billText.tap()
        billText.typeText("Cake Flour 1 kg\nLaundry Detergent 1 L\n")
        app.buttons["inventory.purchaseBill.createDrafts"].tap()

        XCTAssertTrue(app.staticTexts["Cake Flour 1 kg"].waitForExistence(timeout: 5))
        app.buttons["inventory.purchaseBill.save"].tap()

        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cake Flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current Quantity: 1 kg"].waitForExistence(timeout: 5))
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
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.view.")).firstMatch
    }
}
