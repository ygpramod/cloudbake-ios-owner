import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var customLogoImage: UIImage?
    @Published private(set) var isPreparingBackup = false
    @Published private(set) var pendingManualBackupPhotoProposal: ManualBackupUnavailablePhotoProposal?
    @Published var isConfirmingManualBackupPhotoRemoval = false
    @Published private(set) var lastManualBackupDate: Date?
    @Published private(set) var lastManualBackupOmittedAssetCount: Int
    @Published private(set) var isWeeklyBackupReminderEnabled: Bool
    @Published private(set) var manualBackupReminderStatus: ManualBackupReminderStatus
    @Published private(set) var nextManualBackupReminderDate: Date?

    private let repository: any InventoryItemRepository & InventoryStockBatchRepository
    private let csvService: InventoryCSVService
    private let recipeRepository:
        (
            any RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & RecipeCSVImportRepository
                & InventoryItemRepository
        )?
    private let recipeCSVService: RecipeCSVService
    private let logoStore: AppLogoStore
    private let manualBackupService: (any ManualBackupPreparing)?
    private let manualBackupPreferences: ManualBackupPreferences
    private let refreshReminderSchedule: () async -> Void

    init(
        repository: any InventoryItemRepository & InventoryStockBatchRepository,
        csvService: InventoryCSVService = InventoryCSVService(),
        recipeRepository: (
            any RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & RecipeCSVImportRepository
                & InventoryItemRepository
        )? = nil,
        recipeCSVService: RecipeCSVService = RecipeCSVService(),
        logoStore: AppLogoStore = AppLogoStore(),
        manualBackupService: (any ManualBackupPreparing)? = nil,
        manualBackupPreferences: ManualBackupPreferences = ManualBackupPreferences(),
        manualBackupReminderScheduler: ManualBackupReminderScheduler? = nil,
        refreshReminderSchedule: (() async -> Void)? = nil
    ) {
        self.repository = repository
        self.csvService = csvService
        self.recipeRepository = recipeRepository
        self.recipeCSVService = recipeCSVService
        self.logoStore = logoStore
        self.manualBackupService = manualBackupService
        self.manualBackupPreferences = manualBackupPreferences
        let fallbackScheduler =
            manualBackupReminderScheduler
            ?? ManualBackupReminderScheduler(preferences: manualBackupPreferences)
        self.refreshReminderSchedule =
            refreshReminderSchedule ?? {
                _ = await fallbackScheduler.refreshReminder()
            }
        lastManualBackupDate = manualBackupPreferences.lastSuccessfulExport
        lastManualBackupOmittedAssetCount =
            manualBackupPreferences.lastSuccessfulOmittedAssetCount
        isWeeklyBackupReminderEnabled = manualBackupPreferences.isReminderEnabled
        manualBackupReminderStatus = manualBackupPreferences.reminderDeliveryStatus
        nextManualBackupReminderDate = manualBackupPreferences.nextReminderDate
        customLogoImage = logoStore.load()
    }

    func prepareManualBackup() async -> ManualBackupExport? {
        guard let manualBackupService else {
            errorMessage = "CloudBake backup is not available in this build."
            statusMessage = nil
            return nil
        }
        isPreparingBackup = true
        defer { isPreparingBackup = false }
        do {
            return handleManualBackupPreparation(
                try await manualBackupService.prepareBackup()
            )
        } catch {
            handleManualBackupPreparationFailure(error)
            return nil
        }
    }

    func approveManualBackupPhotoOmissions() async -> ManualBackupExport? {
        guard let manualBackupService,
            let proposal = pendingManualBackupPhotoProposal
        else { return nil }
        pendingManualBackupPhotoProposal = nil
        isPreparingBackup = true
        defer { isPreparingBackup = false }
        do {
            return handleManualBackupPreparation(
                try await manualBackupService.approveUnavailablePhotoOmissions(
                    proposalID: proposal.id
                )
            )
        } catch {
            handleManualBackupPreparationFailure(error)
            return nil
        }
    }

    func requestManualBackupPhotoRemoval() {
        guard pendingManualBackupPhotoProposal != nil else { return }
        isConfirmingManualBackupPhotoRemoval = true
    }

    func confirmManualBackupPhotoRemoval() async -> ManualBackupExport? {
        guard let manualBackupService,
            let proposal = pendingManualBackupPhotoProposal
        else { return nil }
        isConfirmingManualBackupPhotoRemoval = false
        pendingManualBackupPhotoProposal = nil
        isPreparingBackup = true
        defer { isPreparingBackup = false }
        do {
            return handleManualBackupPreparation(
                try await manualBackupService.removeUnavailablePhotos(
                    proposalID: proposal.id
                )
            )
        } catch {
            handleManualBackupPreparationFailure(error)
            return nil
        }
    }

    func cancelManualBackupPhotoDecision() async {
        guard let manualBackupService,
            let proposal = pendingManualBackupPhotoProposal
        else { return }
        pendingManualBackupPhotoProposal = nil
        isConfirmingManualBackupPhotoRemoval = false
        let result = await manualBackupService.cancelUnavailablePhotoDecision(
            proposalID: proposal.id
        )
        if result == .cancelledAfterPhotoRemoval {
            statusMessage = "The unavailable photo references were removed from CloudBake. The backup was cancelled."
            errorMessage = nil
        }
    }

    func markManualBackupExported(
        omittedAssetCount: Int = 0,
        at date: Date = Date()
    ) async {
        manualBackupPreferences.recordSuccessfulExport(
            at: date,
            omittedAssetCount: omittedAssetCount
        )
        lastManualBackupDate = date
        lastManualBackupOmittedAssetCount = omittedAssetCount
        if omittedAssetCount > 0 {
            statusMessage = "CloudBake backup saved without \(omittedAssetCount) unavailable photo\(omittedAssetCount == 1 ? "" : "s")."
        } else {
            statusMessage = "CloudBake backup saved successfully."
        }
        errorMessage = nil
        await refreshReminderSchedule()
        manualBackupReminderStatus = manualBackupPreferences.reminderDeliveryStatus
        nextManualBackupReminderDate = manualBackupPreferences.nextReminderDate
    }

    func markManualBackupExportFailed() {
        statusMessage = nil
        errorMessage = "The backup was not saved. Your existing data was not changed."
    }

    func setWeeklyBackupReminderEnabled(_ isEnabled: Bool) {
        manualBackupPreferences.isReminderEnabled = isEnabled
        isWeeklyBackupReminderEnabled = isEnabled
        Task {
            await refreshReminderSchedule()
            manualBackupReminderStatus = manualBackupPreferences.reminderDeliveryStatus
            nextManualBackupReminderDate = manualBackupPreferences.nextReminderDate
        }
    }

    func saveLogo(_ image: UIImage) -> Bool {
        do {
            try logoStore.save(image)
            customLogoImage = logoStore.load()
            statusMessage = "CloudBake logo updated."
            errorMessage = nil
            return true
        } catch {
            statusMessage = nil
            errorMessage = "The selected logo could not be saved."
            return false
        }
    }

    func restoreDefaultLogo() -> Bool {
        do {
            try logoStore.remove()
            customLogoImage = nil
            statusMessage = "Default CloudBake logo restored."
            errorMessage = nil
            return true
        } catch {
            statusMessage = nil
            errorMessage = "The default logo could not be restored."
            return false
        }
    }

    func markLogoSelectionFailed() {
        statusMessage = nil
        errorMessage = "The selected logo could not be opened."
    }

    func exportRecipeDocument() -> InventoryCSVDocument? {
        guard let recipeRepository else { return nil }
        do {
            let text = try recipeCSVService.exportCSV(repository: recipeRepository)
            statusMessage = "Recipe export is ready. Choose a location to save the CSV."
            errorMessage = nil
            return InventoryCSVDocument(text: text)
        } catch {
            statusMessage = nil
            errorMessage = "Recipes could not be exported."
            return nil
        }
    }

    func importRecipeCSV(from url: URL) {
        guard let recipeRepository else { return }
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let summary = try recipeCSVService.importCSV(text, repository: recipeRepository)
            statusMessage = "Imported \(summary.importedRecipeCount) recipes and \(summary.importedIngredientCount) ingredients."
            errorMessage = nil
        } catch {
            statusMessage = nil
            errorMessage = "Recipe CSV could not be imported. Check names, ingredient format, and inventory matches."
        }
    }

    func exportInventoryDocument() -> InventoryCSVDocument? {
        do {
            let text = try csvService.exportCSV(repository: repository)
            statusMessage = "Inventory export is ready. Choose a location to save the CSV."
            errorMessage = nil
            return InventoryCSVDocument(text: text)
        } catch {
            statusMessage = nil
            errorMessage = "Inventory could not be exported."
            return nil
        }
    }

    func importInventoryCSV(from url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let summary = try csvService.importCSV(text, repository: repository)
            statusMessage = "Imported \(summary.importedItemCount) inventory items and \(summary.importedBatchCount) stock batches."
            errorMessage = nil
        } catch {
            statusMessage = nil
            errorMessage = "Inventory CSV could not be imported."
        }
    }

    func markExportFailed() {
        statusMessage = nil
        errorMessage = "Inventory CSV could not be exported."
    }

    func markRecipeExportFailed() {
        statusMessage = nil
        errorMessage = "Recipe CSV could not be exported."
    }

    private func handleManualBackupPreparation(
        _ result: ManualBackupPreparationResult
    ) -> ManualBackupExport? {
        switch result {
        case .ready(let export):
            pendingManualBackupPhotoProposal = nil
            if export.omittedAssetCount > 0 {
                statusMessage =
                    "Backup is ready without \(export.omittedAssetCount) unavailable photo\(export.omittedAssetCount == 1 ? "" : "s"). Choose a safe location to save it."
            } else {
                statusMessage = "Backup is ready. Choose a safe location to save it."
            }
            errorMessage = nil
            return export
        case .requiresUnavailablePhotoDecision(let proposal):
            pendingManualBackupPhotoProposal = proposal
            statusMessage = nil
            errorMessage = nil
            return nil
        }
    }

    private func handleManualBackupPreparationFailure(_ error: Error) {
        statusMessage = nil
        if error as? ManualBackupServiceError == .photosAccessDeniedAfterPhotoRemoval {
            errorMessage =
                "The unavailable photo references were removed from CloudBake, but the backup did not complete. Allow CloudBake full access to Photos in iPhone Settings, then try again."
        } else if error as? ManualBackupServiceError == .backupFailedAfterPhotoRemoval {
            errorMessage = "The unavailable photo references were removed, but CloudBake could not create the backup. Try again."
        } else if error as? BackupExternalAssetResolverError == .accessDenied {
            errorMessage = "Allow CloudBake full access to Photos in iPhone Settings, then try again."
        } else {
            errorMessage = "CloudBake could not create a complete backup. No backup was saved."
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var orderNotificationRouter: OrderNotificationRouter
    @StateObject private var viewModel: SettingsViewModel
    @StateObject private var orderReminderSettingsViewModel: OrderReminderSettingsViewModel
    @StateObject private var paymentReminderSettingsViewModel: PaymentReminderSettingsViewModel
    @StateObject private var cloudBackupViewModel: CloudBackupSettingsViewModel
    @StateObject private var cloudRestoreViewModel: CloudRestoreSettingsViewModel
    @AppStorage(AppSettings.currencySymbolKey) private var selectedCurrencySymbol = AppCurrency.defaultCurrency.symbol
    @AppStorage(AppSettings.logoRevisionKey) private var logoRevision = 0
    @State private var isSelectingCurrency = false
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var activeFileImport: SettingsFileImportKind?
    @State private var pendingDataOperation: SettingsDataOperation?
    @State private var isBackupExpanded = false
    @State private var isDataManagementExpanded = false
    @State private var isConfirmingManualBackup = false
    @State private var activeFileExport: SettingsFileExport?
    private let onShowIntroduction: () -> Void

    init(
        viewModel: SettingsViewModel,
        orderReminderSettingsViewModel: OrderReminderSettingsViewModel,
        paymentReminderSettingsViewModel: PaymentReminderSettingsViewModel,
        cloudBackupService: (any CloudBackupSettingsServing)? = nil,
        cloudRestoreService: (any CloudRestoreSettingsServing)? = nil,
        onShowIntroduction: @escaping () -> Void = {}
    ) {
        self.onShowIntroduction = onShowIntroduction
        _viewModel = StateObject(wrappedValue: viewModel)
        _orderReminderSettingsViewModel = StateObject(
            wrappedValue: orderReminderSettingsViewModel
        )
        _paymentReminderSettingsViewModel = StateObject(
            wrappedValue: paymentReminderSettingsViewModel
        )
        _cloudBackupViewModel = StateObject(
            wrappedValue: CloudBackupSettingsViewModel(
                service: cloudBackupService ?? UnavailableCloudBackupSettingsService()
            )
        )
        _cloudRestoreViewModel = StateObject(
            wrappedValue: CloudRestoreSettingsViewModel(
                service: cloudRestoreService ?? UnavailableCloudRestoreSettingsService()
            )
        )
    }

    var body: some View {
        CloudBakeScreenScaffold(
            title: "Settings",
            selectedDestination: .settings
        ) {
            CloudBakeSection("Pricing") {
                CloudBakeDetailCard {
                    Button {
                        isSelectingCurrency = true
                    } label: {
                        CloudBakeDetailRow("Currency") {
                            HStack(spacing: 8) {
                                Text(selectedCurrency.displayName)
                                Image(systemName: "chevron.right")
                                    .imageScale(.small)
                                    .foregroundStyle(Color.cloudBakePink)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.currency")
                }
            }

            CloudBakeSection("Appearance") {
                CloudBakeDetailCard {
                    HStack(spacing: 16) {
                        logoPreview

                        VStack(alignment: .leading, spacing: 5) {
                            Text("CloudBake Logo")
                                .font(.headline)
                            Text("Shown in the app. The Home Screen icon is unchanged.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        PhotosPicker(selection: $selectedLogoItem, matching: .images, photoLibrary: .shared()) {
                            Text("Choose")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.cloudBakePink)
                        }
                        .accessibilityIdentifier("settings.logo.choose")
                    }
                    .padding(.vertical, 12)

                    if viewModel.customLogoImage != nil {
                        CloudBakeDetailDivider()

                        Button("Restore Default Logo", role: .destructive) {
                            if viewModel.restoreDefaultLogo() {
                                logoRevision += 1
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .accessibilityIdentifier("settings.logo.restoreDefault")
                    }
                }
            }

            CloudBakeSection("Reminders") {
                CloudBakeDetailCard {
                    NavigationLink {
                        OrderReminderSettingsView(
                            viewModel: orderReminderSettingsViewModel,
                            paymentViewModel: paymentReminderSettingsViewModel
                        )
                    } label: {
                        HStack(spacing: 16) {
                            CloudBakeRowIcon(
                                systemImage: "bell.badge",
                                tint: .cloudBakePink
                            )
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Order Reminders")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Choose the default schedule copied to new orders.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.orderReminders")
                }
            }

            CloudBakeSection("Help") {
                CloudBakeDetailCard {
                    NavigationLink {
                        HelpGuideView(onShowIntroduction: onShowIntroduction)
                    } label: {
                        HStack(spacing: 16) {
                            CloudBakeRowIcon(systemImage: "questionmark.circle", tint: .cloudBakePink)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Help & Guide").font(.headline).foregroundStyle(.primary)
                                Text("Learn CloudBake features and common workflows.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }.padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.helpGuide")

                    CloudBakeDetailDivider()

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack(spacing: 16) {
                            CloudBakeRowIcon(systemImage: "hand.raised", tint: .cloudBakePink)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Privacy Policy").font(.headline).foregroundStyle(.primary)
                                Text("Understand local storage, Cloud Backup, and your controls.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }.padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.privacyPolicy")
                }
            }

            CloudBakeSection {
                DisclosureGroup(isExpanded: $isBackupExpanded) {
                    CloudBackupSettingsCard(viewModel: cloudBackupViewModel)
                        .padding(.top, 12)

                    CloudBakeDetailCard {
                        CloudBakeDetailRow("Manual File Backup") {
                            Text(lastBackupDescription)
                        }

                        CloudBakeDetailDivider()

                        Toggle(
                            "Weekly Backup Reminder",
                            isOn: Binding(
                                get: { viewModel.isWeeklyBackupReminderEnabled },
                                set: { isEnabled in
                                    viewModel.setWeeklyBackupReminderEnabled(isEnabled)
                                }
                            )
                        )
                        .padding(.vertical, 12)
                        .accessibilityIdentifier("settings.backup.weeklyReminder")

                        Text(backupReminderDescription)
                            .font(.footnote)
                            .foregroundStyle(
                                viewModel.manualBackupReminderStatus == .authorizationDenied
                                    || viewModel.manualBackupReminderStatus == .failed
                                    ? Color.orange
                                    : Color.secondary
                            )
                            .padding(.bottom, 12)
                            .accessibilityIdentifier("settings.backup.weeklyReminder.status")

                        CloudBakeDetailDivider()

                        settingsAction(
                            title: viewModel.isPreparingBackup ? "Preparing Backup…" : "Create Full Backup",
                            detail: "Includes app data, photos, and your custom logo.",
                            systemImage: "externaldrive.badge.plus",
                            accessibilityIdentifier: "settings.backup.create"
                        ) {
                            isConfirmingManualBackup = true
                        }
                        .disabled(viewModel.isPreparingBackup)
                    }
                    .padding(.top, 8)
                } label: {
                    settingsDisclosureLabel(
                        "Backup",
                        accessibilityIdentifier: "settings.backup.disclosure"
                    )
                }
            }

            CloudBakeSection {
                DisclosureGroup(isExpanded: $isDataManagementExpanded) {
                    CloudBakeDetailCard {
                        settingsAction(
                            title: cloudRestoreViewModel.isWorking
                                ? "Inspecting Cloud Backup…"
                                : "Restore from Cloud Backup",
                            detail: "Inspect and restore one complete, validated recovery snapshot.",
                            systemImage: "icloud.and.arrow.down",
                            accessibilityIdentifier: "settings.cloudBackup.restore"
                        ) {
                            Task { await cloudRestoreViewModel.inspect() }
                        }
                        .disabled(cloudRestoreViewModel.isWorking)

                        if let restoreMessage = cloudRestoreViewModel.actionMessage {
                            Text(restoreMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 12)
                                .accessibilityIdentifier("settings.cloudRestore.message")
                        }

                        CloudBakeDetailDivider()

                        settingsAction(
                            title: "Delete Cloud Backup",
                            detail: "Permanently remove the complete recovery backup from iCloud. Local data stays on this iPhone.",
                            systemImage: "trash",
                            accessibilityIdentifier: "settings.cloudBackup.delete"
                        ) {
                            cloudBackupViewModel.requestCloudBackupDeletion()
                        }

                        if let deletionMessage = cloudBackupViewModel.deletionMessage {
                            Text(deletionMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 12)
                                .accessibilityIdentifier("settings.cloudBackup.delete.message")
                        }

                        CloudBakeDetailDivider()

                        settingsAction(
                            title: "Import Inventory CSV",
                            detail: "Review merge behavior before choosing a CSV file.",
                            systemImage: "square.and.arrow.down",
                            accessibilityIdentifier: "settings.inventory.import"
                        ) {
                            pendingDataOperation = .importInventory
                        }

                        CloudBakeDetailDivider()

                        settingsAction(
                            title: "Export Inventory CSV",
                            detail: "Review export contents before choosing where to save.",
                            systemImage: "square.and.arrow.up",
                            accessibilityIdentifier: "settings.inventory.export"
                        ) {
                            pendingDataOperation = .exportInventory
                        }

                        CloudBakeDetailDivider()

                        settingsAction(
                            title: "Import Recipe CSV",
                            detail: "Import name, recipe notes, and pipe-separated ingredients.",
                            systemImage: "square.and.arrow.down",
                            accessibilityIdentifier: "settings.recipes.import"
                        ) {
                            pendingDataOperation = .importRecipes
                        }

                        CloudBakeDetailDivider()

                        settingsAction(
                            title: "Export Recipe CSV",
                            detail: "Export recipes with a reusable ingredient format example.",
                            systemImage: "square.and.arrow.up",
                            accessibilityIdentifier: "settings.recipes.export"
                        ) {
                            pendingDataOperation = .exportRecipes
                        }
                    }
                    .padding(.top, 12)
                } label: {
                    settingsDisclosureLabel(
                        "Data Management",
                        accessibilityIdentifier: "settings.dataManagement.disclosure"
                    )
                }
            }

            if let statusMessage = viewModel.statusMessage {
                settingsStatusBanner(statusMessage)
                    .accessibilityIdentifier("settings.inventory.status")
            }

            if let errorMessage = viewModel.errorMessage {
                CloudBakeErrorBanner(
                    message: errorMessage,
                    accessibilityIdentifier: "settings.inventory.error"
                )
            }
        }
        .onAppear(perform: expandBackupWhenNotificationIsPending)
        .onChange(of: orderNotificationRouter.isBackupSettingsPending) { _, isPending in
            guard isPending else { return }
            expandBackupWhenNotificationIsPending()
        }
        .accessibilityIdentifier(AppDestination.settings.screenAccessibilityIdentifier)
        .cloudBackupPrompts(viewModel: cloudBackupViewModel)
        .cloudRestorePrompts(viewModel: cloudRestoreViewModel)
        .cloudBakeConfirmationDialog(
            isPresented: $cloudBackupViewModel.isConfirmingDeletion,
            title: "Delete Cloud Backup?",
            message:
                "This permanently removes CloudBake's complete recovery backup from the current iCloud account. Your database and photos on this iPhone will not be changed. Cloud backup will be turned off after deletion.",
            cancelAccessibilityIdentifier: "settings.cloudBackup.delete.cancel",
            onCancel: { cloudBackupViewModel.cancelCloudBackupDeletion() }
        ) {
            nativeDialogButton("Delete Cloud Backup", role: .destructive) {
                Task { await cloudBackupViewModel.confirmCloudBackupDeletion() }
            }
            .accessibilityIdentifier("settings.cloudBackup.delete.confirm")
        }
        .task {
            await cloudBackupViewModel.refresh()
        }
        .sheet(isPresented: $isSelectingCurrency) {
            CurrencySelectionView(
                selectedCurrency: selectedCurrency,
                onSelect: { currency in
                    selectedCurrencySymbol = currency.symbol
                    isSelectingCurrency = false
                }
            )
        }
        .onChange(of: selectedLogoItem) { _, item in
            guard let item else { return }
            Task {
                defer { selectedLogoItem = nil }
                do {
                    let image = try await PhotoPickerImageLoader.image(from: item)
                    if viewModel.saveLogo(image) {
                        logoRevision += 1
                    }
                } catch {
                    viewModel.markLogoSelectionFailed()
                }
            }
        }
        .cloudBakeConfirmationDialog(
            isPresented: $isConfirmingManualBackup,
            title: "Create Full Backup?",
            message:
                "CloudBake will prepare the complete database, app-managed photos, lightweight recovery copies of linked Photos-library images, and your custom logo. You will choose where to save the package.",
            cancelAccessibilityIdentifier: "settings.backup.cancel",
            onCancel: { isConfirmingManualBackup = false }
        ) {
            nativeDialogButton("Create Backup") {
                dismissManualBackupPopupAndPrepare()
            }
            .accessibilityIdentifier("settings.backup.create.continue")
        }
        .cloudBakeConfirmationDialog(
            isPresented: Binding(
                get: {
                    viewModel.pendingManualBackupPhotoProposal != nil
                        && !viewModel.isConfirmingManualBackupPhotoRemoval
                },
                set: { isPresented in
                    guard !isPresented,
                        viewModel.pendingManualBackupPhotoProposal != nil,
                        !viewModel.isConfirmingManualBackupPhotoRemoval
                    else { return }
                    Task { await viewModel.cancelManualBackupPhotoDecision() }
                }
            ),
            title: "Unavailable Photos",
            message: manualBackupUnavailablePhotoDescription,
            cancelAccessibilityIdentifier: "settings.manualBackup.photos.cancel",
            onCancel: {
                Task { await viewModel.cancelManualBackupPhotoDecision() }
            }
        ) {
            nativeDialogButton("Back Up Without Photos") {
                continueManualBackup {
                    await viewModel.approveManualBackupPhotoOmissions()
                }
            }
            .accessibilityIdentifier("settings.manualBackup.photos.omit")

            nativeDialogButton("Remove From CloudBake And Back Up", role: .destructive) {
                viewModel.requestManualBackupPhotoRemoval()
            }
            .accessibilityIdentifier("settings.manualBackup.photos.remove")
        }
        .cloudBakeConfirmationDialog(
            isPresented: $viewModel.isConfirmingManualBackupPhotoRemoval,
            title: "Remove Broken References?",
            message:
                "This removes only the unavailable photo references from CloudBake. It never deletes photos from the iPhone Photos library.",
            cancelAccessibilityIdentifier: "settings.manualBackup.photos.remove.cancel",
            onCancel: {
                Task { await viewModel.cancelManualBackupPhotoDecision() }
            }
        ) {
            nativeDialogButton("Remove And Back Up", role: .destructive) {
                continueManualBackup {
                    await viewModel.confirmManualBackupPhotoRemoval()
                }
            }
            .accessibilityIdentifier("settings.manualBackup.photos.remove.confirm")
        }
        .cloudBakeConfirmationDialog(
            isPresented: optionalPresentationBinding($pendingDataOperation),
            title: pendingDataOperation?.title ?? "Inventory CSV",
            message: pendingDataOperation?.explanation ?? "",
            cancelAccessibilityIdentifier: "settings.data.cancel",
            onCancel: { pendingDataOperation = nil }
        ) {
            if let pendingDataOperation {
                nativeDialogButton(pendingDataOperation.primaryActionTitle) {
                    continueDataOperation(pendingDataOperation)
                }
                .accessibilityIdentifier(pendingDataOperation.primaryAccessibilityIdentifier)
            }
        }
        .sheet(item: $activeFileImport) { importKind in
            SettingsFileImporter(
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { url in
                activeFileImport = nil
                guard let url else { return }
                switch importKind {
                case .inventory:
                    viewModel.importInventoryCSV(from: url)
                case .recipes:
                    viewModel.importRecipeCSV(from: url)
                }
            }
            .interactiveDismissDisabled()
        }
        .sheet(item: $activeFileExport) { export in
            SettingsFileExporter(fileURL: export.fileURL) { result in
                activeFileExport = nil
                switch export.kind {
                case .inventory:
                    try? FileManager.default.removeItem(at: export.fileURL)
                case .recipes:
                    try? FileManager.default.removeItem(at: export.fileURL)
                case .manualBackup(let backup):
                    if result == .exported {
                        Task {
                            await viewModel.markManualBackupExported(
                                omittedAssetCount: backup.omittedAssetCount
                            )
                        }
                    }
                    backup.removeStagedFiles()
                }
            }
            .interactiveDismissDisabled()
        }
    }

    private func expandBackupWhenNotificationIsPending() {
        guard orderNotificationRouter.isBackupSettingsPending else { return }
        isBackupExpanded = true
        orderNotificationRouter.clearPendingBackupSettings()
    }

    private func settingsAction(
        title: String,
        detail: String,
        systemImage: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                CloudBakeRowIcon(systemImage: systemImage, tint: .cloudBakePink)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func unavailableSettingsAction(
        title: String,
        detail: String,
        systemImage: String,
        accessibilityIdentifier: String
    ) -> some View {
        settingsAction(
            title: title,
            detail: detail,
            systemImage: systemImage,
            accessibilityIdentifier: accessibilityIdentifier,
            action: {}
        )
        .disabled(true)
        .accessibilityHint("Not available yet")
    }

    private func settingsDisclosureLabel(
        _ title: String,
        accessibilityIdentifier: String
    ) -> some View {
        Text(title)
            .font(CloudBakeTheme.Typography.sectionTitle)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    private var logoPreview: some View {
        Group {
            if let customLogo = viewModel.customLogoImage {
                Image(uiImage: customLogo)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("CloudBakeLogo")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private func settingsStatusBanner(_ message: String) -> some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var selectedCurrency: AppCurrency {
        AppCurrency(rawValue: selectedCurrencySymbol) ?? AppCurrency.defaultCurrency
    }

    private var lastBackupDescription: String {
        guard let date = viewModel.lastManualBackupDate else { return "Never" }
        let dateDescription = date.formatted(date: .abbreviated, time: .shortened)
        guard viewModel.lastManualBackupOmittedAssetCount > 0 else {
            return dateDescription
        }
        let count = viewModel.lastManualBackupOmittedAssetCount
        return "\(dateDescription) · \(count) photo\(count == 1 ? "" : "s") omitted"
    }

    private var backupReminderDescription: String {
        switch viewModel.manualBackupReminderStatus {
        case .scheduled:
            if let date = viewModel.nextManualBackupReminderDate {
                return "Next reminder: \(date.formatted(date: .abbreviated, time: .shortened))."
            }
            return "The weekly reminder is scheduled."
        case .disabled:
            return "Weekly backup reminders are off."
        case .authorizationDenied:
            return "Notifications are off. Allow CloudBake notifications in iPhone Settings."
        case .failed:
            return "The reminder could not be scheduled. CloudBake will try again later."
        case .notChecked:
            return "Reminder delivery has not been checked yet."
        }
    }

    private func dismissManualBackupPopupAndPrepare() {
        isConfirmingManualBackup = false
        continueManualBackup {
            await viewModel.prepareManualBackup()
        }
    }

    private func continueManualBackup(
        _ operation: @escaping @MainActor () async -> ManualBackupExport?
    ) {
        Task {
            guard let export = await operation() else { return }
            activeFileExport = SettingsFileExport(
                fileURL: export.packageURL,
                kind: .manualBackup(export)
            )
        }
    }

    private var manualBackupUnavailablePhotoDescription: String {
        let count = viewModel.pendingManualBackupPhotoProposal?.unavailablePhotoCount ?? 0
        return
            "CloudBake found \(count) linked photo\(count == 1 ? "" : "s") that no longer exist\(count == 1 ? "s" : "") in Photos. Continue without \(count == 1 ? "it" : "them"), remove the broken CloudBake references, or cancel. No backup has been saved."
    }

    private func continueDataOperation(_ operation: SettingsDataOperation) {
        switch operation {
        case .importInventory:
            pendingDataOperation = nil
            DispatchQueue.main.async {
                activeFileImport = .inventory
            }
        case .exportInventory:
            let document = viewModel.exportInventoryDocument()
            pendingDataOperation = nil
            if let document {
                presentExporter(document: document, kind: .inventory)
            }
        case .importRecipes:
            pendingDataOperation = nil
            DispatchQueue.main.async {
                activeFileImport = .recipes
            }
        case .exportRecipes:
            let document = viewModel.exportRecipeDocument()
            pendingDataOperation = nil
            if let document {
                presentExporter(document: document, kind: .recipes)
            }
        }
    }

    private func presentExporter(document: InventoryCSVDocument, kind: SettingsExportKind) {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(kind.defaultFilename)
        do {
            try Data(document.text.utf8).write(to: fileURL, options: .atomic)
            activeFileExport = SettingsFileExport(fileURL: fileURL, kind: kind.fileExportKind)
        } catch {
            switch kind {
            case .inventory:
                viewModel.markExportFailed()
            case .recipes:
                viewModel.markRecipeExportFailed()
            }
        }
    }
}

private struct SettingsFileExport: Identifiable {
    let id = UUID()
    let fileURL: URL
    let kind: Kind

    enum Kind {
        case inventory
        case recipes
        case manualBackup(ManualBackupExport)
    }
}

private enum SettingsFileImportKind: String, Identifiable {
    case inventory
    case recipes

    var id: String { rawValue }
}

private enum SettingsExportKind {
    case inventory
    case recipes

    var defaultFilename: String {
        switch self {
        case .inventory:
            return "cloudbake-inventory.csv"
        case .recipes:
            return "cloudbake-recipes.csv"
        }
    }

    var fileExportKind: SettingsFileExport.Kind {
        switch self {
        case .inventory:
            return .inventory
        case .recipes:
            return .recipes
        }
    }
}

private enum SettingsDataOperation: Identifiable {
    case importInventory
    case exportInventory
    case importRecipes
    case exportRecipes

    var id: String {
        switch self {
        case .importInventory:
            return "importInventory"
        case .exportInventory:
            return "exportInventory"
        case .importRecipes:
            return "importRecipes"
        case .exportRecipes:
            return "exportRecipes"
        }
    }

    var title: String {
        switch self {
        case .importInventory:
            return "Import Inventory CSV?"
        case .exportInventory:
            return "Export Inventory CSV?"
        case .importRecipes:
            return "Import Recipe CSV?"
        case .exportRecipes:
            return "Export Recipe CSV?"
        }
    }

    var explanation: String {
        switch self {
        case .importInventory:
            return
                "CloudBake will merge rows by item name and unit. Matching items are updated, and their stock batches are replaced by the CSV rows."
        case .exportInventory:
            return "CloudBake will export active inventory items and stock batches. Archived items are not included."
        case .importRecipes:
            return "CloudBake will create new recipes. Ingredient names must match one active inventory name or alias."
        case .exportRecipes:
            return "CloudBake will export recipe names, notes, and ingredients. The example row is ignored during import."
        }
    }

    var systemImage: String {
        switch self {
        case .importInventory:
            return "square.and.arrow.down"
        case .exportInventory:
            return "square.and.arrow.up"
        case .importRecipes:
            return "square.and.arrow.down"
        case .exportRecipes:
            return "square.and.arrow.up"
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .importInventory:
            return "Choose CSV File"
        case .exportInventory:
            return "Create Export"
        case .importRecipes:
            return "Choose CSV File"
        case .exportRecipes:
            return "Create Export"
        }
    }

    var primaryAccessibilityIdentifier: String {
        switch self {
        case .importInventory:
            return "settings.inventory.import.continue"
        case .exportInventory:
            return "settings.inventory.export.continue"
        case .importRecipes:
            return "settings.recipes.import.continue"
        case .exportRecipes:
            return "settings.recipes.export.continue"
        }
    }
}

private struct CurrencySelectionView: View {
    let selectedCurrency: AppCurrency
    let onSelect: (AppCurrency) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppCurrency.allCases, id: \.rawValue) { currency in
                    Button {
                        onSelect(currency)
                    } label: {
                        HStack {
                            Text(currency.displayName)
                            Spacer()
                            if selectedCurrency == currency {
                                Image(systemName: "checkmark")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(Color.cloudBakePink)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityValue(selectedCurrency == currency ? "Selected" : "")
                    .accessibilityIdentifier("settings.currency.option.\(currency.symbol)")
                }
            }
            .navigationTitle("Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.currency.cancel")
                }
            }
        }
    }
}
