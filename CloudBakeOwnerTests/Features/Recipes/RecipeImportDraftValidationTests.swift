import XCTest
@testable import CloudBakeOwner

final class RecipeImportDraftValidationTests: XCTestCase {
    func testValidateReturnsRecipeAndParsedIngredientDrafts() {
        let flourDraft = ingredientDraft(
            id: "draft-flour",
            quantity: "1,000",
            inventoryItemId: "inventory-flour",
            note: " Sift "
        )
        let result = RecipeImportDraftValidation.validate(
            RecipeImportDraftValidationInput(
                recipeName: " Vanilla Sponge ",
                recipeNotes: " Book page 12 ",
                ingredientDrafts: [flourDraft],
                availableInventoryItemIds: ["inventory-flour"]
            )
        )

        XCTAssertEqual(
            try? result.get(),
            ValidatedRecipeImportDraft(
                recipe: ValidatedRecipeDraft(
                    name: "Vanilla Sponge",
                    notes: "Book page 12"
                ),
                ingredients: [
                    ValidatedRecipeImportIngredientDraft(
                        draft: flourDraft,
                        quantity: 1_000
                    )
                ]
            )
        )
    }

    func testValidateRejectsUnlinkedOrMissingInventoryLinks() {
        XCTAssertEqual(
            validationMessage(
                ingredientDrafts: [
                    ingredientDraft(id: "draft-flour", inventoryItemId: "")
                ],
                availableInventoryItemIds: ["inventory-flour"]
            ),
            "Link each ingredient to an inventory item before saving."
        )
        XCTAssertEqual(
            validationMessage(
                ingredientDrafts: [
                    ingredientDraft(id: "draft-flour", inventoryItemId: "missing-inventory")
                ],
                availableInventoryItemIds: ["inventory-flour"]
            ),
            "Link each ingredient to an inventory item before saving."
        )
    }

    func testValidateRejectsBlankRecipeName() {
        XCTAssertEqual(
            validationMessage(recipeName: " "),
            "Recipe name is required."
        )
    }

    func testValidateRejectsInvalidIngredientQuantities() {
        XCTAssertEqual(
            validationMessage(
                ingredientDrafts: [
                    ingredientDraft(id: "draft-flour", quantity: "0")
                ]
            ),
            "Ingredient quantities must be greater than zero."
        )
        XCTAssertEqual(
            validationMessage(
                ingredientDrafts: [
                    ingredientDraft(id: "draft-flour", quantity: "abc")
                ]
            ),
            "Ingredient quantities must be greater than zero."
        )
    }

    private func validationMessage(
        recipeName: String = "Vanilla Sponge",
        ingredientDrafts: [RecipeImportIngredientDraftRow] = [
            ingredientDraft(id: "draft-flour")
        ],
        availableInventoryItemIds: Set<String> = ["inventory-flour"]
    ) -> String? {
        let result = RecipeImportDraftValidation.validate(
            RecipeImportDraftValidationInput(
                recipeName: recipeName,
                recipeNotes: "",
                ingredientDrafts: ingredientDrafts,
                availableInventoryItemIds: availableInventoryItemIds
            )
        )

        guard case .failure(let error) = result else {
            return nil
        }

        return error.message
    }
}

private func ingredientDraft(
    id: String,
    quantity: String = "250",
    inventoryItemId: String = "inventory-flour",
    note: String = ""
) -> RecipeImportIngredientDraftRow {
    RecipeImportIngredientDraftRow(
        id: id,
        name: "Flour",
        quantity: quantity,
        unit: .gram,
        inventoryItemId: inventoryItemId,
        note: note
    )
}
