import PhotosUI
import SwiftUI
import UIKit

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
                        .navigationTitle("Orders")
                        .toolbar {
                            addOrderToolbarItem
                        }
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
                    .navigationTitle("Orders")
                    .toolbar {
                        addOrderToolbarItem
                    }
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
        List {
            Section {
                Picker("Order Status", selection: $orderScope) {
                    ForEach(OrderScope.allCases, id: \.self) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("orders.scope")
            }

            if viewModel.orders.isEmpty {
                ContentUnavailableView(
                    "No orders yet",
                    systemImage: "calendar",
                    description: Text("Add accepted or draft cake orders to track due dates and customer requests.")
                )
            } else if orderScope == .completed {
                if viewModel.completedOrders.isEmpty {
                    ContentUnavailableView(
                        "No completed orders",
                        systemImage: "checkmark.circle",
                        description: Text("Orders marked completed will appear here.")
                    )
                } else {
                    Section("Completed") {
                        ForEach(viewModel.completedOrders, id: \.id) { order in
                            orderRow(order)
                        }
                    }
                }
            } else if viewModel.activeOrders.isEmpty {
                ContentUnavailableView(
                    "No active orders",
                    systemImage: "calendar",
                    description: Text("Draft, confirmed, in-progress, and ready orders will appear by delivery day.")
                )
            } else {
                ForEach(viewModel.calendarDays, id: \.day) { calendarDay in
                    Section(calendarDay.day.formatted(date: .complete, time: .omitted)) {
                        ForEach(calendarDay.orders, id: \.id) { order in
                            orderRow(order, showsDate: false)
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("orders.error")
                }
            }
        }
        .centeredOrderPopup(
            isPresented: orderSelectingStatus != nil,
            title: "Change Status",
            onCancel: { orderSelectingStatus = nil }
        ) {
            if let order = orderSelectingStatus {
                ForEach(OrderStatus.allCases, id: \.self) { status in
                    centeredPopupButton(status.displayName) {
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
            onCancel: {
                orderAddingPartialPayment = nil
                partialPaymentAmount = ""
            }
        ) {
            TextField("Amount", text: $partialPaymentAmount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("orders.row.payment.partial.amount")
            centeredPopupButton("Save") {
                if let order = orderAddingPartialPayment,
                   viewModel.addPayment(to: order, amountText: partialPaymentAmount) {
                    orderAddingPartialPayment = nil
                    partialPaymentAmount = ""
                }
            }
            .accessibilityIdentifier("orders.row.payment.partial.save")
        }
    }

    private var addOrderToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.beginAddingOrder()
                isAddingOrder = true
            } label: {
                Label("Add Order", systemImage: "plus")
            }
            .accessibilityIdentifier("orders.add")
        }
    }

    private func orderRow(_ order: Order, showsDate: Bool = true) -> some View {
        OrderRow(
            order: order,
            showsDate: showsDate,
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

private extension View {
    func centeredOrderPopup<PopupContent: View>(
        isPresented: Bool,
        title: String,
        onCancel: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> PopupContent
    ) -> some View {
        overlay(alignment: .center) {
            if isPresented {
                CenteredOrderPopup(
                    title: title,
                    onCancel: onCancel,
                    content: content
                )
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPresented)
    }
}

private struct CenteredOrderPopup<Content: View>: View {
    let title: String
    let onCancel: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onCancel)

                VStack(spacing: 14) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 10) {
                        content()
                    }

                    Divider()

                    Button("Cancel", role: .cancel, action: onCancel)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .accessibilityIdentifier("orders.popup.cancel")
                }
                .padding(18)
                .frame(maxWidth: 340)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 0.5)
                }
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.22), radius: 20, y: 10)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(10)
    }
}

private func centeredPopupButton(
    _ title: String,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
) -> some View {
    Button(role: role, action: action) {
        Text(title)
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 40)
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(role == .destructive ? Color.red : Color.accentColor)
}

private struct OrderRow: View {
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

private struct OrderDetailView: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    let showsDoneButton: Bool
    @State private var isEditingOrder = false
    @State private var isSelectingStatus = false
    @State private var statusPendingInventoryDeduction: OrderStatus?
    @State private var isConfirmingEditedOrderInventoryDeduction = false
    @State private var isSelectingPaymentStatus = false
    @State private var isAddingPartialPayment = false
    @State private var selectedCustomerReferencePhotoItem: PhotosPickerItem?
    @State private var selectedFinalCakePhotoItem: PhotosPickerItem?
    @State private var partialPaymentAmount = ""
    @FocusState private var isChecklistTitleFocused: Bool

    init(
        viewModel: OrderListViewModel,
        isPresented: Binding<Bool>,
        showsDoneButton: Bool = true
    ) {
        self.viewModel = viewModel
        _isPresented = isPresented
        self.showsDoneButton = showsDoneButton
    }

    var body: some View {
        List {
            if let order = viewModel.selectedOrder {
                Section("Order") {
                    LabeledContent("Cake") {
                        Text(order.title)
                            .accessibilityIdentifier("orders.detail.cake")
                    }
                    LabeledContent("Status") {
                        HStack(spacing: 8) {
                            Text(order.status.displayName)
                                .accessibilityIdentifier("orders.detail.status")
                            Button {
                                isSelectingStatus = true
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .imageScale(.small)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Change Status")
                            .accessibilityIdentifier("orders.detail.statusMenu")
                        }
                    }
                    LabeledContent("Due") {
                        Text(order.dueAt.formatted(date: .abbreviated, time: .shortened))
                            .accessibilityIdentifier("orders.detail.due")
                    }
                }

                Section("Customer") {
                    LabeledContent("Name") {
                        Text(order.customerName)
                            .accessibilityIdentifier("orders.detail.customerName")
                    }
                    if order.customerId != nil {
                        LabeledContent("Record", value: "Linked")
                    }
                }

                if order.recipeId != nil {
                    Section("Recipe") {
                        LabeledContent("Linked Recipe") {
                            Text(viewModel.selectedOrderRecipe?.name ?? "Recipe unavailable")
                                .accessibilityIdentifier("orders.detail.recipeName")
                        }
                        LabeledContent("Usage") {
                            if let usage = viewModel.selectedOrderRecipeUsage {
                                Text(usage.usedAt.formatted(date: .abbreviated, time: .shortened))
                                    .accessibilityIdentifier("orders.detail.recipeUsage")
                            } else {
                                Text("When Ready")
                                    .accessibilityIdentifier("orders.detail.recipeUsage")
                            }
                        }
                    }
                }

                if order.cakeDesignId != nil {
                    Section("Design") {
                        LabeledContent("Reference") {
                            Text(viewModel.selectedOrderCakeDesign?.name ?? "Design unavailable")
                                .accessibilityIdentifier("orders.detail.designName")
                        }

                        if let notes = viewModel.selectedOrderCakeDesign?.notes {
                            LabeledContent("Notes") {
                                Text(notes)
                                    .accessibilityIdentifier("orders.detail.designNotes")
                            }
                        }

                        if let photoReference = viewModel.selectedOrderCakeDesign?.photoReference {
                            LabeledContent("Photo") {
                                Text(photoReference)
                                    .lineLimit(2)
                                    .accessibilityIdentifier("orders.detail.designPhotoReference")
                            }
                        }
                    }
                }

                Section("Photos") {
                    photoGroup(
                        title: "Customer References",
                        emptyText: "No reference photos",
                        photos: viewModel.selectedCustomerReferencePhotos,
                        pickerTitle: "Add Reference Photo",
                        pickerSystemImage: "photo.badge.plus",
                        pickerIdentifier: "orders.detail.photos.reference.add",
                        selection: $selectedCustomerReferencePhotoItem
                    )

                    photoGroup(
                        title: "Final Cake Photos",
                        emptyText: "No final cake photos",
                        photos: viewModel.selectedFinalCakePhotos,
                        pickerTitle: "Add Final Cake Photo",
                        pickerSystemImage: "photo.on.rectangle",
                        pickerIdentifier: "orders.detail.photos.final.add",
                        selection: $selectedFinalCakePhotoItem
                    )
                }

                if let customer = viewModel.selectedOrderCustomer, customer.hasOrderContext {
                    Section("Customer Details") {
                        if let allergies = customer.orderAllergies {
                            LabeledContent("Allergies") {
                                Text(allergies)
                                    .foregroundStyle(.red)
                                    .accessibilityIdentifier("orders.detail.customerAllergies")
                            }
                        }

                        if let dietaryRestrictions = customer.orderDietaryRestrictions {
                            LabeledContent("Dietary Restrictions") {
                                Text(dietaryRestrictions)
                                    .accessibilityIdentifier("orders.detail.customerDietaryRestrictions")
                            }
                        }

                        if let likes = customer.orderLikes {
                            LabeledContent("Likes") {
                                Text(likes)
                                    .accessibilityIdentifier("orders.detail.customerLikes")
                            }
                        }

                        if let dislikes = customer.orderDislikes {
                            LabeledContent("Dislikes") {
                                Text(dislikes)
                                    .accessibilityIdentifier("orders.detail.customerDislikes")
                            }
                        }

                        if let notes = customer.orderNotes {
                            LabeledContent("Notes") {
                                Text(notes)
                                    .accessibilityIdentifier("orders.detail.customerNotes")
                            }
                        }
                    }
                }

                Section("Fulfillment") {
                    LabeledContent("Type") {
                        Text(order.fulfillmentType.displayName)
                            .accessibilityIdentifier("orders.detail.fulfillmentType")
                    }
                    if let deliveryAddress = order.deliveryAddress {
                        LabeledContent("Address", value: deliveryAddress)
                    }
                }

                if let cakeNotes = order.cakeNotes {
                    Section("Cake Notes") {
                        Text(cakeNotes)
                            .accessibilityIdentifier("orders.detail.cakeNotes")
                    }
                }

                Section("Pricing And Payment") {
                    LabeledContent("Status") {
                        HStack(spacing: 8) {
                            Text(order.paymentStatus)
                                .accessibilityIdentifier("orders.detail.paymentStatus")
                            Button {
                                isSelectingPaymentStatus = true
                            } label: {
                                Image(systemName: "banknote")
                                    .imageScale(.small)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Change Payment Status")
                            .accessibilityIdentifier("orders.detail.paymentStatusMenu")
                        }
                    }

                    if let quotedPrice = order.quotedPrice {
                        LabeledContent("Quoted Price") {
                            Text(formattedMoney(quotedPrice))
                                .accessibilityIdentifier("orders.detail.quotedPrice")
                        }
                    }

                    if let depositPaid = order.depositPaid {
                        LabeledContent("Deposit Paid") {
                            Text(formattedMoney(depositPaid))
                                .accessibilityIdentifier("orders.detail.depositPaid")
                        }
                    }

                    if let balanceDue = order.balanceDue {
                        LabeledContent("Balance Due") {
                            Text(formattedMoney(balanceDue))
                                .accessibilityIdentifier("orders.detail.balanceDue")
                        }
                    }

                    if let paymentNotes = order.paymentNotes {
                        LabeledContent("Notes") {
                            Text(paymentNotes)
                                .accessibilityIdentifier("orders.detail.paymentNotes")
                        }
                    }
                }

                Section("Checklist") {
                    if viewModel.selectedOrderChecklistItems.isEmpty {
                        Text("No checklist items")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("orders.detail.checklist.empty")
                    } else {
                        ForEach(viewModel.selectedOrderChecklistItems, id: \.id) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                                Text(item.title)
                                    .strikethrough(item.isCompleted)
                                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                _ = viewModel.toggleChecklistItem(item)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("orders.detail.checklist.item.\(item.id)")
                            .accessibilityLabel(item.title)
                            .accessibilityValue(item.isCompleted ? "Complete" : "Incomplete")
                            .accessibilityAction {
                                _ = viewModel.toggleChecklistItem(item)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    _ = viewModel.deleteChecklistItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityIdentifier("orders.detail.checklist.delete.\(item.id)")
                            }
                        }
                    }

                    HStack {
                        TextField("Add checklist item", text: $viewModel.draftChecklistItemTitle)
                            .textInputAutocapitalization(.sentences)
                            .focused($isChecklistTitleFocused)
                            .accessibilityIdentifier("orders.detail.checklist.title")

                        Button {
                            if viewModel.addChecklistItemToSelectedOrder() {
                                isChecklistTitleFocused = false
                            }
                        } label: {
                            Label("Add Checklist Item", systemImage: "plus.circle")
                                .labelStyle(.iconOnly)
                        }
                        .accessibilityIdentifier("orders.detail.checklist.add")
                    }
                }

                Section("Reminders") {
                    if let reminder = viewModel.nextReminder(for: order) {
                        LabeledContent(reminder.title) {
                            Text(reminder.remindAt.formatted(date: .abbreviated, time: .shortened))
                                .accessibilityIdentifier("orders.detail.reminder.\(reminder.offsetDays)")
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("orders.detail.error")
                    }
                }
            }
        }
        .onChange(of: selectedCustomerReferencePhotoItem) { _, item in
            Task {
                await importOrderPhoto(item, kind: .customerReference)
                selectedCustomerReferencePhotoItem = nil
            }
        }
        .onChange(of: selectedFinalCakePhotoItem) { _, item in
            Task {
                await importOrderPhoto(item, kind: .finalCake)
                selectedFinalCakePhotoItem = nil
            }
        }
        .navigationTitle(viewModel.selectedOrder?.title ?? "Order")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.beginEditingOrder()
                    isEditingOrder = true
                } label: {
                    Label("Edit Order", systemImage: "pencil")
                }
                .accessibilityIdentifier("orders.detail.edit")
            }

            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .accessibilityIdentifier("orders.detail.done")
                }
            }
        }
        .centeredOrderPopup(
            isPresented: isSelectingStatus,
            title: "Change Status",
            onCancel: { isSelectingStatus = false }
        ) {
            if let order = viewModel.selectedOrder {
                ForEach(OrderStatus.allCases, id: \.self) { status in
                    centeredPopupButton(status.displayName) {
                        changeStatus(status, for: order)
                        isSelectingStatus = false
                    }
                    .accessibilityIdentifier("orders.detail.status.\(status.rawValue)")
                }
            }
        }
        .centeredOrderPopup(
            isPresented: statusPendingInventoryDeduction != nil,
            title: "Deduct Inventory?",
            onCancel: { statusPendingInventoryDeduction = nil }
        ) {
            if let status = statusPendingInventoryDeduction {
                centeredPopupButton("Mark \(status.displayName)", role: .destructive) {
                    _ = viewModel.changeSelectedOrderStatus(to: status)
                    statusPendingInventoryDeduction = nil
                }
                .accessibilityIdentifier("orders.detail.confirmInventoryDeduction")
            }
        }
        .centeredOrderPopup(
            isPresented: isSelectingPaymentStatus,
            title: "Record Payment",
            onCancel: { isSelectingPaymentStatus = false }
        ) {
            centeredPopupButton("Mark Paid") {
                _ = viewModel.markSelectedOrderPaid()
                isSelectingPaymentStatus = false
            }
            .accessibilityIdentifier("orders.detail.payment.paid")

            centeredPopupButton("Add Partial Payment") {
                partialPaymentAmount = ""
                isAddingPartialPayment = true
                isSelectingPaymentStatus = false
            }
            .accessibilityIdentifier("orders.detail.payment.partial")
        }
        .centeredOrderPopup(
            isPresented: isAddingPartialPayment,
            title: "Add Partial Payment",
            onCancel: {
                isAddingPartialPayment = false
                partialPaymentAmount = ""
            }
        ) {
            TextField("Amount", text: $partialPaymentAmount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("orders.detail.payment.partial.amount")
            centeredPopupButton("Save") {
                if viewModel.addPaymentToSelectedOrder(amountText: partialPaymentAmount) {
                    isAddingPartialPayment = false
                    partialPaymentAmount = ""
                }
            }
            .accessibilityIdentifier("orders.detail.payment.partial.save")
        }
        .sheet(isPresented: $isEditingOrder, onDismiss: viewModel.cancelEditingOrder) {
            NavigationStack {
                OrderForm(
                    title: "Edit Order",
                    viewModel: viewModel,
                    isPresented: $isEditingOrder,
                    statusOptions: OrderStatus.allCases,
                    onCancel: viewModel.cancelEditingOrder,
                    onSave: saveEditedOrder
                )
                .confirmationDialog(
                    "Deduct inventory?",
                    isPresented: $isConfirmingEditedOrderInventoryDeduction,
                    titleVisibility: .visible
                ) {
                    Button("Save And Deduct") {
                        if viewModel.saveEditedOrder(confirmingRecipeUsage: true) {
                            isConfirmingEditedOrderInventoryDeduction = false
                            isEditingOrder = false
                        }
                    }
                    .accessibilityIdentifier("orders.form.confirmInventoryDeduction")

                    Button("Cancel", role: .cancel) {}
                }
            }
        }
    }

    private func changeStatus(_ status: OrderStatus, for order: Order) {
        if shouldConfirmInventoryDeduction(from: order, to: status) {
            statusPendingInventoryDeduction = status
        } else {
            _ = viewModel.changeSelectedOrderStatus(to: status)
        }
    }

    private func shouldConfirmInventoryDeduction(from order: Order, to status: OrderStatus) -> Bool {
        order.status == .confirmed &&
            (status == .ready || status == .completed) &&
            order.recipeId != nil &&
            viewModel.selectedOrderRecipeUsage == nil
    }

    private func saveEditedOrder() -> Bool {
        if viewModel.editedOrderRequiresInventoryDeductionConfirmation {
            isConfirmingEditedOrderInventoryDeduction = true
            return false
        }

        return viewModel.saveEditedOrder()
    }

    @ViewBuilder
    private func photoGroup(
        title: String,
        emptyText: String,
        photos: [OrderPhoto],
        pickerTitle: String,
        pickerSystemImage: String,
        pickerIdentifier: String,
        selection: Binding<PhotosPickerItem?>
    ) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("\(pickerIdentifier).header")

        PhotosPicker(selection: selection, matching: .images, photoLibrary: .shared()) {
            Label(pickerTitle, systemImage: pickerSystemImage)
        }
        .accessibilityIdentifier(pickerIdentifier)

        if photos.isEmpty {
            Text(emptyText)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("\(pickerIdentifier).empty")
        } else {
            ForEach(photos, id: \.id) { photo in
                orderPhotoRow(photo)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            _ = viewModel.deleteOrderPhoto(photo)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityIdentifier("orders.detail.photos.delete.\(photo.id)")
                    }
            }
        }
    }

    private func orderPhotoRow(_ photo: OrderPhoto) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: viewModel.orderPhotoURL(photo)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.quaternary)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(photo.caption ?? photo.kind.displayName)
                    .font(.body)
                    .accessibilityIdentifier("orders.detail.photos.item.\(photo.id)")
                Text(photo.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private func importOrderPhoto(_ item: PhotosPickerItem?, kind: OrderPhotoKind) async {
        guard let item else {
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  !data.isEmpty else {
                viewModel.errorMessage = "Order photo could not be read."
                return
            }

            _ = viewModel.addOrderPhoto(
                kind: kind,
                imageData: normalizedPhotoData(from: data)
            )
        } catch {
            viewModel.errorMessage = "Order photo could not be read."
        }
    }

    private func normalizedPhotoData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.85) else {
            return data
        }

        return jpegData
    }

    private func formattedMoney(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }
}

private extension OrderPhotoKind {
    var displayName: String {
        switch self {
        case .customerReference:
            return "Reference Photo"
        case .finalCake:
            return "Final Cake Photo"
        }
    }
}

private struct OrderReminderDueRow: View {
    let group: OrderReminderDueGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.order.title)
                .font(.headline)
            Text(reminderSummary)
                .font(.subheadline)
                .foregroundStyle(.orange)
            Text(group.order.dueAt.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var reminderSummary: String {
        let offsets = group.reminders
            .map(\.offsetDays)
            .map(String.init)
            .joined(separator: ", ")

        return "\(offsets) Day \(group.reminders.count == 1 ? "Reminder" : "Reminders") Due"
    }
}

private extension Customer {
    var hasOrderContext: Bool {
        [orderAllergies, orderDietaryRestrictions, orderLikes, orderDislikes, orderNotes]
            .contains { $0 != nil }
    }

    var orderAllergies: String? {
        meaningful(allergies)
    }

    var orderDietaryRestrictions: String? {
        meaningful(dietaryRestrictions)
    }

    var orderLikes: String? {
        meaningful(likes)
    }

    var orderDislikes: String? {
        meaningful(dislikes)
    }

    var orderNotes: String? {
        meaningful(notes)
    }

    private func meaningful(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct OrderForm: View {
    let title: String
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    let statusOptions: [OrderStatus]
    let onCancel: () -> Void
    let onSave: () -> Bool
    @State private var isSelectingCustomer = false
    @State private var isSelectingRecipe = false
    @State private var isSelectingDesign = false

    init(
        title: String = "Add Order",
        viewModel: OrderListViewModel,
        isPresented: Binding<Bool>,
        statusOptions: [OrderStatus] = OrderStatus.addOptions,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Bool
    ) {
        self.title = title
        self.viewModel = viewModel
        _isPresented = isPresented
        self.statusOptions = statusOptions
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Cake") {
                TextField("Cake Name", text: $viewModel.draftTitle)
                    .accessibilityIdentifier("orders.form.title")

                TextField("Cake Notes", text: $viewModel.draftCakeNotes, axis: .vertical)
                    .lineLimit(2...5)
                    .accessibilityIdentifier("orders.form.cakeNotes")
            }

            if !viewModel.recipes.isEmpty {
                Section("Recipe") {
                    Button {
                        isSelectingRecipe = true
                    } label: {
                        LabeledContent("Linked Recipe", value: viewModel.draftRecipeName())
                    }
                    .accessibilityIdentifier("orders.form.recipe")
                    .sheet(isPresented: $isSelectingRecipe) {
                        NavigationStack {
                            RecipeSelectionView(viewModel: viewModel, isPresented: $isSelectingRecipe)
                        }
                    }
                }
            }

            if !viewModel.cakeDesigns.isEmpty {
                Section("Design") {
                    Button {
                        isSelectingDesign = true
                    } label: {
                        LabeledContent("Linked Design", value: viewModel.draftCakeDesignName())
                    }
                    .accessibilityIdentifier("orders.form.design")
                    .sheet(isPresented: $isSelectingDesign) {
                        NavigationStack {
                            DesignSelectionView(viewModel: viewModel, isPresented: $isSelectingDesign)
                        }
                    }
                }
            }

            Section("Customer") {
                if !viewModel.customers.isEmpty {
                    Button {
                        isSelectingCustomer = true
                    } label: {
                        LabeledContent("Customer Record", value: viewModel.draftCustomerRecordName())
                    }
                    .accessibilityIdentifier("orders.form.customerRecord")
                    .sheet(isPresented: $isSelectingCustomer) {
                        NavigationStack {
                            CustomerSelectionView(viewModel: viewModel, isPresented: $isSelectingCustomer)
                        }
                    }
                }

                TextField("Customer Name", text: $viewModel.draftCustomerName)
                    .textContentType(.name)
                    .accessibilityIdentifier("orders.form.customerName")
            }

            Section("Due") {
                DatePicker(
                    "Due Date",
                    selection: $viewModel.draftDueAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .accessibilityIdentifier("orders.form.dueAt")

                Picker("Status", selection: $viewModel.draftStatus) {
                    ForEach(statusOptions, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .accessibilityIdentifier("orders.form.status")
            }

            Section("Fulfillment") {
                Picker("Type", selection: $viewModel.draftFulfillmentType) {
                    ForEach(OrderFulfillmentType.allCases, id: \.self) { fulfillmentType in
                        Text(fulfillmentType.displayName).tag(fulfillmentType)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("orders.form.fulfillmentType")

                if viewModel.draftFulfillmentType == .delivery {
                    TextField("Delivery Address", text: $viewModel.draftDeliveryAddress, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("orders.form.deliveryAddress")
                }
            }

            Section("Pricing And Payment") {
                TextField("Quoted Price", text: $viewModel.draftQuotedPrice)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("orders.form.quotedPrice")

                TextField("Deposit Paid", text: $viewModel.draftDepositPaid)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("orders.form.depositPaid")

                TextField("Payment Notes", text: $viewModel.draftPaymentNotes, axis: .vertical)
                    .lineLimit(2...5)
                    .accessibilityIdentifier("orders.form.paymentNotes")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("orders.form.error")
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    isPresented = false
                }
                .accessibilityIdentifier("orders.form.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if onSave() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("orders.form.save")
            }
        }
    }
}

private struct DesignSelectionView: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.clearDraftCakeDesignLink()
                    isPresented = false
                } label: {
                    HStack {
                        Text("No Linked Design")
                        Spacer()
                        if viewModel.draftCakeDesignId.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .accessibilityIdentifier("orders.designSelection.none")
            }

            Section("Designs") {
                let matchingDesigns = viewModel.cakeDesigns(matching: searchText)
                if matchingDesigns.isEmpty {
                    Text("No matching designs")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("orders.designSelection.empty")
                } else {
                    ForEach(matchingDesigns, id: \.id) { design in
                        Button {
                            viewModel.selectDraftCakeDesign(id: design.id)
                            isPresented = false
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(design.name)
                                        .font(.headline)
                                    if let notes = design.notes {
                                        Text(notes)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    if let photoReference = design.photoReference {
                                        Label(photoReference, systemImage: "photo")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if viewModel.draftCakeDesignId == design.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier("orders.designSelection.design.\(design.id)")
                    }
                }
            }
        }
        .navigationTitle("Design")
        .searchable(text: $searchText, prompt: "Search Designs")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("orders.designSelection.done")
            }
        }
    }
}

private struct RecipeSelectionView: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.clearDraftRecipeLink()
                    isPresented = false
                } label: {
                    HStack {
                        Text("No Linked Recipe")
                        Spacer()
                        if viewModel.draftRecipeId.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .accessibilityIdentifier("orders.recipeSelection.none")
            }

            Section("Recipes") {
                let matchingRecipes = viewModel.recipes(matching: searchText)
                if matchingRecipes.isEmpty {
                    Text("No matching recipes")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("orders.recipeSelection.empty")
                } else {
                    ForEach(matchingRecipes, id: \.id) { recipe in
                        Button {
                            viewModel.selectDraftRecipe(id: recipe.id)
                            isPresented = false
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recipe.name)
                                        .font(.headline)
                                    if let notes = recipe.notes {
                                        Text(notes)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                if viewModel.draftRecipeId == recipe.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier("orders.recipeSelection.recipe.\(recipe.id)")
                    }
                }
            }
        }
        .navigationTitle("Recipe")
        .searchable(text: $searchText, prompt: "Search Recipes")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("orders.recipeSelection.done")
            }
        }
    }
}

private struct CustomerSelectionView: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.clearDraftCustomerLink()
                    isPresented = false
                } label: {
                    HStack {
                        Text("No Linked Customer")
                        Spacer()
                        if viewModel.draftCustomerId.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .accessibilityIdentifier("orders.customerSelection.none")
            }

            Section("Customers") {
                let matchingCustomers = viewModel.customers(matching: searchText)
                if matchingCustomers.isEmpty {
                    Text("No matching customers")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("orders.customerSelection.empty")
                } else {
                    ForEach(matchingCustomers, id: \.id) { customer in
                        Button {
                            viewModel.selectDraftCustomer(id: customer.id)
                            isPresented = false
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(customer.name)
                                        .font(.headline)
                                    Text(customer.phone)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    if let allergies = customer.allergies {
                                        Label(allergies, systemImage: "exclamationmark.triangle")
                                            .font(.footnote)
                                            .foregroundStyle(.orange)
                                    }
                                }

                                Spacer()

                                if viewModel.draftCustomerId == customer.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier("orders.customerSelection.customer.\(customer.id)")
                    }
                }
            }
        }
        .navigationTitle("Customer Record")
        .searchable(text: $searchText, prompt: "Search Customers")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("orders.customerSelection.done")
            }
        }
    }
}

private extension OrderStatus {
    static let addOptions: [OrderStatus] = [.draft, .confirmed]
}
