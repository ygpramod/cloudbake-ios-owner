import Foundation

struct PurchaseBillDraftInventoryItem: Equatable {
    let name: String
    let sourceLine: String
    let quantity: Double?
    let unit: InventoryUnit?
}

enum PurchaseBillDraftParser {
    static func draftItems(
        from recognizedText: String,
        catalog: [BakingCatalogItem]
    ) -> [PurchaseBillDraftInventoryItem] {
        recognizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                guard let catalogItem = BakingCatalog.matches(in: line, catalog: catalog).first else {
                    return nil
                }

                let measurement = parsedMeasurement(from: line)
                return PurchaseBillDraftInventoryItem(
                    name: catalogItem.name,
                    sourceLine: line,
                    quantity: measurement?.quantity,
                    unit: measurement?.unit
                )
            }
    }

    private static func parsedMeasurement(from line: String) -> (quantity: Double, unit: InventoryUnit)? {
        let pattern = #"(?i)\b(\d+(?:[\.,]\d+)?)\s*(kg|kilograms?|g|gm|grams?|l|liters?|litres?|ml|milliliters?|millilitres?|tsp|teaspoons?|tbsp|tablespoons?|cups?|pcs|pc|pieces?|each)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let quantityRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let quantityText = String(line[quantityRange]).replacingOccurrences(of: ",", with: ".")
        guard let quantity = Double(quantityText),
              let unit = inventoryUnit(from: String(line[unitRange])) else {
            return nil
        }

        return (quantity, unit)
    }

    private static func inventoryUnit(from text: String) -> InventoryUnit? {
        switch text.lowercased() {
        case "kg", "kilogram", "kilograms":
            return .kilogram
        case "g", "gm", "gram", "grams":
            return .gram
        case "l", "liter", "liters", "litre", "litres":
            return .liter
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres":
            return .milliliter
        case "tsp", "teaspoon", "teaspoons":
            return .teaspoon
        case "tbsp", "tablespoon", "tablespoons":
            return .tablespoon
        case "cup", "cups":
            return .cup
        case "pc", "pcs", "piece", "pieces", "each":
            return .each
        default:
            return nil
        }
    }
}
