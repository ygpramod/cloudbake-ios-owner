import SwiftUI

struct RecipeListView: View {
    @StateObject private var viewModel: RecipeListViewModel
    @State private var isAddingRecipe = false
    @State private var isImportingRecipe = false
    @State private var isViewingRecipe = false
    @FocusState private var isSearchFocused: Bool

    init(viewModel: RecipeListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        CloudBakeScreenScaffold(
            title: "Recipes",
            selectedDestination: .recipes,
            primaryAction: CloudBakeScreenAction(
                title: "Add recipe",
                systemImage: "plus",
                accessibilityIdentifier: "recipes.add",
                action: { isAddingRecipe = true }
            ),
            secondaryActions: [
                CloudBakeScreenAction(
                    title: "Import recipe",
                    systemImage: "doc.text.viewfinder",
                    accessibilityIdentifier: "recipes.import",
                    action: { isImportingRecipe = true }
                )
            ]
        ) {
            if viewModel.recipes.isEmpty {
                CloudBakeEmptyState(
                    title: "No recipes yet",
                    systemImage: "book",
                    message: "Add trusted cake recipes before ingredients and recipe-book conversion arrive."
                )
            } else {
                CloudBakeSearchField(
                    text: $viewModel.searchText,
                    prompt: "Search recipes",
                    accessibilityIdentifier: "recipes.search",
                    isFocused: $isSearchFocused
                )

                recipeResults
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            isSearchFocused = false
                        }
                    )
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

    @ViewBuilder
    private var recipeResults: some View {
        if viewModel.visibleRecipes.isEmpty {
            CloudBakeEmptyState(
                title: "No matching recipes",
                systemImage: "magnifyingglass",
                message: "Try another cake name, ingredient note, or recipe note."
            )
        } else {
            CloudBakeSection("Recipes") {
                VStack(spacing: 16) {
                    ForEach(viewModel.visibleRecipes, id: \.id) { recipe in
                        recipeCard(recipe)
                    }
                }
            }
        }
    }

    private func recipeCard(_ recipe: Recipe) -> some View {
        Button {
            viewModel.beginViewingRecipe(recipe)
            isViewingRecipe = true
        } label: {
            HStack(spacing: 18) {
                CloudBakeRowIcon(systemImage: "book", tint: .cloudBakeMint)

                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let notes = recipe.notes {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.cloudBakePink.opacity(0.72))
                    .accessibilityHidden(true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cloudBakeCardStyle()
        .accessibilityIdentifier("recipes.item.\(recipe.id)")
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
