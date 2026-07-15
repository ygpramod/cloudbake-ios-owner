import SwiftUI

struct ArchivedInventoryView: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeleteItem: InventoryItem?

    var body: some View {
        CloudBakeDetailScaffold(
            title: "Archived",
            backAccessibilityIdentifier: "inventory.archived.done",
            onBack: {
                dismiss()
            }
        ) {
            if viewModel.archivedItems.isEmpty {
                CloudBakeEmptyState(
                    title: "No archived inventory",
                    systemImage: "archivebox",
                    message: "Archived ingredients and supplies will appear here."
                )
            } else {
                CloudBakeSection("Archived Items") {
                    VStack(spacing: 16) {
                        ForEach(viewModel.archivedItems, id: \.id) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                InventoryItemRow(item: item)

                                if let archivedAt = item.archivedAt {
                                    Text("Archived \(archivedAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 10) {
                                    if pendingDeleteItem?.id == item.id {
                                        Button("Cancel") {
                                            pendingDeleteItem = nil
                                        }
                                        .font(.caption.weight(.semibold))
                                        .buttonStyle(.bordered)
                                        .buttonBorderShape(.capsule)
                                        .accessibilityIdentifier("inventory.archived.delete.cancel")

                                        Button("Delete Permanently", role: .destructive) {
                                            _ = viewModel.deleteItem(item)
                                            pendingDeleteItem = nil
                                        }
                                        .font(.caption.weight(.semibold))
                                        .buttonStyle(.borderedProminent)
                                        .buttonBorderShape(.capsule)
                                        .tint(.red)
                                        .accessibilityIdentifier("inventory.archived.delete.confirm")
                                    } else {
                                        Button {
                                            viewModel.restoreItem(item)
                                        } label: {
                                            Label("Restore", systemImage: "arrow.uturn.backward")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.green)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .background(Color.green.opacity(0.10), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("inventory.archived.restore.\(item.id)")

                                        Button {
                                            pendingDeleteItem = item
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.red)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .background(Color.red.opacity(0.10), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("inventory.archived.delete.\(item.id)")
                                    }
                                }
                            }
                            .padding(20)
                            .cloudBakeCardStyle()
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    CloudBakeErrorBanner(
                        message: errorMessage,
                        accessibilityIdentifier: "inventory.archived.error"
                    )
                }
            }
        }
        .onAppear {
            viewModel.loadArchivedItems()
        }
        .accessibilityIdentifier("inventory.archived.screen")
    }
}
