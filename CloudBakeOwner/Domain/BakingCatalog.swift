import Foundation

struct BakingCatalogItem: Codable, Equatable {
    let name: String
    let aliases: [String]
    let category: String
    let active: Bool

    var searchableTerms: [String] {
        [name] + aliases
    }
}

enum BakingCatalog {
    static func load(from data: Data) throws -> [BakingCatalogItem] {
        try JSONDecoder().decode([BakingCatalogItem].self, from: data)
    }

    static func loadBundledCatalog(bundle: Bundle = .main) throws -> [BakingCatalogItem] {
        guard let url = bundle.url(forResource: "BakingCatalog", withExtension: "json") else {
            throw BakingCatalogError.missingBundledCatalog
        }

        return try load(from: Data(contentsOf: url))
    }

    static func matches(in text: String, catalog: [BakingCatalogItem]) -> [BakingCatalogItem] {
        let textTokens = normalizedTokens(from: text)
        guard !textTokens.isEmpty else {
            return []
        }

        return catalog.filter { item in
            guard item.active else {
                return false
            }

            return item.searchableTerms.contains { term in
                contains(normalizedTokens(from: term), in: textTokens)
            }
        }
    }

    private static func contains(_ termTokens: [String], in textTokens: [String]) -> Bool {
        guard !termTokens.isEmpty, termTokens.count <= textTokens.count else {
            return false
        }

        for startIndex in 0...(textTokens.count - termTokens.count) {
            let endIndex = startIndex + termTokens.count
            if Array(textTokens[startIndex..<endIndex]) == termTokens {
                return true
            }
        }

        return false
    }

    private static func normalizedTokens(from text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { token in
                if token.count > 3, token.hasSuffix("s") {
                    return String(token.dropLast())
                }
                return token
            }
    }
}

enum BakingCatalogError: Error, Equatable {
    case missingBundledCatalog
}
