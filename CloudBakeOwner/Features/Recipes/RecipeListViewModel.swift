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
    @Published var importIngredientDrafts: [RecipeImportIngredientDraftRow] = []
    @Published var searchText = ""
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

    var visibleRecipes: [Recipe] {
        let query = TextInputFormatting.normalizedSearchKey(searchText)
        guard !query.isEmpty else {
            return recipes
        }

        return recipes.filter { recipe in
            [
                recipe.name,
                recipe.notes
            ]
            .compactMap { $0 }
            .map(TextInputFormatting.normalizedSearchKey)
            .contains { $0.contains(query) }
        }
    }

    func beginViewingRecipe(_ recipe: Recipe) {
        selectedRecipe = recipe
        loadRecipeDetail()
    }

    func beginEditingRecipe() {
        guard let selectedRecipe else {
            errorMessage = "Recipe could not be found."
            return
        }

        draftName = selectedRecipe.name
        draftNotes = selectedRecipe.notes ?? ""
        errorMessage = nil
    }

    func closeRecipeDetail() {
        selectedRecipe = nil
        recipeIngredients = []
        availableInventoryItems = []
        resetIngredientDraft()
        errorMessage = nil
    }

    func addRecipe() -> Bool {
        guard let draft = validatedRecipeDraft() else {
            return false
        }

        let now = dateProvider()
        let recipe = Recipe(
            id: idGenerator(),
            name: draft.name,
            notes: draft.notes,
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

    func saveEditedRecipe() -> Bool {
        guard let selectedRecipe else {
            errorMessage = "Recipe could not be found."
            return false
        }

        guard let draft = validatedRecipeDraft() else {
            return false
        }

        let recipe = Recipe(
            id: selectedRecipe.id,
            name: draft.name,
            notes: draft.notes,
            createdAt: selectedRecipe.createdAt,
            updatedAt: dateProvider()
        )

        do {
            try repository.save(recipe)
            self.selectedRecipe = recipe
            resetDraft()
            load()
            loadRecipeDetail()
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
        loadAvailableInventoryItems()
        importIngredientDrafts = draft.ingredients.map { ingredient in
            RecipeImportIngredientDraftRow(
                id: idGenerator(),
                name: ingredient.name,
                quantity: ingredient.quantity.formatted(),
                unit: ingredient.unit,
                inventoryItemId: matchedInventoryItemId(for: ingredient.name) ?? "",
                note: ingredient.note ?? ""
            )
        }
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
        importIngredientDrafts = []
        cancelAddRecipe()
    }

    func saveRecipeImportDraft() -> Bool {
        guard let draft = validatedRecipeImportDraft() else {
            return false
        }

        let now = dateProvider()
        let recipe = Recipe(
            id: idGenerator(),
            name: draft.recipe.name,
            notes: draft.recipe.notes,
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.save(recipe)
            if !draft.ingredients.isEmpty {
                let component = try defaultComponent(for: recipe)
                for parsedDraft in draft.ingredients {
                    let note = parsedDraft.draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
                    try repository.save(
                        RecipeIngredient(
                            id: idGenerator(),
                            componentId: component.id,
                            inventoryItemId: parsedDraft.draft.inventoryItemId,
                            quantity: parsedDraft.quantity,
                            unit: parsedDraft.draft.unit,
                            note: note.isEmpty ? parsedDraft.draft.name : note,
                            createdAt: now,
                            updatedAt: now
                        )
                    )
                }
            }
            recipeScanRecognizedText = ""
            importIngredientDrafts = []
            resetDraft()
            load()
            return true
        } catch {
            errorMessage = "Recipe could not be saved."
            return false
        }
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

        guard let quantity = RecipeImportDraftValidation.parsedIngredientQuantity(from: draftIngredientQuantity),
              quantity > 0 else {
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

    private func validatedRecipeDraft() -> ValidatedRecipeDraft? {
        switch RecipeDraftValidation.validate(
            RecipeDraftValidationInput(
                name: draftName,
                notes: draftNotes
            )
        ) {
        case .success(let draft):
            return draft
        case .failure(let error):
            errorMessage = error.message
            return nil
        }
    }

    private func validatedRecipeImportDraft() -> ValidatedRecipeImportDraft? {
        switch RecipeImportDraftValidation.validate(
            RecipeImportDraftValidationInput(
                recipeName: draftName,
                recipeNotes: draftNotes,
                ingredientDrafts: importIngredientDrafts,
                availableInventoryItemIds: Set(availableInventoryItems.map(\.id))
            )
        ) {
        case .success(let draft):
            return draft
        case .failure(let error):
            errorMessage = error.message
            return nil
        }
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

    private func matchedInventoryItemId(for ingredientName: String) -> String? {
        let normalizedIngredientName = normalizedName(ingredientName)
        return availableInventoryItems.first { item in
            let normalizedItemName = normalizedName(item.name)
            return normalizedItemName == normalizedIngredientName
                || normalizedItemName.contains(normalizedIngredientName)
                || normalizedIngredientName.contains(normalizedItemName)
        }?.id
    }

    private func normalizedName(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined()
    }
}

struct RecipeIngredientRow: Identifiable, Equatable {
    let ingredient: RecipeIngredient
    let inventoryItemName: String

    var id: String {
        ingredient.id
    }
}

struct RecipeImportIngredientDraftRow: Identifiable, Equatable {
    let id: String
    var name: String
    var quantity: String
    var unit: InventoryUnit
    var inventoryItemId: String
    var note: String
}
