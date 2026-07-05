import Foundation

struct RecipeDraft: Equatable {
    let name: String
    let notes: String?
}

enum RecipeDraftParser {
    static func draft(from text: String) -> RecipeDraft? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let name = lines.first else {
            return nil
        }

        let notes = lines.dropFirst().joined(separator: "\n")
        return RecipeDraft(
            name: name,
            notes: notes.isEmpty ? nil : notes
        )
    }
}
