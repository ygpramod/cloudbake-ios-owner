import SwiftUI

struct RecipeIngredientForm: View {
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool
    let onSave: () -> Bool
    let onPrepareForNext: () -> Void
    @State private var isConfirmingInventoryShortage = false
    @State private var completionAfterSave: SaveCompletion = .close
    @State private var continuesAddingIngredients = false

    init(
        viewModel: RecipeListViewModel,
        isPresented: Binding<Bool>,
        onSave: (() -> Bool)? = nil,
        onPrepareForNext: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        _isPresented = isPresented
        self.onSave = onSave ?? viewModel.saveIngredient
        self.onPrepareForNext = onPrepareForNext ?? viewModel.beginAddingIngredient
    }

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

                if viewModel.editingIngredient == nil {
                    Section {
                        Toggle("Continue adding ingredients", isOn: $continuesAddingIngredients)
                            .accessibilityIdentifier("recipes.ingredient.continueAdding")
                    }
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
        .orderConfirmationDialog(
            isPresented: $isConfirmingInventoryShortage,
            title: "Inventory Shortage",
            message: viewModel.inventoryShortageWarningMessage,
            messageAccessibilityIdentifier: "recipes.ingredient.inventoryShortage.message",
            onCancel: {
                isConfirmingInventoryShortage = false
                viewModel.cancelInventoryShortageOverride()
            }
        ) {
            nativeDialogButton("Continue And Save", role: .destructive) {
                if viewModel.confirmPendingIngredientInventoryShortage() {
                    isConfirmingInventoryShortage = false
                    completeSuccessfulSave()
                } else {
                    isConfirmingInventoryShortage = false
                }
            }
            .accessibilityIdentifier("recipes.ingredient.inventoryShortage.continue")
        }
        .cloudBakeFormScreenStyle()
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
                    let completion: SaveCompletion =
                        viewModel.editingIngredient == nil && continuesAddingIngredients
                        ? .addAnother
                        : .close
                    submit(completion)
                }
                .disabled(!viewModel.canSubmitIngredientDraft)
                .accessibilityIdentifier("recipes.ingredient.save")
            }
        }
    }

    private func submit(_ completion: SaveCompletion) {
        completionAfterSave = completion
        if onSave() {
            completeSuccessfulSave()
        } else if !viewModel.pendingInventoryShortages.isEmpty {
            isConfirmingInventoryShortage = true
        }
    }

    private func completeSuccessfulSave() {
        switch completionAfterSave {
        case .close:
            isPresented = false
        case .addAnother:
            onPrepareForNext()
        }
    }

    private enum SaveCompletion {
        case close
        case addAnother
    }
}
