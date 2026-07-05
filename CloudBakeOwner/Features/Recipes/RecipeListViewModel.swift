import Foundation

@MainActor
final class RecipeListViewModel: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published var draftName = ""
    @Published var draftNotes = ""
    @Published var errorMessage: String?

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

    private func resetDraft() {
        draftName = ""
        draftNotes = ""
    }
}
