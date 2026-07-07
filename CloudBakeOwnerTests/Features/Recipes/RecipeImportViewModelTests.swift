import XCTest
@testable import CloudBakeOwner

@MainActor
final class RecipeImportViewModelTests: XCTestCase {
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
        guard let image = placeholderCGImage() else {
            XCTFail("Expected placeholder image setup to succeed.")
            return
        }

        let didCreateDraft = await viewModel.recognizeRecipeImage(
            image,
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
        guard let image = placeholderCGImage() else {
            XCTFail("Expected placeholder image setup to succeed.")
            return
        }

        let didCreateDraft = await viewModel.recognizeRecipeImage(
            image,
            recognizer: FakeRecipeTextRecognizer(result: .failure(PurchaseBillTextRecognitionError.unreadableResult))
        )

        XCTAssertFalse(didCreateDraft)
        XCTAssertEqual(viewModel.recipeScanRecognizedText, "Existing text")
        XCTAssertFalse(viewModel.isRecognizingRecipeScan)
        XCTAssertEqual(viewModel.errorMessage, "Recipe image could not be read.")
    }
}
