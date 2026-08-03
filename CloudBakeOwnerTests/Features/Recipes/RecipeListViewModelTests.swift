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

    func testLoadBuildsRecipeSummariesFromIngredients() {
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
        let sugar = InventoryItem(
            id: "inventory-sugar",
            name: "Caster Sugar",
            unit: .gram,
            currentQuantity: 1_000,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.recipes = [recipe]
        repository.components = [component]
        repository.inventoryItems = [sugar, flour]
        repository.ingredients = [
            RecipeIngredient(
                id: "ingredient-sugar",
                componentId: component.id,
                inventoryItemId: sugar.id,
                quantity: 100,
                unit: .gram,
                note: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            RecipeIngredient(
                id: "ingredient-flour",
                componentId: component.id,
                inventoryItemId: flour.id,
                quantity: 250,
                unit: .gram,
                note: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
        ]
        let viewModel = RecipeListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(
            viewModel.recipeSummaries[recipe.id],
            RecipeListSummary(
                ingredientCount: 2,
                ingredientNames: ["Cake Flour", "Caster Sugar"]
            )
        )

        viewModel.searchText = "cake flour"

        XCTAssertEqual(viewModel.visibleRecipes, [recipe])
    }

    func testVisibleRecipesIncludeRecipesRegardlessOfIngredientState() {
        let repository = FakeRecipeRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let complete = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let draft = Recipe(
            id: "recipe-draft",
            name: "New Cake Idea",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-ingredients",
            recipeId: complete.id,
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
        repository.recipes = [complete, draft]
        repository.components = [component]
        repository.inventoryItems = [flour]
        repository.ingredients = [
            RecipeIngredient(
                id: "ingredient-flour",
                componentId: component.id,
                inventoryItemId: flour.id,
                quantity: 250,
                unit: .gram,
                note: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        let viewModel = RecipeListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.visibleRecipes, [complete, draft])
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

    func testAddRecipePersistsContinuouslyEnteredIngredientDrafts() {
        let repository = FakeRecipeRepository()
        let now = Date(timeIntervalSince1970: 1_800_031_000)
        let flour = InventoryItem(
            id: "inventory-flour",
            name: "Cake Flour",
            unit: .gram,
            currentQuantity: 1_000,
            minimumQuantity: 500,
            createdAt: now,
            updatedAt: now
        )
        repository.inventoryItems = [flour]
        var generatedIds = [
            "ingredient-flour-1",
            "ingredient-flour-2",
            "recipe-vanilla",
            "component-ingredients",
        ].makeIterator()
        let viewModel = RecipeListViewModel(
            repository: repository,
            idGenerator: { generatedIds.next() ?? "unexpected-id" },
            dateProvider: { now }
        )

        viewModel.beginAddingNewRecipeIngredient()
        viewModel.draftIngredientQuantity = "250"
        XCTAssertTrue(viewModel.saveNewRecipeIngredientDraft())
        XCTAssertEqual(viewModel.newRecipeIngredientDrafts.count, 1)
        XCTAssertEqual(viewModel.draftIngredientQuantity, "")

        viewModel.beginAddingNewRecipeIngredient()
        viewModel.draftIngredientQuantity = "100"
        XCTAssertTrue(viewModel.saveNewRecipeIngredientDraft())

        viewModel.draftName = "Vanilla Sponge"
        XCTAssertTrue(viewModel.addRecipe())

        XCTAssertEqual(repository.recipes.map(\.id), ["recipe-vanilla"])
        XCTAssertEqual(repository.components.map(\.id), ["component-ingredients"])
        XCTAssertEqual(repository.ingredients.map(\.quantity), [250, 100])
        XCTAssertTrue(viewModel.newRecipeIngredientDrafts.isEmpty)
    }

    func testAddRecipeKeepsIngredientDraftsWhenAtomicSaveFails() {
        enum ExpectedError: Error {
            case save
        }

        let repository = FakeRecipeRepository()
        let now = Date(timeIntervalSince1970: 1_800_031_000)
        repository.inventoryItems = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake Flour",
                unit: .gram,
                currentQuantity: 1_000,
                minimumQuantity: 500,
                createdAt: now,
                updatedAt: now
            )
        ]
        let viewModel = RecipeListViewModel(repository: repository)
        viewModel.beginAddingNewRecipeIngredient()
        viewModel.draftIngredientQuantity = "250"
        XCTAssertTrue(viewModel.saveNewRecipeIngredientDraft())
        viewModel.draftName = "Vanilla Sponge"
        repository.recipeAggregateSaveError = ExpectedError.save

        XCTAssertFalse(viewModel.addRecipe())

        XCTAssertTrue(repository.recipes.isEmpty)
        XCTAssertTrue(repository.components.isEmpty)
        XCTAssertTrue(repository.ingredients.isEmpty)
        XCTAssertEqual(viewModel.newRecipeIngredientDrafts.count, 1)
        XCTAssertEqual(viewModel.errorMessage, "Recipe could not be saved.")
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

    func testSaveIngredientShortagePreservesDraftAndStableIdAcrossOverride() {
        let repository = FakeRecipeRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let flour = InventoryItem(
            id: "inventory-flour",
            name: "Cake Flour",
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 50,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.recipes = [recipe]
        repository.inventoryItems = [flour]
        repository.recipeIngredientMutationError = OrderRecipeUsageError.insufficientStock([
            OrderInventoryShortage(
                inventoryItemId: flour.id,
                inventoryItemName: flour.name,
                requiredQuantity: 300,
                availableQuantity: 100,
                unit: .gram
            )
        ])
        var dateOffset: TimeInterval = 0
        let viewModel = RecipeListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "ingredient"),
            dateProvider: {
                defer { dateOffset += 1 }
                return timestamp.addingTimeInterval(dateOffset)
            }
        )
        viewModel.beginViewingRecipe(recipe)
        viewModel.beginAddingIngredient()
        viewModel.draftIngredientQuantity = "300"
        viewModel.draftIngredientNote = "Sift twice"

        XCTAssertFalse(viewModel.saveIngredient())
        XCTAssertEqual(
            viewModel.inventoryShortageWarningMessage,
            "Cake Flour: short by 200 g"
        )
        XCTAssertEqual(viewModel.draftIngredientQuantity, "300")
        XCTAssertEqual(viewModel.draftIngredientNote, "Sift twice")
        XCTAssertTrue(repository.components.isEmpty)
        XCTAssertTrue(repository.ingredients.isEmpty)

        viewModel.cancelInventoryShortageOverride()

        XCTAssertTrue(viewModel.pendingInventoryShortages.isEmpty)
        XCTAssertEqual(viewModel.draftIngredientQuantity, "300")
        XCTAssertFalse(viewModel.confirmPendingIngredientInventoryShortage())
        XCTAssertEqual(
            viewModel.errorMessage,
            "Review an inventory shortage before continuing."
        )
        XCTAssertFalse(viewModel.saveIngredient())
        viewModel.draftIngredientQuantity = "999"
        XCTAssertTrue(viewModel.confirmPendingIngredientInventoryShortage())

        XCTAssertEqual(repository.components.map(\.id), ["ingredient-1"])
        XCTAssertEqual(repository.ingredients.map(\.id), ["ingredient-2"])
        XCTAssertEqual(repository.ingredients.first?.quantity, 300)
        XCTAssertEqual(repository.allowInventoryShortageRequests, [false, false, true])
        XCTAssertEqual(
            repository.recipeIngredientMutationRequests[1].ingredient,
            repository.recipeIngredientMutationRequests[2].ingredient
        )
        XCTAssertEqual(
            repository.recipeIngredientMutationRequests[1].component,
            repository.recipeIngredientMutationRequests[2].component
        )
    }

    func testSaveIngredientOverrideFailureRemainsEditable() {
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
            currentQuantity: 100,
            minimumQuantity: 50,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.recipes = [recipe]
        repository.components = [component]
        repository.inventoryItems = [flour]
        let existingIngredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: flour.id,
            quantity: 100,
            unit: .gram,
            note: "Original",
            createdAt: timestamp.addingTimeInterval(-100),
            updatedAt: timestamp.addingTimeInterval(-50)
        )
        repository.ingredients = [existingIngredient]
        repository.recipeIngredientMutationError = OrderRecipeUsageError.insufficientStock([
            OrderInventoryShortage(
                inventoryItemId: flour.id,
                inventoryItemName: flour.name,
                requiredQuantity: 300,
                availableQuantity: 100,
                unit: .gram
            )
        ])
        var dateOffset: TimeInterval = 0
        let viewModel = RecipeListViewModel(
            repository: repository,
            idGenerator: { "ingredient-flour" },
            dateProvider: {
                defer { dateOffset += 1 }
                return timestamp.addingTimeInterval(dateOffset)
            }
        )
        viewModel.beginViewingRecipe(recipe)
        viewModel.beginEditingIngredient(existingIngredient)
        viewModel.draftIngredientQuantity = "300"

        XCTAssertFalse(viewModel.saveIngredient())

        repository.recipeIngredientMutationError =
            OrderRecipeUsageError.missingInventoryItem(flour.id)
        XCTAssertFalse(viewModel.confirmPendingIngredientInventoryShortage())

        XCTAssertTrue(viewModel.pendingInventoryShortages.isEmpty)
        XCTAssertEqual(
            viewModel.errorMessage,
            "A recipe ingredient inventory item could not be found."
        )
        XCTAssertEqual(viewModel.draftIngredientQuantity, "300")
        XCTAssertEqual(repository.ingredients, [existingIngredient])

        repository.recipeIngredientMutationError = OrderRecipeUsageError.insufficientStock([
            OrderInventoryShortage(
                inventoryItemId: flour.id,
                inventoryItemName: flour.name,
                requiredQuantity: 300,
                availableQuantity: 100,
                unit: .gram
            )
        ])
        XCTAssertFalse(viewModel.saveIngredient())
        XCTAssertTrue(viewModel.confirmPendingIngredientInventoryShortage())

        XCTAssertEqual(repository.ingredients.first?.id, existingIngredient.id)
        XCTAssertEqual(repository.ingredients.first?.createdAt, existingIngredient.createdAt)
        XCTAssertEqual(
            repository.recipeIngredientMutationRequests[2].ingredient,
            repository.recipeIngredientMutationRequests[3].ingredient
        )
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
