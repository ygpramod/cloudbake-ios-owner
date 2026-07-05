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

    func testCreateRecipeDraftFromRecognizedTextCopiesTextIntoDraftFields() {
        let viewModel = RecipeListViewModel(repository: FakeRecipeRepository())
        viewModel.recipeScanRecognizedText = """
        Lemon Drizzle
        Flour 200 g
        Sugar 150 g
        """

        XCTAssertTrue(viewModel.createRecipeDraftFromRecognizedText())

        XCTAssertEqual(viewModel.draftName, "Lemon Drizzle")
        XCTAssertEqual(viewModel.draftNotes, "Flour 200 g\nSugar 150 g")
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
        XCTAssertEqual(viewModel.draftNotes, "Carrot 200 g")
        XCTAssertFalse(viewModel.isRecognizingRecipeScan)
        XCTAssertNil(viewModel.errorMessage)
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

private struct FakeRecipeTextRecognizer: RecipeTextRecognizing {
    let result: Result<String, Error>

    func recognizedText(from image: CGImage) async throws -> String {
        try result.get()
    }
}
