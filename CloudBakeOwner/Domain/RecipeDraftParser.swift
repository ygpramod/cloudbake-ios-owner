import Foundation

struct RecipeDraft: Equatable {
    let name: String
    let notes: String?
    let ingredients: [RecipeIngredientDraft]
}

struct RecipeIngredientDraft: Equatable {
    let name: String
    let quantity: Double
    let unit: InventoryUnit
    let note: String?
}

enum RecipeDraftParser {
    static func draft(from text: String) -> RecipeDraft? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return nil
        }

        var name: String?
        var notes: [String] = []
        var ingredients: [RecipeIngredientDraft] = []

        for line in lines {
            if let ingredient = ingredient(from: line) {
                ingredients.append(ingredient)
            } else if name == nil {
                name = cleanedRecipeName(line)
            } else {
                notes.append(line)
            }
        }

        guard let draftName = name ?? lines.first else {
            return nil
        }

        return RecipeDraft(
            name: draftName,
            notes: notes.isEmpty ? nil : notes.joined(separator: "\n"),
            ingredients: ingredients
        )
    }

    private static func ingredient(from line: String) -> RecipeIngredientDraft? {
        let normalizedLine = line
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = normalizedLine.split(separator: " ").map(String.init)

        for index in tokens.indices {
            guard let quantity = quantity(from: tokens[index]) else {
                continue
            }

            let nextIndex = tokens.index(after: index)
            guard nextIndex < tokens.endIndex,
                  let unit = unit(from: tokens[nextIndex]) else {
                continue
            }

            let rawName = tokens[..<index]
                .joined(separator: " ")
                .trimmingCharacters(in: CharacterSet(charactersIn: " -:"))
            guard !rawName.isEmpty else {
                continue
            }

            let trailingNoteStart = tokens.index(after: nextIndex)
            let trailingNote = trailingNoteStart < tokens.endIndex
                ? tokens[trailingNoteStart...].joined(separator: " ")
                : ""

            return RecipeIngredientDraft(
                name: cleanedIngredientName(rawName),
                quantity: quantity,
                unit: unit,
                note: trailingNote.isEmpty ? nil : trailingNote
            )
        }

        return nil
    }

    private static func quantity(from text: String) -> Double? {
        let cleanedText = text
            .trimmingCharacters(in: CharacterSet(charactersIn: " -:"))
            .replacingOccurrences(of: ",", with: "")

        if cleanedText.contains("/") {
            let parts = cleanedText.split(separator: "/")
            guard parts.count == 2,
                  let numerator = Double(parts[0]),
                  let denominator = Double(parts[1]),
                  denominator != 0 else {
                return nil
            }
            return numerator / denominator
        }

        return Double(cleanedText)
    }

    private static func unit(from text: String) -> InventoryUnit? {
        let cleanedText = text
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".:,;()"))

        switch cleanedText {
        case "kg", "kilogram", "kilograms":
            return .kilogram
        case "g", "gm", "gms", "gram", "grams":
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
        case "each", "pc", "pcs", "piece", "pieces":
            return .each
        default:
            return nil
        }
    }

    private static func cleanedRecipeName(_ line: String) -> String {
        line
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -:"))
    }

    private static func cleanedIngredientName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -:"))
    }
}
