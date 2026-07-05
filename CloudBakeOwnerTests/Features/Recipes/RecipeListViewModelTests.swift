import CoreGraphics
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

    func testCreateRecipeDraftFromRecognizedTextCopiesTextIntoDraftFields() {
        let repository = FakeRecipeRepository()
        repository.inventoryItems = [
            InventoryItem(
                id: "inventory-flour",
                name: "Flour",
                unit: .gram,
                currentQuantity: 1_000,
                minimumQuantity: 500,
                createdAt: Date(timeIntervalSince1970: 1_800_030_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_030_000)
            )
        ]
        let viewModel = RecipeListViewModel(repository: repository)
        viewModel.recipeScanRecognizedText = """
        Lemon Drizzle
        Flour 200 g
        Sugar 150 g
        """

        XCTAssertTrue(viewModel.createRecipeDraftFromRecognizedText())

        XCTAssertEqual(viewModel.draftName, "Lemon Drizzle")
        XCTAssertEqual(viewModel.draftNotes, "")
        XCTAssertEqual(
            viewModel.importIngredientDrafts,
            [
                RecipeImportIngredientDraftRow(
                    id: viewModel.importIngredientDrafts[0].id,
                    name: "Flour",
                    quantity: "200",
                    unit: .gram,
                    inventoryItemId: "inventory-flour",
                    note: ""
                ),
                RecipeImportIngredientDraftRow(
                    id: viewModel.importIngredientDrafts[1].id,
                    name: "Sugar",
                    quantity: "150",
                    unit: .gram,
                    inventoryItemId: "",
                    note: ""
                )
            ]
        )
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRecognizeRecipeImageCreatesDraftFromRecognizedText() async {
        let viewModel = RecipeListViewModel(repository: FakeRecipeRepository())

        let didCreateDraft = await viewModel.recognizeRecipeImage(
            placeholderCGImage(),
            recognizer: FakeRecipeTextRecognizer(result: .success("Carrot Cake\nCarrot 200 g"))
        )

        XCTAssertTrue(didCreateDraft)
        XCTAssertEqual(viewModel.recipeScanRecognizedText, "Carrot Cake\nCarrot 200 g")
        XCTAssertEqual(viewModel.draftName, "Carrot Cake")
        XCTAssertEqual(viewModel.draftNotes, "")
        XCTAssertEqual(viewModel.importIngredientDrafts.first?.name, "Carrot")
        XCTAssertEqual(viewModel.importIngredientDrafts.first?.quantity, "200")
        XCTAssertEqual(viewModel.importIngredientDrafts.first?.unit, .gram)
        XCTAssertFalse(viewModel.isRecognizingRecipeScan)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSaveRecipeImportDraftPersistsRecipeAndLinkedIngredients() {
        let repository = FakeRecipeRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        repository.inventoryItems = [
            InventoryItem(
                id: "inventory-flour",
                name: "Flour",
                unit: .gram,
                currentQuantity: 1_000,
                minimumQuantity: 500,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            InventoryItem(
                id: "inventory-sugar",
                name: "Sugar",
                unit: .gram,
                currentQuantity: 1_000,
                minimumQuantity: 500,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        var ids = ["draft-flour", "draft-sugar", "recipe-lemon-drizzle", "component-ingredients", "ingredient-flour", "ingredient-sugar"]
        let viewModel = RecipeListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { timestamp }
        )
        viewModel.recipeScanRecognizedText = """
        Lemon Drizzle
        Flour 200 g
        Sugar 150 g
        Bake until golden
        """
        XCTAssertTrue(viewModel.createRecipeDraftFromRecognizedText())

        XCTAssertTrue(viewModel.saveRecipeImportDraft())

        XCTAssertEqual(repository.recipes.first?.name, "Lemon Drizzle")
        XCTAssertEqual(repository.recipes.first?.notes, "Bake until golden")
        XCTAssertEqual(repository.components.first?.name, "Ingredients")
        XCTAssertEqual(repository.ingredients.count, 2)
        XCTAssertEqual(repository.ingredients.map(\.inventoryItemId), ["inventory-flour", "inventory-sugar"])
        XCTAssertEqual(repository.ingredients.map(\.quantity), [200, 150])
        XCTAssertEqual(repository.ingredients.map(\.note), ["Flour", "Sugar"])
        XCTAssertTrue(viewModel.importIngredientDrafts.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSaveRecipeImportDraftRequiresIngredientLinks() {
        let repository = FakeRecipeRepository()
        var ids = ["draft-flour", "recipe-lemon-drizzle"]
        let viewModel = RecipeListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() }
        )
        viewModel.recipeScanRecognizedText = """
        Lemon Drizzle
        Flour 200 g
        """
        XCTAssertTrue(viewModel.createRecipeDraftFromRecognizedText())

        XCTAssertFalse(viewModel.saveRecipeImportDraft())

        XCTAssertEqual(viewModel.errorMessage, "Link each ingredient to an inventory item before saving.")
        XCTAssertTrue(repository.recipes.isEmpty)
    }

    func testSaveRecipeImportDraftRejectsInventoryLinksOutsideLoadedInventory() {
        let repository = FakeRecipeRepository()
        var ids = ["draft-flour", "recipe-lemon-drizzle"]
        let viewModel = RecipeListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() }
        )
        viewModel.recipeScanRecognizedText = """
        Lemon Drizzle
        Flour 200 g
        """
        XCTAssertTrue(viewModel.createRecipeDraftFromRecognizedText())
        viewModel.importIngredientDrafts[0].inventoryItemId = "missing-inventory"

        XCTAssertFalse(viewModel.saveRecipeImportDraft())

        XCTAssertEqual(viewModel.errorMessage, "Link each ingredient to an inventory item before saving.")
        XCTAssertTrue(repository.recipes.isEmpty)
    }

    func testRecognizeRecipeImageShowsErrorWhenOCRFails() async {
        let viewModel = RecipeListViewModel(repository: FakeRecipeRepository())
        viewModel.recipeScanRecognizedText = "Existing text"

        let didCreateDraft = await viewModel.recognizeRecipeImage(
            placeholderCGImage(),
            recognizer: FakeRecipeTextRecognizer(result: .failure(PurchaseBillTextRecognitionError.unreadableResult))
        )

        XCTAssertFalse(didCreateDraft)
        XCTAssertEqual(viewModel.recipeScanRecognizedText, "Existing text")
        XCTAssertFalse(viewModel.isRecognizingRecipeScan)
        XCTAssertEqual(viewModel.errorMessage, "Recipe image could not be read.")
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

    private func placeholderCGImage() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }
}

private final class FakeRecipeRepository: RecipeRepository,
    RecipeComponentRepository,
    RecipeIngredientRepository,
    InventoryItemRepository {
    var recipes: [Recipe] = []
    var components: [RecipeComponent] = []
    var ingredients: [RecipeIngredient] = []
    var inventoryItems: [InventoryItem] = []
    var archivedInventoryItems: [InventoryItem] = []

    func save(_ recipe: Recipe) throws {
        recipes.removeAll { $0.id == recipe.id }
        recipes.append(recipe)
    }

    func fetchRecipe(id: String) throws -> Recipe? {
        recipes.first { $0.id == id }
    }

    func fetchRecipes() throws -> [Recipe] {
        recipes
    }

    func save(_ component: RecipeComponent) throws {
        components.removeAll { $0.id == component.id }
        components.append(component)
    }

    func fetchRecipeComponent(id: String) throws -> RecipeComponent? {
        components.first { $0.id == id }
    }

    func fetchRecipeComponents(recipeId: String) throws -> [RecipeComponent] {
        components.filter { $0.recipeId == recipeId }
    }

    func save(_ ingredient: RecipeIngredient) throws {
        ingredients.removeAll { $0.id == ingredient.id }
        ingredients.append(ingredient)
    }

    func fetchRecipeIngredient(id: String) throws -> RecipeIngredient? {
        ingredients.first { $0.id == id }
    }

    func fetchRecipeIngredients(componentId: String) throws -> [RecipeIngredient] {
        ingredients.filter { $0.componentId == componentId }
    }

    func deleteRecipeIngredient(id: String) throws {
        ingredients.removeAll { $0.id == id }
    }

    func save(_ item: InventoryItem) throws {
        inventoryItems.removeAll { $0.id == item.id }
        inventoryItems.append(item)
    }

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        inventoryItems.first { $0.id == id } ?? archivedInventoryItems.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        inventoryItems
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        archivedInventoryItems
    }
}

private struct FakeRecipeTextRecognizer: RecipeTextRecognizing {
    let result: Result<String, Error>

    func recognizedText(from image: CGImage) async throws -> String {
        try result.get()
    }
}
