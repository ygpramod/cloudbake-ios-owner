import Foundation
import SwiftUI

struct InventoryListView: View {
    @StateObject private var viewModel: InventoryListViewModel
    @EnvironmentObject private var inventoryNavigationRouter: InventoryNavigationRouter
    @State private var isAddingItem = false
    @State private var isViewingItem = false
    @State private var isShowingArchivedItems = false
    @State private var isAdjustingStock = false
    @State private var isConsumingStock = false
    @State private var isShowingHistory = false
    @State private var isImportingPurchaseBill = false
    @State private var isAddingInventoryByVoice = false
    @State private var pendingArchiveItem: InventoryItem?
    @State private var pendingDeleteItem: InventoryItem?
    @FocusState private var isSearchFocused: Bool

    init(viewModel: InventoryListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        CloudBakeScreenScaffold(
            title: "Inventory",
            selectedDestination: .inventory,
            secondaryActions: [
                CloudBakeScreenAction(
                    title: "Archived inventory",
                    systemImage: "archivebox",
                    accessibilityIdentifier: "inventory.archived",
                    action: { isShowingArchivedItems = true }
                ),
                CloudBakeScreenAction(
                    title: "Import purchase bill",
                    systemImage: "doc.text.viewfinder",
                    accessibilityIdentifier: "inventory.purchaseBill.import",
                    action: { isImportingPurchaseBill = true }
                ),
                CloudBakeScreenAction(
                    title: "Add inventory by voice",
                    systemImage: "mic",
                    accessibilityIdentifier: "inventory.voice.add",
                    action: { isAddingInventoryByVoice = true }
                )
            ],
            collapsesActionsIntoMenu: true
        ) {
            if viewModel.items.isEmpty {
                inventoryResults
            } else {
                CloudBakeSearchField(
                    text: $viewModel.searchText,
                    prompt: "Search inventory",
                    accessibilityIdentifier: "inventory.search",
                    isFocused: $isSearchFocused
                )

                Picker("Inventory filter", selection: $viewModel.itemFilter) {
                    ForEach(InventoryItemFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(6)
                .background(.white.opacity(0.90), in: Capsule())
                .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                .accessibilityIdentifier("inventory.filter")

                inventoryResults
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            isSearchFocused = false
                        }
                    )
            }
        }
        .accessibilityIdentifier(AppDestination.inventory.screenAccessibilityIdentifier)
        .sheet(isPresented: $isAddingItem, onDismiss: viewModel.cancelEditing) {
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
        .sheet(
            isPresented: $isAddingInventoryByVoice,
            onDismiss: viewModel.cancelVoiceInventoryImport
        ) {
            NavigationStack {
                VoiceInventoryImportView(
                    viewModel: viewModel,
                    isPresented: $isAddingInventoryByVoice
                )
            }
        }
        .cloudBakeCenteredPopup(
            isPresented: pendingArchiveItem != nil,
            title: "Archive Inventory?",
            subtitle: "Archive this item from active inventory. You can restore it later.",
            systemImage: "archivebox",
            cancelAccessibilityIdentifier: "inventory.archive.cancel",
            onCancel: { pendingArchiveItem = nil }
        ) {
            if let pendingArchiveItem {
                centeredPopupButton("Archive \(pendingArchiveItem.name)", role: .destructive) {
                    viewModel.archiveItem(pendingArchiveItem)
                    self.pendingArchiveItem = nil
                }
                .accessibilityIdentifier("inventory.archive.confirm")
            }
        }
        .cloudBakeCenteredPopup(
            isPresented: pendingDeleteItem != nil,
            title: "Delete Inventory?",
            subtitle: "Delete this unused inventory item permanently. Items linked to stock history, recipes, or orders must be archived instead.",
            systemImage: "trash",
            cancelAccessibilityIdentifier: "inventory.delete.cancel",
            onCancel: { pendingDeleteItem = nil }
        ) {
            if let pendingDeleteItem {
                centeredPopupButton("Delete \(pendingDeleteItem.name)", role: .destructive) {
                    _ = viewModel.deleteItem(pendingDeleteItem)
                    self.pendingDeleteItem = nil
                }
                .accessibilityIdentifier("inventory.delete.confirm")
            }
        }
        .onAppear {
            viewModel.load()
            openPendingInventoryItem()
        }
        .onChange(of: inventoryNavigationRouter.pendingInventoryItemId) { _, _ in
            openPendingInventoryItem()
        }
    }

    @ViewBuilder
    private var inventoryResults: some View {
        CloudBakeSection(
            "Items",
            action: CloudBakeSectionAction(
                title: "Add inventory item",
                systemImage: "plus",
                accessibilityIdentifier: "inventory.add",
                action: {
                    viewModel.beginAdding()
                    isAddingItem = true
                }
            )
        ) {
            if viewModel.items.isEmpty {
                CloudBakeEmptyState(
                    title: "No inventory yet",
                    systemImage: "shippingbox",
                    message: "Add ingredients and supplies as you stock the kitchen."
                )
            } else if viewModel.visibleItems.isEmpty {
                CloudBakeEmptyState(
                    title: "No matching inventory",
                    systemImage: "magnifyingglass",
                    message: viewModel.searchText.isEmpty
                        ? "Try another stock filter."
                        : "Try another ingredient, alias, or unit name."
                )
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.visibleItems, id: \.id) { item in
                        inventoryItemCard(item)
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                CloudBakeErrorBanner(
                    message: errorMessage,
                    accessibilityIdentifier: "inventory.error"
                )
            }
        }
    }

    private func inventoryItemCard(_ item: InventoryItem) -> some View {
        InventorySwipeActionCard(
            onHistory: {
                viewModel.beginViewingHistory(item)
                isShowingHistory = true
            },
            onArchive: { pendingArchiveItem = item },
            onDelete: { pendingDeleteItem = item },
            itemID: item.id
        ) {
            VStack(alignment: .leading, spacing: 14) {
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

                HStack(spacing: 12) {
                    Spacer(minLength: 0)

                    CloudBakeIconActionButton(
                        title: "Adjust",
                        systemImage: "plus",
                        tint: .cloudBakePurple,
                        accessibilityIdentifier: "inventory.item.adjust.\(item.id)"
                    ) {
                        viewModel.beginAdjusting(item)
                        isAdjustingStock = true
                    }

                    CloudBakeIconActionButton(
                        title: "Use stock",
                        systemImage: "minus",
                        tint: .cloudBakeOrange,
                        accessibilityIdentifier: "inventory.item.consume.\(item.id)"
                    ) {
                        viewModel.beginConsuming(item)
                        isConsumingStock = true
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: 240)
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .cloudBakeCardStyle()
        }
    }

    private func openPendingInventoryItem() {
        guard let itemId = inventoryNavigationRouter.pendingInventoryItemId,
              let item = viewModel.item(id: itemId) else {
            return
        }

        viewModel.beginViewingItem(item)
        isViewingItem = true
        inventoryNavigationRouter.clearPendingInventoryItemId()
    }
}

private struct InventorySwipeActionCard<Content: View>: View {
    private enum Position: Hashable {
        case history
        case content
        case destructiveActions
    }

    private static var actionWidth: CGFloat { 76 }

    let onHistory: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let itemID: String
    @ViewBuilder let content: Content

    @State private var position: Position? = .content

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                swipeButton(
                    title: "History",
                    systemImage: "clock",
                    color: .cloudBakeTeal,
                    accessibilityIdentifier: "inventory.item.history.\(itemID)",
                    action: onHistory
                )
                .id(Position.history)

                content
                    .containerRelativeFrame(.horizontal)
                    .id(Position.content)

                HStack(spacing: 0) {
                    swipeButton(
                        title: "Archive",
                        systemImage: "archivebox",
                        color: .cloudBakeOrange,
                        accessibilityIdentifier: "inventory.item.archive.\(itemID)",
                        action: onArchive
                    )
                    swipeButton(
                        title: "Delete",
                        systemImage: "trash",
                        color: .red,
                        accessibilityIdentifier: "inventory.item.delete.\(itemID)",
                        action: onDelete
                    )
                }
                .id(Position.destructiveActions)
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $position, anchor: .leading)
        .clipShape(RoundedRectangle(cornerRadius: CloudBakeTheme.Shape.cardRadius, style: .continuous))
    }

    private func swipeButton(
        title: String,
        systemImage: String,
        color: Color,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { position = .content }
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .labelStyle(.iconOnly)
                .foregroundStyle(.white)
                .frame(width: Self.actionWidth)
                .frame(maxHeight: .infinity)
                .background(color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
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

private final class PreviewInventoryItemRepository: InventoryItemRepository, InventoryTransactionRepository, InventoryStockBatchRepository, VoiceInventoryImportRepository, ExpiredStockDisposalRepository {
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

    func replaceInventoryStock(item: InventoryItem, batches: [InventoryStockBatch]) throws {
        try save(item)
        self.batches.removeAll { $0.inventoryItemId == item.id }
        self.batches.append(contentsOf: batches)
    }

    func saveVoiceInventoryImport(items: [InventoryItem], batches: [InventoryStockBatch]) throws {
        for item in items {
            try save(item)
        }
        for batch in batches {
            try save(batch)
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

    func saveExpiredStockDisposal(
        item: InventoryItem,
        batches: [InventoryStockBatch],
        transaction: InventoryTransaction
    ) throws {
        try save(item)
        self.batches.removeAll { $0.inventoryItemId == item.id }
        self.batches.append(contentsOf: batches)
        try save(transaction)
    }
}
