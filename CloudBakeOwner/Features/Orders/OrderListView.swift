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
    @State private var cameraPhotoKind: OrderPhotoKind?
    @State private var previewingPhoto: OrderPhoto?
    @State private var editingChecklistItem: OrderChecklistItem?
    @State private var editedChecklistItemTitle = ""
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

                OrderDetailCustomerSection(order: order)

                OrderDetailRecipeSection(
                    order: order,
                    recipe: viewModel.selectedOrderRecipe,
                    recipeUsage: viewModel.selectedOrderRecipeUsage
                )

                OrderDetailDesignSection(
                    order: order,
                    cakeDesign: viewModel.selectedOrderCakeDesign
                )

                OrderDetailPhotosSection(
                    customerReferencePhotos: viewModel.selectedCustomerReferencePhotos,
                    finalCakePhotos: viewModel.selectedFinalCakePhotos,
                    selectedCustomerReferencePhotoItem: $selectedCustomerReferencePhotoItem,
                    selectedFinalCakePhotoItem: $selectedFinalCakePhotoItem,
                    photoURL: viewModel.orderPhotoURL,
                    onPreviewPhoto: { photo in
                        previewingPhoto = photo
                    },
                    onDeletePhoto: { photo in
                        _ = viewModel.deleteOrderPhoto(photo)
                    },
                    onTakePhoto: { kind in
                        cameraPhotoKind = kind
                    }
                )

                if let customer = viewModel.selectedOrderCustomer {
                    OrderDetailCustomerContextSection(customer: customer)
                }

                OrderDetailFulfillmentSection(order: order)

                OrderDetailCakeNotesSection(order: order)

                OrderDetailPaymentSection(order: order) {
                    isSelectingPaymentStatus = true
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
                                Button {
                                    editingChecklistItem = item
                                    editedChecklistItemTitle = item.title
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                                .accessibilityIdentifier("orders.detail.checklist.edit.\(item.id)")

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
        .sheet(
            isPresented: Binding(
                get: { editingChecklistItem != nil },
                set: { isPresented in
                    if !isPresented {
                        editingChecklistItem = nil
                        editedChecklistItemTitle = ""
                    }
                }
            )
        ) {
            NavigationStack {
                Form {
                    Section("Checklist Item") {
                        TextField("Title", text: $editedChecklistItemTitle)
                            .textInputAutocapitalization(.sentences)
                            .accessibilityIdentifier("orders.detail.checklist.edit.title")
                    }
                }
                .navigationTitle("Edit Checklist Item")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editingChecklistItem = nil
                            editedChecklistItemTitle = ""
                        }
                        .accessibilityIdentifier("orders.detail.checklist.edit.cancel")
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let editingChecklistItem else {
                                return
                            }
                            if viewModel.updateChecklistItemTitle(
                                editingChecklistItem,
                                title: editedChecklistItemTitle
                            ) {
                                self.editingChecklistItem = nil
                                editedChecklistItemTitle = ""
                            }
                        }
                        .accessibilityIdentifier("orders.detail.checklist.edit.save")
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
        .fullScreenCover(
            isPresented: Binding(
                get: { cameraPhotoKind != nil },
                set: { isPresented in
                    if !isPresented {
                        cameraPhotoKind = nil
                    }
                }
            )
        ) {
            if let cameraPhotoKind {
                OrderPhotoCameraView { image in
                    saveCameraPhoto(image, kind: cameraPhotoKind)
                    self.cameraPhotoKind = nil
                }
                .ignoresSafeArea()
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { previewingPhoto != nil },
                set: { isPresented in
                    if !isPresented {
                        previewingPhoto = nil
                    }
                }
            )
        ) {
            if let previewingPhoto {
                OrderPhotoPreviewView(
                    photo: previewingPhoto,
                    photoURL: viewModel.orderPhotoURL(previewingPhoto),
                    onSaveCaption: { caption in
                        guard viewModel.updateOrderPhotoCaption(previewingPhoto, caption: caption),
                              let updatedPhoto = viewModel.selectedOrderPhotos.first(where: { $0.id == previewingPhoto.id }) else {
                            return nil
                        }

                        self.previewingPhoto = updatedPhoto
                        return updatedPhoto
                    },
                    onPromoteToDesign: { name, notes in
                        if viewModel.promoteFinalCakePhotoToDesign(previewingPhoto, name: name, notes: notes) {
                            self.previewingPhoto = nil
                            return true
                        }

                        return false
                    },
                    onClose: {
                        self.previewingPhoto = nil
                    }
                )
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

    private func saveCameraPhoto(_ image: UIImage, kind: OrderPhotoKind) {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            viewModel.errorMessage = "Order photo could not be read."
            return
        }

        _ = viewModel.addOrderPhoto(kind: kind, imageData: imageData)
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

}
