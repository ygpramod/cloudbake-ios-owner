import SwiftUI

struct ArchivedInventoryView: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if viewModel.archivedItems.isEmpty {
                ContentUnavailableView(
                    "No archived inventory",
                    systemImage: "archivebox",
                    description: Text("Archived ingredients and supplies will appear here.")
                )
            } else {
                Section("Archived Items") {
                    ForEach(viewModel.archivedItems, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            InventoryItemRow(item: item)

                            if let archivedAt = item.archivedAt {
                                Text("Archived \(archivedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                viewModel.restoreItem(item)
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                            .accessibilityIdentifier("inventory.archived.restore.\(item.id)")
                        }
                        .accessibilityIdentifier("inventory.archived.item.\(item.id)")
                    }
                }
            }
        }
        .navigationTitle("Archived")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .accessibilityIdentifier("inventory.archived.done")
            }
        }
        .onAppear {
            viewModel.loadArchivedItems()
        }
        .accessibilityIdentifier("inventory.archived.screen")
    }
}
