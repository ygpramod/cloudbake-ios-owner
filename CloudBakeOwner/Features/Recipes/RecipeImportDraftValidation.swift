import Foundation

struct ValidatedRecipeImportIngredientDraft: Equatable {
    let draft: RecipeImportIngredientDraftRow
    let quantity: Double
}

struct RecipeImportDraftValidationInput {
    let recipeName: String
    let recipeNotes: String
    let ingredientDrafts: [RecipeImportIngredientDraftRow]
    let availableInventoryItemIds: Set<String>
}

struct ValidatedRecipeImportDraft: Equatable {
    let recipe: ValidatedRecipeDraft
    let ingredients: [ValidatedRecipeImportIngredientDraft]
}

struct RecipeImportDraftValidationError: Error, Equatable {
    let message: String
}

enum RecipeImportDraftValidation {
    static func validate(_ input: RecipeImportDraftValidationInput) -> Result<ValidatedRecipeImportDraft, RecipeImportDraftValidationError> {
        let linkedDrafts = input.ingredientDrafts.filter { !$0.inventoryItemId.isEmpty }
        guard input.ingredientDrafts.count == linkedDrafts.count else {
            return .failure(.linkEveryIngredient)
        }

        guard linkedDrafts.allSatisfy({ input.availableInventoryItemIds.contains($0.inventoryItemId) }) else {
            return .failure(.linkEveryIngredient)
        }

        let recipeResult = RecipeDraftValidation.validate(
            RecipeDraftValidationInput(
                name: input.recipeName,
                notes: input.recipeNotes
            )
        )
        let recipe: ValidatedRecipeDraft
        switch recipeResult {
        case .success(let validatedRecipe):
            recipe = validatedRecipe
        case .failure(let error):
            return .failure(RecipeImportDraftValidationError(message: error.message))
        }

        let parsedDrafts = linkedDrafts.compactMap { draft -> ValidatedRecipeImportIngredientDraft? in
            guard let quantity = parsedIngredientQuantity(from: draft.quantity), quantity > 0 else {
                return nil
            }

            return ValidatedRecipeImportIngredientDraft(draft: draft, quantity: quantity)
        }
        guard parsedDrafts.count == linkedDrafts.count else {
            return .failure(RecipeImportDraftValidationError(message: "Ingredient quantities must be greater than zero."))
        }

        return .success(
            ValidatedRecipeImportDraft(
                recipe: recipe,
                ingredients: parsedDrafts
            )
        )
    }

    static func parsedIngredientQuantity(from text: String) -> Double? {
        let trimmedText = TextInputFormatting.trimmed(text)
        guard !trimmedText.isEmpty else {
            return nil
        }

        if let quantity = Double(trimmedText) {
            return quantity
        }

        let groupingSeparator = Locale.current.groupingSeparator ?? ","
        let normalizedText = trimmedText
            .replacingOccurrences(of: groupingSeparator, with: "")
            .replacingOccurrences(of: ",", with: "")

        return Double(normalizedText)
    }
}

private extension RecipeImportDraftValidationError {
    static let linkEveryIngredient = RecipeImportDraftValidationError(
        message: "Link each ingredient to an inventory item before saving."
    )
}
