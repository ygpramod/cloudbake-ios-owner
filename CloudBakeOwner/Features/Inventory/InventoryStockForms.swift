import SwiftUI

struct InventoryBatchForm: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            if let item = viewModel.selectedItem,
               viewModel.editingBatch != nil {
                Section("Stock Batch") {
                    LabeledContent("Item", value: item.name)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quantity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("Quantity", text: $viewModel.draftBatchQuantity)
                                .keyboardType(.decimalPad)
                                .accessibilityIdentifier("inventory.batch.quantity")
                            Text(item.unit.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    DatePicker(
                        "Expiry Date",
                        selection: $viewModel.draftBatchExpiryDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("inventory.batch.expiryDate")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $viewModel.draftBatchAmount)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("inventory.batch.amount")
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("inventory.batch.error")
                }
            }
        }
        .cloudBakeFormScreenStyle()
        .navigationTitle("Edit Batch")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelEditingBatch()
                    isPresented = false
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.saveEditedBatch() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("inventory.batch.save")
            }
        }
    }
}

struct InventoryStockConsumptionForm: View {
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
        .cloudBakeFormScreenStyle()
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

struct InventoryStockAdjustmentForm: View {
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

                TextField("Amount", text: $viewModel.draftAdjustmentAmount)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("inventory.adjust.amount")

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
        .cloudBakeFormScreenStyle()
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
