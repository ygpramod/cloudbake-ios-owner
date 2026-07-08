import SwiftUI

struct InventoryItemForm: View {
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
        .cloudBakeFormScreenStyle()
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
