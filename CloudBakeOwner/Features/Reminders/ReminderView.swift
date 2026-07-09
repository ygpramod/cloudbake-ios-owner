import SwiftUI
import UIKit

struct ReminderView: View {
    @StateObject private var viewModel: ReminderViewModel
    @Environment(\.openURL) private var openURL
    @State private var pendingPaidItem: PaymentDueReminderItem?
    @State private var orderDetailRequest: ReminderOrderDetailRequest?
    @State private var inventoryDetailRequest: ReminderInventoryDetailRequest?
    @State private var canOpenWhatsApp = false
    private let makeOrderViewModel: () -> OrderListViewModel
    private let makeInventoryViewModel: () -> InventoryListViewModel

    init(
        viewModel: ReminderViewModel,
        makeOrderViewModel: @escaping () -> OrderListViewModel,
        makeInventoryViewModel: @escaping () -> InventoryListViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.makeOrderViewModel = makeOrderViewModel
        self.makeInventoryViewModel = makeInventoryViewModel
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
            canOpenWhatsApp = URL(string: "whatsapp://send")
                .map { UIApplication.shared.canOpenURL($0) } ?? false
        }
        .sheet(item: $orderDetailRequest, onDismiss: closeOrderDetail) { request in
            NavigationStack {
                OrderDetailView(
                    viewModel: request.viewModel,
                    isPresented: orderDetailPresentedBinding
                )
            }
        }
        .sheet(item: $inventoryDetailRequest, onDismiss: closeInventoryDetail) { request in
            NavigationStack {
                InventoryItemDetailView(
                    viewModel: request.viewModel,
                    isPresented: inventoryDetailPresentedBinding
                )
            }
        }
        .cloudBakeCenteredPopup(
            isPresented: pendingPaidItem != nil,
            title: "Mark As Paid?",
            subtitle: "Confirm payment received for this order.",
            systemImage: "checkmark.circle",
            cancelAccessibilityIdentifier: "reminders.paymentDue.markPaid.cancel",
            onCancel: { pendingPaidItem = nil }
        ) {
            if let pendingPaidItem {
                centeredPopupButton("Mark \(pendingPaidItem.orderName) Paid") {
                    if viewModel.markPaid(orderId: pendingPaidItem.id) {
                        self.pendingPaidItem = nil
                    }
                }
                .accessibilityIdentifier("reminders.paymentDue.markPaid.confirm")
            }
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
                PaymentDueReminderRow(
                    item: item,
                    canOpenWhatsApp: canOpenWhatsApp,
                    onOpenOrder: { openOrder(id: item.id) },
                    onWhatsAppReminder: {
                        if let whatsappURL = item.whatsappURL {
                            openURL(whatsappURL)
                        }
                    },
                    onMarkPaid: {
                        pendingPaidItem = item
                    }
                )
                .accessibilityIdentifier("reminders.paymentDue.\(item.id)")
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
        let detailViewModel = makeOrderViewModel()
        detailViewModel.load()
        guard let order = detailViewModel.order(id: id) else {
            return
        }

        detailViewModel.beginViewingOrder(order)
        orderDetailRequest = ReminderOrderDetailRequest(id: id, viewModel: detailViewModel)
    }

    private func openInventoryItem(id: String) {
        let detailViewModel = makeInventoryViewModel()
        detailViewModel.load()
        guard let item = detailViewModel.item(id: id) else {
            return
        }

        detailViewModel.beginViewingItem(item)
        inventoryDetailRequest = ReminderInventoryDetailRequest(id: id, viewModel: detailViewModel)
    }

    private var orderDetailPresentedBinding: Binding<Bool> {
        Binding(
            get: { orderDetailRequest != nil },
            set: { isPresented in
                if !isPresented {
                    closeOrderDetail()
                }
            }
        )
    }

    private var inventoryDetailPresentedBinding: Binding<Bool> {
        Binding(
            get: { inventoryDetailRequest != nil },
            set: { isPresented in
                if !isPresented {
                    closeInventoryDetail()
                }
            }
        )
    }

    private func closeOrderDetail() {
        orderDetailRequest?.viewModel.closeOrderDetail()
        orderDetailRequest = nil
        viewModel.load()
    }

    private func closeInventoryDetail() {
        inventoryDetailRequest?.viewModel.closeSelectedItem()
        inventoryDetailRequest = nil
        viewModel.load()
    }
}

private struct ReminderOrderDetailRequest: Identifiable {
    let id: String
    let viewModel: OrderListViewModel
}

private struct ReminderInventoryDetailRequest: Identifiable {
    let id: String
    let viewModel: InventoryListViewModel
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

private struct PaymentDueReminderRow: View {
    let item: PaymentDueReminderItem
    let canOpenWhatsApp: Bool
    let onOpenOrder: () -> Void
    let onWhatsAppReminder: () -> Void
    let onMarkPaid: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpenOrder) {
                Text(item.paymentMessage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("reminders.paymentDue.open.\(item.id)")

            HStack(spacing: 12) {
                if item.whatsappURL != nil, canOpenWhatsApp {
                    CloudBakeInlineActionButton(
                        title: "WhatsApp Reminder",
                        systemImage: "message",
                        tint: .cloudBakeTeal,
                        accessibilityIdentifier: "reminders.paymentDue.whatsapp.\(item.id)",
                        prominence: .prominent,
                        action: onWhatsAppReminder
                    )
                }

                CloudBakeInlineActionButton(
                    title: "Mark as Paid",
                    systemImage: "checkmark.circle",
                    tint: .cloudBakeMint,
                    accessibilityIdentifier: "reminders.paymentDue.markPaid.\(item.id)",
                    prominence: .prominent,
                    action: onMarkPaid
                )
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
            ),
            makeOrderViewModel: {
                OrderListViewModel(repository: database.makeCoreDataRepository())
            },
            makeInventoryViewModel: {
                InventoryListViewModel(repository: database.makeCoreDataRepository())
            }
        )
    }
}
