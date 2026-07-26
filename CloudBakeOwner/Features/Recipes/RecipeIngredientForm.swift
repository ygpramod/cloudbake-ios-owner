import SwiftUI

struct RecipeIngredientForm: View {
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool
    @State private var isConfirmingInventoryShortage = false

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
        .centeredOrderPopup(
            isPresented: isConfirmingInventoryShortage,
            title: "Inventory Shortage",
            onCancel: {
                isConfirmingInventoryShortage = false
                viewModel.cancelInventoryShortageOverride()
            }
        ) {
            Text(viewModel.inventoryShortageWarningMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("recipes.ingredient.inventoryShortage.message")

            centeredPopupButton("Continue And Save", role: .destructive) {
                if viewModel.confirmPendingIngredientInventoryShortage() {
                    isConfirmingInventoryShortage = false
                    isPresented = false
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
                    if viewModel.saveIngredient() {
                        isPresented = false
                    } else if !viewModel.pendingInventoryShortages.isEmpty {
                        isConfirmingInventoryShortage = true
                    }
                }
                .disabled(!viewModel.canSubmitIngredientDraft)
                .accessibilityIdentifier("recipes.ingredient.save")
            }
        }
    }
}
