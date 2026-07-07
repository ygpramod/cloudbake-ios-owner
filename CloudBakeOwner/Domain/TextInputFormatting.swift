import Foundation

enum TextInputFormatting {
    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func optionalText(_ value: String) -> String? {
        let trimmedValue = trimmed(value)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    static func normalizedSearchKey(_ value: String) -> String {
        trimmed(value)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    static func digitsOnly(_ value: String) -> String {
        value.filter(\.isNumber)
    }

    static func decimalText(_ value: Decimal?) -> String {
        guard let value else {
            return ""
        }

        return NSDecimalNumber(decimal: value).stringValue
    }
}
