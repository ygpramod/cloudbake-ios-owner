import PhotosUI
import SwiftUI
import UIKit

struct RecipeListView: View {
    @StateObject private var viewModel: RecipeListViewModel
    @State private var isAddingRecipe = false
    @State private var isImportingRecipe = false
    @State private var isViewingRecipe = false

    init(viewModel: RecipeListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if viewModel.recipes.isEmpty {
                ContentUnavailableView(
                    "No recipes yet",
                    systemImage: "book",
                    description: Text("Add trusted cake recipes before ingredients and recipe-book conversion arrive.")
                )
            } else {
                Section("Recipes") {
                    ForEach(viewModel.recipes, id: \.id) { recipe in
                        Button {
                            viewModel.beginViewingRecipe(recipe)
                            isViewingRecipe = true
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(recipe.name)
                                    .font(.headline)
                                if let notes = recipe.notes {
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recipes.item.\(recipe.id)")
                    }
                }
            }
        }
        .navigationTitle("Recipes")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isImportingRecipe = true
                } label: {
                    Label("Import recipe", systemImage: "doc.text.viewfinder")
                }
                .accessibilityIdentifier("recipes.import")

                Button {
                    isAddingRecipe = true
                } label: {
                    Label("Add recipe", systemImage: "plus")
                }
                .accessibilityIdentifier("recipes.add")
            }
        }
        .sheet(isPresented: $isAddingRecipe, onDismiss: viewModel.cancelAddRecipe) {
            NavigationStack {
                RecipeForm(
                    viewModel: viewModel,
                    isPresented: $isAddingRecipe
                )
            }
        }
        .sheet(isPresented: $isViewingRecipe, onDismiss: viewModel.closeRecipeDetail) {
            NavigationStack {
                RecipeDetailView(
                    viewModel: viewModel,
                    isPresented: $isViewingRecipe
                )
            }
        }
        .sheet(isPresented: $isImportingRecipe, onDismiss: viewModel.cancelRecipeImport) {
            NavigationStack {
                RecipeImportView(
                    viewModel: viewModel,
                    isPresented: $isImportingRecipe
                )
            }
        }
        .onAppear {
            viewModel.load()
        }
        .accessibilityIdentifier(AppDestination.recipes.screenAccessibilityIdentifier)
    }
}

private struct RecipeDetailView: View {
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool
    @State private var isEditingIngredient = false

    var body: some View {
        List {
            if let recipe = viewModel.selectedRecipe {
                if let notes = recipe.notes {
                    Section("Notes") {
                        Text(notes)
                    }
                }

                if viewModel.recipeIngredients.isEmpty {
                    ContentUnavailableView(
                        "No ingredients yet",
                        systemImage: "list.bullet",
                        description: Text("Add linked inventory items with the quantity needed for this recipe.")
                    )
                } else {
                    Section("Ingredients") {
                        ForEach(viewModel.recipeIngredients) { row in
                            Button {
                                viewModel.beginEditingIngredient(row.ingredient)
                                isEditingIngredient = true
                            } label: {
                                RecipeIngredientListRow(row: row)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("recipes.ingredient.view.\(row.id)")
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteIngredient(row.ingredient)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityIdentifier("recipes.ingredient.delete.\(row.id)")
                            }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("recipes.detail.error")
                    }
                }
            }
        }
        .navigationTitle(viewModel.selectedRecipe?.name ?? "Recipe")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("recipes.detail.done")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.beginAddingIngredient()
                    isEditingIngredient = true
                } label: {
                    Label("Add ingredient", systemImage: "plus")
                }
                .accessibilityIdentifier("recipes.ingredient.add")
            }
        }
        .sheet(isPresented: $isEditingIngredient, onDismiss: viewModel.cancelIngredientEdit) {
            NavigationStack {
                RecipeIngredientForm(
                    viewModel: viewModel,
                    isPresented: $isEditingIngredient
                )
            }
        }
    }
}

private struct RecipeIngredientListRow: View {
    let row: RecipeIngredientRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.inventoryItemName)
                .font(.headline)
            Text("\(row.ingredient.quantity.formatted()) \(row.ingredient.unit.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let note = row.ingredient.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RecipeIngredientForm: View {
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            if viewModel.availableInventoryItems.isEmpty {
                ContentUnavailableView(
                    "No inventory items",
                    systemImage: "shippingbox",
                    description: Text("Add inventory before linking ingredients to a recipe.")
                )
            } else {
                Section("Ingredient") {
                    Picker("Inventory Item", selection: $viewModel.draftIngredientInventoryItemId) {
                        ForEach(viewModel.availableInventoryItems, id: \.id) { item in
                            Text(item.name).tag(item.id)
                        }
                    }
                    .onChange(of: viewModel.draftIngredientInventoryItemId) { _, _ in
                        viewModel.updateDraftIngredientUnitForSelectedInventoryItem()
                    }
                    .accessibilityIdentifier("recipes.ingredient.inventoryItem")

                    TextField("Quantity", text: $viewModel.draftIngredientQuantity)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("recipes.ingredient.quantity")

                    Picker("Unit", selection: $viewModel.draftIngredientUnit) {
                        ForEach(InventoryUnit.inventoryInputCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .accessibilityIdentifier("recipes.ingredient.unit")

                    TextField("Note", text: $viewModel.draftIngredientNote, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("recipes.ingredient.note")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("recipes.ingredient.error")
                }
            }
        }
        .navigationTitle(viewModel.editingIngredient == nil ? "Add Ingredient" : "Edit Ingredient")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelIngredientEdit()
                    isPresented = false
                }
                .accessibilityIdentifier("recipes.ingredient.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.saveIngredient() {
                        isPresented = false
                    }
                }
                .disabled(viewModel.availableInventoryItems.isEmpty)
                .accessibilityIdentifier("recipes.ingredient.save")
            }
        }
    }
}

private struct RecipeImportView: View {
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool
    @State private var isShowingCamera = false
    @State private var selectedRecipeImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let recognizer: RecipeTextRecognizing

    init(
        viewModel: RecipeListViewModel,
        isPresented: Binding<Bool>,
        recognizer: RecipeTextRecognizing = VisionRecipeTextRecognizer()
    ) {
        self.viewModel = viewModel
        _isPresented = isPresented
        self.recognizer = recognizer
    }

    var body: some View {
        Form {
            Section("Recipe Photo") {
                Button {
                    isShowingCamera = true
                } label: {
                    Label(selectedRecipeImage == nil ? "Take Recipe Photo" : "Retake Recipe Photo", systemImage: "camera")
                }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera) || viewModel.isRecognizingRecipeScan)
                .accessibilityIdentifier("recipes.import.camera")

                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label("Choose From Library", systemImage: "photo.on.rectangle")
                }
                .disabled(viewModel.isRecognizingRecipeScan)
                .accessibilityIdentifier("recipes.import.library")

                if let selectedRecipeImage {
                    Image(uiImage: selectedRecipeImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("recipes.import.preview")
                }

                if viewModel.isRecognizingRecipeScan {
                    ProgressView("Reading recipe")
                        .accessibilityIdentifier("recipes.import.recognizing")
                }
            }

            Section("Recipe Text") {
                TextField("Recipe Text", text: $viewModel.recipeScanRecognizedText, axis: .vertical)
                    .lineLimit(4...10)
                    .accessibilityIdentifier("recipes.import.text")

                Button {
                    _ = viewModel.createRecipeDraftFromRecognizedText()
                } label: {
                    Label("Create Draft", systemImage: "wand.and.stars")
                }
                .disabled(viewModel.isRecognizingRecipeScan)
                .accessibilityIdentifier("recipes.import.createDraft")
            }

            Section("Draft Recipe") {
                TextField("Name", text: $viewModel.draftName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("recipes.import.name")

                TextField("Notes", text: $viewModel.draftNotes, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("recipes.import.notes")
            }

            if !viewModel.importIngredientDrafts.isEmpty {
                Section("Draft Ingredients") {
                    ForEach($viewModel.importIngredientDrafts) { $draft in
                        RecipeImportIngredientDraftRowView(
                            draft: $draft,
                            inventoryItems: viewModel.availableInventoryItems
                        )
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("recipes.import.error")
                }
            }
        }
        .navigationTitle("Import Recipe")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelRecipeImport()
                    isPresented = false
                }
                .accessibilityIdentifier("recipes.import.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.saveRecipeImportDraft() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("recipes.import.save")
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            RecipeCameraView { image in
                selectedRecipeImage = image
                recognize(image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else {
                return
            }

            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    viewModel.errorMessage = "Recipe image could not be opened."
                    selectedPhotoItem = nil
                    return
                }

                selectedRecipeImage = image
                recognize(image)
                selectedPhotoItem = nil
            }
        }
    }

    private func recognize(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            viewModel.errorMessage = "Recipe image could not be opened."
            return
        }

        Task {
            _ = await viewModel.recognizeRecipeImage(
                cgImage,
                recognizer: recognizer
            )
        }
    }
}

private struct RecipeImportIngredientDraftRowView: View {
    @Binding var draft: RecipeImportIngredientDraftRow
    let inventoryItems: [InventoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Ingredient", text: $draft.name)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("recipes.import.ingredient.name.\(draft.id)")

            Picker("Inventory Item", selection: $draft.inventoryItemId) {
                Text("Choose").tag("")
                ForEach(inventoryItems, id: \.id) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .accessibilityIdentifier("recipes.import.ingredient.inventory.\(draft.id)")

            HStack {
                TextField("Quantity", text: $draft.quantity)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("recipes.import.ingredient.quantity.\(draft.id)")

                Picker("Unit", selection: $draft.unit) {
                    ForEach(InventoryUnit.inventoryInputCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("recipes.import.ingredient.unit.\(draft.id)")
            }

            TextField("Note", text: $draft.note, axis: .vertical)
                .lineLimit(1...3)
                .accessibilityIdentifier("recipes.import.ingredient.note.\(draft.id)")
        }
        .padding(.vertical, 4)
    }
}

private struct RecipeCameraView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onImageSelected: onImageSelected,
            dismiss: dismiss
        )
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImageSelected: (UIImage) -> Void
        private let dismiss: DismissAction

        init(
            onImageSelected: @escaping (UIImage) -> Void,
            dismiss: DismissAction
        ) {
            self.onImageSelected = onImageSelected
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            }

            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

private struct RecipeForm: View {
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            Section("Recipe") {
                TextField("Name", text: $viewModel.draftName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("recipes.form.name")

                TextField("Notes", text: $viewModel.draftNotes, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("recipes.form.notes")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("recipes.error")
                }
            }
        }
        .navigationTitle("Add Recipe")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelAddRecipe()
                    isPresented = false
                }
                .accessibilityIdentifier("recipes.form.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.addRecipe() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("recipes.form.save")
            }
        }
    }
}

#Preview {
    NavigationStack {
        if let database = try? AppDatabase.makeInMemory() {
            RecipeListView(
                viewModel: RecipeListViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
        }
    }
}
