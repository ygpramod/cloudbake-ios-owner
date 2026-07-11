import SwiftUI
import UIKit

struct OrderListView: View {
    @StateObject private var viewModel: OrderListViewModel
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var orderNotificationRouter: OrderNotificationRouter
    @EnvironmentObject private var orderNavigationRouter: OrderNavigationRouter
    @State private var isAddingOrder = false
    @State private var isViewingOrder = false
    @State private var orderScope: OrderScope = .active
    @State private var orderSelectingStatus: Order?
    @State private var pendingStatusChange: OrderStatusChangeRequest?
    @State private var orderReceivingPayment: Order?
    @State private var orderAddingPartialPayment: Order?
    @State private var partialPaymentAmount = ""
    @State private var canOpenWhatsApp = false
    @FocusState private var isSearchFocused: Bool

    init(viewModel: OrderListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        orderList
        .sheet(isPresented: $isAddingOrder, onDismiss: viewModel.cancelAddOrder) {
            NavigationStack {
                OrderForm(
                    viewModel: viewModel,
                    isPresented: $isAddingOrder,
                    onCancel: viewModel.cancelAddOrder,
                    onSave: viewModel.addOrder
                )
            }
        }
        .sheet(isPresented: $isViewingOrder, onDismiss: viewModel.closeOrderDetail) {
            NavigationStack {
                OrderDetailView(
                    viewModel: viewModel,
                    isPresented: $isViewingOrder
                )
            }
        }
        .onAppear {
            viewModel.load()
            refreshWhatsAppAvailability()
            openPendingNotificationOrder()
            openPendingNewOrder()
        }
        .onChange(of: orderNotificationRouter.pendingOrderId) { _, _ in
            openPendingNotificationOrder()
        }
        .onChange(of: orderNavigationRouter.pendingNewOrderCustomerId) { _, _ in
            openPendingNewOrder()
        }
        .accessibilityIdentifier(AppDestination.orders.screenAccessibilityIdentifier)
    }

    private var orderList: some View {
        CloudBakeScreenScaffold(
            title: "Orders",
            selectedDestination: .orders,
            primaryAction: CloudBakeScreenAction(
                title: "Add Order",
                systemImage: "plus",
                accessibilityIdentifier: "orders.add",
                action: {
                    viewModel.beginAddingOrder()
                    isAddingOrder = true
                }
            )
        ) {
            orderScopeContent
        }
        .contentShape(Rectangle())
        .simultaneousGesture(orderScopeSwipeGesture)
        .centeredOrderPopup(
            isPresented: orderSelectingStatus != nil,
            title: "Change Status",
            onCancel: { orderSelectingStatus = nil }
        ) {
            if let order = orderSelectingStatus {
                ForEach(OrderStatus.allCases, id: \.self) { status in
                    centeredPopupSelectionButton(
                        status.displayName,
                        isSelected: status == order.status
                    ) {
                        pendingStatusChange = OrderStatusChangeRequest(order: order, status: status)
                        orderSelectingStatus = nil
                    }
                    .accessibilityIdentifier("orders.row.status.\(status.rawValue).\(order.id)")
                }
            }
        }
        .centeredOrderPopup(
            isPresented: pendingStatusChange != nil,
            title: "Confirm Status Change",
            onCancel: { pendingStatusChange = nil }
        ) {
            if let request = pendingStatusChange {
                centeredPopupButton(statusConfirmationTitle(for: request), role: .destructive) {
                    _ = viewModel.changeOrderStatus(request.order, to: request.status)
                    pendingStatusChange = nil
                }
                .accessibilityIdentifier("orders.row.confirmStatus")
            }
        }
        .centeredOrderPopup(
            isPresented: orderReceivingPayment != nil,
            title: "Record Payment",
            onCancel: { orderReceivingPayment = nil }
        ) {
            if let order = orderReceivingPayment {
                centeredPopupButton("Mark Paid") {
                    _ = viewModel.markOrderPaid(order)
                    orderReceivingPayment = nil
                }
                .accessibilityIdentifier("orders.row.payment.paid.\(order.id)")

                centeredPopupButton("Add Partial Payment") {
                    partialPaymentAmount = ""
                    orderAddingPartialPayment = order
                    orderReceivingPayment = nil
                }
                .accessibilityIdentifier("orders.row.payment.partial.\(order.id)")
            }
        }
        .centeredOrderPopup(
            isPresented: orderAddingPartialPayment != nil,
            title: "Add Partial Payment",
            showsCancelButton: false,
            onCancel: {
                orderAddingPartialPayment = nil
                partialPaymentAmount = ""
            }
        ) {
            TextField("Amount", text: $partialPaymentAmount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("orders.row.payment.partial.amount")

            HStack(spacing: 16) {
                centeredPopupPillButton("Cancel") {
                    orderAddingPartialPayment = nil
                    partialPaymentAmount = ""
                }
                .accessibilityIdentifier("orders.row.payment.partial.cancel")

                centeredPopupPillButton("Save") {
                    if let order = orderAddingPartialPayment,
                       viewModel.addPayment(to: order, amountText: partialPaymentAmount) {
                        orderAddingPartialPayment = nil
                        partialPaymentAmount = ""
                    }
                }
                .accessibilityIdentifier("orders.row.payment.partial.save")
            }
        }
    }

    private var orderScopeContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            if let overdueAlert = viewModel.overdueAlert {
                overdueBanner(overdueAlert)
            }

            CloudBakeSection {
                Picker("Order Status", selection: $orderScope) {
                    ForEach(OrderScope.allCases, id: \.self) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding(6)
                .background(.white.opacity(0.90), in: Capsule())
                .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                .accessibilityIdentifier("orders.scope")
            }

            if !viewModel.orders.isEmpty {
                CloudBakeSearchField(
                    text: $viewModel.searchText,
                    prompt: "Search orders",
                    accessibilityIdentifier: "orders.search",
                    isFocused: $isSearchFocused
                )
            }

            if viewModel.orders.isEmpty {
                CloudBakeEmptyState(
                    title: "No orders yet",
                    systemImage: "calendar",
                    message: "Add accepted or draft cake orders to track due dates and customer requests."
                )
            } else if orderScope == .completed {
                if viewModel.visibleCompletedOrders.isEmpty {
                    CloudBakeEmptyState(
                        title: viewModel.searchText.isEmpty ? "No completed orders" : "No matching completed orders",
                        systemImage: "checkmark.circle",
                        message: viewModel.searchText.isEmpty
                            ? "Orders marked completed will appear here."
                            : "Try another cake, customer, status, or fulfillment detail."
                    )
                } else {
                    CloudBakeSection("Completed") {
                        VStack(spacing: 16) {
                            ForEach(viewModel.visibleCompletedOrders, id: \.id) { order in
                                orderRow(order, dueDateDisplay: .dateOnly)
                                    .cloudBakeCardStyle()
                            }
                        }
                    }
                }
            } else if viewModel.visibleActiveOrders.isEmpty {
                CloudBakeEmptyState(
                    title: viewModel.searchText.isEmpty ? "No active orders" : "No matching active orders",
                    systemImage: "calendar",
                    message: viewModel.searchText.isEmpty
                        ? "Draft, confirmed, in-progress, and ready orders will appear by delivery day."
                        : "Try another cake, customer, status, or fulfillment detail."
                )
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel.calendarDays, id: \.day) { calendarDay in
                        VStack(alignment: .leading, spacing: 12) {
                            Label(calendarDay.day.formatted(date: .complete, time: .omitted), systemImage: "calendar")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)

                            VStack(spacing: 16) {
                                ForEach(calendarDay.orders, id: \.id) { order in
                                    orderRow(order, dueDateDisplay: .timeOnly)
                                        .cloudBakeCardStyle()
                                }
                            }
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                CloudBakeErrorBanner(
                    message: errorMessage,
                    accessibilityIdentifier: "orders.error"
                )
            }
        }
    }

    private func orderRow(
        _ order: Order,
        dueDateDisplay: OrderRow.DueDateDisplay = .dateAndTime
    ) -> some View {
        OrderRow(
            order: order,
            dueDateDisplay: dueDateDisplay,
            isOverdue: viewModel.isOverdue(order),
            onChangeStatus: {
                orderSelectingStatus = order
            },
            onReceivePayment: {
                orderReceivingPayment = order
            },
            onSendMessage: messageAction(for: order),
            action: {
                openOrder(order)
            }
        )
    }

    private func messageAction(for order: Order) -> (() -> Void)? {
        guard canOpenWhatsApp,
              let url = viewModel.whatsappMessageURL(for: order) else {
            return nil
        }

        return {
            openURL(url)
        }
    }

    private func refreshWhatsAppAvailability() {
        canOpenWhatsApp = URL(string: "whatsapp://send")
            .map { UIApplication.shared.canOpenURL($0) } ?? false
    }

    private func overdueBanner(_ alert: OrderOverdueAlert) -> some View {
        Button {
            openOrder(alert.order)
        } label: {
            Label(alert.message, systemImage: "clock.badge.exclamationmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cloudBakePink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.cloudBakePink.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("orders.overdue.banner")
    }

    private func openOrder(_ order: Order) {
        viewModel.beginViewingOrder(order)
        isViewingOrder = true
    }

    private func openPendingNotificationOrder() {
        guard let orderId = orderNotificationRouter.pendingOrderId,
              let order = viewModel.order(id: orderId) else {
            return
        }

        openOrder(order)
        orderNotificationRouter.clearPendingOrderId()
    }

    private func openPendingNewOrder() {
        guard let customerId = orderNavigationRouter.pendingNewOrderCustomerId else {
            return
        }

        viewModel.beginAddingOrder()
        viewModel.selectDraftCustomer(id: customerId)
        isAddingOrder = true
        orderNavigationRouter.clearPendingNewOrder()
    }

    private var orderScopeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 36, coordinateSpace: .local)
            .onEnded(handleOrderScopeSwipe)
    }

    private func handleOrderScopeSwipe(_ value: DragGesture.Value) {
        guard value.startLocation.x > 32 else {
            return
        }

        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height
        guard abs(horizontalDistance) >= 72,
              abs(horizontalDistance) > abs(verticalDistance) * 1.4 else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            if horizontalDistance < 0, orderScope == .active {
                orderScope = .completed
            } else if horizontalDistance > 0, orderScope == .completed {
                orderScope = .active
            }
        }
    }

    private func statusConfirmationTitle(for request: OrderStatusChangeRequest) -> String {
        if request.requiresInventoryDeductionConfirmation {
            return "Mark \(request.status.displayName) And Deduct"
        }

        return "Mark \(request.status.displayName)"
    }
}

private struct OrderStatusChangeRequest: Identifiable {
    let id = UUID()
    let order: Order
    let status: OrderStatus

    var requiresInventoryDeductionConfirmation: Bool {
        order.status == .confirmed &&
            (status == .ready || status == .completed) &&
            order.recipeId != nil
    }
}

private enum OrderScope: CaseIterable {
    case active
    case completed

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        }
    }
}
