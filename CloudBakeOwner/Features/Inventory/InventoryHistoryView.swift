import SwiftUI

struct InventoryHistoryView: View {
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
