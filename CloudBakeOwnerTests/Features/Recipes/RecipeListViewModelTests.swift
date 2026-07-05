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
}

private final class FakeRecipeRepository: RecipeRepository {
    var recipes: [Recipe] = []

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
}
