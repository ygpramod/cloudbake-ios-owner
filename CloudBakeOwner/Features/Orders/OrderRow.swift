import SwiftUI

struct OrderRow: View {
    let order: Order
    let showsDate: Bool
    let onChangeStatus: () -> Void
    let onReceivePayment: () -> Void
    let action: () -> Void

    init(
        order: Order,
        showsDate: Bool = true,
        onChangeStatus: @escaping () -> Void,
        onReceivePayment: @escaping () -> Void,
        action: @escaping () -> Void
    ) {
        self.order = order
        self.showsDate = showsDate
        self.onChangeStatus = onChangeStatus
        self.onReceivePayment = onReceivePayment
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(order.title)
                        .font(.headline)
                    Spacer(minLength: 8)
                    if order.status == .cancelled {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.small)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Cancelled")
                            .accessibilityIdentifier("orders.item.cancelledBadge.\(order.id)")
                    }
                }
                Text(order.customerName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    if showsDate {
                        Text(order.dueAt.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        Text(order.dueAt.formatted(date: .omitted, time: .shortened))
                    }
                    Text(order.fulfillmentType.displayName)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("orders.item.\(order.id)")
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onChangeStatus()
            } label: {
                Label("Status", systemImage: "arrow.triangle.2.circlepath")
            }
            .tint(.blue)
            .accessibilityIdentifier("orders.item.status.\(order.id)")
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onReceivePayment()
            } label: {
                Label("Payment", systemImage: "banknote")
            }
            .tint(.green)
            .accessibilityIdentifier("orders.item.payment.\(order.id)")
        }
    }
}
