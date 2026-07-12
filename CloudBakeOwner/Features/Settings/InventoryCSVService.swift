import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct InventoryCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw InventoryCSVError.invalidFile
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

enum InventoryCSVError: Error, Equatable {
    case invalidFile
    case missingRequiredHeader(String)
    case invalidRow(Int, String)
}

struct InventoryCSVImportSummary: Equatable {
    let importedItemCount: Int
    let importedBatchCount: Int
}

struct InventoryCSVService {
    private let calendar: Calendar
    private let idGenerator: () -> String
    private let dateProvider: () -> Date

    init(
        calendar: Calendar = .current,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.calendar = calendar
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    func exportCSV(
        repository: any InventoryItemRepository & InventoryStockBatchRepository
    ) throws -> String {
        let items = try repository.fetchInventoryItems()
        var rows: [[String]] = [
            [
                "name",
                "aliases",
                "type",
                "unit",
                "current_quantity",
                "minimum_quantity",
                "batch_quantity",
                "amount",
                "expiry_date"
            ]
        ]

        for item in items {
            let batches = try repository.fetchInventoryStockBatches(inventoryItemId: item.id)
            if batches.isEmpty {
                rows.append(csvRow(item: item, batchQuantity: item.currentQuantity, amount: nil, expiryDate: nil))
            } else {
                for batch in batches {
                    rows.append(
                        csvRow(
                            item: item,
                            batchQuantity: batch.remainingQuantity,
                            amount: batch.amount,
                            expiryDate: batch.expiresAt
                        )
                    )
                }
            }
        }

        return CloudBakeCSV.encode(rows)
    }

    func importCSV(
        _ csvText: String,
        repository: any InventoryItemRepository & InventoryStockBatchRepository
    ) throws -> InventoryCSVImportSummary {
        let importedRows = try parseImportRows(csvText)
        let groupedRows = Dictionary(grouping: importedRows) { row in
            "\(TextInputFormatting.normalizedSearchKey(row.name))|\(row.unit.rawValue)"
        }
        try validateItemMetadata(in: groupedRows)
        let existingItems = try repository.fetchInventoryItems()
        let now = dateProvider()
        var importedBatchCount = 0

        for rows in groupedRows.values {
            guard let firstRow = rows.first else {
                continue
            }

            let existingItem = existingItems.first { item in
                TextInputFormatting.normalizedSearchKey(item.name) == TextInputFormatting.normalizedSearchKey(firstRow.name)
                    && item.unit == firstRow.unit
            }
            let itemId = existingItem?.id ?? idGenerator()
            let batches = rows
                .filter { $0.batchQuantity > 0 }
                .map { row in
                    InventoryStockBatch(
                        id: idGenerator(),
                        inventoryItemId: itemId,
                        remainingQuantity: row.batchQuantity,
                        expiresAt: row.expiryDate,
                        amount: row.amount,
                        createdAt: now,
                        updatedAt: now
                    )
                }
            let item = InventoryItem(
                id: itemId,
                name: firstRow.name,
                aliases: firstRow.aliases,
                type: firstRow.type,
                unit: firstRow.unit,
                currentQuantity: batches.reduce(0) { $0 + $1.remainingQuantity },
                minimumQuantity: firstRow.minimumQuantity,
                createdAt: existingItem?.createdAt ?? now,
                updatedAt: now
            )

            try repository.replaceInventoryStock(item: item, batches: batches)
            importedBatchCount += batches.count
        }

        return InventoryCSVImportSummary(
            importedItemCount: groupedRows.count,
            importedBatchCount: importedBatchCount
        )
    }

    private func validateItemMetadata(in groupedRows: [String: [InventoryCSVImportRow]]) throws {
        for rows in groupedRows.values {
            guard let firstRow = rows.first else { continue }
            let expectedAliases = normalizedAliases(firstRow.aliases)

            for row in rows.dropFirst() {
                guard normalizedAliases(row.aliases) == expectedAliases else {
                    throw InventoryCSVError.invalidRow(
                        row.rowNumber,
                        "Aliases must match across batch rows for the same item."
                    )
                }
                guard row.type == firstRow.type else {
                    throw InventoryCSVError.invalidRow(
                        row.rowNumber,
                        "Type must match across batch rows for the same item."
                    )
                }
                guard row.minimumQuantity == firstRow.minimumQuantity else {
                    throw InventoryCSVError.invalidRow(
                        row.rowNumber,
                        "Minimum quantity must match across batch rows for the same item."
                    )
                }
            }
        }
    }

    private func normalizedAliases(_ aliases: [String]) -> [String] {
        aliases
            .map(TextInputFormatting.normalizedSearchKey)
            .sorted()
    }

    private func csvRow(item: InventoryItem, batchQuantity: Double, amount: Decimal?, expiryDate: Date?) -> [String] {
        [
            item.name,
            InventoryAliases.displayText(item.aliases),
            item.type.displayName,
            item.unit.displayName,
            formatQuantity(item.currentQuantity),
            formatQuantity(item.minimumQuantity),
            formatQuantity(batchQuantity),
            amount.map(formatMoney) ?? "",
            expiryDate.map(formatDate) ?? ""
        ]
    }

    private func parseImportRows(_ csvText: String) throws -> [InventoryCSVImportRow] {
        let table = CloudBakeCSV.parse(csvText)
            .filter { row in row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        guard let header = table.first else {
            return []
        }

        let headerLookup = Dictionary(uniqueKeysWithValues: header.enumerated().map { index, value in
            (TextInputFormatting.normalizedSearchKey(value), index)
        })
        let nameIndex = try requiredHeader("name", in: headerLookup)
        let aliasesIndex = try requiredHeader("aliases", in: headerLookup)
        let typeIndex = try requiredHeader("type", in: headerLookup)
        let unitIndex = try requiredHeader("unit", in: headerLookup)
        let minimumIndex = try requiredHeader("minimum_quantity", in: headerLookup)
        let currentIndex = headerLookup[TextInputFormatting.normalizedSearchKey("current_quantity")]
        let batchIndex = headerLookup[TextInputFormatting.normalizedSearchKey("batch_quantity")]
        let amountIndex = headerLookup[TextInputFormatting.normalizedSearchKey("amount")]
            ?? headerLookup[TextInputFormatting.normalizedSearchKey("unit_cost")]
        let expiryIndex = headerLookup[TextInputFormatting.normalizedSearchKey("expiry_date")]

        return try table.dropFirst().enumerated().map { offset, row in
            let rowNumber = offset + 2
            let name = value(at: nameIndex, in: row).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw InventoryCSVError.invalidRow(rowNumber, "Name is required.")
            }
            let aliases = InventoryAliases.aliases(from: value(at: aliasesIndex, in: row))
            guard let type = InventoryItemType.csvValue(value(at: typeIndex, in: row)) else {
                throw InventoryCSVError.invalidRow(rowNumber, "Type must be Standard or Perishable.")
            }
            guard let unit = InventoryUnit.csvValue(value(at: unitIndex, in: row)) else {
                throw InventoryCSVError.invalidRow(rowNumber, "Unit is not supported.")
            }
            guard let minimumQuantity = Double(value(at: minimumIndex, in: row)), minimumQuantity >= 0 else {
                throw InventoryCSVError.invalidRow(rowNumber, "Minimum quantity must be zero or greater.")
            }

            let batchText = batchIndex.map { value(at: $0, in: row) } ?? ""
            let currentText = currentIndex.map { value(at: $0, in: row) } ?? ""
            let quantityText = batchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? currentText : batchText
            guard let batchQuantity = Double(quantityText), batchQuantity >= 0 else {
                throw InventoryCSVError.invalidRow(rowNumber, "Batch quantity must be zero or greater.")
            }
            let amountText = amountIndex.map { value(at: $0, in: row) } ?? ""
            guard let amount = parseOptionalMoney(amountText) else {
                throw InventoryCSVError.invalidRow(rowNumber, "Amount must be zero or greater.")
            }

            let expiryText = expiryIndex.map { value(at: $0, in: row) } ?? ""
            let expiryDate = try parseOptionalDate(expiryText, rowNumber: rowNumber)

            return InventoryCSVImportRow(
                rowNumber: rowNumber,
                name: name,
                aliases: aliases,
                type: type,
                unit: unit,
                minimumQuantity: minimumQuantity,
                batchQuantity: batchQuantity,
                amount: amount,
                expiryDate: expiryDate
            )
        }
    }

    private func requiredHeader(_ name: String, in lookup: [String: Int]) throws -> Int {
        let normalizedName = TextInputFormatting.normalizedSearchKey(name)
        guard let index = lookup[normalizedName] else {
            throw InventoryCSVError.missingRequiredHeader(name)
        }

        return index
    }

    private func value(at index: Int, in row: [String]) -> String {
        guard row.indices.contains(index) else {
            return ""
        }

        return row[index]
    }

    private func parseOptionalDate(_ text: String, rowNumber: Int) throws -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        guard let date = Self.dateFormatter.date(from: trimmed) else {
            throw InventoryCSVError.invalidRow(rowNumber, "Expiry date must use yyyy-MM-dd.")
        }

        return date
    }

    private func parseOptionalMoney(_ text: String) -> Decimal?? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .some(nil)
        }

        guard let amount = Decimal(string: trimmed), amount >= 0 else {
            return nil
        }

        return .some(amount)
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatQuantity(_ quantity: Double) -> String {
        Self.quantityFormatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
    }

    private func formatMoney(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }

}

enum CloudBakeCSV {
    static func encode(_ rows: [[String]]) -> String {
        rows
            .map { row in row.map(escaped).joined(separator: ",") }
            .joined(separator: "\n")
            + "\n"
    }

    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == "\"" {
                let nextIndex = text.index(after: index)
                if isInsideQuotes, nextIndex < text.endIndex, text[nextIndex] == "\"" {
                    field.append("\"")
                    index = text.index(after: nextIndex)
                    continue
                }

                isInsideQuotes.toggle()
            } else if character == ",", !isInsideQuotes {
                row.append(field)
                field = ""
            } else if character == "\n", !isInsideQuotes {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }

            index = text.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    private static func escaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

}

enum RecipeCSVError: Error, Equatable {
    case missingRequiredHeader(String)
    case invalidRow(Int, String)
}

struct RecipeCSVImportSummary: Equatable {
    let importedRecipeCount: Int
    let importedIngredientCount: Int
}

struct RecipeCSVService {
    private let idGenerator: () -> String
    private let dateProvider: () -> Date

    init(
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    func exportCSV(
        repository: any RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & InventoryItemRepository
    ) throws -> String {
        let inventoryById = Dictionary(
            uniqueKeysWithValues: try repository.fetchInventoryItems().map { ($0.id, $0) }
        )
        var rows = [
            ["name", "recipe", "ingredients"],
            ["# Example - ignored during import", "", "Cake Flour:250:g | Sugar:200:g | Cream:150:ml"]
        ]

        for recipe in try repository.fetchRecipes() {
            var ingredientValues: [String] = []
            for component in try repository.fetchRecipeComponents(recipeId: recipe.id) {
                for ingredient in try repository.fetchRecipeIngredients(componentId: component.id) {
                    guard let inventoryItem = inventoryById[ingredient.inventoryItemId] else { continue }
                    ingredientValues.append(
                        "\(inventoryItem.name):\(Self.formatQuantity(ingredient.quantity)):\(ingredient.unit.displayName)"
                    )
                }
            }
            rows.append([recipe.name, recipe.notes ?? "", ingredientValues.joined(separator: " | ")])
        }

        return CloudBakeCSV.encode(rows)
    }

    func importCSV(
        _ csvText: String,
        repository: any RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & InventoryItemRepository
    ) throws -> RecipeCSVImportSummary {
        let rows = try parseRows(csvText, inventoryItems: repository.fetchInventoryItems())
        let groupedRows = Dictionary(grouping: rows) {
            TextInputFormatting.normalizedSearchKey($0.name)
        }
        if let duplicateRows = groupedRows.values.first(where: { $0.count > 1 }),
           let duplicateRow = duplicateRows.dropFirst().first {
            throw RecipeCSVError.invalidRow(duplicateRow.rowNumber, "Recipe names must be unique within the CSV.")
        }
        let existingRecipeNames = Set(
            try repository.fetchRecipes().map { TextInputFormatting.normalizedSearchKey($0.name) }
        )
        for row in rows where existingRecipeNames.contains(TextInputFormatting.normalizedSearchKey(row.name)) {
            throw RecipeCSVError.invalidRow(row.rowNumber, "A recipe with this name already exists.")
        }

        let now = dateProvider()
        var ingredientCount = 0
        for row in rows {
            let recipeId = idGenerator()
            try repository.save(
                Recipe(id: recipeId, name: row.name, notes: row.notes, createdAt: now, updatedAt: now)
            )
            guard !row.ingredients.isEmpty else { continue }
            let componentId = idGenerator()
            try repository.save(
                RecipeComponent(
                    id: componentId,
                    recipeId: recipeId,
                    name: "Ingredients",
                    sortOrder: 0,
                    createdAt: now,
                    updatedAt: now
                )
            )
            for value in row.ingredients {
                try repository.save(
                    RecipeIngredient(
                        id: idGenerator(),
                        componentId: componentId,
                        inventoryItemId: value.inventoryItemId,
                        quantity: value.quantity,
                        unit: value.unit,
                        note: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )
                ingredientCount += 1
            }
        }

        return RecipeCSVImportSummary(
            importedRecipeCount: rows.count,
            importedIngredientCount: ingredientCount
        )
    }

    private func parseRows(_ text: String, inventoryItems: [InventoryItem]) throws -> [RecipeCSVImportRow] {
        let table = CloudBakeCSV.parse(text).filter { $0.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        guard let header = table.first else { return [] }
        let lookup = Dictionary(uniqueKeysWithValues: header.enumerated().map {
            (TextInputFormatting.normalizedSearchKey($0.element), $0.offset)
        })
        let nameIndex = try requiredHeader("name", in: lookup)
        let recipeIndex = try requiredHeader("recipe", in: lookup)
        let ingredientsIndex = try requiredHeader("ingredients", in: lookup)

        return try table.dropFirst().enumerated().compactMap { offset, columns in
            let rowNumber = offset + 2
            let name = value(at: nameIndex, in: columns).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.hasPrefix("#") else { return nil }
            guard !name.isEmpty else {
                throw RecipeCSVError.invalidRow(rowNumber, "Name is required.")
            }
            let notesText = value(at: recipeIndex, in: columns).trimmingCharacters(in: .whitespacesAndNewlines)
            let ingredients = try parseIngredients(
                value(at: ingredientsIndex, in: columns),
                rowNumber: rowNumber,
                inventoryItems: inventoryItems
            )
            return RecipeCSVImportRow(
                rowNumber: rowNumber,
                name: name,
                notes: notesText.isEmpty ? nil : notesText,
                ingredients: ingredients
            )
        }
    }

    private func parseIngredients(
        _ text: String,
        rowNumber: Int,
        inventoryItems: [InventoryItem]
    ) throws -> [RecipeCSVIngredient] {
        try text.split(separator: "|").map { rawValue in
            let parts = rawValue.split(separator: ":", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 3, !parts[0].isEmpty else {
                throw RecipeCSVError.invalidRow(rowNumber, "Ingredients must use name:quantity:unit separated by |.")
            }
            guard let quantity = Double(parts[1]), quantity > 0 else {
                throw RecipeCSVError.invalidRow(rowNumber, "Ingredient quantity must be greater than zero.")
            }
            guard let unit = InventoryUnit.csvValue(parts[2]) else {
                throw RecipeCSVError.invalidRow(rowNumber, "Ingredient unit is not supported.")
            }
            let key = TextInputFormatting.normalizedSearchKey(parts[0])
            let matches = inventoryItems.filter { item in
                ([item.name] + item.aliases).contains {
                    TextInputFormatting.normalizedSearchKey($0) == key
                }
            }
            guard matches.count == 1, let inventoryItem = matches.first else {
                let message = matches.isEmpty
                    ? "Ingredient '\(parts[0])' does not match active inventory."
                    : "Ingredient '\(parts[0])' matches more than one inventory item."
                throw RecipeCSVError.invalidRow(rowNumber, message)
            }
            return RecipeCSVIngredient(
                inventoryItemId: inventoryItem.id,
                quantity: quantity,
                unit: unit
            )
        }
    }

    private func requiredHeader(_ name: String, in lookup: [String: Int]) throws -> Int {
        guard let index = lookup[TextInputFormatting.normalizedSearchKey(name)] else {
            throw RecipeCSVError.missingRequiredHeader(name)
        }
        return index
    }

    private func value(at index: Int, in row: [String]) -> String {
        row.indices.contains(index) ? row[index] : ""
    }

    private static func formatQuantity(_ quantity: Double) -> String {
        quantity.formatted(.number.grouping(.never).precision(.fractionLength(0...6)))
    }
}

private struct RecipeCSVImportRow {
    let rowNumber: Int
    let name: String
    let notes: String?
    let ingredients: [RecipeCSVIngredient]
}

private struct RecipeCSVIngredient {
    let inventoryItemId: String
    let quantity: Double
    let unit: InventoryUnit
}

private extension InventoryCSVService {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let quantityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 6
        return formatter
    }()
}

private struct InventoryCSVImportRow {
    let rowNumber: Int
    let name: String
    let aliases: [String]
    let type: InventoryItemType
    let unit: InventoryUnit
    let minimumQuantity: Double
    let batchQuantity: Double
    let amount: Decimal?
    let expiryDate: Date?
}

private extension InventoryItemType {
    static func csvValue(_ text: String) -> InventoryItemType? {
        let normalized = TextInputFormatting.normalizedSearchKey(text)
        return InventoryItemType.allCases.first { type in
            normalized == TextInputFormatting.normalizedSearchKey(type.rawValue)
                || normalized == TextInputFormatting.normalizedSearchKey(type.displayName)
        }
    }
}

private extension InventoryUnit {
    static func csvValue(_ text: String) -> InventoryUnit? {
        let normalized = TextInputFormatting.normalizedSearchKey(text)
        return InventoryUnit.inventoryInputCases.first { unit in
            normalized == TextInputFormatting.normalizedSearchKey(unit.rawValue)
                || normalized == TextInputFormatting.normalizedSearchKey(unit.displayName)
        }
    }
}
