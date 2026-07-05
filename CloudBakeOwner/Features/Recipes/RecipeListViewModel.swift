import CoreGraphics
import Foundation

@MainActor
final class RecipeListViewModel: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published var draftName = ""
    @Published var draftNotes = ""
    @Published var recipeScanRecognizedText = ""
    @Published var errorMessage: String?
    @Published private(set) var isRecognizingRecipeScan = false

    private let repository: any RecipeRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date

    init(
        repository: any RecipeRepository,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    func load() {
        do {
            recipes = try repository.fetchRecipes()
            errorMessage = nil
        } catch {
            errorMessage = "Recipes could not be loaded."
        }
    }

    func addRecipe() -> Bool {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Recipe name is required."
            return false
        }

        let notes = draftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = dateProvider()
        let recipe = Recipe(
            id: idGenerator(),
            name: name,
            notes: notes.isEmpty ? nil : notes,
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.save(recipe)
            resetDraft()
            load()
            return true
        } catch {
            errorMessage = "Recipe could not be saved."
            return false
        }
    }

    func cancelAddRecipe() {
        resetDraft()
        errorMessage = nil
    }

    func createRecipeDraftFromRecognizedText() -> Bool {
        guard let draft = RecipeDraftParser.draft(from: recipeScanRecognizedText) else {
            errorMessage = "Recipe text could not be turned into a draft."
            return false
        }

        draftName = draft.name
        draftNotes = draft.notes ?? ""
        errorMessage = nil
        return true
    }

    func recognizeRecipeImage(
        _ image: CGImage,
        recognizer: RecipeTextRecognizing
    ) async -> Bool {
        isRecognizingRecipeScan = true
        errorMessage = nil

        do {
            recipeScanRecognizedText = try await recognizer.recognizedText(from: image)
            isRecognizingRecipeScan = false
            return createRecipeDraftFromRecognizedText()
        } catch {
            isRecognizingRecipeScan = false
            errorMessage = "Recipe image could not be read."
            return false
        }
    }

    func cancelRecipeImport() {
        recipeScanRecognizedText = ""
        cancelAddRecipe()
    }

    private func resetDraft() {
        draftName = ""
        draftNotes = ""
    }
}
