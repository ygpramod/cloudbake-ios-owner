import Foundation

struct PurchaseBillDraftInventoryItem: Equatable {
    let name: String
    let sourceLine: String
    let quantity: Double?
    let unit: InventoryUnit?
    let receiptName: String
    let amount: Decimal?
    let shouldDefaultToIgnore: Bool

    init(
        name: String,
        sourceLine: String,
        quantity: Double?,
        unit: InventoryUnit?,
        receiptName: String = "",
        amount: Decimal? = nil,
        shouldDefaultToIgnore: Bool = false
    ) {
        self.name = name
        self.sourceLine = sourceLine
        self.quantity = quantity
        self.unit = unit
        self.receiptName = receiptName
        self.amount = amount
        self.shouldDefaultToIgnore = shouldDefaultToIgnore
    }
}

enum PurchaseBillDraftParser {
    static func draftItems(
        from recognizedText: String,
        catalog: [BakingCatalogItem]
    ) -> [PurchaseBillDraftInventoryItem] {
        let lines =
            recognizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var drafts: [PurchaseBillDraftInventoryItem] = []
        var index = 0
        var hasFoundProduct = false

        while index < lines.count {
            let sourceLine = lines[index]
            let normalizedLine = normalizedOCRSpacing(sourceLine)

            if hasFoundProduct, beginsReceiptSummary(normalizedLine) {
                break
            }
            if shouldIgnoreLine(normalizedLine) {
                index += 1
                continue
            }

            let broadCatalogItem = BakingCatalog.matches(in: normalizedLine, catalog: catalog).first
            if let measurement = parsedMeasurement(from: normalizedLine) {
                let receiptName = cleanedReceiptName(
                    String(normalizedLine[..<measurement.range.lowerBound])
                )
                guard !receiptName.isEmpty else {
                    index += 1
                    continue
                }

                var consumedLineCount = 1
                var packageCount = 1.0
                var amount = parsedTrailingAmount(from: normalizedLine)
                var combinedSourceLine = sourceLine
                let catalogItem = exactCatalogMatch(for: receiptName, catalog: catalog)

                if amount == nil, index + 1 < lines.count,
                    let followingPrice = parsedStandalonePriceLine(lines[index + 1])
                {
                    packageCount = followingPrice.itemCount
                    amount = followingPrice.amount
                    combinedSourceLine += "\n" + lines[index + 1]
                    consumedLineCount = 2
                }

                drafts.append(
                    PurchaseBillDraftInventoryItem(
                        name: catalogItem?.name ?? displayProductName(receiptName),
                        sourceLine: combinedSourceLine,
                        quantity: measurement.quantity * packageCount,
                        unit: measurement.unit,
                        receiptName: receiptName,
                        amount: amount
                    )
                )
                hasFoundProduct = true
                index += consumedLineCount
                continue
            }

            if let catalogItem = broadCatalogItem {
                let receiptName = cleanedReceiptName(removingTrailingAmount(from: normalizedLine))
                drafts.append(
                    PurchaseBillDraftInventoryItem(
                        name: catalogItem.name,
                        sourceLine: sourceLine,
                        quantity: nil,
                        unit: nil,
                        receiptName: receiptName,
                        amount: parsedTrailingAmount(from: normalizedLine)
                    )
                )
                hasFoundProduct = true
                index += 1
                continue
            }

            if hasFoundProduct,
                let amount = parsedTrailingAmount(from: normalizedLine),
                containsLetters(normalizedLine)
            {
                let receiptName = cleanedReceiptName(removingTrailingAmount(from: normalizedLine))
                if !receiptName.isEmpty {
                    drafts.append(
                        PurchaseBillDraftInventoryItem(
                            name: displayProductName(receiptName),
                            sourceLine: sourceLine,
                            quantity: 1,
                            unit: .each,
                            receiptName: receiptName,
                            amount: amount,
                            shouldDefaultToIgnore: true
                        )
                    )
                }
            }

            index += 1
        }

        return drafts
    }

    private static func parsedMeasurement(
        from line: String
    ) -> (quantity: Double, unit: InventoryUnit, range: Range<String.Index>)? {
        let pattern =
            #"(?i)\b(\d+(?:[\.,]\d+)?)\s*(kg|kilograms?|g|gm|grams?|l|liters?|litres?|ml|milliliters?|millilitres?|tsp|teaspoons?|tbsp|tablespoons?|cups?|pcs|pc|pieces?|each)\b\.?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: fullRange),
            let matchRange = Range(match.range, in: line),
            let quantityRange = Range(match.range(at: 1), in: line),
            let unitRange = Range(match.range(at: 2), in: line)
        else {
            return nil
        }

        let quantityText = String(line[quantityRange]).replacingOccurrences(of: ",", with: ".")
        guard let quantity = Double(quantityText),
            let unit = inventoryUnit(from: String(line[unitRange]))
        else {
            return nil
        }

        return (quantity, unit, matchRange)
    }

    private static func parsedTrailingAmount(from line: String) -> Decimal? {
        let pattern = #"(\d+\.\d{2})\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: fullRange),
            let amountRange = Range(match.range(at: 1), in: line)
        else {
            return nil
        }
        return Decimal(string: String(line[amountRange]))
    }

    private static func parsedStandalonePriceLine(
        _ sourceLine: String
    ) -> (itemCount: Double, amount: Decimal)? {
        let line = normalizedOCRSpacing(sourceLine)
        let countAndPricePattern = #"^(\d+)\s+(\d+\.\d{2})$"#
        if let regex = try? NSRegularExpression(pattern: countAndPricePattern) {
            let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex.firstMatch(in: line, range: fullRange),
                let countRange = Range(match.range(at: 1), in: line),
                let amountRange = Range(match.range(at: 2), in: line),
                let itemCount = Double(line[countRange]),
                let amount = Decimal(string: String(line[amountRange]))
            {
                return (itemCount, amount)
            }
        }

        let pricePattern = #"^(\d+\.\d{2})$"#
        guard let regex = try? NSRegularExpression(pattern: pricePattern) else {
            return nil
        }
        let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: fullRange),
            let amountRange = Range(match.range(at: 1), in: line),
            let amount = Decimal(string: String(line[amountRange]))
        else {
            return nil
        }
        return (1, amount)
    }

    private static func removingTrailingAmount(from line: String) -> String {
        line.replacingOccurrences(
            of: #"\s+\d+\.\d{2}\s*$"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func normalizedOCRSpacing(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"(\d)\.\s+(\d{2})"#,
            with: "$1.$2",
            options: .regularExpression
        )
    }

    private static func cleanedReceiptName(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
    }

    private static func displayProductName(_ receiptName: String) -> String {
        receiptName.lowercased().localizedCapitalized
    }

    private static func exactCatalogMatch(
        for receiptName: String,
        catalog: [BakingCatalogItem]
    ) -> BakingCatalogItem? {
        let receiptKey = InventoryDuplicateMatcher.duplicateKey(for: receiptName)
        return catalog.first { item in
            item.active
                && item.searchableTerms.contains {
                    InventoryDuplicateMatcher.duplicateKey(for: $0) == receiptKey
                }
        }
    }

    private static func containsLetters(_ line: String) -> Bool {
        line.unicodeScalars.contains(where: CharacterSet.letters.contains)
    }

    private static func beginsReceiptSummary(_ line: String) -> Bool {
        let key = line.lowercased()
        return key.hasPrefix("total ")
            || key.hasPrefix("total(")
            || key.hasPrefix("total (")
            || key.hasPrefix("subtotal")
            || key.hasPrefix("gst amt")
    }

    private static func shouldIgnoreLine(_ line: String) -> Bool {
        let key = line.lowercased()
        return key.hasPrefix("price off")
            || key.hasPrefix("total saving")
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
