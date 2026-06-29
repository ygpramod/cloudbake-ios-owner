import SwiftUI

struct InventoryListView: View {
    @StateObject private var viewModel: InventoryListViewModel
    @State private var isAddingItem = false

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
                        InventoryItemRow(item: item)
                    }
                }
            }
        }
        .navigationTitle("Inventory")
        .toolbar {
            Button {
                isAddingItem = true
            } label: {
                Label("Add inventory item", systemImage: "plus")
            }
            .accessibilityIdentifier("inventory.add")
        }
        .sheet(isPresented: $isAddingItem) {
            NavigationStack {
                InventoryItemForm(viewModel: viewModel, isPresented: $isAddingItem)
            }
        }
        .onAppear {
            viewModel.load()
        }
        .accessibilityIdentifier(AppDestination.inventory.screenAccessibilityIdentifier)
    }
}

private struct InventoryItemRow: View {
    let item: InventoryItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text("Current \(item.currentQuantity.formatted()) \(item.unit.displayName)")
                    .font(.subheadline)
                Text("Minimum \(item.minimumQuantity.formatted()) \(item.unit.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if item.isLowStock {
                Label("Low stock", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("inventory.item.lowStock.\(item.id)")
            }
        }
        .accessibilityIdentifier("inventory.item.\(item.id)")
    }
}

private struct InventoryItemForm: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $viewModel.draftName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("inventory.form.name")

                Picker("Unit", selection: $viewModel.draftUnit) {
                    ForEach(InventoryUnit.inventoryInputCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .accessibilityIdentifier("inventory.form.unit")

                TextField("Current quantity", text: $viewModel.draftCurrentQuantity)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("inventory.form.currentQuantity")

                TextField("Minimum quantity", text: $viewModel.draftMinimumQuantity)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("inventory.form.minimumQuantity")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("inventory.form.error")
                }
            }
        }
        .navigationTitle("Add Item")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.addItem() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("inventory.form.save")
            }
        }
    }
}

extension InventoryUnit {
    static let inventoryInputCases: [InventoryUnit] = [
        .kilogram,
        .gram,
        .milliliter,
        .teaspoon,
        .tablespoon,
        .cup,
        .each
    ]

    var displayName: String {
        switch self {
        case .kilogram: "kg"
        case .gram: "g"
        case .milliliter: "ml"
        case .teaspoon: "tsp"
        case .tablespoon: "tbsp"
        case .cup: "cup"
        case .each: "each"
        }
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

private final class PreviewInventoryItemRepository: InventoryItemRepository {
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

    func save(_ item: InventoryItem) throws {
        items.append(item)
    }

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        items.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        items
    }
}
