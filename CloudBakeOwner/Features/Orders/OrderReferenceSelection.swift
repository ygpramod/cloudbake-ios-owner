import Foundation

enum OrderReferenceSelection {
    static func customerName(for id: String, customers: [Customer]) -> String {
        guard !id.isEmpty,
              let customer = customers.first(where: { $0.id == id }) else {
            return "No Linked Customer"
        }

        return customer.name
    }

    static func recipeName(for id: String, recipes: [Recipe]) -> String {
        guard !id.isEmpty,
              let recipe = recipes.first(where: { $0.id == id }) else {
            return "No Linked Recipe"
        }

        return recipe.name
    }

    static func cakeDesignName(for id: String, cakeDesigns: [CakeDesign]) -> String {
        guard !id.isEmpty,
              let design = cakeDesigns.first(where: { $0.id == id }) else {
            return "No Linked Design"
        }

        return design.name
    }

    static func customers(_ customers: [Customer], matching searchText: String) -> [Customer] {
        matching(searchText, in: customers) { customer in
            [customer.name, customer.phone, customer.email, customer.address]
        }
    }

    static func recipes(_ recipes: [Recipe], matching searchText: String) -> [Recipe] {
        matching(searchText, in: recipes) { recipe in
            [recipe.name, recipe.notes]
        }
    }

    static func cakeDesigns(_ cakeDesigns: [CakeDesign], matching searchText: String) -> [CakeDesign] {
        matching(searchText, in: cakeDesigns) { design in
            [design.name, design.notes, design.photoReference]
        }
    }

    private static func matching<T>(
        _ searchText: String,
        in values: [T],
        searchableFields: (T) -> [String?]
    ) -> [T] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return values
        }

        let query = normalizedSearchText(trimmed)
        return values.filter { value in
            searchableFields(value)
                .compactMap { $0 }
                .map(normalizedSearchText)
                .contains { $0.contains(query) }
        }
    }

    private static func normalizedSearchText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
