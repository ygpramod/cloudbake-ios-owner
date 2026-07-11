import XCTest
@testable import CloudBakeOwner

@MainActor
final class RecipeListViewModelTests: XCTestCase {
    func testLoadFetchesRecipes() {
        let repository = FakeRecipeRepository()
        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: "Book page 12",
            createdAt: Date(timeIntervalSince1970: 1_800_030_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        repository.recipes = [recipe]
        let viewModel = RecipeListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.recipes, [recipe])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testVisibleRecipesFiltersByNameAndNotes() {
        let repository = FakeRecipeRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let vanilla = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: "Book page 12",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let chocolate = Recipe(
            id: "recipe-chocolate-fudge",
            name: "Chocolate Fudge",
            notes: "Ganache filling",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.recipes = [vanilla, chocolate]
        let viewModel = RecipeListViewModel(repository: repository)

        viewModel.load()
        viewModel.searchText = "ganache"

        XCTAssertEqual(viewModel.visibleRecipes, [chocolate])

        viewModel.searchText = "vanilla"

        XCTAssertEqual(viewModel.visibleRecipes, [vanilla])
    }

    func testRecipeDraftCanSubmitOnlyWhenNameIsPresent() {
        let repository = FakeRecipeRepository()
        let viewModel = RecipeListViewModel(repository: repository)

        viewModel.draftName = " "

        XCTAssertFalse(viewModel.canSubmitRecipeDraft)

        viewModel.draftName = "Vanilla Sponge"

        XCTAssertTrue(viewModel.canSubmitRecipeDraft)
    }

    func testIngredientDraftCanSubmitOnlyWhenInventoryItemAndPositiveQuantityArePresent() {
        let repository = FakeRecipeRepository()
        repository.inventoryItems = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake Flour",
                unit: .kilogram,
                currentQuantity: 1,
                minimumQuantity: 1,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        let viewModel = RecipeListViewModel(repository: repository)

        XCTAssertFalse(viewModel.canSubmitIngredientDraft)

        viewModel.beginAddingIngredient()
        XCTAssertFalse(viewModel.canSubmitIngredientDraft)

        viewModel.draftIngredientQuantity = "0"
        XCTAssertFalse(viewModel.canSubmitIngredientDraft)

        viewModel.draftIngredientQuantity = "250"
        XCTAssertTrue(viewModel.canSubmitIngredientDraft)
    }

    func testAddRecipePersistsAndReloadsRecipes() {
        let repository = FakeRecipeRepository()
        let now = Date(timeIntervalSince1970: 1_800_031_000)
        let viewModel = RecipeListViewModel(
            repository: repository,
            idGenerator: { "recipe-chocolate-truffle" },
            dateProvider: { now }
        )
        viewModel.draftName = " Chocolate Truffle "
        viewModel.draftNotes = "  Use less sweet frosting. "

        XCTAssertTrue(viewModel.addRecipe())

        XCTAssertEqual(
            repository.recipes,
            [
                Recipe(
                    id: "recipe-chocolate-truffle",
                    name: "Chocolate Truffle",
                    notes: "Use less sweet frosting.",
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
        XCTAssertEqual(viewModel.recipes, repository.recipes)
        XCTAssertEqual(viewModel.draftName, "")
        XCTAssertEqual(viewModel.draftNotes, "")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddRecipeRejectsBlankName() {
        let repository = FakeRecipeRepository()
        let viewModel = RecipeListViewModel(repository: repository)
        viewModel.draftName = " "
        viewModel.draftNotes = "Owner note"

        XCTAssertFalse(viewModel.addRecipe())
        XCTAssertEqual(viewModel.errorMessage, "Recipe name is required.")
        XCTAssertTrue(repository.recipes.isEmpty)
    }

    func testSaveEditedRecipePersistsNameAndNotes() {
        let repository = FakeRecipeRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_030_000)
        let updatedAt = Date(timeIntervalSince1970: 1_800_031_000)
        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: "Book page 12",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.recipes = [recipe]
        let viewModel = RecipeListViewModel(
            repository: repository,
            dateProvider: { updatedAt }
        )
        viewModel.beginViewingRecipe(recipe)
        viewModel.beginEditingRecipe()
        viewModel.draftName = "Vanilla Sponge Cake"
        viewModel.draftNotes = "Use two tins"

        XCTAssertTrue(viewModel.saveEditedRecipe())

        let edited = Recipe(
            id: recipe.id,
            name: "Vanilla Sponge Cake",
            notes: "Use two tins",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        XCTAssertEqual(repository.recipes, [edited])
        XCTAssertEqual(viewModel.selectedRecipe, edited)
        XCTAssertEqual(viewModel.recipes, [edited])
        XCTAssertEqual(viewModel.draftName, "")
        XCTAssertEqual(viewModel.draftNotes, "")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testBeginViewingRecipeLoadsIngredientRowsWithInventoryNames() {
        let repository = FakeRecipeRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-ingredients",
            recipeId: recipe.id,
            name: "Ingredients",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let flour = InventoryItem(
            id: "inventory-flour",
            name: "Cake Flour",
            unit: .gram,
            currentQuantity: 1_000,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: flour.id,
            quantity: 250,
            unit: .gram,
            note: "Sift",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.recipes = [recipe]
        repository.components = [component]
        repository.inventoryItems = [flour]
        repository.ingredients = [ingredient]
        let viewModel = RecipeListViewModel(repository: repository)

        viewModel.beginViewingRecipe(recipe)

        XCTAssertEqual(viewModel.selectedRecipe, recipe)
        XCTAssertEqual(
            viewModel.recipeIngredients,
            [
                RecipeIngredientRow(
                    ingredient: ingredient,
                    inventoryItemName: "Cake Flour"
                )
            ]
        )
    }

    func testBeginAddingIngredientDefaultsToFirstInventoryItem() {
        let repository = FakeRecipeRepository()
        repository.inventoryItems = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake Flour",
                unit: .kilogram,
                currentQuantity: 1,
                minimumQuantity: 1,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        let viewModel = RecipeListViewModel(repository: repository)

        viewModel.beginAddingIngredient()

        XCTAssertEqual(viewModel.draftIngredientInventoryItemId, "inventory-flour")
        XCTAssertEqual(viewModel.draftIngredientUnit, .kilogram)
    }

    func testSaveIngredientCreatesDefaultComponentAndPersistsIngredient() {
        let repository = FakeRecipeRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.recipes = [recipe]
        repository.inventoryItems = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake Flour",
                unit: .gram,
                currentQuantity: 1_000,
                minimumQuantity: 500,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        var ids = ["component-ingredients", "ingredient-flour"]
        let viewModel = RecipeListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { timestamp }
        )
        viewModel.beginViewingRecipe(recipe)
        viewModel.beginAddingIngredient()
        viewModel.draftIngredientQuantity = "250"
        viewModel.draftIngredientNote = "Sift"

        XCTAssertTrue(viewModel.saveIngredient())

        XCTAssertEqual(
            repository.components,
            [
                RecipeComponent(
                    id: "component-ingredients",
                    recipeId: recipe.id,
                    name: "Ingredients",
                    sortOrder: 0,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            ]
        )
        XCTAssertEqual(repository.ingredients.count, 1)
        XCTAssertEqual(repository.ingredients.first?.inventoryItemId, "inventory-flour")
        XCTAssertEqual(repository.ingredients.first?.quantity, 250)
        XCTAssertEqual(repository.ingredients.first?.unit, .gram)
        XCTAssertEqual(repository.ingredients.first?.note, "Sift")
        XCTAssertEqual(viewModel.recipeIngredients.first?.inventoryItemName, "Cake Flour")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSaveIngredientRejectsInvalidQuantity() {
        let repository = FakeRecipeRepository()
        repository.inventoryItems = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake Flour",
                unit: .gram,
                currentQuantity: 1_000,
                minimumQuantity: 500,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_030_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
        )
        let viewModel = RecipeListViewModel(repository: repository)
        viewModel.beginViewingRecipe(recipe)
        viewModel.beginAddingIngredient()
        viewModel.draftIngredientQuantity = "0"

        XCTAssertFalse(viewModel.saveIngredient())
        XCTAssertEqual(viewModel.errorMessage, "Ingredient quantity must be greater than zero.")
        XCTAssertTrue(repository.ingredients.isEmpty)
    }

    func testSaveEditedIngredientAcceptsGroupedQuantityText() {
        let repository = FakeRecipeRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-ingredients",
            recipeId: recipe.id,
            name: "Ingredients",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let flour = InventoryItem(
            id: "inventory-flour",
            name: "Cake Flour",
            unit: .gram,
            currentQuantity: 2_000,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: flour.id,
            quantity: 1_000,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.recipes = [recipe]
        repository.components = [component]
        repository.inventoryItems = [flour]
        repository.ingredients = [ingredient]
        let viewModel = RecipeListViewModel(repository: repository)
        viewModel.beginViewingRecipe(recipe)
        viewModel.beginEditingIngredient(ingredient)
        viewModel.draftIngredientQuantity = "1,000"
        viewModel.draftIngredientNote = "Sift twice"

        XCTAssertTrue(viewModel.saveIngredient())

        XCTAssertEqual(repository.ingredients.first?.quantity, 1_000)
        XCTAssertEqual(repository.ingredients.first?.note, "Sift twice")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDeleteIngredientRemovesIngredientAndReloadsRows() {
        let repository = FakeRecipeRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-ingredients",
            recipeId: recipe.id,
            name: "Ingredients",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: "inventory-flour",
            quantity: 250,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.recipes = [recipe]
        repository.components = [component]
        repository.ingredients = [ingredient]
        let viewModel = RecipeListViewModel(repository: repository)
        viewModel.beginViewingRecipe(recipe)

        viewModel.deleteIngredient(ingredient)

        XCTAssertTrue(repository.ingredients.isEmpty)
        XCTAssertTrue(viewModel.recipeIngredients.isEmpty)
    }

}
