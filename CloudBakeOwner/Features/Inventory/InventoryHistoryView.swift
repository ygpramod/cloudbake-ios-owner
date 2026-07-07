import SwiftUI

struct InventoryHistoryView: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        CloudBakeDetailScaffold(
            title: "Stock History",
            backAccessibilityIdentifier: "inventory.history.done",
            onBack: {
                viewModel.closeHistory()
                isPresented = false
            }
        ) {
            if let item = viewModel.historyItem {
                CloudBakeHeroCard(systemImage: "clock", tint: .cloudBakeTeal) {
                    Text("Inventory History")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.cloudBakeTeal)

                    Text(item.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("\(item.currentQuantity.formatted()) \(item.unit.displayName) current")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                CloudBakeSection("Item") {
                    CloudBakeDetailCard {
                        CloudBakeDetailRow("Name") {
                            Text(item.name)
                        }
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Current") {
                            Text("\(item.currentQuantity.formatted()) \(item.unit.displayName)")
                        }
                    }
                }

                if viewModel.historyTransactions.isEmpty {
                    CloudBakeEmptyState(
                        title: "No stock history",
                        systemImage: "clock",
                        message: "Adjustments and stock usage will appear here."
                    )
                } else {
                    CloudBakeSection("Stock Changes") {
                        CloudBakeDetailCard {
                        ForEach(viewModel.historyTransactions, id: \.id) { transaction in
                            InventoryTransactionRow(transaction: transaction, unit: item.unit)
                            if transaction.id != viewModel.historyTransactions.last?.id {
                                CloudBakeDetailDivider()
                            }
                        }
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                CloudBakeErrorBanner(
                    message: errorMessage,
                    accessibilityIdentifier: "inventory.history.error"
                )
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
        .padding(.vertical, 12)
        .accessibilityIdentifier("inventory.history.transaction.\(transaction.id)")
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
