import XCTest

extension CloudBakeOwnerUITests {
    func testInventoryDuplicateNameShowsWarningBeforeAdding() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Inventory", in: app)
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

        openDashboardDestination("Inventory", in: app)
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

        let batchRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.detail.batch.edit.")).firstMatch
        XCTAssertTrue(batchRow.waitForExistence(timeout: 5))
        batchRow.tap()
        XCTAssertTrue(app.navigationBars["Edit Batch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["inventory.batch.quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["inventory.batch.expiryDate"].waitForExistence(timeout: 5))
        app.buttons["inventory.batch.save"].tap()
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
        returnToDashboard(in: app)

        assertDashboardVisible(in: app, timeout: 5)
        XCTAssertTrue(app.staticTexts["Low inventory"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Expiring soon"].waitForExistence(timeout: 5))
    }

    func testInventoryCanBeArchivedAndRestored() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 20
        app.launch()

        openDashboardDestination("Inventory", in: app, timeout: transitionTimeout)
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)

        let row = inventoryRow(named: "Cake flour", in: app)
        scrollToHittable(row, in: app, timeout: transitionTimeout)
        let archiveButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.archive.")).firstMatch
        scrollToHittable(archiveButton, in: app, timeout: transitionTimeout)
        tapWhenReady(archiveButton, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["No inventory yet"].waitForExistence(timeout: transitionTimeout))

        tapWhenReady(app.buttons["inventory.archived"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Archived"].waitForExistence(timeout: transitionTimeout))

        let archivedRow = archivedInventoryRow(named: "Cake flour", in: app)
        scrollToHittable(archivedRow, in: app, timeout: transitionTimeout)
        archivedRow.swipeLeft()
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.archived.restore.")).firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.staticTexts["No archived inventory"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["inventory.archived.done"], timeout: transitionTimeout)

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Current Quantity: 250 g"].waitForExistence(timeout: transitionTimeout))
    }

    func testInventoryDetailShowsStockActionsInMoreMenu() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Inventory", in: app)
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)
        firstEditableInventoryRow(in: app).tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons["inventory.detail.edit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inventory.detail.more"].waitForExistence(timeout: 5))

        app.buttons["inventory.detail.more"].tap()
        app.buttons["inventory.detail.adjust"].tap()
        XCTAssertTrue(app.navigationBars["Adjust Stock"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))

        app.buttons["inventory.detail.more"].tap()
        app.buttons["inventory.detail.consume"].tap()
        XCTAssertTrue(app.navigationBars["Use Stock"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))

        app.buttons["inventory.detail.more"].tap()
        app.buttons["inventory.detail.history"].tap()
        XCTAssertTrue(app.navigationBars["Stock History"].waitForExistence(timeout: 5))
        app.buttons["inventory.history.done"].tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))
    }

    func testInventoryPurchaseBillImportShowsCameraAndManualDraftControls() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Inventory", in: app)
        app.buttons["inventory.purchaseBill.import"].tap()
        XCTAssertTrue(app.navigationBars["Import Bill"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons["inventory.purchaseBill.camera"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inventory.purchaseBill.library"].waitForExistence(timeout: 5))
        let billText = app.textFields["inventory.purchaseBill.text"]
        XCTAssertTrue(billText.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inventory.purchaseBill.createDrafts"].waitForExistence(timeout: 5))
    }
}
