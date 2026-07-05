import SwiftUI
import UIKit

struct InventoryListView: View {
    @StateObject private var viewModel: InventoryListViewModel
    @State private var isAddingItem = false
    @State private var isViewingItem = false
    @State private var isShowingArchivedItems = false
    @State private var isAdjustingStock = false
    @State private var isConsumingStock = false
    @State private var isShowingHistory = false
    @State private var isImportingPurchaseBill = false

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
                            viewModel.beginViewingItem(item)
                            isViewingItem = true
                        } label: {
                            InventoryItemRow(item: item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("inventory.item.view.\(item.id)")
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
                    isImportingPurchaseBill = true
                } label: {
                    Label("Import purchase bill", systemImage: "doc.text.viewfinder")
                }
                .accessibilityIdentifier("inventory.purchaseBill.import")

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
                    showsUnit: true,
                    showsCurrentQuantity: true,
                    showsExpiryDate: true,
                    onCancel: {},
                    onSave: viewModel.addItem
                )
            }
        }
        .sheet(isPresented: $isViewingItem) {
            NavigationStack {
                InventoryItemDetailView(
                    viewModel: viewModel,
                    isPresented: $isViewingItem
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
        .sheet(
            isPresented: $isImportingPurchaseBill,
            onDismiss: viewModel.cancelPurchaseBillImport
        ) {
            NavigationStack {
                PurchaseBillImportView(
                    viewModel: viewModel,
                    isPresented: $isImportingPurchaseBill
                )
            }
        }
        .onAppear {
            viewModel.load()
        }
        .accessibilityIdentifier(AppDestination.inventory.screenAccessibilityIdentifier)
    }
}

private struct PurchaseBillImportView: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingCamera = false
    @State private var hasOfferedCamera = false

    private let recognizer: PurchaseBillTextRecognizing
    private let catalogProvider: () -> [BakingCatalogItem]

    init(
        viewModel: InventoryListViewModel,
        isPresented: Binding<Bool>,
        recognizer: PurchaseBillTextRecognizing = VisionPurchaseBillTextRecognizer(),
        catalogProvider: @escaping () -> [BakingCatalogItem] = { (try? BakingCatalog.loadBundledCatalog()) ?? [] }
    ) {
        self.viewModel = viewModel
        _isPresented = isPresented
        self.recognizer = recognizer
        self.catalogProvider = catalogProvider
    }

    var body: some View {
        Form {
            Section("Bill Photo") {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Take Bill Photo", systemImage: "camera")
                }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera) || viewModel.isRecognizingPurchaseBill)
                .accessibilityIdentifier("inventory.purchaseBill.camera")

                if viewModel.isRecognizingPurchaseBill {
                    ProgressView("Reading bill")
                        .accessibilityIdentifier("inventory.purchaseBill.recognizing")
                }
            }

            Section("Bill Text") {
                TextField("Bill Text", text: $viewModel.purchaseBillRecognizedText, axis: .vertical)
                    .lineLimit(4...8)
                    .accessibilityIdentifier("inventory.purchaseBill.text")

                Button {
                    _ = viewModel.createPurchaseBillDrafts(catalog: catalogProvider())
                } label: {
                    Label("Create Drafts", systemImage: "wand.and.stars")
                }
                .disabled(viewModel.isRecognizingPurchaseBill)
                .accessibilityIdentifier("inventory.purchaseBill.createDrafts")
            }

            if !viewModel.purchaseBillDrafts.isEmpty {
                Section("Draft Items") {
                    ForEach($viewModel.purchaseBillDrafts) { $draft in
                        PurchaseBillDraftRow(draft: $draft)
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("inventory.purchaseBill.error")
                }
            }
        }
        .navigationTitle("Import Bill")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelPurchaseBillImport()
                    isPresented = false
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.savePurchaseBillDrafts() {
                        isPresented = false
                        dismiss()
                    }
                }
                .disabled(viewModel.purchaseBillDrafts.isEmpty)
                .accessibilityIdentifier("inventory.purchaseBill.save")
            }
        }
        .onAppear {
            guard UIImagePickerController.isSourceTypeAvailable(.camera), !hasOfferedCamera else {
                return
            }
            hasOfferedCamera = true
            isShowingCamera = true
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            PurchaseBillCameraView { image in
                guard let cgImage = image.cgImage else {
                    viewModel.errorMessage = "The bill photo could not be read. Try another photo or enter the bill text manually."
                    return
                }

                Task {
                    _ = await viewModel.recognizePurchaseBillImage(
                        cgImage,
                        recognizer: recognizer,
                        catalog: catalogProvider()
                    )
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct PurchaseBillCameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImageCaptured: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onImageCaptured: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageCaptured = onImageCaptured
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer {
                dismiss()
            }

            guard let image = info[.originalImage] as? UIImage else {
                return
            }
            onImageCaptured(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

private struct PurchaseBillDraftRow: View {
    @Binding var draft: PurchaseBillInventoryDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $draft.isSelected) {
                Text(draft.sourceLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("inventory.purchaseBill.draft.selected.\(draft.id)")

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Name", text: $draft.name)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("inventory.purchaseBill.draft.name.\(draft.id)")
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Quantity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Current Quantity", text: $draft.quantityText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("inventory.purchaseBill.draft.quantity.\(draft.id)")
                }

                Picker("Unit", selection: $draft.unit) {
                    ForEach(InventoryUnit.inventoryInputCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .accessibilityIdentifier("inventory.purchaseBill.draft.unit.\(draft.id)")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Minimum Quantity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Minimum Quantity", text: $draft.minimumQuantityText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("inventory.purchaseBill.draft.minimum.\(draft.id)")
            }

            DatePicker(
                "Expiry Date",
                selection: $draft.expiryDate,
                displayedComponents: .date
            )
            .accessibilityIdentifier("inventory.purchaseBill.draft.expiry.\(draft.id)")
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("inventory.purchaseBill.draft.\(draft.id)")
    }
}

private struct InventoryItemDetailView: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool
    @State private var isEditingItem = false
    @State private var isEditingBatchExpiry = false

    var body: some View {
        List {
            if let item = viewModel.selectedItem {
                Section("Item") {
                    LabeledContent("Name", value: item.name)
                    LabeledContent("Unit", value: item.unit.displayName)
                    LabeledContent("Current Quantity", value: "\(item.currentQuantity.formatted()) \(item.unit.displayName)")
                    LabeledContent("Minimum Quantity", value: "\(item.minimumQuantity.formatted()) \(item.unit.displayName)")
                }

                Section("Expiry") {
                    if viewModel.selectedItemBatches.filter({ $0.remainingQuantity > 0 }).isEmpty {
                        ContentUnavailableView(
                            "No stock batches",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Stock added with expiry dates will appear here.")
                        )
                    } else {
                        HStack {
                            Text("Quantity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Expiry")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(viewModel.selectedItemBatches.filter { $0.remainingQuantity > 0 }, id: \.id) { batch in
                            Button {
                                viewModel.beginEditingBatchExpiry(batch)
                                isEditingBatchExpiry = true
                            } label: {
                                HStack {
                                    Text("\(batch.remainingQuantity.formatted()) \(item.unit.displayName)")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(batch.expiryDisplayText)
                                        .foregroundStyle(batch.expiryColor)
                                    Image(systemName: "calendar")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier("inventory.detail.batch.edit.\(batch.id)")
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("inventory.detail.error")
                    }
                }
            }
        }
        .navigationTitle("Inventory Item")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    viewModel.closeSelectedItem()
                    isPresented = false
                }
                .accessibilityIdentifier("inventory.detail.done")
            }

            ToolbarItem(placement: .confirmationAction) {
                if let item = viewModel.selectedItem {
                    Button("Edit") {
                        viewModel.beginEditing(item)
                        isEditingItem = true
                    }
                    .accessibilityIdentifier("inventory.detail.edit")
                }
            }
        }
        .sheet(isPresented: $isEditingItem) {
            NavigationStack {
                InventoryItemForm(
                    title: "Edit Item",
                    viewModel: viewModel,
                    isPresented: $isEditingItem,
                    showsUnit: false,
                    showsCurrentQuantity: false,
                    showsExpiryDate: false,
                    onCancel: viewModel.cancelEditing,
                    onSave: viewModel.saveEditedItem
                )
            }
        }
        .sheet(isPresented: $isEditingBatchExpiry) {
            NavigationStack {
                InventoryBatchExpiryForm(
                    viewModel: viewModel,
                    isPresented: $isEditingBatchExpiry
                )
            }
        }
        .onAppear {
            viewModel.loadSelectedItemBatches()
        }
        .accessibilityIdentifier("inventory.detail.screen")
    }
}

private struct InventoryBatchExpiryForm: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            if let item = viewModel.selectedItem,
               let batch = viewModel.editingBatch {
                Section("Stock Batch") {
                    LabeledContent("Item", value: item.name)
                    LabeledContent("Quantity", value: "\(batch.remainingQuantity.formatted()) \(item.unit.displayName)")
                    DatePicker(
                        "Expiry Date",
                        selection: $viewModel.draftBatchExpiryDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("inventory.batchExpiry.expiryDate")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("inventory.batchExpiry.error")
                }
            }
        }
        .navigationTitle("Edit Expiry")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelEditingBatchExpiry()
                    isPresented = false
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.saveEditedBatchExpiry() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("inventory.batchExpiry.save")
            }
        }
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

                if let item = viewModel.consumingItem {
                    Picker("Unit", selection: $viewModel.draftConsumptionUnit) {
                        ForEach(item.unit.compatibleUnits, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .accessibilityIdentifier("inventory.consume.unit")
                }

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

                if let item = viewModel.adjustingItem {
                    Picker("Unit", selection: $viewModel.draftAdjustmentUnit) {
                        ForEach(item.unit.compatibleUnits, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .accessibilityIdentifier("inventory.adjust.unit")
                }

                DatePicker(
                    "Expiry Date",
                    selection: $viewModel.draftAdjustmentExpiryDate,
                    displayedComponents: .date
                )
                .accessibilityIdentifier("inventory.adjust.expiryDate")

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
                Text("Current Quantity: \(item.currentQuantity.formatted()) \(item.unit.displayName)")
                    .font(.subheadline)
                Text("Minimum Quantity: \(item.minimumQuantity.formatted()) \(item.unit.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let earliestExpiryAt = item.earliestExpiryAt {
                    Text("Expires: \(earliestExpiryAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(item.expiryColor)
                }
            }

            Spacer()

            if item.isLowStock {
                Label(item.lowStockLabel, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(item.alertColor)
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
    let showsUnit: Bool
    let showsCurrentQuantity: Bool
    let showsExpiryDate: Bool
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

                if showsUnit {
                    Picker("Unit", selection: $viewModel.draftUnit) {
                        ForEach(InventoryUnit.inventoryInputCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .accessibilityIdentifier("inventory.form.unit")
                }

                if showsCurrentQuantity {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Quantity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Current Quantity", text: $viewModel.draftCurrentQuantity)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("inventory.form.currentQuantity")
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Minimum Quantity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Minimum Quantity", text: $viewModel.draftMinimumQuantity)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("inventory.form.minimumQuantity")
                }

                if showsExpiryDate {
                    DatePicker(
                        "Expiry Date",
                        selection: $viewModel.draftExpiryDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("inventory.form.expiryDate")
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
        .liter,
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
        case .liter: "L"
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

private extension InventoryStockBatch {
    var expiryDisplayText: String {
        guard let expiresAt else {
            return "No expiry"
        }

        return expiresAt.formatted(date: .abbreviated, time: .omitted)
    }

    var isExpired: Bool {
        guard let expiresAt else {
            return false
        }

        return expiresAt < Date()
    }

    var isExpiringSoon: Bool {
        guard let expiresAt else {
            return false
        }

        let now = Date()
        let threshold = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now.addingTimeInterval(30 * 24 * 60 * 60)
        return expiresAt >= now && expiresAt <= threshold
    }

    var expiryColor: Color {
        if isExpired {
            return .red
        }

        if isExpiringSoon {
            return .orange
        }

        return .primary
    }
}

private extension InventoryItem {
    var lowStockLabel: String {
        if hasExpiredStock {
            return "Expired stock"
        }

        if hasExpiringSoonStock {
            return "Expiring soon"
        }

        return "Low stock"
    }

    var alertColor: Color {
        hasExpiringSoonStock && !hasExpiredStock ? .orange : .red
    }

    var expiryColor: Color {
        if hasExpiredStock {
            return .red
        }

        if hasExpiringSoonStock {
            return .orange
        }

        return .secondary
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

private final class PreviewInventoryItemRepository: InventoryItemRepository, InventoryTransactionRepository, InventoryStockBatchRepository {
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
    private var batches: [InventoryStockBatch] = []

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

    func save(_ batch: InventoryStockBatch) throws {
        if let existingIndex = batches.firstIndex(where: { $0.id == batch.id }) {
            batches[existingIndex] = batch
        } else {
            batches.append(batch)
        }
    }

    func fetchInventoryStockBatches(inventoryItemId: String) throws -> [InventoryStockBatch] {
        batches
            .filter { $0.inventoryItemId == inventoryItemId }
            .sorted {
                switch ($0.expiresAt, $1.expiresAt) {
                case let (.some(left), .some(right)):
                    if left == right {
                        return $0.createdAt < $1.createdAt
                    }

                    return left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return $0.createdAt < $1.createdAt
                }
            }
    }
}
