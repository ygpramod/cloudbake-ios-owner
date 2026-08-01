import Foundation

enum PurchaseBillDraftDestination: Equatable {
    case newItem
    case existingItem(String)
    case ignored
}

struct PurchaseBillInventoryDraft: Identifiable, Equatable {
    let id: String
    let sourceLine: String
    var name: String
    var quantityText: String
    var unit: InventoryUnit
    var minimumQuantityText: String
    var expiryDate: Date
    var matchedInventoryItemId: String? = nil
    var matchedInventoryItemName: String? = nil
    var hasExpiryDate: Bool = true
    var expiryUsesDefault: Bool = true
    var receiptName: String = ""
    var amountPaidText: String = ""
    var destination: PurchaseBillDraftDestination = .newItem

    var showsMinimumQuantity: Bool {
        destination == .newItem
    }
}

enum InventoryPurchaseBillDraftBuilder {
    static func drafts(
        from parsedDrafts: [PurchaseBillDraftInventoryItem],
        inventoryItems: [InventoryItem],
        defaultExpiryDate: (InventoryItem?) -> Date,
        idProvider: () -> String
    ) -> [PurchaseBillInventoryDraft] {
        parsedDrafts.map { draft in
            let matchedItem = uniqueExactMatch(named: draft.name, in: inventoryItems)
            let destination: PurchaseBillDraftDestination
            if let matchedItem {
                destination = .existingItem(matchedItem.id)
            } else if draft.shouldDefaultToIgnore {
                destination = .ignored
            } else {
                destination = .newItem
            }
            return PurchaseBillInventoryDraft(
                id: idProvider(),
                sourceLine: draft.sourceLine,
                name: draft.name,
                quantityText: draft.quantity?.formatted() ?? "1",
                unit: draft.unit ?? .each,
                minimumQuantityText: "0",
                expiryDate: defaultExpiryDate(matchedItem),
                matchedInventoryItemId: matchedItem?.id,
                matchedInventoryItemName: matchedItem?.name,
                receiptName: draft.receiptName,
                amountPaidText: draft.amount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "",
                destination: destination
            )
        }
    }

    static func matchedInventoryItem(
        for draft: PurchaseBillInventoryDraft,
        inventoryItems: [InventoryItem]
    ) -> InventoryItem? {
        uniqueExactMatch(named: draft.name, in: inventoryItems)
    }

    private static func uniqueExactMatch(
        named name: String,
        in inventoryItems: [InventoryItem]
    ) -> InventoryItem? {
        let nameKey = InventoryDuplicateMatcher.duplicateKey(for: name)
        let matches = inventoryItems.filter { item in
            ([item.name] + item.aliases).contains {
                InventoryDuplicateMatcher.duplicateKey(for: $0) == nameKey
            }
        }
        guard matches.count == 1 else {
            return nil
        }
        return matches[0]
    }
}

enum VoiceInventoryDraftDestination: Equatable {
    case unresolved
    case newItem
    case existingItem(String)
}

struct VoiceInventoryDraft: Identifiable, Equatable {
    let id: String
    let sourcePhrase: String
    var name: String
    var quantityText: String
    var unit: InventoryUnit
    var minimumQuantityText: String
    var hasExpiryDate: Bool
    var expiryDate: Date
    var expiryUsesDefault: Bool
    var destination: VoiceInventoryDraftDestination

    var showsMinimumQuantity: Bool {
        if case .existingItem = destination {
            return false
        }
        return true
    }
}

struct ParsedVoiceInventoryItem: Equatable {
    let name: String
    let sourcePhrase: String
    let quantity: Double
    let unit: InventoryUnit
}

enum VoiceInventoryDraftParser {
    static func items(from transcript: String) -> [ParsedVoiceInventoryItem] {
        let pattern =
            #"(?i)\b(\d+(?:[\.,]\d+)?)\s*(kg|kilograms?|g|gm|grams?|l|liters?|litres?|ml|milliliters?|millilitres?|tsp|teaspoons?|tbsp|tablespoons?|cups?|pcs|pc|pieces?|each)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let fullRange = NSRange(transcript.startIndex..<transcript.endIndex, in: transcript)
        let matches = regex.matches(in: transcript, range: fullRange)
        var priorMeasurementEnd = transcript.startIndex

        return matches.compactMap { match in
            guard let measurementRange = Range(match.range, in: transcript),
                let quantityRange = Range(match.range(at: 1), in: transcript),
                let unitRange = Range(match.range(at: 2), in: transcript)
            else {
                return nil
            }

            let rawName = String(transcript[priorMeasurementEnd..<measurementRange.lowerBound])
            priorMeasurementEnd = measurementRange.upperBound
            let name = cleanedName(rawName)
            let quantityText = String(transcript[quantityRange]).replacingOccurrences(of: ",", with: ".")
            guard !name.isEmpty,
                let quantity = Double(quantityText),
                quantity > 0,
                let unit = inventoryUnit(from: String(transcript[unitRange]))
            else {
                return nil
            }

            return ParsedVoiceInventoryItem(
                name: name,
                sourcePhrase: "\(name) \(String(transcript[measurementRange]))",
                quantity: quantity,
                unit: unit
            )
        }
    }

    private static func cleanedName(_ text: String) -> String {
        var name = text.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;."))
        )
        name = name.split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
        if name.lowercased().hasPrefix("and ") {
            name = String(name.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return name
    }

    private static func inventoryUnit(from text: String) -> InventoryUnit? {
        switch text.lowercased() {
        case "kg", "kilogram", "kilograms": .kilogram
        case "g", "gm", "gram", "grams": .gram
        case "l", "liter", "liters", "litre", "litres": .liter
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres": .milliliter
        case "tsp", "teaspoon", "teaspoons": .teaspoon
        case "tbsp", "tablespoon", "tablespoons": .tablespoon
        case "cup", "cups": .cup
        case "pc", "pcs", "piece", "pieces", "each": .each
        default: nil
        }
    }
}
