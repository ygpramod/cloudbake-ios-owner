import SwiftUI

struct RootView: View {
    let database: AppDatabase
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var orderNotificationRouter: OrderNotificationRouter
    @EnvironmentObject private var orderNavigationRouter: OrderNavigationRouter
    @EnvironmentObject private var inventoryNavigationRouter: InventoryNavigationRouter
    @State private var navigationPath: [AppDestination] = []
    private let maximumSectionHistoryCount = 4

    private var selectedDestination: AppDestination {
        navigationPath.last ?? .dashboard
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $navigationPath) {
                destinationView(for: .dashboard)
                    .navigationDestination(for: AppDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .background(NativeBackSwipeEnabler().frame(width: 0, height: 0))

            CloudBakeBottomNavigation(
                selectedDestination: selectedDestination,
                onSelect: navigate
            )
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            navigateToOrdersWhenNotificationIsPending()
            navigateToOrdersWhenNewOrderIsPending()
            navigateToInventoryWhenItemIsPending()
        }
        .environment(\.navigateToAppDestination, navigate)
        .onChange(of: orderNotificationRouter.pendingOrderId) { _, orderId in
            guard orderId != nil else {
                return
            }

            navigateToOrdersWhenNotificationIsPending()
        }
        .onChange(of: orderNavigationRouter.pendingNewOrderCustomerId) { _, customerId in
            guard customerId != nil else {
                return
            }

            navigateToOrdersWhenNewOrderIsPending()
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

    private func navigateToOrdersWhenNewOrderIsPending() {
        guard orderNavigationRouter.pendingNewOrderCustomerId != nil else {
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
        case .more:
            MoreView()
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
            CakeDesignListView(
                viewModel: CakeDesignListViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
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

private struct MoreView: View {
    @Environment(\.navigateToAppDestination) private var navigate

    private let sections: [MoreSection] = [
        MoreSection(
            title: "Bakery Library",
            destinations: [.recipes, .designs, .customers]
        ),
        MoreSection(
            title: "App",
            destinations: [.settings]
        )
    ]

    var body: some View {
        CloudBakeScreenScaffold(
            title: "More",
            selectedDestination: .more
        ) {
            ForEach(sections) { section in
                CloudBakeSection(section.title) {
                    CloudBakeListCard {
                        ForEach(section.destinations.indices, id: \.self) { index in
                            let destination = section.destinations[index]

                            Button {
                                navigate(destination)
                            } label: {
                                HStack(spacing: CloudBakeTheme.Spacing.rowContent) {
                                    CloudBakeRowIcon(systemImage: destination.systemImage, tint: tint(for: destination))

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(destination.title)
                                            .font(CloudBakeTheme.Typography.rowTitle)
                                            .foregroundStyle(.primary)

                                        Text(detail(for: destination))
                                            .font(CloudBakeTheme.Typography.rowDetail)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer(minLength: 12)

                                    Image(systemName: "chevron.right")
                                        .font(CloudBakeTheme.Typography.rowTitle)
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, CloudBakeTheme.Spacing.cardPadding)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(destination.accessibilityIdentifier)

                            if index < section.destinations.count - 1 {
                                CloudBakeCardDivider()
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(AppDestination.more.screenAccessibilityIdentifier)
    }

    private func tint(for destination: AppDestination) -> Color {
        switch destination {
        case .recipes:
            CloudBakeTheme.ColorToken.recipeAccent
        case .customers:
            CloudBakeTheme.ColorToken.customerAccent
        case .designs:
            CloudBakeTheme.ColorToken.primaryAction
        case .settings:
            .gray
        default:
            CloudBakeTheme.ColorToken.secondaryAction
        }
    }

    private func detail(for destination: AppDestination) -> String {
        switch destination {
        case .recipes:
            "Ingredients, components, and saved recipe notes"
        case .customers:
            "Contacts, preferences, allergies, and order history"
        case .designs:
            "Cake photo references and design ideas"
        case .settings:
            "Pricing, currency, and inventory data tools"
        default:
            destination.title
        }
    }
}

private struct MoreSection: Identifiable {
    let title: String
    let destinations: [AppDestination]

    var id: String { title }
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
