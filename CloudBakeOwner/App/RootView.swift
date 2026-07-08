import SwiftUI

struct RootView: View {
    let database: AppDatabase
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedDestination: AppDestination = .dashboard
    @GestureState private var horizontalDragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            currentDestinationView
                .offset(x: selectedDestination == .dashboard ? 0 : max(horizontalDragOffset, 0))
                .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88), value: selectedDestination)
                .simultaneousGesture(edgeBackGesture)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CloudBakeBottomNavigation(selectedDestination: selectedDestination)
        }
        .environment(\.navigateToAppDestination, navigate)
        .accessibilityIdentifier("app.shell")
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

    @ViewBuilder
    private var currentDestinationView: some View {
        NavigationStack {
            destinationView(for: selectedDestination)
        }
        .id(selectedDestination)
    }

    private var edgeBackGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .updating($horizontalDragOffset) { value, state, _ in
                guard selectedDestination != .dashboard,
                      value.startLocation.x <= 24,
                      value.translation.width > 0,
                      abs(value.translation.height) < 80
                else {
                    return
                }

                state = min(value.translation.width, 140)
            }
            .onEnded { value in
                guard selectedDestination != .dashboard,
                      value.startLocation.x <= 24,
                      value.translation.width > 88,
                      abs(value.translation.height) < 80
                else {
                    return
                }

                navigate(.dashboard)
            }
    }

    private func navigate(_ destination: AppDestination) {
        selectedDestination = destination
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
