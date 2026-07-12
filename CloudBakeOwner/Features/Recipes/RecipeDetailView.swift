import SwiftUI

struct RecipeDetailView: View {
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool
    @State private var isEditingIngredient = false
    @State private var isEditingRecipe = false
    @State private var pendingDeleteIngredientRow: RecipeIngredientRow?

    var body: some View {
        CloudBakeDetailScaffold(
            title: viewModel.selectedRecipe?.name ?? "Recipe",
            backAccessibilityIdentifier: "recipes.detail.done",
            primaryAction: CloudBakeDetailAction(
                title: "Edit",
                systemImage: "pencil",
                accessibilityIdentifier: "recipes.detail.edit",
                action: {
                    viewModel.beginEditingRecipe()
                    isEditingRecipe = true
                }
            ),
            onBack: {
                isPresented = false
            }
        ) {
            if let recipe = viewModel.selectedRecipe {
                CloudBakeHeroCard(systemImage: "book", tint: .cloudBakeMint) {
                    Text("Recipe")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.cloudBakeMint)

                    Text(recipe.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("\(viewModel.recipeIngredients.count) ingredient\(viewModel.recipeIngredients.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let notes = recipe.notes {
                    CloudBakeSection("Notes") {
                        CloudBakeDetailCard {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                        }
                    }
                }

                CloudBakeSection(
                    "Ingredients",
                    action: CloudBakeSectionAction(
                        title: "Add Ingredient",
                        systemImage: "plus",
                        accessibilityIdentifier: "recipes.ingredient.add",
                        action: {
                            viewModel.beginAddingIngredient()
                            isEditingIngredient = true
                        }
                    )
                ) {
                    if viewModel.recipeIngredients.isEmpty {
                        CloudBakeEmptyState(
                            title: "No ingredients yet",
                            systemImage: "list.bullet",
                            message: "Add linked inventory items with the quantity needed for this recipe."
                        )
                    } else {
                        CloudBakeDetailCard {
                        ForEach(viewModel.recipeIngredients) { row in
                            HStack(spacing: 12) {
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

                                Button(role: .destructive) {
                                    pendingDeleteIngredientRow = row
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 34, height: 34)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Delete ingredient")
                                .accessibilityIdentifier("recipes.ingredient.delete.\(row.id)")
                            }
                            .padding(.vertical, 12)

                            if row.id != viewModel.recipeIngredients.last?.id {
                                CloudBakeDetailDivider()
                            }
                        }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    CloudBakeErrorBanner(
                        message: errorMessage,
                        accessibilityIdentifier: "recipes.detail.error"
                    )
                }
            }
        }
        .cloudBakeCenteredPopup(
            isPresented: pendingDeleteIngredientRow != nil,
            title: "Delete Ingredient?",
            subtitle: pendingDeleteIngredientSubtitle,
            systemImage: "trash",
            cancelAccessibilityIdentifier: "recipes.ingredient.delete.cancel",
            onCancel: { pendingDeleteIngredientRow = nil }
        ) {
            if let pendingDeleteIngredientRow {
                centeredPopupButton("Delete \(pendingDeleteIngredientRow.inventoryItemName)", role: .destructive) {
                    viewModel.deleteIngredient(pendingDeleteIngredientRow.ingredient)
                    self.pendingDeleteIngredientRow = nil
                }
                .accessibilityIdentifier("recipes.ingredient.delete.confirm")
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

    private var pendingDeleteIngredientSubtitle: String {
        guard let pendingDeleteIngredientRow else {
            return "Remove this ingredient from the recipe."
        }

        return "Remove \(pendingDeleteIngredientRow.inventoryItemName) from this recipe. This cannot be undone."
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
