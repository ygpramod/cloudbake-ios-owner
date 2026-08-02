import Foundation

struct OrderDraftValidationInput {
    let title: String
    let customerName: String
    let recipeScaleMultiplier: String
    let quotedPrice: String
    let depositPaid: String
    let cakeServings: String
    let cakeWeightKilograms: String

    init(
        title: String,
        customerName: String,
        recipeScaleMultiplier: String,
        quotedPrice: String,
        depositPaid: String,
        cakeServings: String = "",
        cakeWeightKilograms: String = ""
    ) {
        self.title = title
        self.customerName = customerName
        self.recipeScaleMultiplier = recipeScaleMultiplier
        self.quotedPrice = quotedPrice
        self.depositPaid = depositPaid
        self.cakeServings = cakeServings
        self.cakeWeightKilograms = cakeWeightKilograms
    }
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

        if let cakeCapacityError = cakeCapacityError(
            servings: input.cakeServings,
            weightKilograms: input.cakeWeightKilograms
        ) {
            return .failure(cakeCapacityError)
        }

        switch decimalAmount(from: input.quotedPrice, fieldName: "Quoted price") {
        case .failure(let error):
            return .failure(error)
        case .success(let quotedPrice):
            switch decimalAmount(from: input.depositPaid, fieldName: "Deposit paid") {
            case .failure(let error):
                return .failure(error)
            case .success(let depositPaid):
                guard
                    let recipeScaleMultiplier = requiredPositiveDecimalAmount(
                        from: input.recipeScaleMultiplier,
                        fieldName: "Recipe multiplier"
                    )
                else {
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

    static func cakeCapacityError(
        servings: String,
        weightKilograms: String
    ) -> OrderDraftValidationError? {
        let servings = TextInputFormatting.trimmed(servings)
        if !servings.isEmpty, Int(servings).map({ $0 > 0 }) != true {
            return OrderDraftValidationError(message: "Servings must be a positive whole number.")
        }

        let weight = TextInputFormatting.trimmed(weightKilograms)
        if !weight.isEmpty, Decimal(string: weight).map({ $0 > 0 }) != true {
            return OrderDraftValidationError(message: "Weight must be greater than zero.")
        }

        return nil
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

enum OrderReminderDraftMode: String, CaseIterable {
    case useDefaults
    case custom
    case disabled

    var displayName: String {
        switch self {
        case .useDefaults:
            return "Use Defaults"
        case .custom:
            return "Custom"
        case .disabled:
            return "Off"
        }
    }
}

enum OrderReminderDraftValidation {
    static func configuration(
        mode: OrderReminderDraftMode,
        dayOffsetsText: String,
        includesDueTime: Bool
    ) throws -> OrderReminderConfiguration {
        if mode == .disabled {
            return .disabled
        }

        let tokens =
            dayOffsetsText
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let offsets: [Int]
        if tokens.count == 1, tokens[0].isEmpty {
            offsets = []
        } else {
            guard !tokens.contains(where: \.isEmpty),
                tokens.allSatisfy({ Int($0) != nil })
            else {
                throw OrderDraftValidationError(
                    message: "Enter reminder days as whole numbers separated by commas, for example 7, 3, 1."
                )
            }
            offsets = tokens.compactMap(Int.init)
        }

        do {
            return try OrderReminderConfiguration(
                mode: mode == .custom ? .custom : .defaultSnapshot,
                dayOffsets: offsets,
                includesDueTime: includesDueTime
            )
        } catch let error as OrderReminderConfigurationError {
            throw OrderDraftValidationError(message: message(for: error))
        }
    }

    private static func message(for error: OrderReminderConfigurationError) -> String {
        switch error {
        case .invalidDayOffset:
            return "Each reminder day must be a whole number from 1 to 30."
        case .duplicateDayOffset:
            return "Enter each reminder day only once."
        case .emptyEnabledSchedule:
            return "Add at least one reminder day or keep the due-time reminder on."
        case .invalidDisabledSchedule:
            return "The reminder schedule is invalid."
        }
    }
}
