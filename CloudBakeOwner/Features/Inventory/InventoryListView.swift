import SwiftUI

struct InventoryListView: View {
    @StateObject private var viewModel: InventoryListViewModel
    @State private var isAddingItem = false
    @State private var isEditingItem = false
    @State private var isShowingArchivedItems = false
    @State private var isAdjustingStock = false
    @State private var isConsumingStock = false
    @State private var isShowingHistory = false

    init(viewModel: InventoryListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "No inventory yet",
                    systemImage: "shippingbox",
                    description: Text("Add ingredients and supplies as you stock the kitchen.")
                )
            } else {
                Section("Items") {
                    ForEach(viewModel.items, id: \.id) { item in
                        Button {
                            viewModel.beginEditing(item)
                            isEditingItem = true
                        } label: {
                            InventoryItemRow(item: item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("inventory.item.edit.\(item.id)")
                        .swipeActions(edge: .leading) {
                            Button {
                                viewModel.beginViewingHistory(item)
                                isShowingHistory = true
                            } label: {
                                Label("History", systemImage: "clock")
                            }
                            .tint(.purple)
                            .accessibilityIdentifier("inventory.item.history.\(item.id)")

                            Button {
                                viewModel.beginConsuming(item)
                                isConsumingStock = true
                            } label: {
                                Label("Use", systemImage: "minus")
                            }
                            .tint(.orange)
                            .accessibilityIdentifier("inventory.item.consume.\(item.id)")

                            Button {
                                viewModel.beginAdjusting(item)
                                isAdjustingStock = true
                            } label: {
                                Label("Adjust", systemImage: "plusminus")
                            }
                            .tint(.blue)
                            .accessibilityIdentifier("inventory.item.adjust.\(item.id)")
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.archiveItem(item)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .accessibilityIdentifier("inventory.item.archive.\(item.id)")
                        }
                    }
                }
            }
        }
        .navigationTitle("Inventory")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isShowingArchivedItems = true
                } label: {
                    Label("Archived inventory", systemImage: "archivebox")
                }
                .accessibilityIdentifier("inventory.archived")

                Button {
                    isAddingItem = true
                } label: {
                    Label("Add inventory item", systemImage: "plus")
                }
                .accessibilityIdentifier("inventory.add")
            }
        }
        .sheet(isPresented: $isAddingItem) {
            NavigationStack {
                InventoryItemForm(
                    title: "Add Item",
                    viewModel: viewModel,
                    isPresented: $isAddingItem,
                    onCancel: {},
                    onSave: viewModel.addItem
                )
            }
        }
        .sheet(isPresented: $isEditingItem) {
            NavigationStack {
                InventoryItemForm(
                    title: "Edit Item",
                    viewModel: viewModel,
                    isPresented: $isEditingItem,
                    onCancel: viewModel.cancelEditing,
                    onSave: viewModel.saveEditedItem
                )
            }
        }
        .sheet(isPresented: $isShowingArchivedItems) {
            NavigationStack {
                ArchivedInventoryView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $isAdjustingStock) {
            NavigationStack {
                InventoryStockAdjustmentForm(
                    viewModel: viewModel,
                    isPresented: $isAdjustingStock
                )
            }
        }
        .sheet(isPresented: $isConsumingStock) {
            NavigationStack {
                InventoryStockConsumptionForm(
                    viewModel: viewModel,
                    isPresented: $isConsumingStock
                )
            }
        }
        .sheet(isPresented: $isShowingHistory) {
            NavigationStack {
                InventoryHistoryView(
                    viewModel: viewModel,
                    isPresented: $isShowingHistory
                )
            }
        }
        .onAppear {
            viewModel.load()
        }
        .accessibilityIdentifier(AppDestination.inventory.screenAccessibilityIdentifier)
    }
}

private struct InventoryHistoryView: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        List {
            if let item = viewModel.historyItem {
                Section("Item") {
                    LabeledContent("Name", value: item.name)
                    LabeledContent("Current", value: "\(item.currentQuantity.formatted()) \(item.unit.displayName)")
                }

                if viewModel.historyTransactions.isEmpty {
                    ContentUnavailableView(
                        "No stock history",
                        systemImage: "clock",
                        description: Text("Adjustments and stock usage will appear here.")
                    )
                } else {
                    Section("Stock Changes") {
                        ForEach(viewModel.historyTransactions, id: \.id) { transaction in
                            InventoryTransactionRow(transaction: transaction, unit: item.unit)
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("inventory.history.error")
                }
            }
        }
        .navigationTitle("Stock History")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    viewModel.closeHistory()
                    isPresented = false
                }
                .accessibilityIdentifier("inventory.history.done")
            }
        }
        .accessibilityIdentifier("inventory.history.screen")
    }
}

private struct InventoryTransactionRow: View {
    let transaction: InventoryTransaction
    let unit: InventoryUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(transaction.displayTitle, systemImage: transaction.systemImageName)
                    .font(.headline)

                Spacer()

                Text(transaction.signedQuantityText(unit: unit))
                    .font(.headline)
                    .foregroundStyle(transaction.quantityColor)
            }

            Text(transaction.occurredAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let note = transaction.note {
                Text(note)
                    .font(.subheadline)
            }
        }
        .accessibilityIdentifier("inventory.history.transaction.\(transaction.id)")
    }
}

private struct InventoryStockConsumptionForm: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            Section("Stock") {
                if let item = viewModel.consumingItem {
                    LabeledContent("Item", value: item.name)
                    LabeledContent("Current", value: "\(item.currentQuantity.formatted()) \(item.unit.displayName)")
                }

                TextField("Quantity used", text: $viewModel.draftConsumptionQuantity)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("inventory.consume.quantity")

                TextField("Note", text: $viewModel.draftConsumptionNote)
                    .accessibilityIdentifier("inventory.consume.note")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("inventory.consume.error")
                }
            }
        }
        .navigationTitle("Use Stock")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelStockConsumption()
                    isPresented = false
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.recordStockConsumption() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("inventory.consume.save")
            }
        }
    }
}

private struct InventoryStockAdjustmentForm: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            Section("Stock") {
                if let item = viewModel.adjustingItem {
                    LabeledContent("Item", value: item.name)
                    LabeledContent("Current", value: "\(item.currentQuantity.formatted()) \(item.unit.displayName)")
                }

                TextField("Quantity to add", text: $viewModel.draftAdjustmentQuantity)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("inventory.adjust.quantity")

                TextField("Note", text: $viewModel.draftAdjustmentNote)
                    .accessibilityIdentifier("inventory.adjust.note")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("inventory.adjust.error")
                }
            }
        }
        .navigationTitle("Adjust Stock")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelStockAdjustment()
                    isPresented = false
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.recordStockAdjustment() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("inventory.adjust.save")
            }
        }
    }
}

private struct ArchivedInventoryView: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if viewModel.archivedItems.isEmpty {
                ContentUnavailableView(
                    "No archived inventory",
                    systemImage: "archivebox",
                    description: Text("Archived ingredients and supplies will appear here.")
                )
            } else {
                Section("Archived Items") {
                    ForEach(viewModel.archivedItems, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            InventoryItemRow(item: item)

                            if let archivedAt = item.archivedAt {
                                Text("Archived \(archivedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                viewModel.restoreItem(item)
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                            .accessibilityIdentifier("inventory.archived.restore.\(item.id)")
                        }
                        .accessibilityIdentifier("inventory.archived.item.\(item.id)")
                    }
                }
            }
        }
        .navigationTitle("Archived")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .accessibilityIdentifier("inventory.archived.done")
            }
        }
        .onAppear {
            viewModel.loadArchivedItems()
        }
        .accessibilityIdentifier("inventory.archived.screen")
    }
}

private struct InventoryItemRow: View {
    let item: InventoryItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text("Current quantity: \(item.currentQuantity.formatted()) \(item.unit.displayName)")
                    .font(.subheadline)
                Text("Minimum quantity: \(item.minimumQuantity.formatted()) \(item.unit.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if item.isLowStock {
                Label("Low stock", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("inventory.item.lowStock.\(item.id)")
            }
        }
        .accessibilityIdentifier("inventory.item.\(item.id)")
    }
}

private struct InventoryItemForm: View {
    let title: String
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool
    let onCancel: () -> Void
    let onSave: () -> Bool

    var body: some View {
        Form {
            Section("Item") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Name", text: $viewModel.draftName)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("inventory.form.name")
                }

                Picker("Unit", selection: $viewModel.draftUnit) {
                    ForEach(InventoryUnit.inventoryInputCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .accessibilityIdentifier("inventory.form.unit")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Current quantity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Current quantity", text: $viewModel.draftCurrentQuantity)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("inventory.form.currentQuantity")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Minimum quantity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Minimum quantity", text: $viewModel.draftMinimumQuantity)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("inventory.form.minimumQuantity")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("inventory.form.error")
                }
            }

            if let duplicateWarningMessage = viewModel.duplicateWarningMessage {
                Section {
                    Label(duplicateWarningMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("inventory.form.duplicateWarning")
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    isPresented = false
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if onSave() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("inventory.form.save")
            }
        }
    }
}

extension InventoryUnit {
    static let inventoryInputCases: [InventoryUnit] = [
        .kilogram,
        .gram,
        .milliliter,
        .teaspoon,
        .tablespoon,
        .cup,
        .each
    ]

    var displayName: String {
        switch self {
        case .kilogram: "kg"
        case .gram: "g"
        case .milliliter: "ml"
        case .teaspoon: "tsp"
        case .tablespoon: "tbsp"
        case .cup: "cup"
        case .each: "each"
        }
    }
}

private extension InventoryTransaction {
    var displayTitle: String {
        switch kind {
        case .adjustment: "Adjustment"
        case .purchase: "Purchase"
        case .consumption: "Used"
        }
    }

    var systemImageName: String {
        switch kind {
        case .adjustment, .purchase: "plus.circle"
        case .consumption: "minus.circle"
        }
    }

    var quantityColor: Color {
        switch kind {
        case .adjustment, .purchase: .green
        case .consumption: .orange
        }
    }

    func signedQuantityText(unit: InventoryUnit) -> String {
        let sign: String
        switch kind {
        case .adjustment, .purchase:
            sign = "+"
        case .consumption:
            sign = "-"
        }

        return "\(sign)\(quantity.formatted()) \(unit.displayName)"
    }
}

#Preview {
    NavigationStack {
        InventoryListView(
            viewModel: InventoryListViewModel(
                repository: PreviewInventoryItemRepository()
            )
        )
    }
}

private final class PreviewInventoryItemRepository: InventoryItemRepository, InventoryTransactionRepository {
    private var items: [InventoryItem] = [
        InventoryItem(
            id: "preview-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
    private var transactions: [InventoryTransaction] = []

    func save(_ item: InventoryItem) throws {
        if let existingIndex = items.firstIndex(where: { $0.id == item.id }) {
            items[existingIndex] = item
        } else {
            items.append(item)
        }
    }

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        items.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        items.filter { !$0.isArchived }
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        items.filter(\.isArchived)
    }

    func save(_ transaction: InventoryTransaction) throws {
        if let existingIndex = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[existingIndex] = transaction
        } else {
            transactions.append(transaction)
        }
    }

    func fetchInventoryTransaction(id: String) throws -> InventoryTransaction? {
        transactions.first { $0.id == id }
    }

    func fetchInventoryTransactions(inventoryItemId: String) throws -> [InventoryTransaction] {
        transactions
            .filter { $0.inventoryItemId == inventoryItemId }
            .sorted {
                if $0.occurredAt == $1.occurredAt {
                    return $0.createdAt > $1.createdAt
                }

                return $0.occurredAt > $1.occurredAt
            }
    }
}
