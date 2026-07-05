import Foundation

extension InventoryUnit {
    static let inventoryInputCases: [InventoryUnit] = [
        .kilogram,
        .gram,
        .liter,
        .milliliter,
        .teaspoon,
        .tablespoon,
        .cup,
        .each
    ]

    var displayName: String {
        switch self {
        case .kilogram: "kg"
        case .gram: "g"
        case .liter: "L"
        case .milliliter: "ml"
        case .teaspoon: "tsp"
        case .tablespoon: "tbsp"
        case .cup: "cup"
        case .each: "each"
        }
    }
}
