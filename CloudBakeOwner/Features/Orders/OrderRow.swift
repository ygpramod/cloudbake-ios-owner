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
        VStack(alignment: .leading, spacing: 14) {
            Button(action: action) {
                HStack(spacing: 18) {
                    CloudBakeRowIcon(systemImage: orderIconName, tint: .cloudBakePink)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text(order.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)

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
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .accessibilityHidden(true)

                            Text(orderDateText)
                            Text("·")
                            Text(order.fulfillmentType.displayName)
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.cloudBakePink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cloudBakePink.opacity(0.08), in: Capsule())
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.cloudBakePink.opacity(0.72))
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("orders.item.\(order.id)")

            HStack(spacing: 10) {
                CloudBakeInlineActionButton(
                    title: "Status",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .cloudBakePurple,
                    accessibilityIdentifier: "orders.item.status.\(order.id)",
                    action: onChangeStatus
                )

                CloudBakeInlineActionButton(
                    title: "Payment",
                    systemImage: "banknote",
                    tint: .cloudBakeMint,
                    accessibilityIdentifier: "orders.item.payment.\(order.id)",
                    action: onReceivePayment
                )
            }
        }
        .padding(20)
    }

    private var orderDateText: String {
        if showsDate {
            return order.dueAt.formatted(date: .abbreviated, time: .shortened)
        }

        return order.dueAt.formatted(date: .omitted, time: .shortened)
    }

    private var orderIconName: String {
        switch order.fulfillmentType {
        case .pickup:
            return "birthday.cake"
        case .delivery:
            return "car"
        }
    }
}
