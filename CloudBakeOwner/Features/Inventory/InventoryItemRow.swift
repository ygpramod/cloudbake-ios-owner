import SwiftUI

struct InventoryItemRow: View {
    let item: InventoryItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text("Current Quantity: \(item.currentQuantity.formatted()) \(item.unit.displayName)")
                    .font(.subheadline)
                Text("Minimum Quantity: \(item.minimumQuantity.formatted()) \(item.unit.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let earliestExpiryAt = item.earliestExpiryAt {
                    Text("Expires: \(earliestExpiryAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(item.expiryColor)
                }
            }

            Spacer()

            if item.isLowStock {
                Label(item.lowStockLabel, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(item.alertColor)
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("inventory.item.lowStock.\(item.id)")
            }
        }
        .accessibilityIdentifier("inventory.item.\(item.id)")
    }
}

private extension InventoryItem {
    var lowStockLabel: String {
        if hasExpiredStock {
            return "Expired stock"
        }

        if hasExpiringSoonStock {
            return "Expiring soon"
        }

        return "Low stock"
    }

    var alertColor: Color {
        hasExpiringSoonStock && !hasExpiredStock ? .orange : .red
    }

    var expiryColor: Color {
        if hasExpiredStock {
            return .red
        }

        if hasExpiringSoonStock {
            return .orange
        }

        return .secondary
    }
}
