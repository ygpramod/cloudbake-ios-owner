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
        CloudBakeDetailScaffold(
            title: viewModel.selectedItem?.name ?? "Inventory Item",
            backAccessibilityIdentifier: "inventory.detail.done",
            primaryAction: CloudBakeDetailAction(
                title: "Edit",
                systemImage: "pencil",
                accessibilityIdentifier: "inventory.detail.edit",
                action: {
                    if let item = viewModel.selectedItem {
                        viewModel.beginEditing(item)
                        isEditingItem = true
                    }
                }
            ),
            onBack: {
                viewModel.closeSelectedItem()
                isPresented = false
            }
        ) {
            if let item = viewModel.selectedItem {
                CloudBakeHeroCard(systemImage: "shippingbox", tint: .cloudBakeOrange) {
                    Text("Inventory Item")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.cloudBakeOrange)

                    Text(item.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("\(item.currentQuantity.formatted()) \(item.unit.displayName) in stock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    CloudBakeInlineActionButton(
                        title: "Adjust",
                        systemImage: "plusminus",
                        tint: .cloudBakePurple,
                        accessibilityIdentifier: "inventory.detail.adjust"
                    ) {
                        viewModel.beginAdjusting(item)
                        isAdjustingStock = true
                    }

                    CloudBakeInlineActionButton(
                        title: "Use",
                        systemImage: "minus",
                        tint: .cloudBakeOrange,
                        accessibilityIdentifier: "inventory.detail.consume"
                    ) {
                        viewModel.beginConsuming(item)
                        isConsumingStock = true
                    }

                    CloudBakeInlineActionButton(
                        title: "History",
                        systemImage: "clock",
                        tint: .cloudBakeTeal,
                        accessibilityIdentifier: "inventory.detail.history"
                    ) {
                        viewModel.beginViewingHistory(item)
                        isShowingHistory = true
                    }
                }

                CloudBakeSection("Item") {
                    CloudBakeDetailCard {
                        CloudBakeDetailRow("Name") {
                            Text(item.name)
                        }
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Unit") {
                            Text(item.unit.displayName)
                        }
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Current Quantity") {
                            Text("\(item.currentQuantity.formatted()) \(item.unit.displayName)")
                        }
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Minimum Quantity") {
                            Text("\(item.minimumQuantity.formatted()) \(item.unit.displayName)")
                        }
                    }
                }

                CloudBakeSection("Expiry") {
                    CloudBakeDetailCard {
                        let activeBatches = viewModel.selectedItemBatches.filter { $0.remainingQuantity > 0 }
                        if activeBatches.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Color.cloudBakePink)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(Color.cloudBakePink.opacity(0.10)))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("No stock batches")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Stock added with expiry dates will appear here.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 14)
                        } else {
                            HStack {
                                Text("Quantity")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Expiry")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)

                            ForEach(activeBatches, id: \.id) { batch in
                                CloudBakeDetailDivider()
                                HStack(spacing: 12) {
                                    Button {
                                        viewModel.beginEditingBatch(batch)
                                        isEditingBatch = true
                                    } label: {
                                        HStack {
                                            Text("\(batch.remainingQuantity.formatted()) \(item.unit.displayName)")
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 3) {
                                                if let unitCost = batch.unitCost {
                                                    Text("Unit Cost \(MoneyDisplay.formatted(unitCost))")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }

                                                Text(batch.expiryDisplayText)
                                                    .foregroundStyle(batch.expiryColor)
                                            }
                                            Image(systemName: "calendar")
                                                .foregroundStyle(.secondary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("inventory.detail.batch.edit.\(batch.id)")

                                    Button(role: .destructive) {
                                        viewModel.deleteBatch(batch)
                                    } label: {
                                        Image(systemName: "trash")
                                            .frame(width: 34, height: 34)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.red)
                                    .accessibilityLabel("Delete batch")
                                    .accessibilityIdentifier("inventory.detail.batch.delete.\(batch.id)")
                                }
                                .padding(.vertical, 12)
                            }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    CloudBakeErrorBanner(
                        message: errorMessage,
                        accessibilityIdentifier: "inventory.detail.error"
                    )
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
