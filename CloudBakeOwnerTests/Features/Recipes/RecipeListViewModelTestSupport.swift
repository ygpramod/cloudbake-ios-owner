import CoreGraphics
@testable import CloudBakeOwner

func placeholderCGImage() -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    return context.makeImage()
}

final class FakeRecipeRepository: RecipeRepository,
    RecipeComponentRepository,
    RecipeIngredientRepository,
    RecipeCSVImportRepository,
    InventoryItemRepository {
    var recipes: [Recipe] = []
    var components: [RecipeComponent] = []
    var ingredients: [RecipeIngredient] = []
    var inventoryItems: [InventoryItem] = []
    var archivedInventoryItems: [InventoryItem] = []
    var recipeCSVImportError: Error?

    func saveRecipeCSVImport(
        recipes: [Recipe],
        components: [RecipeComponent],
        ingredients: [RecipeIngredient]
    ) throws {
        if let recipeCSVImportError { throw recipeCSVImportError }
        self.recipes.append(contentsOf: recipes)
        self.components.append(contentsOf: components)
        self.ingredients.append(contentsOf: ingredients)
    }

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

struct FakeRecipeTextRecognizer: RecipeTextRecognizing {
    let result: Result<String, Error>

    func recognizedText(from image: CGImage) async throws -> String {
        try result.get()
    }
}
