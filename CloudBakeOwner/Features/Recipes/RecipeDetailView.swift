import SwiftUI

struct RecipeDetailView: View {
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool
    @State private var isEditingIngredient = false
    @State private var isEditingRecipe = false

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

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.beginEditingRecipe()
                    isEditingRecipe = true
                } label: {
                    Label("Edit Recipe", systemImage: "pencil")
                }
                .accessibilityIdentifier("recipes.detail.edit")

                Button {
                    viewModel.beginAddingIngredient()
                    isEditingIngredient = true
                } label: {
                    Label("Add Ingredient", systemImage: "plus")
                }
                .accessibilityIdentifier("recipes.ingredient.add")
            }
        }
        .sheet(isPresented: $isEditingRecipe, onDismiss: viewModel.cancelAddRecipe) {
            NavigationStack {
                RecipeForm(
                    title: "Edit Recipe",
                    viewModel: viewModel,
                    isPresented: $isEditingRecipe,
                    onCancel: viewModel.cancelAddRecipe,
                    onSave: viewModel.saveEditedRecipe
                )
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
