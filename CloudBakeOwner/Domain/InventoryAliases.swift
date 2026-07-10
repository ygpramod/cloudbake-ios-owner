import Foundation

enum InventoryAliases {
    static func aliases(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",\n")
        var seenKeys = Set<String>()

        return text
            .components(separatedBy: separators)
            .map(TextInputFormatting.trimmed)
            .filter { !$0.isEmpty }
            .filter { alias in
                let key = TextInputFormatting.normalizedSearchKey(alias)
                guard !key.isEmpty, !seenKeys.contains(key) else {
                    return false
                }

                seenKeys.insert(key)
                return true
            }
    }

    static func displayText(_ aliases: [String]) -> String {
        aliases.joined(separator: ", ")
    }
}
