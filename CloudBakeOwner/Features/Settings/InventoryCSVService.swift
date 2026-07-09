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

        return encode(rows)
    }

    func importCSV(
        _ csvText: String,
        repository: any InventoryItemRepository & InventoryStockBatchRepository
    ) throws -> InventoryCSVImportSummary {
        let importedRows = try parseImportRows(csvText)
        let groupedRows = Dictionary(grouping: importedRows) { row in
            "\(TextInputFormatting.normalizedSearchKey(row.name))|\(row.unit.rawValue)"
        }
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

    private func csvRow(item: InventoryItem, batchQuantity: Double, amount: Decimal?, expiryDate: Date?) -> [String] {
        [
            item.name,
            item.unit.displayName,
            formatQuantity(item.currentQuantity),
            formatQuantity(item.minimumQuantity),
            formatQuantity(batchQuantity),
            amount.map(formatMoney) ?? "",
            expiryDate.map(formatDate) ?? ""
        ]
    }

    private func parseImportRows(_ csvText: String) throws -> [InventoryCSVImportRow] {
        let table = parseCSV(csvText)
            .filter { row in row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        guard let header = table.first else {
            return []
        }

        let headerLookup = Dictionary(uniqueKeysWithValues: header.enumerated().map { index, value in
            (TextInputFormatting.normalizedSearchKey(value), index)
        })
        let nameIndex = try requiredHeader("name", in: headerLookup)
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
                name: name,
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

    private func encode(_ rows: [[String]]) -> String {
        rows
            .map { row in row.map(escaped).joined(separator: ",") }
            .joined(separator: "\n")
            + "\n"
    }

    private func escaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func parseCSV(_ text: String) -> [[String]] {
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
    let name: String
    let unit: InventoryUnit
    let minimumQuantity: Double
    let batchQuantity: Double
    let amount: Decimal?
    let expiryDate: Date?
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
