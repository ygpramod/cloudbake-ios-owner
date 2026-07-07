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
        CloudBakeDetailScaffold(
            title: viewModel.selectedOrder?.title ?? "Order",
            showsBackButton: showsDoneButton,
            backAccessibilityIdentifier: "orders.detail.done",
            primaryAction: CloudBakeDetailAction(
                title: "Edit",
                systemImage: "pencil",
                accessibilityIdentifier: "orders.detail.edit",
                action: {
                    viewModel.beginEditingOrder()
                    isEditingOrder = true
                }
            ),
            onBack: {
                isPresented = false
            }
        ) {
            if let order = viewModel.selectedOrder {
                CloudBakeHeroCard(systemImage: "birthday.cake", tint: .cloudBakePink) {
                    Text("Cake Order")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.cloudBakePink)

                    Text(order.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("orders.detail.cake")

                    HStack(spacing: 8) {
                        Label(order.dueAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                            .accessibilityIdentifier("orders.detail.cake")
                        Text("•")
                        Text(order.fulfillmentType.displayName)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)

                    HStack(spacing: 8) {
                        Text(order.status.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.cloudBakePink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.cloudBakePink.opacity(0.10), in: Capsule())
                            .accessibilityIdentifier("orders.detail.status")

                        Text(order.paymentStatus)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.12), in: Capsule())
                            .accessibilityIdentifier("orders.detail.paymentStatus")
                    }
                }

                CloudBakeSection("Order Overview") {
                    CloudBakeDetailCard {
                        if let quotedPrice = order.quotedPrice {
                            CloudBakeDetailRow("Quoted Price") {
                                Text(formattedMoney(quotedPrice))
                                    .accessibilityIdentifier("orders.detail.quotedPrice")
                            }
                            CloudBakeDetailDivider()
                        }

                        if let depositPaid = order.depositPaid {
                            CloudBakeDetailRow("Deposit Paid") {
                                Text(formattedMoney(depositPaid))
                                    .accessibilityIdentifier("orders.detail.depositPaid")
                            }
                            CloudBakeDetailDivider()
                        }

                        if let balanceDue = order.balanceDue {
                            CloudBakeDetailRow("Balance Due") {
                                Text(formattedMoney(balanceDue))
                                    .foregroundStyle(balanceDue == 0 ? .green : .secondary)
                                    .accessibilityIdentifier("orders.detail.balanceDue")
                            }
                        }
                    }
                }

                CloudBakeSection("Order") {
                    CloudBakeDetailCard {
                        CloudBakeDetailRow("Status") {
                            HStack(spacing: 8) {
                                Text(order.status.displayName)
                                Button {
                                    isSelectingStatus = true
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .imageScale(.small)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.cloudBakePink)
                                .accessibilityLabel("Change Status")
                                .accessibilityIdentifier("orders.detail.statusMenu")
                            }
                        }
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Due") {
                            Text(order.dueAt.formatted(date: .abbreviated, time: .shortened))
                            .accessibilityIdentifier("orders.detail.due")
                        }
                    }
                }

                customerSection(order: order)
                recipeSection(order: order)
                designSection(order: order)
                photosSection
                customerContextSection
                fulfillmentSection(order: order)
                notesSection(order: order)
                paymentSection(order: order)
                checklistSection
                remindersSection(order: order)

                if let errorMessage = viewModel.errorMessage {
                    CloudBakeErrorBanner(
                        message: errorMessage,
                        accessibilityIdentifier: "orders.detail.error"
                    )
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

    @ViewBuilder
    private func customerSection(order: Order) -> some View {
        CloudBakeSection("Customer") {
            CloudBakeDetailCard {
                CloudBakeDetailRow("Name") {
                    Text(order.customerName)
                        .accessibilityIdentifier("orders.detail.customerName")
                }
                if order.customerId != nil {
                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Record") {
                        Text("Linked")
                            .foregroundStyle(Color.cloudBakePink)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recipeSection(order: Order) -> some View {
        if order.recipeId != nil {
            CloudBakeSection("Recipe Information") {
                CloudBakeDetailCard {
                    CloudBakeDetailRow("Linked Recipe") {
                        Text(viewModel.selectedOrderRecipe?.name ?? "Recipe unavailable")
                            .accessibilityIdentifier("orders.detail.recipeName")
                    }
                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Recipe Multiplier") {
                        Text(TextInputFormatting.decimalText(order.recipeScaleMultiplier))
                            .accessibilityIdentifier("orders.detail.recipeScaleMultiplier")
                    }
                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Usage") {
                        if let recipeUsage = viewModel.selectedOrderRecipeUsage {
                            Text("\(recipeUsage.usedAt.formatted(date: .abbreviated, time: .shortened)) at \(TextInputFormatting.decimalText(recipeUsage.recipeScaleMultiplier))x")
                                .accessibilityIdentifier("orders.detail.recipeUsage")
                        } else {
                            Text("When Ready")
                                .accessibilityIdentifier("orders.detail.recipeUsage")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func designSection(order: Order) -> some View {
        if order.cakeDesignId != nil {
            CloudBakeSection("Design") {
                CloudBakeDetailCard {
                    CloudBakeDetailRow("Reference") {
                        Text(viewModel.selectedOrderCakeDesign?.name ?? "Design unavailable")
                            .accessibilityIdentifier("orders.detail.designName")
                    }

                    if let notes = viewModel.selectedOrderCakeDesign?.notes {
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Notes") {
                            Text(notes)
                                .accessibilityIdentifier("orders.detail.designNotes")
                        }
                    }

                    if let photoReference = viewModel.selectedOrderCakeDesign?.photoReference {
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Photo") {
                            Text(photoReference)
                                .lineLimit(2)
                                .accessibilityIdentifier("orders.detail.designPhotoReference")
                        }
                    }
                }
            }
        }
    }

    private var photosSection: some View {
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
    }

    @ViewBuilder
    private var customerContextSection: some View {
        if let customer = viewModel.selectedOrderCustomer, customer.hasDetailOrderContext {
            CloudBakeSection("Customer Details") {
                CloudBakeDetailCard {
                    orderContextRow("Allergies", value: customer.detailOrderAllergies, identifier: "orders.detail.customerAllergies", tint: .red)
                    orderContextRow("Dietary Restrictions", value: customer.detailOrderDietaryRestrictions, identifier: "orders.detail.customerDietaryRestrictions")
                    orderContextRow("Likes", value: customer.detailOrderLikes, identifier: "orders.detail.customerLikes")
                    orderContextRow("Dislikes", value: customer.detailOrderDislikes, identifier: "orders.detail.customerDislikes")
                    orderContextRow("Notes", value: customer.detailOrderNotes, identifier: "orders.detail.customerNotes")
                }
            }
        }
    }

    @ViewBuilder
    private func orderContextRow(_ title: String, value: String?, identifier: String, tint: Color = .secondary) -> some View {
        if let value {
            CloudBakeDetailRow(title) {
                Text(value)
                    .foregroundStyle(tint)
                    .accessibilityIdentifier(identifier)
            }
            if title != "Notes" {
                CloudBakeDetailDivider()
            }
        }
    }

    @ViewBuilder
    private func fulfillmentSection(order: Order) -> some View {
        CloudBakeSection("Fulfillment") {
            CloudBakeDetailCard {
                CloudBakeDetailRow("Type") {
                    Text(order.fulfillmentType.displayName)
                        .accessibilityIdentifier("orders.detail.fulfillmentType")
                }
                if let deliveryAddress = order.deliveryAddress {
                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Address") {
                        Text(deliveryAddress)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func notesSection(order: Order) -> some View {
        if let cakeNotes = order.cakeNotes {
            CloudBakeSection("Notes") {
                CloudBakeDetailCard {
                    CloudBakeDetailRow("Cake Notes") {
                        Text(cakeNotes)
                            .accessibilityIdentifier("orders.detail.cakeNotes")
                    }
                }
            }
        }
    }

    private func paymentSection(order: Order) -> some View {
        CloudBakeSection("Pricing And Payment") {
            CloudBakeDetailCard {
                CloudBakeDetailRow("Status") {
                    HStack(spacing: 8) {
                        Text(order.paymentStatus)
                            .foregroundStyle(.green)
                            .accessibilityIdentifier("orders.detail.paymentStatus")
                        Button {
                            isSelectingPaymentStatus = true
                        } label: {
                            Image(systemName: "banknote")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.cloudBakePink)
                        .accessibilityLabel("Change Payment Status")
                        .accessibilityIdentifier("orders.detail.paymentStatusMenu")
                    }
                }

                if let quotedPrice = order.quotedPrice {
                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Quoted Price") {
                        Text(formattedMoney(quotedPrice))
                            .accessibilityIdentifier("orders.detail.quotedPrice")
                    }
                }

                if let depositPaid = order.depositPaid {
                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Deposit Paid") {
                        Text(formattedMoney(depositPaid))
                            .accessibilityIdentifier("orders.detail.depositPaid")
                    }
                }

                if let balanceDue = order.balanceDue {
                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Balance Due") {
                        Text(formattedMoney(balanceDue))
                            .foregroundStyle(balanceDue == 0 ? .green : .secondary)
                            .accessibilityIdentifier("orders.detail.balanceDue")
                    }
                }

                if let paymentNotes = order.paymentNotes {
                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Notes") {
                        Text(paymentNotes)
                            .accessibilityIdentifier("orders.detail.paymentNotes")
                    }
                }
            }
        }
    }

    private var checklistSection: some View {
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
    }

    @ViewBuilder
    private func remindersSection(order: Order) -> some View {
        if let reminder = viewModel.nextReminder(for: order) {
            CloudBakeSection("Reminders") {
                CloudBakeDetailCard {
                    CloudBakeDetailRow(reminder.title) {
                        Text(reminder.remindAt.formatted(date: .abbreviated, time: .shortened))
                            .accessibilityIdentifier("orders.detail.reminder.\(reminder.offsetDays)")
                    }
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

    private func formattedMoney(_ amount: Decimal) -> String {
        "$\(NSDecimalNumber(decimal: amount).stringValue)"
    }
}

private extension Customer {
    var hasDetailOrderContext: Bool {
        [detailOrderAllergies, detailOrderDietaryRestrictions, detailOrderLikes, detailOrderDislikes, detailOrderNotes]
            .contains { $0 != nil }
    }

    var detailOrderAllergies: String? {
        meaningfulOrderContext(allergies)
    }

    var detailOrderDietaryRestrictions: String? {
        meaningfulOrderContext(dietaryRestrictions)
    }

    var detailOrderLikes: String? {
        meaningfulOrderContext(likes)
    }

    var detailOrderDislikes: String? {
        meaningfulOrderContext(dislikes)
    }

    var detailOrderNotes: String? {
        meaningfulOrderContext(notes)
    }

    private func meaningfulOrderContext(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
