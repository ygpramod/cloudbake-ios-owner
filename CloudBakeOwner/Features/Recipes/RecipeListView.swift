import SwiftUI

struct RecipeListView: View {
    @StateObject private var viewModel: RecipeListViewModel
    @State private var isAddingRecipe = false

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
                        VStack(alignment: .leading, spacing: 6) {
                            Text(recipe.name)
                                .font(.headline)
                            if let notes = recipe.notes {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("recipes.item.\(recipe.id)")
                    }
                }
            }
        }
        .navigationTitle("Recipes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
        .onAppear {
            viewModel.load()
        }
        .accessibilityIdentifier(AppDestination.recipes.screenAccessibilityIdentifier)
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
