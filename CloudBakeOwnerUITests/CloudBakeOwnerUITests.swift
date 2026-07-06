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

    func testOrderCanBeAddedAndListed() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["No orders yet"].waitForExistence(timeout: transitionTimeout))

        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: transitionTimeout))
    }

    func testOrderCanBeOpenedFromListAndViewed() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))

        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        let orderRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
            .firstMatch
        tapWhenReady(orderRow)

        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.customerName"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.fulfillmentType"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.cakeNotes"], in: app, timeout: transitionTimeout)
    }

    func testOrderShowsDueRemindersAndReminderPlan() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        let orderTitle = "Reminder Vanilla Birthday"
        app.launch()

        tapWhenReady(app.staticTexts["Orders"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        addOrder(named: orderTitle, notes: "Pink flowers", customerName: "Amy", in: app)

        scrollToTop(in: app)
        XCTAssertTrue(app.staticTexts["Reminders Due"].waitForExistence(timeout: transitionTimeout))
        let reminderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.reminder.",
                orderTitle
            )
        )
            .firstMatch
        tapWhenReady(reminderRow, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars[orderTitle].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.reminder.3"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.reminder.2"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.reminder.1"], in: app, timeout: transitionTimeout)
    }

    func testOrderCanBeEditedFromDetail() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.detail.edit"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Edit Order"].waitForExistence(timeout: transitionTimeout))

        let titleField = app.textFields["orders.form.title"]
        tapWhenReady(titleField, timeout: transitionTimeout)
        titleField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        titleField.typeText("Chocolate Birthday")

        let notesField = app.textFields["orders.form.cakeNotes"]
        tapWhenReady(notesField, timeout: transitionTimeout)
        notesField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        notesField.typeText("Gold leaf")

        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Chocolate Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.cakeNotes"], in: app, timeout: transitionTimeout)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Gold leaf"))
                .firstMatch
                .waitForExistence(timeout: transitionTimeout)
        )
    }

    func testOrderCanLinkCustomerFromSearchableSelection() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Customers"])
        addCustomer(named: "Amy", phone: "5550101", in: app)
        app.navigationBars.buttons["CloudBake"].tap()

        tapWhenReady(app.staticTexts["Orders"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        tapWhenReady(app.buttons["orders.form.customerRecord"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Customer Record"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.customerSelection.customer."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        typeText("Vanilla Birthday", into: app.textFields["orders.form.title"], timeout: transitionTimeout)
        typeText("Pink flowers", into: app.textFields["orders.form.cakeNotes"], timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
                .firstMatch,
            timeout: transitionTimeout
        )

        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.customerName"], in: app, timeout: transitionTimeout)
        let allergyText = app.staticTexts["orders.detail.customerAllergies"]
        assertExistsAfterScrolling(allergyText, in: app, timeout: transitionTimeout)
        XCTAssertTrue(allergyText.label.contains("Nuts"))
    }

    func testOrderCalendarViewShowsOrders() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        tapWhenReady(app.buttons["Calendar"], timeout: transitionTimeout)

        XCTAssertTrue(app.staticTexts["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
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

    func testInventoryDetailShowsStockActionsInMoreMenu() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
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

        app.staticTexts["Inventory"].tap()
        app.buttons["inventory.purchaseBill.import"].tap()
        XCTAssertTrue(app.navigationBars["Import Bill"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons["inventory.purchaseBill.camera"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inventory.purchaseBill.library"].waitForExistence(timeout: 5))
        let billText = app.textFields["inventory.purchaseBill.text"]
        XCTAssertTrue(billText.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inventory.purchaseBill.createDrafts"].waitForExistence(timeout: 5))
    }

    func testRecipesCanBeAdded() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Recipes"].tap()
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No recipes yet"].waitForExistence(timeout: 5))

        app.buttons["recipes.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Recipe"].waitForExistence(timeout: 5))
        app.textFields["recipes.form.name"].tap()
        app.textFields["recipes.form.name"].typeText("Vanilla Sponge")
        app.textFields["recipes.form.notes"].tap()
        app.textFields["recipes.form.notes"].typeText("Book page 12")
        app.buttons["recipes.form.save"].tap()

        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Vanilla Sponge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Book page 12"].waitForExistence(timeout: 5))
    }

    func testRecipeCanBeImportedFromRecognizedTextDraft() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Flour", currentQuantity: "1000", minimumQuantity: "500", in: app)
        app.navigationBars.buttons["CloudBake"].tap()

        app.staticTexts["Recipes"].tap()
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 5))
        app.buttons["recipes.import"].tap()
        XCTAssertTrue(app.navigationBars["Import Recipe"].waitForExistence(timeout: 5))

        let recipeText = app.textFields["recipes.import.text"]
        XCTAssertTrue(recipeText.waitForExistence(timeout: 5))
        recipeText.tap()
        recipeText.typeText("Chocolate Fudge\nFlour 250 g\nBake until set")
        app.buttons["recipes.import.createDraft"].tap()

        XCTAssertEqual(app.textFields["recipes.import.name"].value as? String, "Chocolate Fudge")
        XCTAssertEqual(app.textFields["recipes.import.notes"].value as? String, "Bake until set")
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.import.ingredient.name.")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.import.ingredient.quantity.")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["recipes.import.save"].tap()

        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chocolate Fudge"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.navigationBars["Chocolate Fudge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["250 g"].waitForExistence(timeout: 5))
    }

    func testRecipeIngredientCanBeAddedFromInventory() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "1000", minimumQuantity: "500", in: app)
        app.navigationBars.buttons["CloudBake"].tap()

        app.staticTexts["Recipes"].tap()
        addRecipe(named: "Vanilla Sponge", notes: "Book page 12", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.navigationBars["Vanilla Sponge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No ingredients yet"].waitForExistence(timeout: 5))

        app.buttons["recipes.ingredient.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Ingredient"].waitForExistence(timeout: 5))
        app.textFields["recipes.ingredient.quantity"].tap()
        app.textFields["recipes.ingredient.quantity"].typeText("250")
        app.textFields["recipes.ingredient.note"].tap()
        app.textFields["recipes.ingredient.note"].typeText("Sift")
        app.buttons["recipes.ingredient.save"].tap()

        XCTAssertTrue(app.navigationBars["Vanilla Sponge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["250 g"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sift"].waitForExistence(timeout: 5))
    }

    func testRecipeNotesCanBeEditedFromDetail() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Recipes"].tap()
        addRecipe(named: "Vanilla Sponge", notes: "Book page 12", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.navigationBars["Vanilla Sponge"].waitForExistence(timeout: 5))

        app.buttons["recipes.detail.edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Recipe"].waitForExistence(timeout: 5))
        let notesField = app.textFields["recipes.form.notes"]
        XCTAssertTrue(notesField.waitForExistence(timeout: 5))
        notesField.tap()
        notesField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        notesField.typeText("Use two tins")
        app.buttons["recipes.form.save"].tap()

        XCTAssertTrue(app.navigationBars["Vanilla Sponge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Use two tins")).firstMatch.waitForExistence(timeout: 5))
    }

    func testCustomerCanBeAddedAndViewed() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Customers"].tap()
        XCTAssertTrue(app.navigationBars["Customers"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No customers yet"].waitForExistence(timeout: 5))

        addCustomer(named: "Amy", phone: "5550101", in: app)

        XCTAssertTrue(app.navigationBars["Customers"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["5550101"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item."))
            .firstMatch
            .tap()

        XCTAssertTrue(app.navigationBars["Amy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Phone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Birthday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nuts"].waitForExistence(timeout: 5))
    }

    func testCustomerDetailUsesSplitViewOnIPad() throws {
        let app = makeApp()
        app.launchEnvironment["CLOUDBAKE_SEED_CUSTOMER_FIXTURE"] = "1"
        app.launch()

        guard app.windows.firstMatch.waitForExistence(timeout: 5),
              app.windows.firstMatch.frame.width >= 700 else {
            throw XCTSkip("Customer split view is only expected on regular-width iPad layouts.")
        }

        app.staticTexts["Customers"].tap()
        XCTAssertTrue(app.navigationBars["Customers"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Select a customer"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item."))
            .firstMatch
            .tap()

        XCTAssertTrue(app.navigationBars["Amy"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["customers.detail.done"].exists)
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Phone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Birthday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nuts"].waitForExistence(timeout: 5))
    }

    func testCustomerAddOffersContactsImportAndManualEntry() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Customers"].tap()
        XCTAssertTrue(app.navigationBars["Customers"].waitForExistence(timeout: 5))
        app.buttons["customers.add"].tap()

        XCTAssertTrue(app.buttons["Import From Contacts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Enter Manually"].waitForExistence(timeout: 5))
        app.buttons["Enter Manually"].tap()
        XCTAssertTrue(app.navigationBars["Add Customer"].waitForExistence(timeout: 5))
    }

    func testCustomerDuplicateWarningAppearsBeforeSaving() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Customers"].tap()
        addCustomer(named: "Amy", phone: "5550101", in: app)
        app.buttons["customers.add"].tap()
        XCTAssertTrue(app.buttons["Enter Manually"].waitForExistence(timeout: 5))
        app.buttons["Enter Manually"].tap()
        XCTAssertTrue(app.navigationBars["Add Customer"].waitForExistence(timeout: 5))
        app.textFields["customers.form.name"].tap()
        app.textFields["customers.form.name"].typeText("Amy")
        app.textFields["customers.form.phone"].tap()
        app.textFields["customers.form.phone"].typeText("5550101")
        app.buttons["customers.form.save"].tap()

        XCTAssertTrue(app.staticTexts["Possible duplicate: Amy already exists. Tap Save again to add a separate customer."].waitForExistence(timeout: 5))
    }

    func testCustomerCanBeEditedFromDetail() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Customers"].tap()
        addCustomer(named: "Amy", phone: "5550101", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.navigationBars["Amy"].waitForExistence(timeout: 5))

        app.buttons["customers.detail.edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Customer"].waitForExistence(timeout: 5))
        let nameField = app.textFields["customers.form.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        nameField.typeText("Amy B")
        app.buttons["customers.form.save"].tap()

        XCTAssertTrue(app.navigationBars["Amy B"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Amy B"].waitForExistence(timeout: 5))
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

    private func addOrder(
        named name: String,
        notes: String,
        customerName: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 15
    ) {
        tapWhenReady(app.buttons["orders.add"])
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: timeout))
        typeText(name, into: app.textFields["orders.form.title"])
        typeText(notes, into: app.textFields["orders.form.cakeNotes"])
        typeText(customerName, into: app.textFields["orders.form.customerName"])
        tapWhenReady(app.buttons["orders.form.save"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: timeout))
    }

    private func addRecipe(named name: String, notes: String, in app: XCUIApplication) {
        app.buttons["recipes.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Recipe"].waitForExistence(timeout: 5))
        app.textFields["recipes.form.name"].tap()
        app.textFields["recipes.form.name"].typeText(name)
        app.textFields["recipes.form.notes"].tap()
        app.textFields["recipes.form.notes"].typeText(notes)
        app.buttons["recipes.form.save"].tap()
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 5))
    }

    private func addCustomer(named name: String, phone: String, in app: XCUIApplication) {
        app.buttons["customers.add"].tap()
        XCTAssertTrue(app.buttons["Enter Manually"].waitForExistence(timeout: 5))
        app.buttons["Enter Manually"].tap()
        XCTAssertTrue(app.navigationBars["Add Customer"].waitForExistence(timeout: 5))
        app.textFields["customers.form.name"].tap()
        app.textFields["customers.form.name"].typeText(name)
        app.textFields["customers.form.phone"].tap()
        app.textFields["customers.form.phone"].typeText(phone)
        app.textFields["customers.form.email"].tap()
        app.textFields["customers.form.email"].typeText("amy@example.com")
        app.textFields["customers.form.address"].tap()
        app.textFields["customers.form.address"].typeText("10 Cake Street")
        app.textFields["customers.form.importantDate.label"].tap()
        app.textFields["customers.form.importantDate.label"].typeText("Birthday")
        app.textFields["customers.form.allergies"].tap()
        app.textFields["customers.form.allergies"].typeText("Nuts")
        app.buttons["customers.form.save"].tap()
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

    private func tapWhenReady(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element did not exist before tap.", file: file, line: line)
        let hittable = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: hittable, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Element was not hittable before tap.",
            file: file,
            line: line
        )
        element.tap()
    }

    private func typeText(
        _ text: String,
        into element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tapWhenReady(element, timeout: timeout, file: file, line: line)
        element.typeText(text)
    }

    private func assertExistsAfterScrolling(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !element.exists && Date() < deadline {
            app.swipeUp()
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(element.exists, "Element did not exist after scrolling.", file: file, line: line)
    }

    private func scrollToTop(in app: XCUIApplication) {
        for _ in 0..<3 {
            app.swipeDown()
        }
    }
}
