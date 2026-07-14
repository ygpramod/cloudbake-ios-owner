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

                VStack(alignment: .leading, spacing: 6) {
                    Text("Aliases")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Aliases", text: $viewModel.draftAliases, axis: .vertical)
                        .textInputAutocapitalization(.words)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("inventory.form.aliases")
                    Text("Separate bill names with commas or new lines.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Type", selection: $viewModel.draftType) {
                    ForEach(InventoryItemType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .accessibilityIdentifier("inventory.form.type")
                .onChange(of: viewModel.draftType) { _, newType in
                    viewModel.selectDraftType(newType)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Default Expiry (Days)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(
                        "Default Expiry (Days)",
                        text: $viewModel.draftDefaultExpiryDays,
                        prompt: Text("Use type default")
                    )
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Default Expiry (Days)")
                        .accessibilityIdentifier("inventory.form.defaultExpiryDays")
                        .onChange(of: viewModel.draftDefaultExpiryDays) { _, _ in
                            viewModel.updateDraftExpiryFromDefault()
                        }
                    Text("Leave blank to use the inventory type default. You can still change or remove a batch expiry before saving stock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $viewModel.draftAmount)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("inventory.form.amount")
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
                    Toggle("Has Expiry Date", isOn: $viewModel.draftHasExpiryDate)
                        .accessibilityIdentifier("inventory.form.hasExpiryDate")

                    if viewModel.draftHasExpiryDate {
                        DatePicker(
                            "Expiry Date",
                            selection: $viewModel.draftExpiryDate,
                            displayedComponents: .date
                        )
                        .accessibilityIdentifier("inventory.form.expiryDate")
                    }
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
        .accessibilityIdentifier("inventory.form.scroll")
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
                .disabled(!viewModel.canSubmitItemDraft(requiresCurrentQuantity: showsCurrentQuantity))
                .accessibilityIdentifier("inventory.form.save")
            }
        }
    }
}
