import SwiftUI
import UIKit

struct OrderListView: View {
    @StateObject private var viewModel: OrderListViewModel
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var orderNotificationRouter: OrderNotificationRouter
    @EnvironmentObject private var orderNavigationRouter: OrderNavigationRouter
    @State private var isAddingOrder = false
    @State private var isViewingOrder = false
    @State private var opensDuplicatedOrderAfterDetailDismiss = false
    @State private var orderScope: OrderScope = .active
    @State private var pendingStatusChange: OrderStatusChangeRequest?
    @State private var shortageOverrideRequest: OrderStatusChangeRequest?
    @State private var orderAddingPartialPayment: Order?
    @State private var partialPaymentAmount = ""
    @State private var canOpenWhatsApp = false
    @State private var isConfirmingAddedOrderInventoryShortage = false
    @State private var isChoosingTemplateSource = false
    @State private var templateSourcePicker: TemplateSourcePicker?
    @State private var opensTemplateEditorAfterSourceDismiss = false
    @State private var isEditingTemplateDraft = false
    @State private var templateDraftName = ""
    @FocusState private var isSearchFocused: Bool

    init(viewModel: OrderListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        orderList
            .sheet(isPresented: $isAddingOrder, onDismiss: cancelAddingOrder) {
                NavigationStack {
                    OrderForm(
                        viewModel: viewModel,
                        isPresented: $isAddingOrder,
                        onCancel: viewModel.cancelAddOrder,
                        onSave: saveAddedOrder
                    )
                    .orderConfirmationDialog(
                        isPresented: $isConfirmingAddedOrderInventoryShortage,
                        title: "Inventory Shortage",
                        message: viewModel.inventoryShortageWarningMessage,
                        messageAccessibilityIdentifier: "orders.form.inventoryShortage.message",
                        onCancel: {
                            isConfirmingAddedOrderInventoryShortage = false
                            viewModel.cancelInventoryShortageOverride()
                        }
                    ) {
                        nativeDialogButton("Continue And Save", role: .destructive) {
                            if viewModel.addOrder(allowingInventoryShortage: true) {
                                isConfirmingAddedOrderInventoryShortage = false
                                isAddingOrder = false
                            }
                        }
                        .accessibilityIdentifier("orders.form.inventoryShortage.continue")
                    }
                }
            }
            .sheet(isPresented: $isViewingOrder, onDismiss: closeOrderDetail) {
                NavigationStack {
                    OrderDetailView(
                        viewModel: viewModel,
                        isPresented: $isViewingOrder,
                        onDuplicate: duplicateSelectedOrder
                    )
                }
            }
            .sheet(
                item: $templateSourcePicker,
                onDismiss: openTemplateEditorAfterSourceDismiss
            ) { source in
                NavigationStack {
                    TemplateSourceSelectionView(
                        source: source,
                        viewModel: viewModel,
                        onCancel: { templateSourcePicker = nil },
                        onSelectOrder: prepareTemplateDraft,
                        onSelectTemplate: prepareTemplateDraft
                    )
                }
            }
            .sheet(isPresented: $isEditingTemplateDraft, onDismiss: viewModel.cancelAddOrder) {
                NavigationStack {
                    OrderForm(
                        title: "New Template",
                        viewModel: viewModel,
                        isPresented: $isEditingTemplateDraft,
                        templateName: $templateDraftName,
                        onCancel: viewModel.cancelAddOrder,
                        onSave: {
                            viewModel.saveCurrentDraftAsTemplate(named: templateDraftName)
                        }
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
            .onChange(of: orderNavigationRouter.pendingNewOrderRequest) { _, _ in
                openPendingNewOrder()
            }
            .accessibilityIdentifier(AppDestination.orders.screenAccessibilityIdentifier)
    }

    private func saveAddedOrder() -> Bool {
        let didSave = viewModel.addOrder()
        if !didSave, !viewModel.pendingInventoryShortages.isEmpty {
            isConfirmingAddedOrderInventoryShortage = true
        }
        return didSave
    }

    private func cancelAddingOrder() {
        isConfirmingAddedOrderInventoryShortage = false
        viewModel.cancelAddOrder()
    }

    private func duplicateSelectedOrder() {
        guard viewModel.beginDuplicatingSelectedOrder() else {
            return
        }
        opensDuplicatedOrderAfterDetailDismiss = true
        isViewingOrder = false
    }

    private func closeOrderDetail() {
        viewModel.closeOrderDetail()
        guard opensDuplicatedOrderAfterDetailDismiss else {
            return
        }
        opensDuplicatedOrderAfterDetailDismiss = false
        isAddingOrder = true
    }

    private func beginBlankTemplate() {
        viewModel.beginAddingOrder()
        templateDraftName = ""
        isEditingTemplateDraft = true
    }

    private func prepareTemplateDraft(from order: Order) {
        guard viewModel.beginDuplicatingOrder(id: order.id) else {
            templateSourcePicker = nil
            return
        }
        templateDraftName = "\(order.title) Template"
        opensTemplateEditorAfterSourceDismiss = true
        templateSourcePicker = nil
    }

    private func prepareTemplateDraft(from template: OrderTemplate) {
        viewModel.beginAddingOrder()
        viewModel.applyOrderTemplate(template)
        templateDraftName = "\(template.name) Copy"
        opensTemplateEditorAfterSourceDismiss = true
        templateSourcePicker = nil
    }

    private func openTemplateEditorAfterSourceDismiss() {
        guard opensTemplateEditorAfterSourceDismiss else { return }
        opensTemplateEditorAfterSourceDismiss = false
        isEditingTemplateDraft = true
    }

    private var orderList: some View {
        CloudBakeScreenScaffold(
            title: "Orders",
            selectedDestination: .orders,
            primaryAction: CloudBakeScreenAction(
                title: "Add Order",
                systemImage: "plus",
                accessibilityIdentifier: "orders.add",
                longPressTitle: "Create Template",
                longPressAction: { isChoosingTemplateSource = true },
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
        .confirmationDialog(
            "Create New Template From",
            isPresented: $isChoosingTemplateSource,
            titleVisibility: .visible
        ) {
            Button("Blank Template") { beginBlankTemplate() }
                .accessibilityIdentifier("orders.template.create.blank")
            Button("Existing Order") { templateSourcePicker = .order }
                .accessibilityIdentifier("orders.template.create.order")
            Button("Another Template") { templateSourcePicker = .template }
                .accessibilityIdentifier("orders.template.create.template")
            Button("Cancel", role: .cancel) {}
        }
        .orderConfirmationDialog(
            isPresented: optionalPresentationBinding($pendingStatusChange),
            title: "Confirm Status Change",
            onCancel: { pendingStatusChange = nil }
        ) {
            if let request = pendingStatusChange {
                nativeDialogButton(
                    "Mark \(request.status.displayName) And Deduct",
                    role: .destructive
                ) {
                    let didChangeStatus = viewModel.changeOrderStatus(request.order, to: request.status)
                    pendingStatusChange = nil
                    if !didChangeStatus, !viewModel.pendingInventoryShortages.isEmpty {
                        shortageOverrideRequest = request
                    }
                }
                .accessibilityIdentifier("orders.row.confirmStatus")
            }
        }
        .orderConfirmationDialog(
            isPresented: optionalPresentationBinding($shortageOverrideRequest),
            title: "Inventory Shortage",
            message: viewModel.inventoryShortageWarningMessage,
            messageAccessibilityIdentifier: "orders.row.inventoryShortage.message",
            onCancel: {
                shortageOverrideRequest = nil
                viewModel.cancelInventoryShortageOverride()
            }
        ) {
            if let request = shortageOverrideRequest {
                nativeDialogButton("Continue And Mark \(request.status.displayName)", role: .destructive) {
                    _ = viewModel.changeOrderStatus(
                        request.order,
                        to: request.status,
                        allowingInventoryShortage: true
                    )
                    shortageOverrideRequest = nil
                }
                .accessibilityIdentifier("orders.row.inventoryShortage.continue")
            }
        }
        .alert(
            "Add Partial Payment",
            isPresented: optionalPresentationBinding($orderAddingPartialPayment)
        ) {
            TextField("Amount", text: $partialPaymentAmount)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("orders.row.payment.partial.amount")

            Button("Cancel", role: .cancel) {
                orderAddingPartialPayment = nil
                partialPaymentAmount = ""
            }
            .accessibilityIdentifier("orders.row.payment.partial.cancel")

            Button("Save") {
                if let order = orderAddingPartialPayment,
                    viewModel.addPayment(to: order, amountText: partialPaymentAmount)
                {
                    orderAddingPartialPayment = nil
                    partialPaymentAmount = ""
                }
            }
            .accessibilityIdentifier("orders.row.payment.partial.save")
        } message: {
            Text("Add the amount received.")
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

            if orderScope == .active, viewModel.canLoadMoreActiveOrders {
                loadMoreOrdersButton(
                    title: "Load More Active Orders",
                    accessibilityIdentifier: "orders.active.loadMore",
                    action: viewModel.loadMoreActiveOrders
                )
            } else if orderScope == .completed, viewModel.canLoadMoreCompletedOrders {
                loadMoreOrdersButton(
                    title: "Load More Completed Orders",
                    accessibilityIdentifier: "orders.completed.loadMore",
                    action: viewModel.loadMoreCompletedOrders
                )
            }

            if let errorMessage = viewModel.errorMessage {
                CloudBakeErrorBanner(
                    message: errorMessage,
                    accessibilityIdentifier: "orders.error"
                )
            }
        }
    }

    private func loadMoreOrdersButton(
        title: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cloudBakePink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func orderRow(
        _ order: Order,
        dueDateDisplay: OrderRow.DueDateDisplay = .dateAndTime
    ) -> some View {
        OrderRow(
            order: order,
            dueDateDisplay: dueDateDisplay,
            isOverdue: viewModel.isOverdue(order),
            onChangeStatus: { status in
                if viewModel.requiresInventoryDeductionConfirmation(for: order, to: status) {
                    pendingStatusChange = OrderStatusChangeRequest(order: order, status: status)
                } else {
                    _ = viewModel.changeOrderStatus(order, to: status)
                }
            },
            onMarkPaid: {
                _ = viewModel.markOrderPaid(order)
            },
            onAddPartialPayment: {
                partialPaymentAmount = ""
                orderAddingPartialPayment = order
            },
            onSendMessage: messageAction(for: order),
            action: {
                openOrder(order)
            }
        )
    }

    private func messageAction(for order: Order) -> (() -> Void)? {
        guard canOpenWhatsApp,
            let url = viewModel.whatsappMessageURL(for: order)
        else {
            return nil
        }

        return {
            openURL(url)
        }
    }

    private func refreshWhatsAppAvailability() {
        canOpenWhatsApp =
            URL(string: "whatsapp://send")
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
            let order = viewModel.order(id: orderId)
        else {
            return
        }

        openOrder(order)
        orderNotificationRouter.clearPendingOrderId()
    }

    private func openPendingNewOrder() {
        guard let request = orderNavigationRouter.pendingNewOrderRequest else {
            return
        }

        if let sourceOrderId = request.sourceOrderId {
            guard viewModel.beginDuplicatingOrder(id: sourceOrderId) else {
                orderNavigationRouter.clearPendingNewOrder()
                return
            }
        } else {
            viewModel.beginAddingOrder()
        }
        if let customerId = request.customerId {
            viewModel.selectDraftCustomer(id: customerId)
        }
        switch request.designReference {
        case .cakeDesign(let id):
            viewModel.selectDraftCakeDesign(id: id)
        case .customerReference(let photoId):
            viewModel.selectDraftCustomerReference(photoId: photoId)
        case nil:
            break
        }
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
            abs(horizontalDistance) > abs(verticalDistance) * 1.4
        else {
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

}

private struct OrderStatusChangeRequest: Identifiable {
    let id = UUID()
    let order: Order
    let status: OrderStatus

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

private enum TemplateSourcePicker: String, Identifiable {
    case order
    case template

    var id: String { rawValue }
}

private struct TemplateSourceSelectionView: View {
    let source: TemplateSourcePicker
    @ObservedObject var viewModel: OrderListViewModel
    let onCancel: () -> Void
    let onSelectOrder: (Order) -> Void
    let onSelectTemplate: (OrderTemplate) -> Void
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            CloudBakeScreenBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CloudBakeSearchField(
                        text: $searchText,
                        prompt: source == .order ? "Search orders" : "Search templates",
                        accessibilityIdentifier: "orders.template.source.search",
                        isFocused: $isSearchFocused
                    )

                    if source == .order {
                        orderContent
                    } else {
                        templateContent
                    }
                }
                .padding(CloudBakeTheme.Spacing.screenHorizontal)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(source == .order ? "Choose Order" : "Choose Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
                    .accessibilityIdentifier("orders.template.source.cancel")
            }
        }
        .onAppear {
            if source == .order {
                viewModel.searchTemplateSourceOrders(matching: searchText)
            }
        }
        .onChange(of: searchText) { _, newValue in
            if source == .order {
                viewModel.searchTemplateSourceOrders(matching: newValue)
            }
        }
    }

    private var filteredTemplates: [OrderTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.orderTemplates }
        return viewModel.orderTemplates.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.cakeTitle.localizedCaseInsensitiveContains(query)
        }
    }

    @ViewBuilder
    private var orderContent: some View {
        if let errorMessage = viewModel.templateSourceOrderErrorMessage {
            CloudBakeErrorBanner(
                message: errorMessage,
                accessibilityIdentifier: "orders.template.source.error"
            )
        }

        if viewModel.templateSourceOrders.isEmpty {
            CloudBakeEmptyState(
                title: searchText.isEmpty ? "No Orders" : "No Matching Orders",
                systemImage: "calendar.badge.exclamationmark",
                message: searchText.isEmpty
                    ? "Create an order before using one as a template."
                    : "Try another cake or customer name."
            )
        } else {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.templateSourceOrders, id: \.id) { order in
                    sourceCard(
                        title: order.title,
                        subtitle: order.customerName,
                        accessibilityIdentifier: "orders.template.source.order.\(order.id)"
                    ) {
                        onSelectOrder(order)
                    }
                }

                if viewModel.canLoadMoreTemplateSourceOrders {
                    Button(action: viewModel.loadMoreTemplateSourceOrders) {
                        Label("Load More Orders", systemImage: "arrow.down.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CloudBakeTheme.ColorToken.primaryAction)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .cloudBakeCardStyle()
                    .accessibilityIdentifier("orders.template.source.loadMore")
                }
            }
        }
    }

    @ViewBuilder
    private var templateContent: some View {
        if filteredTemplates.isEmpty {
            CloudBakeEmptyState(
                title: searchText.isEmpty ? "No Templates" : "No Matching Templates",
                systemImage: "square.on.square",
                message: searchText.isEmpty
                    ? "Create a template before copying one."
                    : "Try another template or cake name."
            )
        } else {
            LazyVStack(spacing: 14) {
                ForEach(filteredTemplates, id: \.id) { template in
                    sourceCard(
                        title: template.name,
                        subtitle: template.cakeTitle.isEmpty ? nil : template.cakeTitle,
                        accessibilityIdentifier: "orders.template.source.template.\(template.id)"
                    ) {
                        onSelectTemplate(template)
                    }
                }
            }
        }
    }

    private func sourceCard(
        title: String,
        subtitle: String?,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(CloudBakeTheme.Typography.rowTitle)
                        .foregroundStyle(.primary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CloudBakeTheme.ColorToken.primaryAction)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(18)
        .cloudBakeCardStyle()
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
