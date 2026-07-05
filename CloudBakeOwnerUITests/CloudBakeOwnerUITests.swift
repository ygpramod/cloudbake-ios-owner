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

    func testCustomerDuplicateWarningAppearsBeforeSaving() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Customers"].tap()
        addCustomer(named: "Amy", phone: "5550101", in: app)
        app.buttons["customers.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Customer"].waitForExistence(timeout: 5))
        app.textFields["customers.form.name"].tap()
        app.textFields["customers.form.name"].typeText("Amy")
        app.textFields["customers.form.phone"].tap()
        app.textFields["customers.form.phone"].typeText("5550101")
        app.buttons["customers.form.save"].tap()

        XCTAssertTrue(app.staticTexts["Possible duplicate: Amy already exists. Tap Save again to add a separate customer."].waitForExistence(timeout: 5))
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
}
