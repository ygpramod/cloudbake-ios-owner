import SwiftUI
import UIKit
import os

private let reservationRepairLogger = Logger(
    subsystem: "com.cloudbake.owner",
    category: "InventoryReservationRepair"
)

struct RootView: View {
    let database: AppDatabase
    let cloudBackupRuntime: CloudBackupRuntime?
    let cloudBackupSettingsService: (any CloudBackupSettingsServing)?
    let cloudRestoreSettingsService: (any CloudRestoreSettingsServing)?
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var orderNotificationRouter: OrderNotificationRouter
    @EnvironmentObject private var orderNavigationRouter: OrderNavigationRouter
    @EnvironmentObject private var inventoryNavigationRouter: InventoryNavigationRouter
    @State private var navigationPath: [AppDestination] = []
    @State private var restoredDataRevision = 0
    @State private var isRestoreRecoveryRequired = false
    @AppStorage(AppSettings.hasCompletedIntroductionKey) private var hasCompletedIntroduction = false
    @State private var isPresentingIntroduction = false
    @StateObject private var emptyRestoreViewModel: CloudRestoreSettingsViewModel
    private let maximumSectionHistoryCount = 4
    private let reservationRepairCoordinator = OrderInventoryReservationRepairCoordinator.shared

    init(database: AppDatabase, cloudBackupRuntime: CloudBackupRuntime? = nil) {
        self.database = database
        self.cloudBackupRuntime = cloudBackupRuntime
        #if DEBUG
        if AcceptanceTestRuntime.usesCloudBackupSettingsFixture {
            cloudBackupSettingsService = CloudBackupSettingsUITestService()
        } else {
            cloudBackupSettingsService = cloudBackupRuntime
        }
        let restoreService: (any CloudRestoreSettingsServing)?
        if AcceptanceTestRuntime.usesCloudRestoreFixture {
            restoreService = CloudRestoreSettingsUITestService()
        } else {
            restoreService = cloudBackupRuntime
        }
        #else
        cloudBackupSettingsService = cloudBackupRuntime
        let restoreService: (any CloudRestoreSettingsServing)? = cloudBackupRuntime
        #endif
        cloudRestoreSettingsService = restoreService
        _emptyRestoreViewModel = StateObject(
            wrappedValue: CloudRestoreSettingsViewModel(
                service: restoreService ?? UnavailableCloudRestoreSettingsService()
            )
        )
    }

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
            .id(restoredDataRevision)
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
        .cloudRestorePrompts(
            viewModel: emptyRestoreViewModel,
            offersStartFresh: true
        )
        .disabled(isRestoreRecoveryRequired)
        .cloudBakeConfirmationDialog(
            isPresented: .constant(isRestoreRecoveryRequired),
            title: "Reopen CloudBake to Finish Recovery",
            message: "CloudBake has stopped access to your data because restore could not return safely to the previous state. No changes can be made until CloudBake is closed and reopened.",
            messageAccessibilityIdentifier: "restore.recoveryRequired.message",
            showsCancelButton: false,
            onCancel: {}
        ) {}
        .onAppear {
            let hasExistingOwnerData = (try? OwnerInstallationState(database: database).hasRestorableData()) ?? false
            if hasExistingOwnerData && !hasCompletedIntroduction {
                hasCompletedIntroduction = true
            }
            isPresentingIntroduction = AppIntroductionPolicy.shouldPresent(
                hasCompleted: hasCompletedIntroduction,
                hasExistingOwnerData: hasExistingOwnerData,
                isAutomatedTest: AcceptanceTestRuntime.isRunning,
                forcesPresentation: acceptanceTestForcesIntroduction
            )
            navigateToOrdersWhenNotificationIsPending()
            navigateToPaymentReportWhenNotificationIsPending()
            navigateToOrdersWhenNewOrderIsPending()
            navigateToInventoryWhenItemIsPending()
        }
        .environment(\.navigateToAppDestination, navigate)
        .fullScreenCover(isPresented: $isPresentingIntroduction) {
            AppIntroductionView {
                hasCompletedIntroduction = true
                isPresentingIntroduction = false
            }
        }
        .onChange(of: orderNotificationRouter.pendingOrderId) { _, orderId in
            guard orderId != nil else {
                return
            }

            navigateToOrdersWhenNotificationIsPending()
        }
        .onChange(of: orderNotificationRouter.isPaymentReportPending) { _, isPending in
            guard isPending else {
                return
            }

            navigateToPaymentReportWhenNotificationIsPending()
        }
        .onChange(of: orderNavigationRouter.pendingNewOrderRequest) { _, request in
            guard request != nil else {
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
            await prepareInitialRestoreOrBackup()
            guard await repairInventoryReservations() else { return }
            navigateToInitialUITestDestination()
            await refreshLocalReminders()
        }
        .onChange(of: emptyRestoreViewModel.didChooseStartFresh) { _, didChoose in
            if didChoose {
                cloudBackupRuntime?.startLaunchCatchUpIfNeeded()
            }
        }
        .onChange(of: emptyRestoreViewModel.didCompleteRestore) { _, didComplete in
            if didComplete, cloudBackupRuntime == nil {
                Task { await refreshAfterRestore() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudBakeRestoreDidComplete)) { _ in
            Task { await refreshAfterRestore() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudBakeRestoreRecoveryRequired)) { _ in
            isRestoreRecoveryRequired = true
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.significantTimeChangeNotification
            )
        ) { _ in
            Task {
                await refreshLocalReminders()
            }
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

    private func navigateToPaymentReportWhenNotificationIsPending() {
        guard orderNotificationRouter.isPaymentReportPending else {
            return
        }

        navigate(.reports)
        orderNotificationRouter.clearPendingPaymentReport()
    }

    private func navigateToOrdersWhenNewOrderIsPending() {
        guard orderNavigationRouter.pendingNewOrderRequest != nil else {
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
        guard let destination = acceptanceTestInitialDestination else {
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
                    repository: database.makeCoreDataRepository(),
                    onReminderDataChanged: {
                        Task {
                            await refreshLocalReminders()
                        }
                    }
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
                viewModel: makeOrderListViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
        case .reminders:
            let repository = database.makeCoreDataRepository()
            ReminderView(
                viewModel: ReminderViewModel(
                    repository: repository,
                    onPaymentChanged: {
                        Task {
                            await refreshLocalReminders()
                        }
                    }
                ),
                makeOrderViewModel: {
                    makeOrderListViewModel(repository: repository)
                },
                makeInventoryViewModel: {
                    InventoryListViewModel(
                        repository: repository,
                        onReminderDataChanged: {
                            Task {
                                await refreshLocalReminders()
                            }
                        }
                    )
                }
            )
        case .reports:
            let repository = database.makeCoreDataRepository()
            ReportsView(
                viewModel: ReportsViewModel(repository: repository),
                makeOrderViewModel: {
                    makeOrderListViewModel(repository: repository)
                }
            )
        case .settings:
            let repository = database.makeCoreDataRepository()
            SettingsView(
                viewModel: SettingsViewModel(
                    repository: repository,
                    recipeRepository: repository,
                    manualBackupService: try? ManualBackupService.live(database: database),
                    refreshReminderSchedule: {
                        await refreshLocalReminders()
                    }
                ),
                orderReminderSettingsViewModel: OrderReminderSettingsViewModel(
                    repository: repository
                ),
                paymentReminderSettingsViewModel: PaymentReminderSettingsViewModel(
                    repository: repository,
                    onSaved: {
                        Task {
                            await refreshLocalReminders()
                        }
                    }
                ),
                cloudBackupService: cloudBackupSettingsService,
                cloudRestoreService: cloudRestoreSettingsService,
                onShowIntroduction: {
                    isPresentingIntroduction = true
                }
            )
        case .designs:
            let repository = database.makeCoreDataRepository()
            CakeDesignListView(
                viewModel: CakeDesignListViewModel(
                    repository: repository,
                    orderUsageRepository: repository
                )
            )
        }
    }

    private func makeOrderListViewModel(
        repository: GRDBCoreDataRepository
    ) -> OrderListViewModel {
        OrderListViewModel(
            repository: repository,
            onReminderDataChanged: {
                Task {
                    await refreshLocalReminders()
                }
            }
        )
    }

    private func refreshLocalReminders() async {
        guard !AcceptanceTestRuntime.isRunning else {
            return
        }

        await LocalReminderRefreshCoordinator.shared.refresh {
            let repository = database.makeCoreDataRepository()
            await LocalNotificationScheduleCoordinator(
                repository: repository
            ).refreshReminders()
        }
    }

    private var acceptanceTestForcesIntroduction: Bool {
        #if DEBUG
        AcceptanceTestRuntime.forcesIntroduction
        #else
        false
        #endif
    }

    private var acceptanceTestInitialDestination: AppDestination? {
        #if DEBUG
        AcceptanceTestRuntime.initialDestination
        #else
        nil
        #endif
    }

    private func repairInventoryReservations() async -> Bool {
        do {
            _ = try await reservationRepairCoordinator.repair(database: database)
            try Task.checkCancellation()
            return true
        } catch is CancellationError {
            return false
        } catch {
            reservationRepairLogger.error(
                "Inventory reservation repair stopped after a persistence failure"
            )
            return true
        }
    }

    private func prepareInitialRestoreOrBackup() async {
        guard cloudRestoreSettingsService != nil,
              (try? OwnerInstallationState(database: database).hasRestorableData()) == false else {
            cloudBackupRuntime?.startLaunchCatchUpIfNeeded()
            return
        }
        let isOfferingRestore = await emptyRestoreViewModel.inspect()
        if !isOfferingRestore {
            cloudBackupRuntime?.startLaunchCatchUpIfNeeded()
        }
    }

    @MainActor
    private func refreshAfterRestore() async {
        navigationPath.removeAll()
        restoredDataRevision += 1
        guard await repairInventoryReservations() else { return }
        await RestoreCompletionReconciler(
            refreshReminders: refreshLocalReminders,
            resumeBackup: { cloudBackupRuntime?.startPostRestoreCatchUp() }
        ).reconcile()
    }
}

struct OrderInventoryReservationRepairRunner {
    let repository: any OrderInventoryReservationMutationRepository
    var batchLimit = 50
    var maximumBatchCount = 20
    var dateProvider: () -> Date = Date.init
    var activationIdProvider: () -> String = { UUID().uuidString }

    func run() async throws -> OrderInventoryReservationRepairSummary {
        guard batchLimit > 0, maximumBatchCount > 0 else {
            return OrderInventoryReservationRepairSummary(
                completedCount: 0,
                failedCount: 0
            )
        }

        var completedCount = 0
        var failedCount = 0
        var hasMore = false
        let timestamp = dateProvider()
        let activationId = activationIdProvider()
        for _ in 0..<maximumBatchCount {
            try Task.checkCancellation()
            let summary = try repository.repairOrderInventoryReservations(
                limit: batchLimit,
                at: timestamp,
                activationId: activationId
            )
            completedCount += summary.completedCount
            failedCount += summary.failedCount
            hasMore = summary.hasMore
            guard summary.hasMore else {
                break
            }
            await Task.yield()
        }
        return OrderInventoryReservationRepairSummary(
            completedCount: completedCount,
            failedCount: failedCount,
            hasMore: hasMore
        )
    }
}

actor OrderInventoryReservationRepairCoordinator {
    static let shared = OrderInventoryReservationRepairCoordinator()

    private var isRepairing = false
    private var waiters: [
        CheckedContinuation<OrderInventoryReservationRepairSummary, Error>
    ] = []

    func repair(
        database: AppDatabase,
        dateProvider: () -> Date = Date.init,
        activationIdProvider: () -> String = { UUID().uuidString }
    ) async throws -> OrderInventoryReservationRepairSummary {
        if isRepairing {
            return try await withCheckedThrowingContinuation { continuation in
                waiters.append(continuation)
            }
        }

        isRepairing = true
        do {
            let summary = try await performRepair(
                database: database,
                dateProvider: dateProvider,
                activationIdProvider: activationIdProvider
            )
            finishWaiters(with: .success(summary))
            return summary
        } catch {
            finishWaiters(with: .failure(error))
            throw error
        }
    }

    private func performRepair(
        database: AppDatabase,
        dateProvider: () -> Date,
        activationIdProvider: () -> String
    ) async throws -> OrderInventoryReservationRepairSummary {
        let repository = database.makeCoreDataRepository()
        let timestamp = dateProvider()
        let activationId = activationIdProvider()
        var completedCount = 0
        var failedCount = 0

        while true {
            try Task.checkCancellation()
            let summary = try await OrderInventoryReservationRepairRunner(
                repository: repository,
                dateProvider: { timestamp },
                activationIdProvider: { activationId }
            ).run()
            completedCount += summary.completedCount
            failedCount += summary.failedCount
            guard summary.hasMore else {
                return OrderInventoryReservationRepairSummary(
                    completedCount: completedCount,
                    failedCount: failedCount
                )
            }
            await Task.yield()
        }
    }

    private func finishWaiters(
        with result: Result<OrderInventoryReservationRepairSummary, Error>
    ) {
        isRepairing = false
        let continuations = waiters
        waiters = []
        for continuation in continuations {
            continuation.resume(with: result)
        }
    }
}

@MainActor
struct RestoreCompletionReconciler {
    let refreshReminders: () async -> Void
    let resumeBackup: () -> Void

    func reconcile() async {
        await refreshReminders()
        resumeBackup()
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
            title: "Business",
            destinations: [.reminders, .reports]
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
        case .reminders:
            CloudBakeTheme.ColorToken.secondaryAction
        case .reports:
            .cloudBakePurple
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
        case .reminders:
            "Orders, payments, and inventory needing attention"
        case .reports:
            "Payments, ingredient margins, sales, and orders"
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
