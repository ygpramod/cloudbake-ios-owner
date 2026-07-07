import SwiftUI

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
                    isPresented: $isAddingRecipe,
                    onCancel: viewModel.cancelAddRecipe,
                    onSave: viewModel.addRecipe
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
