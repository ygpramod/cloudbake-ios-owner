import SwiftUI

struct OrderListView: View {
    @StateObject private var viewModel: OrderListViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isAddingOrder = false
    @State private var isViewingOrder = false
    @State private var orderScope: OrderScope = .active
    @State private var orderSelectingStatus: Order?
    @State private var pendingStatusChange: OrderStatusChangeRequest?
    @State private var orderReceivingPayment: Order?
    @State private var orderAddingPartialPayment: Order?
    @State private var partialPaymentAmount = ""

    init(viewModel: OrderListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    orderList
                } detail: {
                    if viewModel.selectedOrder == nil {
                        ContentUnavailableView(
                            "Select an order",
                            systemImage: "calendar",
                            description: Text("Choose an order to view cake details, customer context, reminders, and checklist.")
                        )
                        .accessibilityIdentifier("orders.detail.empty")
                    } else {
                        OrderDetailView(
                            viewModel: viewModel,
                            isPresented: .constant(true),
                            showsDoneButton: false
                        )
                    }
                }
            } else {
                orderList
            }
        }
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

            if viewModel.orders.isEmpty {
                CloudBakeEmptyState(
                    title: "No orders yet",
                    systemImage: "calendar",
                    message: "Add accepted or draft cake orders to track due dates and customer requests."
                )
            } else if orderScope == .completed {
                if viewModel.completedOrders.isEmpty {
                    CloudBakeEmptyState(
                        title: "No completed orders",
                        systemImage: "checkmark.circle",
                        message: "Orders marked completed will appear here."
                    )
                } else {
                    CloudBakeSection("Completed") {
                        VStack(spacing: 16) {
                            ForEach(viewModel.completedOrders, id: \.id) { order in
                                orderRow(order, dueDateDisplay: .dateOnly)
                                    .cloudBakeCardStyle()
                            }
                        }
                    }
                }
            } else if viewModel.activeOrders.isEmpty {
                CloudBakeEmptyState(
                    title: "No active orders",
                    systemImage: "calendar",
                    message: "Draft, confirmed, in-progress, and ready orders will appear by delivery day."
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
        .contentShape(Rectangle())
        .simultaneousGesture(orderScopeSwipeGesture)
    }

    private func orderRow(
        _ order: Order,
        dueDateDisplay: OrderRow.DueDateDisplay = .dateAndTime
    ) -> some View {
        OrderRow(
            order: order,
            dueDateDisplay: dueDateDisplay,
            onChangeStatus: {
                orderSelectingStatus = order
            },
            onReceivePayment: {
                orderReceivingPayment = order
            },
            action: {
                openOrder(order)
            }
        )
    }

    private func openOrder(_ order: Order) {
        viewModel.beginViewingOrder(order)
        if horizontalSizeClass != .regular {
            isViewingOrder = true
        }
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
