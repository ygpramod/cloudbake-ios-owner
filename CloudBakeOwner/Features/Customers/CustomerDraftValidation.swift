import Foundation

struct CustomerDraftValidationInput {
    let name: String
    let phone: String
}

struct ValidatedCustomerDraft: Equatable {
    let name: String
    let phone: String
}

struct CustomerDraftValidationError: Error, Equatable {
    let message: String
}

enum CustomerDraftValidation {
    static func validate(_ input: CustomerDraftValidationInput) -> Result<ValidatedCustomerDraft, CustomerDraftValidationError> {
        let name = TextInputFormatting.trimmed(input.name)
        guard !name.isEmpty else {
            return .failure(CustomerDraftValidationError(message: "Customer name is required."))
        }

        let phone = TextInputFormatting.trimmed(input.phone)
        guard !phone.isEmpty else {
            return .failure(CustomerDraftValidationError(message: "Customer phone is required."))
        }

        return .success(
            ValidatedCustomerDraft(
                name: name,
                phone: phone
            )
        )
    }
}
