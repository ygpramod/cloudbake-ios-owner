import SwiftUI

struct OrderRow: View {
    let order: Order
    let dueDateDisplay: DueDateDisplay
    let onChangeStatus: (OrderStatus) -> Void
    let onMarkPaid: () -> Void
    let onAddPartialPayment: () -> Void
    let onSendMessage: (() -> Void)?
    let action: () -> Void
    let isOverdue: Bool

    init(
        order: Order,
        dueDateDisplay: DueDateDisplay = .dateAndTime,
        isOverdue: Bool = false,
        onChangeStatus: @escaping (OrderStatus) -> Void,
        onMarkPaid: @escaping () -> Void,
        onAddPartialPayment: @escaping () -> Void,
        onSendMessage: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.order = order
        self.dueDateDisplay = dueDateDisplay
        self.isOverdue = isOverdue
        self.onChangeStatus = onChangeStatus
        self.onMarkPaid = onMarkPaid
        self.onAddPartialPayment = onAddPartialPayment
        self.onSendMessage = onSendMessage
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: action) {
                HStack(spacing: CloudBakeTheme.Spacing.rowContent) {
                    CloudBakeCompactRowIcon(systemImage: orderIconName, tint: .cloudBakePink)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(order.title)
                                .font(CloudBakeTheme.Typography.rowTitle)
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            if order.status == .cancelled {
                                Image(systemName: "xmark.circle.fill")
                                    .imageScale(.small)
                                    .foregroundStyle(.red)
                                    .accessibilityLabel("Cancelled")
                                    .accessibilityIdentifier("orders.item.cancelledBadge.\(order.id)")
                            }

                            if isOverdue {
                                Text("Overdue")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.10), in: Capsule())
                                    .accessibilityIdentifier("orders.item.overdue.\(order.id)")
                            }
                        }

                        Text(order.customerName)
                            .font(CloudBakeTheme.Typography.rowDetail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .accessibilityHidden(true)

                            Text(orderDateText)
                            Text("·")
                            Text(order.fulfillmentType.displayName)
                        }
                        .font(CloudBakeTheme.Typography.rowDetail.weight(.medium))
                        .foregroundStyle(Color.cloudBakePink)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(CloudBakeTheme.Typography.rowTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("orders.item.\(order.id)")

            HStack(spacing: 6) {
                if order.hasActiveReminderState {
                    CloudBakeAdaptiveActionMenu(
                        title: "Status",
                        systemImage: "arrow.triangle.2.circlepath",
                        tint: .cloudBakePurple,
                        accessibilityIdentifier: "orders.item.status.\(order.id)",
                        isCompact: true
                    ) {
                        ForEach(OrderStatus.allCases, id: \.self) { status in
                            Button {
                                onChangeStatus(status)
                            } label: {
                                if status == order.status {
                                    Label(status.displayName, systemImage: "checkmark")
                                } else {
                                    Text(status.displayName)
                                }
                            }
                            .accessibilityIdentifier("orders.row.status.\(status.rawValue).\(order.id)")
                        }
                    }

                }

                CloudBakeAdaptiveActionMenu(
                    title: "Payment",
                    systemImage: "banknote",
                    tint: .cloudBakeMint,
                    accessibilityIdentifier: "orders.item.payment.\(order.id)",
                    isCompact: true
                ) {
                    Button("Mark Paid", action: onMarkPaid)
                        .accessibilityIdentifier("orders.row.payment.paid.\(order.id)")
                    Button("Add Partial Payment", action: onAddPartialPayment)
                        .accessibilityIdentifier("orders.row.payment.partial.\(order.id)")
                }

                if let onSendMessage {
                    CloudBakeAdaptiveActionButton(
                        title: "Message",
                        systemImage: "message",
                        tint: .cloudBakePink,
                        accessibilityIdentifier: "orders.item.message.\(order.id)",
                        isCompact: true,
                        action: onSendMessage
                    )
                }
            }
        }
        .padding(.horizontal, CloudBakeTheme.Spacing.cardPadding)
        .padding(.vertical, 14)
    }

    private var orderDateText: String {
        switch dueDateDisplay {
        case .dateAndTime:
            return order.dueAt.formatted(date: .abbreviated, time: .shortened)
        case .dateOnly:
            return order.dueAt.formatted(date: .abbreviated, time: .omitted)
        case .timeOnly:
            return order.dueAt.formatted(date: .omitted, time: .shortened)
        }
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

extension OrderRow {
    enum DueDateDisplay {
        case dateAndTime
        case dateOnly
        case timeOnly
    }
}
