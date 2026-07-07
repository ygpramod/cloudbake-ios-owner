import PhotosUI
import SwiftUI
import UIKit

struct OrderDetailView: View {
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

                OrderDetailChecklistSection(
                    draftTitle: $viewModel.draftChecklistItemTitle,
                    items: viewModel.selectedOrderChecklistItems,
                    isTitleFocused: $isChecklistTitleFocused,
                    onAdd: viewModel.addChecklistItemToSelectedOrder,
                    onToggle: { item in
                        _ = viewModel.toggleChecklistItem(item)
                    },
                    onEdit: { item in
                        editingChecklistItem = item
                        editedChecklistItemTitle = item.title
                    },
                    onDelete: { item in
                        _ = viewModel.deleteChecklistItem(item)
                    }
                )

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
                OrderChecklistEditForm(
                    title: $editedChecklistItemTitle,
                    onCancel: cancelChecklistEdit,
                    onSave: saveChecklistEdit
                )
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
                CameraImagePickerView { image in
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

    private func cancelChecklistEdit() {
        editingChecklistItem = nil
        editedChecklistItemTitle = ""
    }

    private func saveChecklistEdit() {
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
            let image = try await PhotoPickerImageLoader.image(from: item)
            guard let imageData = image.jpegData(compressionQuality: 0.85) else {
                viewModel.errorMessage = "Order photo could not be read."
                return
            }

            _ = viewModel.addOrderPhoto(
                kind: kind,
                imageData: imageData
            )
        } catch {
            viewModel.errorMessage = "Order photo could not be read."
        }
    }
}
