import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?

    private let repository: any InventoryItemRepository & InventoryStockBatchRepository
    private let csvService: InventoryCSVService

    init(
        repository: any InventoryItemRepository & InventoryStockBatchRepository,
        csvService: InventoryCSVService = InventoryCSVService()
    ) {
        self.repository = repository
        self.csvService = csvService
    }

    func exportInventoryDocument() -> InventoryCSVDocument? {
        do {
            let text = try csvService.exportCSV(repository: repository)
            statusMessage = "Inventory export is ready."
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
            statusMessage = "Imported \(summary.importedItemCount) inventory items."
            errorMessage = nil
        } catch {
            statusMessage = nil
            errorMessage = "Inventory CSV could not be imported."
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @AppStorage(AppSettings.currencySymbolKey) private var selectedCurrencySymbol = AppCurrency.defaultCurrency.symbol
    @State private var isImportingInventory = false
    @State private var isExportingInventory = false
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
                    Picker("Currency", selection: $selectedCurrencySymbol) {
                        ForEach(AppCurrency.allCases, id: \.rawValue) { currency in
                            Text(currency.displayName).tag(currency.symbol)
                        }
                    }
                    .accessibilityIdentifier("settings.currency")
                    .padding(.vertical, 8)
                }
            }

            CloudBakeSection("Inventory Data") {
                CloudBakeDetailCard {
                    settingsAction(
                        title: "Import Inventory CSV",
                        detail: "Create or update inventory from a CSV file.",
                        systemImage: "square.and.arrow.down",
                        accessibilityIdentifier: "settings.inventory.import"
                    ) {
                        isImportingInventory = true
                    }

                    CloudBakeDetailDivider()

                    settingsAction(
                        title: "Export Inventory CSV",
                        detail: "Save active inventory and stock batches to a CSV file.",
                        systemImage: "square.and.arrow.up",
                        accessibilityIdentifier: "settings.inventory.export"
                    ) {
                        if let document = viewModel.exportInventoryDocument() {
                            exportDocument = document
                            isExportingInventory = true
                        }
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
        ) { _ in }
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
}
