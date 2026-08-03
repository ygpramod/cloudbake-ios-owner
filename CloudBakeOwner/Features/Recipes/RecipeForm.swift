import SwiftUI

struct RecipeForm: View {
    let title: String
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool
    let onCancel: () -> Void
    let onSave: () -> Bool
    let allowsIngredientDrafts: Bool
    @State private var isAddingIngredient = false

    init(
        title: String = "Add Recipe",
        viewModel: RecipeListViewModel,
        isPresented: Binding<Bool>,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Bool,
        allowsIngredientDrafts: Bool = true
    ) {
        self.title = title
        self.viewModel = viewModel
        _isPresented = isPresented
        self.onCancel = onCancel
        self.onSave = onSave
        self.allowsIngredientDrafts = allowsIngredientDrafts
    }

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

            if allowsIngredientDrafts {
                Section {
                    if viewModel.newRecipeIngredientDrafts.isEmpty {
                        Text("No ingredients added")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.newRecipeIngredientDrafts) { ingredient in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ingredient.inventoryItemName)
                                    Text("\(ingredient.quantity.formatted()) \(ingredient.unit.displayName)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    viewModel.removeNewRecipeIngredientDraft(id: ingredient.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete \(ingredient.inventoryItemName)")
                                .accessibilityIdentifier("recipes.form.ingredient.delete.\(ingredient.id)")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Ingredients")
                        Spacer()
                        Button {
                            viewModel.beginAddingNewRecipeIngredient()
                            isAddingIngredient = true
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add Ingredient")
                        .accessibilityIdentifier("recipes.form.ingredient.add")
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("recipes.error")
                }
            }
        }
        .cloudBakeFormScreenStyle()
        .navigationTitle(title)
        .sheet(isPresented: $isAddingIngredient, onDismiss: viewModel.cancelIngredientEdit) {
            NavigationStack {
                RecipeIngredientForm(
                    viewModel: viewModel,
                    isPresented: $isAddingIngredient,
                    onSave: viewModel.saveNewRecipeIngredientDraft,
                    onPrepareForNext: viewModel.beginAddingNewRecipeIngredient
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    isPresented = false
                }
                .accessibilityIdentifier("recipes.form.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if onSave() {
                        isPresented = false
                    }
                }
                .disabled(!viewModel.canSubmitRecipeDraft)
                .accessibilityIdentifier("recipes.form.save")
            }
        }
    }
}
