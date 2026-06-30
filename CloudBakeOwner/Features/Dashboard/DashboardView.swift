import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(viewModel: DashboardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section("Today") {
                DashboardRow(title: "Upcoming orders", detail: "No orders yet")
                LowInventoryDashboardContent(viewModel: viewModel)
            }

            Section("Soon") {
                DashboardRow(title: "Reminders", detail: "Delivery reminders will appear here")
                DashboardRow(title: "Recent designs", detail: "Cake photos will appear here")
            }

            Section("Areas") {
                ForEach(AppDestination.allCases.filter { $0 != .dashboard }) { destination in
                    NavigationLink(value: destination) {
                        Label(destination.title, systemImage: destination.systemImage)
                    }
                    .accessibilityIdentifier(destination.accessibilityIdentifier)
                }
            }
        }
        .navigationTitle("CloudBake")
        .onAppear {
            viewModel.load()
        }
        .accessibilityIdentifier(AppDestination.dashboard.screenAccessibilityIdentifier)
    }
}

private struct LowInventoryDashboardContent: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        if let errorMessage = viewModel.errorMessage {
            DashboardRow(title: "Low inventory", detail: errorMessage)
                .accessibilityIdentifier("dashboard.lowInventory.error")
        } else if viewModel.lowInventoryItems.isEmpty {
            DashboardRow(title: "Low inventory", detail: "No alerts yet")
                .accessibilityIdentifier("dashboard.lowInventory.empty")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Low inventory")
                    .font(.headline)

                ForEach(viewModel.displayedLowInventoryItems, id: \.id) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                        Spacer()
                        Text("\(item.currentQuantity.formatted()) / \(item.minimumQuantity.formatted()) \(item.unit.displayName)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("dashboard.lowInventory.item.\(item.id)")
                }

                if viewModel.additionalLowInventoryCount > 0 {
                    Text("+ \(viewModel.additionalLowInventoryCount) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("dashboard.lowInventory.more")
                }
            }
            .padding(.vertical, 4)
            .accessibilityIdentifier("dashboard.lowInventory.alerts")
        }
    }
}

private struct DashboardRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DashboardView(
        viewModel: DashboardViewModel(
            repository: PreviewDashboardInventoryItemRepository()
        )
    )
}

private final class PreviewDashboardInventoryItemRepository: InventoryItemRepository {
    func save(_ item: InventoryItem) throws {}

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        nil
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        [
            InventoryItem(
                id: "preview-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 250,
                minimumQuantity: 500,
                createdAt: Date(),
                updatedAt: Date()
            )
        ].filter { !$0.isArchived }
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        []
    }
}
