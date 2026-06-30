import SwiftUI

struct RootView: View {
    let database: AppDatabase

    var body: some View {
        NavigationStack {
            DashboardView(
                viewModel: DashboardViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
                .navigationDestination(for: AppDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .accessibilityIdentifier("app.shell")
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .dashboard:
            DashboardView(
                viewModel: DashboardViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
        case .inventory:
            InventoryListView(
                viewModel: InventoryListViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
        case .orders, .recipes, .designs, .customers, .settings:
            PlaceholderScreen(destination: destination)
        }
    }
}

#Preview {
    if let database = try? AppDatabase.makeInMemory() {
        RootView(database: database)
    } else {
        ContentUnavailableView(
            "CloudBake cannot open",
            systemImage: "exclamationmark.triangle",
            description: Text("The preview database could not be prepared.")
        )
    }
}
