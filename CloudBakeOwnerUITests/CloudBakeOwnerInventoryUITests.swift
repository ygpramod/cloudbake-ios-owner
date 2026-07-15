import XCTest

extension CloudBakeOwnerUITests {
    func testExpiredInventoryCanBeDisposedFromItemDetail() throws {
        let app = makeApp(initialDestination: "inventory")
        app.launchEnvironment["CLOUDBAKE_SEED_EXPIRED_INVENTORY_FIXTURE"] = "1"
        app.launch()

        let item = app.buttons["inventory.item.view.inventory-ui-expired-cream"]
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        tapWhenReady(item)
        let detailScroll = app.scrollViews["inventory.detail.screen"]
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5))
        let dispose = app.buttons["inventory.detail.disposeExpired"]
        scrollToHittable(dispose, in: app, scrollContainer: detailScroll, timeout: 10)
        tapWhenReady(dispose)
        let confirmDisposal = app.buttons["inventory.disposeExpired.confirm"]
        XCTAssertTrue(confirmDisposal.waitForExistence(timeout: 5))
        tapWhenReady(confirmDisposal)

        XCTAssertFalse(app.buttons["inventory.detail.disposeExpired"].exists)
        app.buttons["inventory.detail.done"].tap()
        let updatedQuantity = app.staticTexts.element(
            matching: NSPredicate(format: "label == %@", "Current Quantity: 125 ml")
        )
        XCTAssertTrue(updatedQuantity.waitForExistence(timeout: 5))
    }

    func testInventoryDuplicateNameShowsWarningBeforeAdding() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Inventory", in: app)
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)
        tapInventoryHeaderAction(
            "inventory.add",
            in: app,
            waitingFor: app.navigationBars["Add Item"]
        )

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
        let app = makeInventoryFixtureApp()
        openSeededInventoryDetail(in: app)

        XCTAssertTrue(app.buttons["inventory.detail.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Unit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current Quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Minimum Quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Expiry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["250 g"].waitForExistence(timeout: 5))

        app.buttons["inventory.detail.done"].tap()
        assertScreenVisible("screen.inventory", in: app, timeout: 5)
        XCTAssertFalse(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.adjust.")
            ).firstMatch.exists
        )
        XCTAssertFalse(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.consume.")
            ).firstMatch.exists
        )

        adjustFirstInventoryItem(by: "100", in: app)
        XCTAssertTrue(app.staticTexts["Current Quantity: 350 g"].waitForExistence(timeout: 5))

        consumeFirstInventoryItem(by: "50", in: app)
        XCTAssertTrue(app.staticTexts["Current Quantity: 300 g"].waitForExistence(timeout: 5))

        let inventoryRow = inventoryRow(named: "Cake flour", in: app)
        scrollToHittable(inventoryRow, in: app)
        let historyButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.history.")).firstMatch
        XCTAssertFalse(historyButton.isHittable, "History must remain hidden until the owner swipes right.")
        inventoryRow.swipeRight()
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        scrollToHittable(historyButton, in: app)
        tapWhenReady(historyButton, timeout: 10)

        XCTAssertTrue(app.buttons["inventory.history.done"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Used"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["-50 g"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Adjustment"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["+100 g"].waitForExistence(timeout: 5))
        app.buttons["inventory.history.done"].tap()
        returnToDashboard(in: app)

        assertDashboardVisible(in: app, timeout: 5)
        let lowInventoryAlert = app.descendants(matching: .any)["dashboard.attention.lowInventory"]
        XCTAssertTrue(lowInventoryAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(lowInventoryAlert.label.contains("Low inventory"))
        XCTAssertTrue(lowInventoryAlert.label.contains("Cake flour"))
        XCTAssertTrue(lowInventoryAlert.label.contains("Expiring soon"))
    }

    func testInventorySwipeReturnStopsAtClosedCard() throws {
        let app = makeInventoryFixtureApp()
        openDashboardDestination("Inventory", in: app)

        let inventoryRow = inventoryRow(named: "Cake flour", in: app)
        let historyButton = app.buttons["inventory.item.history.inventory-ui-fixture-cake-flour"]
        let archiveButton = app.buttons["inventory.item.archive.inventory-ui-fixture-cake-flour"]
        let closeActions = app.otherElements["inventory.item.closeActions.inventory-ui-fixture-cake-flour"]
        let filter = app.segmentedControls["inventory.filter"]
        XCTAssertFalse(historyButton.isHittable)

        inventoryRow.swipeRight()
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        tapWhenReady(historyButton, timeout: 5)
        XCTAssertTrue(app.buttons["inventory.history.done"].waitForExistence(timeout: 5))
        app.buttons["inventory.history.done"].tap()

        inventoryRow.swipeLeft()
        XCTAssertTrue(archiveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(closeActions.waitForExistence(timeout: 5))
        closeActions.swipeRight()

        XCTAssertGreaterThanOrEqual(
            archiveButton.frame.minX,
            inventoryRow.frame.maxX,
            "Returning from Archive and Delete must place Archive beyond the visible card."
        )
        XCTAssertLessThanOrEqual(
            historyButton.frame.maxX,
            inventoryRow.frame.minX,
            "Closing destructive actions must not reveal History."
        )

        inventoryRow.swipeRight()
        XCTAssertTrue(closeActions.waitForExistence(timeout: 5))
        closeActions.swipeLeft()

        XCTAssertLessThanOrEqual(
            historyButton.frame.maxX,
            inventoryRow.frame.minX,
            "Returning from History must place History beyond the visible card."
        )
        XCTAssertGreaterThanOrEqual(
            archiveButton.frame.minX,
            inventoryRow.frame.maxX,
            "Closing History must not reveal Archive and Delete."
        )
        XCTAssertTrue(filter.buttons["All"].isSelected, "Card swipes must not change inventory filters.")
    }

    func testInventoryEmptySpaceSwipesBetweenAdjacentFilters() throws {
        let app = makeApp(initialDestination: "inventory")
        app.launchEnvironment["CLOUDBAKE_SEED_LONG_INVENTORY_FIXTURE"] = "1"
        app.launch()

        let filter = app.segmentedControls["inventory.filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        XCTAssertTrue(filter.buttons["All"].isSelected)

        let firstRow = inventoryRow(named: "Scroll item 01", in: app)
        let secondRow = inventoryRow(named: "Scroll item 02", in: app)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        XCTAssertTrue(secondRow.waitForExistence(timeout: 5))
        let gapY = (firstRow.frame.maxY + secondRow.frame.minY) / 2

        swipeInventoryFilterLeft(in: app, at: gapY)
        XCTAssertTrue(filter.buttons["Low stock"].isSelected)

        swipeInventoryFilterLeft(in: app)
        XCTAssertTrue(filter.buttons["Expiring soon"].isSelected)

        swipeInventoryFilterRight(in: app)
        XCTAssertTrue(filter.buttons["Low stock"].isSelected)

        swipeInventoryFilterRight(in: app)
        XCTAssertTrue(filter.buttons["All"].isSelected)
    }

    private func swipeInventoryFilterLeft(in app: XCUIApplication, at y: CGFloat? = nil) {
        swipeInventoryFilter(in: app, fromX: 0.88, toX: 0.12, at: y)
    }

    private func swipeInventoryFilterRight(in app: XCUIApplication, at y: CGFloat? = nil) {
        swipeInventoryFilter(in: app, fromX: 0.12, toX: 0.88, at: y)
    }

    private func swipeInventoryFilter(
        in app: XCUIApplication,
        fromX: CGFloat,
        toX: CGFloat,
        at y: CGFloat?
    ) {
        let screen = app.scrollViews["screen.inventory"]
        XCTAssertTrue(screen.waitForExistence(timeout: 5))
        let normalizedY = y.map { ($0 - screen.frame.minY) / screen.frame.height } ?? 0.72
        let start = screen.coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: normalizedY))
        let end = screen.coordinate(withNormalizedOffset: CGVector(dx: toX, dy: normalizedY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func makeInventoryFixtureApp() -> XCUIApplication {
        let app = makeApp()
        app.launchEnvironment["CLOUDBAKE_SEED_INVENTORY_FIXTURE"] = "1"
        app.launch()
        return app
    }

    private func openSeededInventoryDetail(in app: XCUIApplication) {
        openDashboardDestination("Inventory", in: app)

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        tapWhenReady(firstEditableInventoryRow(in: app), timeout: 10)
    }

    func testInventoryCanBeArchivedAndRestored() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 20
        app.launch()

        openDashboardDestination("Inventory", in: app, timeout: transitionTimeout)
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)

        let row = inventoryRow(named: "Cake flour", in: app)
        scrollToHittable(row, in: app, timeout: transitionTimeout)
        XCTAssertFalse(app.staticTexts["Minimum Quantity: 500 g"].exists)
        row.swipeLeft()
        let archiveButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.archive.")).firstMatch
        scrollToHittable(archiveButton, in: app, timeout: transitionTimeout)
        tapWhenReady(
            archiveButton,
            waitingFor: app.buttons["inventory.archive.confirm"],
            in: app,
            timeout: transitionTimeout
        )
        tapWhenReady(app.buttons["inventory.archive.confirm"], timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["No inventory yet"].waitForExistence(timeout: transitionTimeout))

        tapInventoryHeaderAction(
            "inventory.archived",
            in: app,
            waitingFor: app.buttons["inventory.archived.done"],
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.buttons["inventory.archived.done"].waitForExistence(timeout: transitionTimeout))

        let restoreButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.archived.restore.")).firstMatch
        scrollToHittable(restoreButton, in: app, timeout: transitionTimeout)
        tapWhenReady(restoreButton, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["No archived inventory"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["inventory.archived.done"], timeout: transitionTimeout)

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Current Quantity: 250 g"].waitForExistence(timeout: transitionTimeout))
    }

    func testUnusedArchivedInventoryCanBeDeleted() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 20
        app.launch()

        openDashboardDestination("Inventory", in: app, timeout: transitionTimeout)
        addInventoryItem(
            named: "Unused topper",
            currentQuantity: "0",
            minimumQuantity: "0",
            in: app
        )

        let row = inventoryRow(named: "Unused topper", in: app)
        scrollToHittable(row, in: app, timeout: transitionTimeout)
        row.swipeLeft()
        let archiveButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.archive.")
        ).firstMatch
        tapWhenReady(
            archiveButton,
            waitingFor: app.buttons["inventory.archive.confirm"],
            in: app,
            timeout: transitionTimeout
        )
        tapWhenReady(app.buttons["inventory.archive.confirm"], timeout: transitionTimeout)

        tapInventoryHeaderAction(
            "inventory.archived",
            in: app,
            waitingFor: app.buttons["inventory.archived.done"],
            timeout: transitionTimeout
        )
        let deleteButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "inventory.archived.delete.")
        ).firstMatch
        tapWhenReady(deleteButton, timeout: transitionTimeout)
        tapWhenReady(app.buttons["inventory.archived.delete.confirm"], timeout: transitionTimeout)

        XCTAssertTrue(app.staticTexts["No archived inventory"].waitForExistence(timeout: transitionTimeout))
    }

    func testInventoryCardsPreserveVerticalScrollingAcrossLongLists() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 20
        app.launchEnvironment["CLOUDBAKE_SEED_LONG_INVENTORY_FIXTURE"] = "1"
        app.launch()

        openDashboardDestination("Inventory", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["Scroll item 01"].waitForExistence(timeout: transitionTimeout))

        let lastRow = inventoryRow(named: "Scroll item 08", in: app)
        scrollToHittable(lastRow, in: app, timeout: transitionTimeout)
        XCTAssertTrue(lastRow.isHittable)

        lastRow.swipeLeft()
        let archiveButton = app.buttons["inventory.item.archive.inventory-ui-scroll-8"]
        XCTAssertTrue(archiveButton.waitForExistence(timeout: transitionTimeout))
        scrollToHittable(archiveButton, in: app, timeout: transitionTimeout)
        XCTAssertTrue(archiveButton.isHittable)
        XCTAssertTrue(lastRow.isHittable)
        XCTAssertGreaterThan(archiveButton.frame.midX, app.windows.firstMatch.frame.midX)
    }

    func testInventoryDetailShowsStockActionsInMoreMenu() throws {
        let app = makeInventoryFixtureApp()
        openSeededInventoryDetail(in: app)

        XCTAssertTrue(app.buttons["inventory.detail.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inventory.detail.edit"].waitForExistence(timeout: 5))
        let adjustButton = app.buttons["inventory.detail.adjust"]
        let consumeButton = app.buttons["inventory.detail.consume"]
        let historyButton = app.buttons["inventory.detail.history"]
        let aliasButton = app.buttons["inventory.detail.alias"]
        scrollToHittable(adjustButton, in: app, timeout: 5)
        scrollToHittable(consumeButton, in: app, timeout: 5)
        scrollToHittable(historyButton, in: app, timeout: 5)
        scrollToHittable(aliasButton, in: app, timeout: 5)

        let batchRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.detail.batch.edit.")).firstMatch
        XCTAssertTrue(batchRow.waitForExistence(timeout: 5))
        batchRow.tap()
        XCTAssertTrue(app.navigationBars["Edit Batch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["inventory.batch.quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["inventory.batch.expiryDate"].waitForExistence(timeout: 5))
        app.buttons["inventory.batch.save"].tap()
        XCTAssertTrue(app.buttons["inventory.detail.done"].waitForExistence(timeout: 5))

        app.buttons["inventory.detail.edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Item"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Minimum Quantity"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["inventory.form.currentQuantity"].exists)
        XCTAssertFalse(app.buttons["inventory.form.unit"].exists)

        let formScroll = app.descendants(matching: .any)["inventory.form.scroll"]
        let defaultExpiryDaysField = app.textFields["inventory.form.defaultExpiryDays"]
        scrollToHittable(defaultExpiryDaysField, in: app, scrollContainer: formScroll, timeout: 5)
        typeText("45", into: defaultExpiryDaysField)
        dismissKeyboard(in: app)

        let minimumQuantityField = app.textFields["inventory.form.minimumQuantity"]
        scrollToHittable(minimumQuantityField, in: app, scrollContainer: formScroll, timeout: 5)
        minimumQuantityField.tap()
        minimumQuantityField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        minimumQuantityField.typeText("600")
        app.buttons["inventory.form.save"].tap()
        XCTAssertTrue(app.buttons["inventory.detail.done"].waitForExistence(timeout: 5))

        app.buttons["inventory.detail.edit"].tap()
        XCTAssertTrue(defaultExpiryDaysField.waitForExistence(timeout: 5))
        XCTAssertEqual(defaultExpiryDaysField.value as? String, "45")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["inventory.detail.done"].waitForExistence(timeout: 5))

        scrollToHittable(adjustButton, in: app, timeout: 5)
        adjustButton.tap()
        XCTAssertTrue(app.navigationBars["Adjust Stock"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["inventory.detail.done"].waitForExistence(timeout: 5))

        scrollToHittable(consumeButton, in: app, timeout: 5)
        consumeButton.tap()
        XCTAssertTrue(app.navigationBars["Use Stock"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["inventory.detail.done"].waitForExistence(timeout: 5))

        scrollToHittable(historyButton, in: app, timeout: 5)
        historyButton.tap()
        XCTAssertTrue(app.buttons["inventory.history.done"].waitForExistence(timeout: 5))
        app.buttons["inventory.history.done"].tap()
        XCTAssertTrue(app.buttons["inventory.detail.done"].waitForExistence(timeout: 5))
    }

    func testInventoryPurchaseBillImportShowsCameraAndManualDraftControls() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Inventory", in: app)
        tapInventoryHeaderAction(
            "inventory.purchaseBill.import",
            in: app,
            waitingFor: app.navigationBars["Import Bill"]
        )
        XCTAssertTrue(app.navigationBars["Import Bill"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons["inventory.purchaseBill.camera"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inventory.purchaseBill.library"].waitForExistence(timeout: 5))
        let billText = app.textFields["inventory.purchaseBill.text"]
        XCTAssertTrue(billText.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inventory.purchaseBill.createDrafts"].waitForExistence(timeout: 5))
    }

    func testVoiceInventoryDraftsCanUpdateExistingAndCreateUnknownItems() throws {
        let app = makeApp(initialDestination: "inventory")
        app.launchEnvironment["CLOUDBAKE_SEED_INVENTORY_FIXTURE"] = "1"
        app.launch()

        tapInventoryHeaderAction(
            "inventory.voice.add",
            in: app,
            waitingFor: app.navigationBars["Add by Voice"]
        )

        let transcript = app.textViews["inventory.voice.transcript"]
        XCTAssertTrue(transcript.waitForExistence(timeout: 5))
        typeText("Cake flour 800 grams, strawberry 100 grams", into: transcript)
        dismissKeyboard(in: app)
        tapWhenReady(app.buttons["inventory.voice.createDrafts"])

        XCTAssertTrue(app.staticTexts["Inventory Item Not Found"].waitForExistence(timeout: 5))
        tapWhenReady(app.buttons["inventory.voice.unknown.create"])
        tapWhenReady(app.buttons["inventory.voice.save"])

        XCTAssertTrue(app.staticTexts["Current Quantity: 1,050 g"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["strawberry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current Quantity: 100 g"].waitForExistence(timeout: 5))
    }
}
