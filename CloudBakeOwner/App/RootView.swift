import SwiftUI

struct RootView: View {
    let database: AppDatabase
    @Environment(\.scenePhase) private var scenePhase

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
        .task {
            await refreshExpiryReminders()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await refreshExpiryReminders()
            }
        }
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
        case .recipes:
            RecipeListView(
                viewModel: RecipeListViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
        case .orders, .designs, .customers, .settings:
            PlaceholderScreen(destination: destination)
        }
    }

    private func refreshExpiryReminders() async {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] != "1" else {
            return
        }

        await ExpiryReminderScheduler(
            repository: database.makeCoreDataRepository()
        ).refreshReminders()
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
