import CoreGraphics
import Foundation

@MainActor
final class RecipeListViewModel: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var selectedRecipe: Recipe?
    @Published private(set) var recipeIngredients: [RecipeIngredientRow] = []
    @Published private(set) var availableInventoryItems: [InventoryItem] = []
    @Published var draftName = ""
    @Published var draftNotes = ""
    @Published var recipeScanRecognizedText = ""
    @Published var draftIngredientInventoryItemId = ""
    @Published var draftIngredientQuantity = ""
    @Published var draftIngredientUnit: InventoryUnit = .gram
    @Published var draftIngredientNote = ""
    @Published var errorMessage: String?
    @Published private(set) var isRecognizingRecipeScan = false
    @Published private(set) var editingIngredient: RecipeIngredient?

    private let repository: any RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & InventoryItemRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date

    init(
        repository: any RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & InventoryItemRepository,
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

    func beginViewingRecipe(_ recipe: Recipe) {
        selectedRecipe = recipe
        loadRecipeDetail()
    }

    func closeRecipeDetail() {
        selectedRecipe = nil
        recipeIngredients = []
        availableInventoryItems = []
        resetIngredientDraft()
        errorMessage = nil
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

    func beginAddingIngredient() {
        editingIngredient = nil
        resetIngredientDraft()
        loadAvailableInventoryItems()
        defaultIngredientSelectionIfNeeded()
        errorMessage = nil
    }

    func beginEditingIngredient(_ ingredient: RecipeIngredient) {
        editingIngredient = ingredient
        loadAvailableInventoryItems()
        draftIngredientInventoryItemId = ingredient.inventoryItemId
        draftIngredientQuantity = ingredient.quantity.formatted()
        draftIngredientUnit = ingredient.unit
        draftIngredientNote = ingredient.note ?? ""
        errorMessage = nil
    }

    func updateDraftIngredientUnitForSelectedInventoryItem() {
        guard let item = availableInventoryItems.first(where: { $0.id == draftIngredientInventoryItemId }) else {
            return
        }

        draftIngredientUnit = item.unit
    }

    func saveIngredient() -> Bool {
        guard let selectedRecipe else {
            errorMessage = "Recipe could not be found."
            return false
        }

        guard !draftIngredientInventoryItemId.isEmpty,
              availableInventoryItems.contains(where: { $0.id == draftIngredientInventoryItemId }) else {
            errorMessage = "Choose an inventory item."
            return false
        }

        guard let quantity = Double(draftIngredientQuantity), quantity > 0 else {
            errorMessage = "Ingredient quantity must be greater than zero."
            return false
        }

        do {
            let component = try defaultComponent(for: selectedRecipe)
            let now = dateProvider()
            let note = draftIngredientNote.trimmingCharacters(in: .whitespacesAndNewlines)
            let ingredient = RecipeIngredient(
                id: editingIngredient?.id ?? idGenerator(),
                componentId: component.id,
                inventoryItemId: draftIngredientInventoryItemId,
                quantity: quantity,
                unit: draftIngredientUnit,
                note: note.isEmpty ? nil : note,
                createdAt: editingIngredient?.createdAt ?? now,
                updatedAt: now
            )

            try repository.save(ingredient)
            resetIngredientDraft()
            loadRecipeDetail()
            return true
        } catch {
            errorMessage = "Recipe ingredient could not be saved."
            return false
        }
    }

    func deleteIngredient(_ ingredient: RecipeIngredient) {
        do {
            try repository.deleteRecipeIngredient(id: ingredient.id)
            loadRecipeDetail()
        } catch {
            errorMessage = "Recipe ingredient could not be deleted."
        }
    }

    func cancelIngredientEdit() {
        resetIngredientDraft()
        errorMessage = nil
    }

    private func resetDraft() {
        draftName = ""
        draftNotes = ""
    }

    private func loadRecipeDetail() {
        guard let selectedRecipe else {
            recipeIngredients = []
            return
        }

        do {
            if let refreshedRecipe = try repository.fetchRecipe(id: selectedRecipe.id) {
                self.selectedRecipe = refreshedRecipe
            }

            let components = try repository.fetchRecipeComponents(recipeId: selectedRecipe.id)
            let inventoryItems = try repository.fetchInventoryItems()
            availableInventoryItems = inventoryItems
            let inventoryById = Dictionary(uniqueKeysWithValues: inventoryItems.map { ($0.id, $0) })
            recipeIngredients = try components.flatMap { component in
                try repository.fetchRecipeIngredients(componentId: component.id).map { ingredient in
                    RecipeIngredientRow(
                        ingredient: ingredient,
                        inventoryItemName: inventoryById[ingredient.inventoryItemId]?.name ?? "Missing inventory item"
                    )
                }
            }
            errorMessage = nil
        } catch {
            recipeIngredients = []
            errorMessage = "Recipe details could not be loaded."
        }
    }

    private func loadAvailableInventoryItems() {
        do {
            availableInventoryItems = try repository.fetchInventoryItems()
            errorMessage = nil
        } catch {
            availableInventoryItems = []
            errorMessage = "Inventory items could not be loaded."
        }
    }

    private func defaultComponent(for recipe: Recipe) throws -> RecipeComponent {
        if let component = try repository.fetchRecipeComponents(recipeId: recipe.id).first {
            return component
        }

        let now = dateProvider()
        let component = RecipeComponent(
            id: idGenerator(),
            recipeId: recipe.id,
            name: "Ingredients",
            sortOrder: 0,
            createdAt: now,
            updatedAt: now
        )
        try repository.save(component)
        return component
    }

    private func defaultIngredientSelectionIfNeeded() {
        guard draftIngredientInventoryItemId.isEmpty,
              let firstItem = availableInventoryItems.first else {
            return
        }

        draftIngredientInventoryItemId = firstItem.id
        draftIngredientUnit = firstItem.unit
    }

    private func resetIngredientDraft() {
        editingIngredient = nil
        draftIngredientInventoryItemId = ""
        draftIngredientQuantity = ""
        draftIngredientUnit = .gram
        draftIngredientNote = ""
    }
}

struct RecipeIngredientRow: Identifiable, Equatable {
    let ingredient: RecipeIngredient
    let inventoryItemName: String

    var id: String {
        ingredient.id
    }
}
