import Foundation

struct RecipeDraftValidationInput {
    let name: String
    let notes: String
}

struct ValidatedRecipeDraft: Equatable {
    let name: String
    let notes: String?
}

struct RecipeDraftValidationError: Error, Equatable {
    let message: String
}

enum RecipeDraftValidation {
    static func validate(_ input: RecipeDraftValidationInput) -> Result<ValidatedRecipeDraft, RecipeDraftValidationError> {
        let name = TextInputFormatting.trimmed(input.name)
        guard !name.isEmpty else {
            return .failure(RecipeDraftValidationError(message: "Recipe name is required."))
        }

        return .success(
            ValidatedRecipeDraft(
                name: name,
                notes: TextInputFormatting.optionalText(input.notes)
            )
        )
    }
}
