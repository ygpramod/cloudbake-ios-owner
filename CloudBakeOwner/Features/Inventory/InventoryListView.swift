import Foundation
import SwiftUI

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

    func saveBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {
        try save(item)
        try save(batch)
    }

    func deleteBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {
        try save(item)
        batches.removeAll { $0.id == batch.id }
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
