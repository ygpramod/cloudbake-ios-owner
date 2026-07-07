import XCTest

extension CloudBakeOwnerUITests {
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
}
