import XCTest

extension CloudBakeOwnerUITests {
    func testRecipesCanBeAdded() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Recipes", in: app)
        assertScreenVisible("screen.recipes", in: app, timeout: 5)
        XCTAssertTrue(app.staticTexts["No recipes yet"].waitForExistence(timeout: 5))

        app.buttons["recipes.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Recipe"].waitForExistence(timeout: 5))
        app.textFields["recipes.form.name"].tap()
        app.textFields["recipes.form.name"].typeText("Vanilla Sponge")
        app.textFields["recipes.form.notes"].tap()
        app.textFields["recipes.form.notes"].typeText("Book page 12")
        app.buttons["recipes.form.save"].tap()

        assertScreenVisible("screen.recipes", in: app, timeout: 5)
        XCTAssertTrue(app.staticTexts["Vanilla Sponge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Book page 12"].waitForExistence(timeout: 5))
    }

    func testRecipeCanBeImportedFromRecognizedTextDraft() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Inventory", in: app)
        addInventoryItem(named: "Flour", currentQuantity: "1000", minimumQuantity: "500", in: app)
        returnToDashboard(in: app)

        openDashboardDestination("Recipes", in: app)
        assertScreenVisible("screen.recipes", in: app, timeout: 5)
        tapHeaderAction(
            "recipes.import",
            in: app,
            waitingFor: app.navigationBars["Import Recipe"],
            timeout: 15
        )

        let recipeText = app.textFields["recipes.import.text"]
        XCTAssertTrue(recipeText.waitForExistence(timeout: 5))
        typeText("Chocolate Fudge\nFlour 250 g\nBake until set", into: recipeText)
        dismissKeyboard(in: app)
        let ingredientName = app.textFields.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "recipes.import.ingredient.name.")
        ).firstMatch
        tapWhenReady(
            app.buttons["recipes.import.createDraft"],
            waitingFor: ingredientName,
            in: app,
            timeout: 15
        )

        XCTAssertEqual(app.textFields["recipes.import.name"].value as? String, "Chocolate Fudge")
        XCTAssertEqual(app.textFields["recipes.import.notes"].value as? String, "Bake until set")
        XCTAssertTrue(ingredientName.exists)
        XCTAssertTrue(app.staticTexts["Flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.import.ingredient.quantity.")).firstMatch.waitForExistence(timeout: 5))
        let importedRecipe = app.staticTexts["Chocolate Fudge"]
        tapWhenReady(
            app.buttons["recipes.import.save"],
            waitingFor: importedRecipe,
            in: app,
            timeout: 15
        )

        let recipe = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "recipes.item.")
        ).firstMatch
        tapWhenReady(
            recipe,
            waitingFor: app.buttons["recipes.detail.done"],
            in: app,
            timeout: 15
        )
        XCTAssertTrue(app.staticTexts["Flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["250 g"].waitForExistence(timeout: 5))
    }

    func testRecipeIngredientCanBeAddedFromInventory() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Inventory", in: app)
        addInventoryItem(named: "Cake flour", currentQuantity: "1000", minimumQuantity: "500", in: app)
        returnToDashboard(in: app)

        openDashboardDestination("Recipes", in: app)
        addRecipe(named: "Vanilla Sponge", notes: "Book page 12", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.buttons["recipes.detail.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No ingredients yet"].waitForExistence(timeout: 5))

        app.buttons["recipes.ingredient.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Ingredient"].waitForExistence(timeout: 5))
        app.textFields["recipes.ingredient.quantity"].tap()
        app.textFields["recipes.ingredient.quantity"].typeText("250")
        app.textFields["recipes.ingredient.note"].tap()
        app.textFields["recipes.ingredient.note"].typeText("Sift")
        app.buttons["recipes.ingredient.save"].tap()

        XCTAssertTrue(app.buttons["recipes.detail.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["250 g"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sift"].waitForExistence(timeout: 5))

        let deleteButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.ingredient.delete.")).firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        XCTAssertTrue(app.buttons["recipes.ingredient.delete.confirm"].waitForExistence(timeout: 5))
        app.buttons["recipes.ingredient.delete.confirm"].tap()
        XCTAssertTrue(app.staticTexts["No ingredients yet"].waitForExistence(timeout: 5))
    }

    func testRecipeNotesCanBeEditedFromDetail() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Recipes", in: app)
        addRecipe(named: "Vanilla Sponge", notes: "Book page 12", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.buttons["recipes.detail.done"].waitForExistence(timeout: 5))

        app.buttons["recipes.detail.edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Recipe"].waitForExistence(timeout: 5))
        let notesField = app.textFields["recipes.form.notes"]
        XCTAssertTrue(notesField.waitForExistence(timeout: 5))
        notesField.tap()
        notesField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        notesField.typeText("Use two tins")
        app.buttons["recipes.form.save"].tap()

        XCTAssertTrue(app.buttons["recipes.detail.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Use two tins")).firstMatch.waitForExistence(timeout: 5))
    }
}
