import SwiftUI

struct RootView: View {
    let database: AppDatabase
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigationPath: [AppDestination] = []
    @State private var navigationGeneration = 0

    private var selectedDestination: AppDestination {
        navigationPath.last ?? .dashboard
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            destinationView(for: .dashboard)
                .navigationDestination(for: AppDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CloudBakeBottomNavigation(
                selectedDestination: selectedDestination,
                onSelect: navigate
            )
        }
        .environment(\.navigateToAppDestination, navigate)
        .task {
            await refreshLocalReminders()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await refreshLocalReminders()
            }
        }
    }

    private func navigate(_ destination: AppDestination) {
        navigationGeneration += 1

        if destination == .dashboard {
            navigationPath.removeAll()
            return
        }

        guard selectedDestination != destination else {
            return
        }

        if navigationPath.isEmpty {
            navigationPath = [destination]
            return
        }

        let generation = navigationGeneration
        navigationPath.append(destination)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard generation == navigationGeneration,
                  navigationPath.last == destination
            else {
                return
            }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                navigationPath = [destination]
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
        case .customers:
            CustomerListView(
                viewModel: CustomerListViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
        case .orders:
            OrderListView(
                viewModel: OrderListViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
        case .designs, .settings:
            PlaceholderScreen(destination: destination)
        }
    }

    private func refreshLocalReminders() async {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] != "1" else {
            return
        }

        let repository = database.makeCoreDataRepository()
        await ExpiryReminderScheduler(
            repository: repository
        ).refreshReminders()
        await OrderReminderScheduler(
            repository: repository
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
