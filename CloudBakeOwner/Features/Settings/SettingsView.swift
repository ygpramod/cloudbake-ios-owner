import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var customLogoImage: UIImage?
    @Published private(set) var isPreparingBackup = false
    @Published private(set) var lastManualBackupDate: Date?
    @Published private(set) var isWeeklyBackupReminderEnabled: Bool
    @Published private(set) var manualBackupReminderStatus: ManualBackupReminderStatus
    @Published private(set) var nextManualBackupReminderDate: Date?

    private let repository: any InventoryItemRepository & InventoryStockBatchRepository
    private let csvService: InventoryCSVService
    private let recipeRepository: (any RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & RecipeCSVImportRepository & InventoryItemRepository)?
    private let recipeCSVService: RecipeCSVService
    private let logoStore: AppLogoStore
    private let manualBackupService: (any ManualBackupPreparing)?
    private let manualBackupPreferences: ManualBackupPreferences
    private let manualBackupReminderScheduler: ManualBackupReminderScheduler

    init(
        repository: any InventoryItemRepository & InventoryStockBatchRepository,
        csvService: InventoryCSVService = InventoryCSVService(),
        recipeRepository: (any RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & RecipeCSVImportRepository & InventoryItemRepository)? = nil,
        recipeCSVService: RecipeCSVService = RecipeCSVService(),
        logoStore: AppLogoStore = AppLogoStore(),
        manualBackupService: (any ManualBackupPreparing)? = nil,
        manualBackupPreferences: ManualBackupPreferences = ManualBackupPreferences(),
        manualBackupReminderScheduler: ManualBackupReminderScheduler? = nil
    ) {
        self.repository = repository
        self.csvService = csvService
        self.recipeRepository = recipeRepository
        self.recipeCSVService = recipeCSVService
        self.logoStore = logoStore
        self.manualBackupService = manualBackupService
        self.manualBackupPreferences = manualBackupPreferences
        self.manualBackupReminderScheduler = manualBackupReminderScheduler
            ?? ManualBackupReminderScheduler(preferences: manualBackupPreferences)
        lastManualBackupDate = manualBackupPreferences.lastSuccessfulExport
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
            let export = try await manualBackupService.prepareBackup()
            statusMessage = "Backup is ready. Choose a safe location to save it."
            errorMessage = nil
            return export
        } catch {
            statusMessage = nil
            errorMessage = "CloudBake could not create a complete backup. No backup was saved."
            return nil
        }
    }

    func markManualBackupExported(at date: Date = Date()) async {
        manualBackupPreferences.recordSuccessfulExport(at: date)
        lastManualBackupDate = date
        statusMessage = "CloudBake backup saved successfully."
        errorMessage = nil
        manualBackupReminderStatus = await manualBackupReminderScheduler.refreshReminder()
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
            manualBackupReminderStatus = await manualBackupReminderScheduler.refreshReminder()
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
}

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @StateObject private var cloudBackupViewModel: CloudBackupSettingsViewModel
    @StateObject private var cloudRestoreViewModel: CloudRestoreSettingsViewModel
    @AppStorage(AppSettings.currencySymbolKey) private var selectedCurrencySymbol = AppCurrency.defaultCurrency.symbol
    @AppStorage(AppSettings.logoRevisionKey) private var logoRevision = 0
    @State private var isSelectingCurrency = false
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var isImportingInventory = false
    @State private var isImportingRecipes = false
    @State private var pendingDataOperation: SettingsDataOperation?
    @State private var isBackupExpanded = false
    @State private var isDataManagementExpanded = false
    @State private var isConfirmingManualBackup = false
    @State private var activeFileExport: SettingsFileExport?

    init(
        viewModel: SettingsViewModel,
        cloudBackupService: (any CloudBackupSettingsServing)? = nil,
        cloudRestoreService: (any CloudRestoreSettingsServing)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
        .accessibilityIdentifier(AppDestination.settings.screenAccessibilityIdentifier)
        .cloudRestorePrompts(viewModel: cloudRestoreViewModel)
        .cloudBakeCenteredPopup(
            isPresented: cloudBackupViewModel.isConfirmingDeletion,
            title: "Delete Cloud Backup?",
            subtitle: "This permanently removes CloudBake's complete recovery backup from the current iCloud account. Your database and photos on this iPhone will not be changed. Cloud backup will be turned off after deletion.",
            systemImage: "trash",
            cancelAccessibilityIdentifier: "settings.cloudBackup.delete.cancel",
            onCancel: { cloudBackupViewModel.cancelCloudBackupDeletion() }
        ) {
            centeredPopupButton("Delete Cloud Backup", role: .destructive) {
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
        .cloudBakeCenteredPopup(
            isPresented: isConfirmingManualBackup,
            title: "Create Full Backup?",
            subtitle: "CloudBake will prepare the complete database, app-managed photos, lightweight recovery copies of linked Photos-library images, and your custom logo. You will choose where to save the package.",
            systemImage: "externaldrive.badge.plus",
            cancelAccessibilityIdentifier: "settings.backup.cancel",
            onCancel: { isConfirmingManualBackup = false }
        ) {
            centeredPopupButton("Create Backup") {
                dismissManualBackupPopupAndPrepare()
            }
            .accessibilityIdentifier("settings.backup.create.continue")
        }
        .cloudBakeCenteredPopup(
            isPresented: pendingDataOperation != nil,
            title: pendingDataOperation?.title ?? "Inventory CSV",
            subtitle: pendingDataOperation?.explanation ?? "",
            systemImage: pendingDataOperation?.systemImage ?? "tablecells",
            cancelAccessibilityIdentifier: "settings.data.cancel",
            onCancel: { pendingDataOperation = nil }
        ) {
            if let pendingDataOperation {
                centeredPopupButton(pendingDataOperation.primaryActionTitle) {
                    continueDataOperation(pendingDataOperation)
                }
                .accessibilityIdentifier(pendingDataOperation.primaryAccessibilityIdentifier)
            }
        }
        .fileImporter(
            isPresented: $isImportingInventory,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result,
                  let url = urls.first else {
                return
            }

            viewModel.importInventoryCSV(from: url)
        }
        .fileImporter(
            isPresented: $isImportingRecipes,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            viewModel.importRecipeCSV(from: url)
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
                        Task { await viewModel.markManualBackupExported() }
                    }
                    backup.removeStagedFiles()
                }
            }
            .interactiveDismissDisabled()
        }
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
        return date.formatted(date: .abbreviated, time: .shortened)
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
        Task {
            guard let export = await viewModel.prepareManualBackup() else { return }
            activeFileExport = SettingsFileExport(
                fileURL: export.packageURL,
                kind: .manualBackup(export)
            )
        }
    }

    private func continueDataOperation(_ operation: SettingsDataOperation) {
        switch operation {
        case .importInventory:
            pendingDataOperation = nil
            isImportingInventory = true
        case .exportInventory:
            let document = viewModel.exportInventoryDocument()
            pendingDataOperation = nil
            if let document {
                presentExporter(document: document, kind: .inventory)
            }
        case .importRecipes:
            pendingDataOperation = nil
            isImportingRecipes = true
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
            return "CloudBake will merge rows by item name and unit. Matching items are updated, and their stock batches are replaced by the CSV rows."
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
