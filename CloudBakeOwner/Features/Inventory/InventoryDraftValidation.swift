import Foundation

enum InventoryDraftValidation {
    static func quantity(from text: String) -> Double? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
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

enum InventoryDuplicateMatcher {
    static func matchingItem(
        named name: String,
        in items: [InventoryItem],
        excludingItemId: String?
    ) -> InventoryItem? {
        let nameKey = duplicateKey(for: name)
        return items.first { item in
            if item.id == excludingItemId {
                return false
            }

            let existingKey = duplicateKey(for: item.name)
            return existingKey == nameKey || existingKey.contains(nameKey) || nameKey.contains(existingKey)
        }
    }

    static func duplicateKey(for name: String) -> String {
        name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { token in
                if token.count > 3, token.hasSuffix("s") {
                    return String(token.dropLast())
                }
                return token
            }
            .joined(separator: " ")
    }
}
