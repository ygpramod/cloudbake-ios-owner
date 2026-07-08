import SwiftUI

struct ArchivedInventoryView: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Environment(\.dismiss) private var dismiss

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
                        }
                        .padding(20)
                        .cloudBakeCardStyle()
                    }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadArchivedItems()
        }
        .accessibilityIdentifier("inventory.archived.screen")
    }
}
