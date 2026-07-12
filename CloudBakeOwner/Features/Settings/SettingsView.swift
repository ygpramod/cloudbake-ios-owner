import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?

    private let repository: any InventoryItemRepository & InventoryStockBatchRepository
    private let csvService: InventoryCSVService
    private let recipeRepository: (any RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & InventoryItemRepository)?
    private let recipeCSVService: RecipeCSVService

    init(
        repository: any InventoryItemRepository & InventoryStockBatchRepository,
        csvService: InventoryCSVService = InventoryCSVService(),
        recipeRepository: (any RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & InventoryItemRepository)? = nil,
        recipeCSVService: RecipeCSVService = RecipeCSVService()
    ) {
        self.repository = repository
        self.csvService = csvService
        self.recipeRepository = recipeRepository
        self.recipeCSVService = recipeCSVService
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
    @AppStorage(AppSettings.currencySymbolKey) private var selectedCurrencySymbol = AppCurrency.defaultCurrency.symbol
    @State private var isSelectingCurrency = false
    @State private var isImportingInventory = false
    @State private var isExportingInventory = false
    @State private var isImportingRecipes = false
    @State private var isExportingRecipes = false
    @State private var pendingDataOperation: SettingsDataOperation?
    @State private var exportDocument = InventoryCSVDocument()

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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

            CloudBakeSection("Data Management") {
                CloudBakeDetailCard {
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
        .sheet(isPresented: $isSelectingCurrency) {
            CurrencySelectionView(
                selectedCurrency: selectedCurrency,
                onSelect: { currency in
                    selectedCurrencySymbol = currency.symbol
                    isSelectingCurrency = false
                }
            )
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
        .fileExporter(
            isPresented: $isExportingInventory,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "cloudbake-inventory.csv"
        ) { result in
            if case .failure = result {
                viewModel.markExportFailed()
            }
        }
        .fileImporter(
            isPresented: $isImportingRecipes,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            viewModel.importRecipeCSV(from: url)
        }
        .fileExporter(
            isPresented: $isExportingRecipes,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "cloudbake-recipes.csv"
        ) { result in
            if case .failure = result { viewModel.markRecipeExportFailed() }
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

    private func continueDataOperation(_ operation: SettingsDataOperation) {
        pendingDataOperation = nil
        switch operation {
        case .importInventory:
            isImportingInventory = true
        case .exportInventory:
            if let document = viewModel.exportInventoryDocument() {
                exportDocument = document
                isExportingInventory = true
            }
        case .importRecipes:
            isImportingRecipes = true
        case .exportRecipes:
            if let document = viewModel.exportRecipeDocument() {
                exportDocument = document
                isExportingRecipes = true
            }
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
