import Foundation

struct OrderDraftValidationInput {
    let title: String
    let customerName: String
    let recipeScaleMultiplier: String
    let quotedPrice: String
    let depositPaid: String
}

struct ValidatedOrderDraft: Equatable {
    let title: String
    let customerName: String
    let recipeScaleMultiplier: Decimal
    let quotedPrice: Decimal?
    let depositPaid: Decimal?
}

struct OrderDraftValidationError: Error, Equatable {
    let message: String
}

enum OrderDraftValidation {
    static func validate(_ input: OrderDraftValidationInput) -> Result<ValidatedOrderDraft, OrderDraftValidationError> {
        let title = TextInputFormatting.trimmed(input.title)
        guard !title.isEmpty else {
            return .failure(OrderDraftValidationError(message: "Order title is required."))
        }

        let customerName = TextInputFormatting.trimmed(input.customerName)
        guard !customerName.isEmpty else {
            return .failure(OrderDraftValidationError(message: "Customer name is required."))
        }

        switch decimalAmount(from: input.quotedPrice, fieldName: "Quoted price") {
        case .failure(let error):
            return .failure(error)
        case .success(let quotedPrice):
            switch decimalAmount(from: input.depositPaid, fieldName: "Deposit paid") {
            case .failure(let error):
                return .failure(error)
            case .success(let depositPaid):
                guard let recipeScaleMultiplier = requiredPositiveDecimalAmount(
                    from: input.recipeScaleMultiplier,
                    fieldName: "Recipe multiplier"
                ) else {
                    return .failure(OrderDraftValidationError(message: "Recipe multiplier must be greater than zero."))
                }

                if let quotedPrice, let depositPaid, depositPaid > quotedPrice {
                    return .failure(OrderDraftValidationError(message: "Deposit paid cannot be more than quoted price."))
                }

                return .success(
                    ValidatedOrderDraft(
                        title: title,
                        customerName: customerName,
                        recipeScaleMultiplier: recipeScaleMultiplier,
                        quotedPrice: quotedPrice,
                        depositPaid: depositPaid
                    )
                )
            }
        }
    }

    private static func decimalAmount(
        from text: String,
        fieldName: String
    ) -> Result<Decimal?, OrderDraftValidationError> {
        let trimmed = TextInputFormatting.trimmed(text)
        guard !trimmed.isEmpty else {
            return .success(nil)
        }

        guard let amount = Decimal(string: trimmed), amount >= 0 else {
            return .failure(OrderDraftValidationError(message: "\(fieldName) must be a positive number."))
        }

        return .success(amount)
    }

    private static func requiredPositiveDecimalAmount(from text: String, fieldName: String) -> Decimal? {
        let trimmed = TextInputFormatting.trimmed(text)
        guard let amount = Decimal(string: trimmed), amount > 0 else {
            return nil
        }

        return amount
    }
}
