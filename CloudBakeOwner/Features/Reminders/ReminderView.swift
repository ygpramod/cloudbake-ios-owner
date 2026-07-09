import SwiftUI

struct ReminderView: View {
    @StateObject private var viewModel: ReminderViewModel
    @Environment(\.navigateToAppDestination) private var navigate
    @EnvironmentObject private var orderNotificationRouter: OrderNotificationRouter
    @EnvironmentObject private var inventoryNavigationRouter: InventoryNavigationRouter

    init(viewModel: ReminderViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        CloudBakeScreenScaffold(
            title: "Reminders",
            selectedDestination: .reminders
        ) {
            reminderContent
        }
        .onAppear {
            viewModel.load()
        }
        .accessibilityIdentifier(AppDestination.reminders.screenAccessibilityIdentifier)
    }

    private var reminderContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            reminderSection(
                title: "Payment Due",
                emptyTitle: "No payments due",
                emptyMessage: "Orders with a remaining balance will appear here.",
                systemImage: "banknote",
                items: viewModel.paymentDueItems
            ) { item in
                reminderButton(
                    accessibilityIdentifier: "reminders.paymentDue.\(item.id)",
                    action: { openOrder(id: item.id) }
                ) {
                    ReminderListRow(
                        title: item.orderName,
                        subtitle: item.customerName,
                        trailing: item.balanceDueText,
                        tint: .cloudBakePink
                    )
                }
            }

            reminderSection(
                title: "Orders For Today",
                emptyTitle: "No orders today",
                emptyMessage: "Cake orders due today will appear here.",
                systemImage: "calendar",
                items: viewModel.todayOrderItems
            ) { item in
                reminderButton(
                    accessibilityIdentifier: "reminders.todayOrder.\(item.id)",
                    action: { openOrder(id: item.id) }
                ) {
                    ReminderListRow(
                        title: item.orderName,
                        subtitle: item.customerName,
                        tint: .cloudBakePurple
                    )
                }
            }

            reminderSection(
                title: "Low Inventory",
                emptyTitle: "Inventory looks good",
                emptyMessage: "Low and expiry-sensitive inventory will appear here.",
                systemImage: "shippingbox",
                items: viewModel.lowInventoryItems
            ) { item in
                reminderButton(
                    accessibilityIdentifier: "reminders.lowInventory.\(item.id)",
                    action: { openInventoryItem(id: item.id) }
                ) {
                    ReminderListRow(
                        title: item.name,
                        subtitle: item.quantityText,
                        tint: .cloudBakeOrange
                    )
                }
            }

            if let errorMessage = viewModel.errorMessage {
                CloudBakeErrorBanner(
                    message: errorMessage,
                    accessibilityIdentifier: "reminders.error"
                )
            }
        }
    }

    private func reminderSection<Item: Identifiable, Row: View>(
        title: String,
        emptyTitle: String,
        emptyMessage: String,
        systemImage: String,
        items: [Item],
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        CloudBakeSection(title) {
            if items.isEmpty {
                CompactReminderEmptyState(
                    title: emptyTitle,
                    message: emptyMessage,
                    systemImage: systemImage
                )
            } else {
                CloudBakeListCard {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        row(item)
                        if index < items.count - 1 {
                            CloudBakeDetailDivider()
                                .padding(.horizontal, 18)
                        }
                    }
                }
            }
        }
    }

    private func reminderButton<Content: View>(
        accessibilityIdentifier: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            content()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func openOrder(id: String) {
        orderNotificationRouter.openOrder(id: id)
        navigate(.orders)
    }

    private func openInventoryItem(id: String) {
        inventoryNavigationRouter.openInventoryItem(id: id)
        navigate(.inventory)
    }
}

private struct ReminderListRow: View {
    let title: String
    let subtitle: String
    let trailing: String?
    let tint: Color

    init(
        title: String,
        subtitle: String,
        trailing: String? = nil,
        tint: Color
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay {
                    Circle()
                        .fill(tint)
                        .frame(width: 9, height: 9)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if let trailing {
                Text(trailing)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct CompactReminderEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.cloudBakePink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.cloudBakePink.opacity(0.10)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cloudBakeCardStyle()
    }
}

#Preview {
    if let database = try? AppDatabase.makeInMemory() {
        ReminderView(
            viewModel: ReminderViewModel(
                repository: database.makeCoreDataRepository()
            )
        )
        .environmentObject(OrderNotificationRouter())
        .environmentObject(InventoryNavigationRouter())
    }
}
