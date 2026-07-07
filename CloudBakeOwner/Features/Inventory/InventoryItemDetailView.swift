import SwiftUI

struct InventoryItemDetailView: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool
    @State private var isEditingItem = false
    @State private var isEditingBatch = false
    @State private var isAdjustingStock = false
    @State private var isConsumingStock = false
    @State private var isShowingHistory = false

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
                                viewModel.beginEditingBatch(batch)
                                isEditingBatch = true
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
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("inventory.detail.batch.edit.\(batch.id)")
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteBatch(batch)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityIdentifier("inventory.detail.batch.delete.\(batch.id)")
                            }
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

            ToolbarItemGroup(placement: .topBarTrailing) {
                if let item = viewModel.selectedItem {
                    Button {
                        viewModel.beginEditing(item)
                        isEditingItem = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("inventory.detail.edit")

                    Menu {
                        Button {
                            viewModel.beginAdjusting(item)
                            isAdjustingStock = true
                        } label: {
                            Label("Adjust Stock", systemImage: "plusminus")
                        }
                        .accessibilityIdentifier("inventory.detail.adjust")

                        Button {
                            viewModel.beginConsuming(item)
                            isConsumingStock = true
                        } label: {
                            Label("Use Stock", systemImage: "minus")
                        }
                        .accessibilityIdentifier("inventory.detail.consume")

                        Button {
                            viewModel.beginViewingHistory(item)
                            isShowingHistory = true
                        } label: {
                            Label("View History", systemImage: "clock")
                        }
                        .accessibilityIdentifier("inventory.detail.history")
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("inventory.detail.more")
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
        .sheet(isPresented: $isEditingBatch) {
            NavigationStack {
                InventoryBatchForm(
                    viewModel: viewModel,
                    isPresented: $isEditingBatch
                )
            }
        }
        .onAppear {
            viewModel.loadSelectedItemBatches()
        }
        .accessibilityIdentifier("inventory.detail.screen")
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
