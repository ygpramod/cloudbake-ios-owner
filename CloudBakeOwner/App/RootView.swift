import SwiftUI

struct RootView: View {
    let database: AppDatabase
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var orderNotificationRouter: OrderNotificationRouter
    @EnvironmentObject private var inventoryNavigationRouter: InventoryNavigationRouter
    @State private var navigationPath: [AppDestination] = []
    private let maximumSectionHistoryCount = 4

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
        .background(NativeBackSwipeEnabler().frame(width: 0, height: 0))
        .onAppear {
            navigateToOrdersWhenNotificationIsPending()
            navigateToInventoryWhenItemIsPending()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CloudBakeBottomNavigation(
                selectedDestination: selectedDestination,
                onSelect: navigate
            )
        }
        .environment(\.navigateToAppDestination, navigate)
        .onChange(of: orderNotificationRouter.pendingOrderId) { _, orderId in
            guard orderId != nil else {
                return
            }

            navigateToOrdersWhenNotificationIsPending()
        }
        .onChange(of: inventoryNavigationRouter.pendingInventoryItemId) { _, itemId in
            guard itemId != nil else {
                return
            }

            navigateToInventoryWhenItemIsPending()
        }
        .task {
            navigateToInitialUITestDestination()
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
        if destination == .dashboard {
            navigationPath.removeAll()
            return
        }

        guard selectedDestination != destination else {
            return
        }

        if let existingIndex = navigationPath.firstIndex(of: destination) {
            navigationPath = Array(navigationPath.prefix(through: existingIndex))
            return
        }

        navigationPath.append(destination)
        if navigationPath.count > maximumSectionHistoryCount {
            navigationPath.removeFirst(navigationPath.count - maximumSectionHistoryCount)
        }
    }

    private func navigateToOrdersWhenNotificationIsPending() {
        guard orderNotificationRouter.pendingOrderId != nil else {
            return
        }

        navigate(.orders)
    }

    private func navigateToInventoryWhenItemIsPending() {
        guard inventoryNavigationRouter.pendingInventoryItemId != nil else {
            return
        }

        navigate(.inventory)
    }

    private func navigateToInitialUITestDestination() {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] == "1",
              let rawDestination = ProcessInfo.processInfo.environment["CLOUDBAKE_INITIAL_DESTINATION"],
              let destination = AppDestination(rawValue: rawDestination),
              destination != .dashboard else {
            return
        }

        navigate(destination)
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
        case .reminders:
            let repository = database.makeCoreDataRepository()
            ReminderView(
                viewModel: ReminderViewModel(
                    repository: repository
                ),
                makeOrderViewModel: {
                    OrderListViewModel(repository: repository)
                },
                makeInventoryViewModel: {
                    InventoryListViewModel(repository: repository)
                }
            )
        case .settings:
            SettingsView(
                viewModel: SettingsViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
        case .designs:
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
            .environmentObject(OrderNotificationRouter())
            .environmentObject(InventoryNavigationRouter())
    } else {
        ContentUnavailableView(
            "CloudBake cannot open",
            systemImage: "exclamationmark.triangle",
            description: Text("The preview database could not be prepared.")
        )
    }
}
