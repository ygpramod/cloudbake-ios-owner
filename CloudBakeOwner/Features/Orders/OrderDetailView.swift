import PhotosUI
import SwiftUI
import UIKit

struct OrderDetailView: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    let showsDoneButton: Bool
    let onDuplicate: (() -> Void)?
    @State private var isEditingOrder = false
    @State private var statusPendingInventoryDeduction: OrderStatus?
    @State private var statusPendingInventoryShortage: OrderStatus?
    @State private var statusChangeErrorMessage: String?
    @State private var isConfirmingEditedOrderInventoryDeduction = false
    @State private var isConfirmingEditedOrderInventoryShortage = false
    @State private var isConfirmingMarkPaid = false
    @State private var isAddingPartialPayment = false
    @State private var selectedCustomerReferencePhotoItem: PhotosPickerItem?
    @State private var selectedFinalCakePhotoItem: PhotosPickerItem?
    @State private var cameraPhotoKind: OrderPhotoKind?
    @State private var previewingPhoto: OrderPhoto?
    @State private var isPreviewingLinkedDesign = false
    @State private var isAddingExtraIngredient = false
    @State private var isConfirmingExtraIngredientInventoryShortage = false
    @State private var editingChecklistItem: OrderChecklistItem?
    @State private var editedChecklistItemTitle = ""
    @State private var partialPaymentAmount = ""
    @State private var partialPaymentNote = ""
    @State private var receiptPendingVoid: PaymentReceipt?
    @State private var paymentVoidReason = ""
    @FocusState private var isChecklistTitleFocused: Bool
    @FocusState private var isPartialPaymentAmountFocused: Bool

    init(
        viewModel: OrderListViewModel,
        isPresented: Binding<Bool>,
        showsDoneButton: Bool = true,
        onDuplicate: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        _isPresented = isPresented
        self.showsDoneButton = showsDoneButton
        self.onDuplicate = onDuplicate
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
            secondaryActions: Self.duplicateActions(onDuplicate: onDuplicate),
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
                            .accessibilityIdentifier("orders.detail.hero.due")
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
                            .accessibilityIdentifier("orders.detail.hero.paymentStatus")
                    }
                }

                CloudBakeSection("Order Overview") {
                    CloudBakeDetailCard {
                        CloudBakeDetailRow("Balance Due") {
                            Text(balanceDueText(for: order))
                                .foregroundStyle(order.balanceDue == 0 ? .green : .secondary)
                                .accessibilityIdentifier("orders.detail.overview.balanceDue")
                        }

                        if let cakeMessage = order.cakeMessage {
                            CloudBakeDetailDivider()
                            orderDetailBlockRow("Message") {
                                Text(cakeMessage)
                                    .accessibilityIdentifier("orders.detail.overview.message")
                            }
                        }

                        if order.fulfillmentType == .delivery,
                            let deliveryAddress = order.deliveryAddress
                        {
                            CloudBakeDetailDivider()
                            orderDetailBlockRow("Delivery Address") {
                                Text(deliveryAddress)
                                    .accessibilityIdentifier("orders.detail.overview.deliveryAddress")
                            }
                        }
                    }
                }

                CloudBakeSection("Order") {
                    CloudBakeDetailCard {
                        CloudBakeDetailRow("Status") {
                            HStack(spacing: 8) {
                                Text(order.status.displayName)
                                Menu {
                                    ForEach(OrderStatus.allCases, id: \.self) { status in
                                        Button {
                                            changeStatus(status, for: order)
                                        } label: {
                                            if status == order.status {
                                                Label(status.displayName, systemImage: "checkmark")
                                            } else {
                                                Text(status.displayName)
                                            }
                                        }
                                        .accessibilityIdentifier("orders.detail.status.\(status.rawValue)")
                                    }
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .imageScale(.small)
                                }
                                .buttonStyle(.plain)
                                .cloudBakeNativeMenuStyle()
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

                if !viewModel.selectedOrderIngredientShortages.isEmpty {
                    CloudBakeSection("Ingredient Warning") {
                        CloudBakeDetailCard {
                            ForEach(Array(viewModel.selectedOrderIngredientShortages.enumerated()), id: \.element.id) { index, shortage in
                                if index > 0 {
                                    CloudBakeDetailDivider()
                                }
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(shortage.inventoryItemName)
                                            .font(.subheadline.weight(.semibold))
                                        Text(
                                            "Need \(shortage.requiredQuantity.formatted()) \(shortage.unit.displayName) across active orders; \(shortage.availableQuantity.formatted()) \(shortage.unit.displayName) usable."
                                        )
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 14)
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("orders.detail.ingredientShortage.\(shortage.inventoryItemId)")
                            }
                        }
                    }
                }

                if let warning = viewModel.selectedOrderInventoryReservationRepairWarning {
                    CloudBakeDetailCard {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14)
                    }
                    .accessibilityIdentifier("orders.detail.inventoryReservationRepairWarning")
                }

                if !viewModel.selectedOrderInventoryReservations.isEmpty {
                    CloudBakeSection("Reserved Inventory") {
                        CloudBakeDetailCard {
                            ForEach(
                                Array(viewModel.selectedOrderInventoryReservations.enumerated()),
                                id: \.element.id
                            ) { index, row in
                                if index > 0 {
                                    CloudBakeDetailDivider()
                                }
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(Color.cloudBakeMint)
                                        .accessibilityHidden(true)
                                    Text(row.inventoryItemName)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer(minLength: 12)
                                    Text(
                                        "\(row.reservation.requiredQuantity.formatted()) \(row.reservation.unit.displayName)"
                                    )
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 14)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(
                                    "\(row.inventoryItemName), \(row.reservation.requiredQuantity.formatted()) \(row.reservation.unit.displayName) reserved"
                                )
                                .accessibilityIdentifier(
                                    "orders.detail.inventoryReservation.\(row.reservation.inventoryItemId)"
                                )
                            }
                        }
                    }
                }

                customerSection(order: order)
                recipeSection(order: order)
                designSection(order: order)
                photosSection
                customerContextSection
                cakeSpecificationSection(order: order)
                notesSection(order: order)
                paymentSection(order: order)
                if viewModel.isIngredientCostBreakdownExpanded,
                    let summary = viewModel.selectedOrderIngredientCost
                {
                    OrderIngredientCostBreakdownContent(
                        summary: summary,
                        isActual: viewModel.selectedOrderIngredientCostIsActual
                    )
                }
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
            isPresented: $isAddingExtraIngredient,
            onDismiss: cancelExtraIngredientEdit
        ) {
            NavigationStack {
                OrderExtraIngredientForm(
                    viewModel: viewModel,
                    isPresented: $isAddingExtraIngredient,
                    onSave: saveExtraIngredient
                )
                .orderConfirmationDialog(
                    isPresented: $isConfirmingExtraIngredientInventoryShortage,
                    title: "Inventory Shortage",
                    message: viewModel.inventoryShortageWarningMessage,
                    messageAccessibilityIdentifier: "orders.extraIngredient.inventoryShortage.message",
                    onCancel: {
                        isConfirmingExtraIngredientInventoryShortage = false
                        viewModel.cancelInventoryShortageOverride()
                    }
                ) {
                    nativeDialogButton("Continue And Save", role: .destructive) {
                        if viewModel.addExtraIngredientToSelectedOrder(
                            allowingInventoryShortage: true
                        ) {
                            isConfirmingExtraIngredientInventoryShortage = false
                            isAddingExtraIngredient = false
                        } else {
                            isConfirmingExtraIngredientInventoryShortage = false
                        }
                    }
                    .accessibilityIdentifier("orders.extraIngredient.inventoryShortage.continue")
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
                    photoSource: viewModel.orderPhotoSource(previewingPhoto),
                    onSaveCaption: { caption in
                        guard viewModel.updateOrderPhotoCaption(previewingPhoto, caption: caption),
                            let updatedPhoto = viewModel.selectedOrderPhotos.first(where: { $0.id == previewingPhoto.id })
                        else {
                            return nil
                        }

                        self.previewingPhoto = updatedPhoto
                        return updatedPhoto
                    },
                    onPromoteToDesign: { name, notes in
                        if await viewModel.promoteFinalCakePhotoToDesign(previewingPhoto, name: name, notes: notes) {
                            self.previewingPhoto = nil
                            return true
                        }

                        return false
                    },
                    onAddToDesignReferences: { tags in
                        let didAdd = await viewModel.addCustomerReferencePhotoToDesignReferences(
                            previewingPhoto,
                            tags: tags
                        )
                        if didAdd,
                            let updatedPhoto = viewModel.selectedOrderPhotos.first(where: {
                                $0.id == previewingPhoto.id
                            })
                        {
                            self.previewingPhoto = updatedPhoto
                        }
                        return didAdd
                    },
                    referenceErrorMessage: { viewModel.errorMessage },
                    onClose: {
                        self.previewingPhoto = nil
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $isPreviewingLinkedDesign) {
            if let linkedDesignPreview {
                LinkedDesignPhotoPreviewView(
                    title: linkedDesignPreview.title,
                    sourceName: linkedDesignPreview.sourceName,
                    photoSource: linkedDesignPreview.photoSource,
                    onClose: { isPreviewingLinkedDesign = false }
                )
            }
        }
        .orderConfirmationDialog(
            isPresented: optionalPresentationBinding($statusPendingInventoryDeduction),
            title: "Deduct Inventory?",
            onCancel: { statusPendingInventoryDeduction = nil }
        ) {
            if let status = statusPendingInventoryDeduction {
                nativeDialogButton("Mark \(status.displayName)", role: .destructive) {
                    let didChangeStatus = viewModel.changeSelectedOrderStatus(to: status)
                    statusPendingInventoryDeduction = nil
                    if !didChangeStatus, !viewModel.pendingInventoryShortages.isEmpty {
                        statusPendingInventoryShortage = status
                    } else if !didChangeStatus {
                        statusChangeErrorMessage =
                            viewModel.errorMessage
                            ?? "Order status could not be updated."
                    }
                }
                .accessibilityIdentifier("orders.detail.confirmInventoryDeduction")
            }
        }
        .cloudBakeConfirmationDialog(
            isPresented: $isConfirmingMarkPaid,
            title: "Mark as Paid?",
            message: selectedOrderPaymentConfirmationMessage,
            cancelAccessibilityIdentifier: "orders.detail.payment.paid.cancel",
            onCancel: { isConfirmingMarkPaid = false }
        ) {
            nativeDialogButton("Mark Paid") {
                _ = viewModel.markSelectedOrderPaid()
                isConfirmingMarkPaid = false
            }
            .accessibilityIdentifier("orders.detail.payment.paid.confirm")
        }
        .cloudBakeInputPopup(
            isPresented: optionalPresentationBinding($receiptPendingVoid),
            title: "Void Payment",
            message: "The original payment stays in history and is excluded from totals.",
            primaryTitle: "Void Payment",
            primaryRole: .destructive,
            primaryAccessibilityIdentifier: "orders.detail.payment.void.confirm",
            cancelAccessibilityIdentifier: "orders.detail.payment.void.cancel",
            onCancel: {
                receiptPendingVoid = nil
                paymentVoidReason = ""
            },
            onSubmit: {
                if let receiptPendingVoid {
                    _ = viewModel.voidPaymentReceipt(
                        receiptPendingVoid,
                        reason: paymentVoidReason
                    )
                }
                self.receiptPendingVoid = nil
                paymentVoidReason = ""
            }
        ) {
            TextField("Reason (optional)", text: $paymentVoidReason)
                .accessibilityIdentifier("orders.detail.payment.void.reason")
        }
        .orderConfirmationDialog(
            isPresented: optionalPresentationBinding($statusPendingInventoryShortage),
            title: "Inventory Shortage",
            message: viewModel.inventoryShortageWarningMessage,
            messageAccessibilityIdentifier: "orders.detail.inventoryShortage.message",
            onCancel: {
                statusPendingInventoryShortage = nil
                viewModel.cancelInventoryShortageOverride()
            }
        ) {
            if let status = statusPendingInventoryShortage {
                nativeDialogButton("Continue And Mark \(status.displayName)", role: .destructive) {
                    let didChangeStatus = viewModel.changeSelectedOrderStatus(
                        to: status,
                        allowingInventoryShortage: true
                    )
                    statusPendingInventoryShortage = nil
                    if !didChangeStatus {
                        statusChangeErrorMessage =
                            viewModel.errorMessage
                            ?? "Order status could not be updated."
                    }
                }
                .accessibilityIdentifier("orders.detail.inventoryShortage.continue")
            }
        }
        .orderConfirmationDialog(
            isPresented: optionalPresentationBinding($statusChangeErrorMessage),
            title: "Status Not Updated",
            message: statusChangeErrorMessage ?? "Order status could not be updated.",
            messageAccessibilityIdentifier: "orders.detail.statusChangeError",
            showsCancelButton: false,
            onCancel: {}
        ) {
            nativeDialogButton("OK") {
                self.statusChangeErrorMessage = nil
            }
            .accessibilityIdentifier("orders.detail.statusChangeError.dismiss")
        }
        .cloudBakeInputPopup(
            isPresented: $isAddingPartialPayment,
            title: "Add Partial Payment",
            message: "Add the amount received.",
            primaryTitle: "Save",
            primaryAccessibilityIdentifier: "orders.detail.payment.partial.save",
            cancelAccessibilityIdentifier: "orders.detail.payment.partial.cancel",
            onCancel: {
                isPartialPaymentAmountFocused = false
                isAddingPartialPayment = false
                partialPaymentAmount = ""
                partialPaymentNote = ""
            },
            onSubmit: {
                if viewModel.addPaymentToSelectedOrder(
                    amountText: partialPaymentAmount,
                    note: partialPaymentNote
                ) {
                    isPartialPaymentAmountFocused = false
                    isAddingPartialPayment = false
                    partialPaymentAmount = ""
                    partialPaymentNote = ""
                }
            }
        ) {
            TextField("Amount", text: $partialPaymentAmount)
                .keyboardType(.decimalPad)
                .focused($isPartialPaymentAmountFocused)
                .accessibilityIdentifier("orders.detail.payment.partial.amount")

            TextField("Note (optional)", text: $partialPaymentNote)
                .accessibilityIdentifier("orders.detail.payment.partial.note")
        }
        .onChange(of: isAddingPartialPayment) { _, isPresented in
            guard isPresented else {
                isPartialPaymentAmountFocused = false
                return
            }

            Task { @MainActor in
                await Task.yield()
                isPartialPaymentAmountFocused = true
            }
        }
        .sheet(isPresented: $isEditingOrder, onDismiss: cancelEditingOrder) {
            NavigationStack {
                OrderForm(
                    title: "Edit Order",
                    viewModel: viewModel,
                    isPresented: $isEditingOrder,
                    statusOptions: OrderStatus.allCases,
                    onCancel: viewModel.cancelEditingOrder,
                    onSave: saveEditedOrder
                )
                .orderConfirmationDialog(
                    isPresented: $isConfirmingEditedOrderInventoryDeduction,
                    title: "Deduct Inventory?",
                    onCancel: {
                        isConfirmingEditedOrderInventoryDeduction = false
                    }
                ) {
                    nativeDialogButton("Save And Deduct") {
                        let didSave = viewModel.saveEditedOrder(confirmingRecipeUsage: true)
                        isConfirmingEditedOrderInventoryDeduction = false
                        if didSave {
                            isEditingOrder = false
                        } else if !viewModel.pendingInventoryShortages.isEmpty {
                            isConfirmingEditedOrderInventoryShortage = true
                        }
                    }
                    .accessibilityIdentifier("orders.form.confirmInventoryDeduction")
                }
                .orderConfirmationDialog(
                    isPresented: $isConfirmingEditedOrderInventoryShortage,
                    title: "Inventory Shortage",
                    message: viewModel.inventoryShortageWarningMessage,
                    messageAccessibilityIdentifier: "orders.form.inventoryShortage.message",
                    onCancel: {
                        isConfirmingEditedOrderInventoryShortage = false
                        viewModel.cancelInventoryShortageOverride()
                    }
                ) {
                    nativeDialogButton("Continue And Save", role: .destructive) {
                        if viewModel.saveEditedOrder(
                            confirmingRecipeUsage: true,
                            allowingInventoryShortage: true
                        ) {
                            isConfirmingEditedOrderInventoryShortage = false
                            isEditingOrder = false
                        }
                    }
                    .accessibilityIdentifier("orders.form.inventoryShortage.continue")
                }
            }
        }
    }

    static func duplicateActions(
        onDuplicate: (() -> Void)?
    ) -> [CloudBakeDetailAction] {
        guard let onDuplicate else {
            return []
        }
        return [
            CloudBakeDetailAction(
                title: "Duplicate Order",
                systemImage: "doc.on.doc",
                accessibilityIdentifier: "orders.detail.duplicate",
                action: onDuplicate
            )
        ]
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
                            Text(
                                "\(recipeUsage.usedAt.formatted(date: .abbreviated, time: .shortened)) at \(TextInputFormatting.decimalText(recipeUsage.recipeScaleMultiplier))x"
                            )
                            .accessibilityIdentifier("orders.detail.recipeUsage")
                        } else {
                            Text("When Ready")
                                .accessibilityIdentifier("orders.detail.recipeUsage")
                        }
                    }

                    CloudBakeDetailDivider()
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Extra Ingredients")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if viewModel.selectedOrderRecipeUsage == nil {
                                Button {
                                    viewModel.beginAddingExtraIngredient()
                                    isAddingExtraIngredient = true
                                } label: {
                                    Image(systemName: "plus")
                                        .imageScale(.medium)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.cloudBakePink)
                                .accessibilityLabel("Add Extra Ingredient")
                                .accessibilityIdentifier("orders.detail.extraIngredient.add")
                            }
                        }

                        if viewModel.selectedOrderExtraIngredients.isEmpty {
                            Text("No extra ingredients")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("orders.detail.extraIngredient.empty")
                        } else {
                            VStack(spacing: 0) {
                                ForEach(viewModel.selectedOrderExtraIngredients) { row in
                                    OrderExtraIngredientListRow(
                                        row: row,
                                        canDelete: viewModel.selectedOrderRecipeUsage == nil,
                                        onDelete: {
                                            _ = viewModel.deleteExtraIngredient(row)
                                        }
                                    )
                                }
                            }
                            .accessibilityIdentifier("orders.detail.extraIngredient.list")
                        }
                    }
                    .padding(.vertical, 14)
                }
            }
        }
    }

    @ViewBuilder
    private func designSection(order: Order) -> some View {
        if order.cakeDesignId != nil || order.customerReferencePhotoId != nil {
            CloudBakeSection("Design") {
                CloudBakeDetailCard {
                    CloudBakeDetailRow("Source") {
                        Text(viewModel.selectedOrderDesignSourceName ?? "Reference unavailable")
                            .accessibilityIdentifier("orders.detail.designSource")
                    }

                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Reference") {
                        Text(
                            viewModel.selectedOrderCakeDesign?.name
                                ?? viewModel.selectedOrderCustomerReferencePhoto?.caption
                                ?? "Customer Reference"
                        )
                        .accessibilityIdentifier("orders.detail.designName")
                    }

                    if let notes = viewModel.selectedOrderCakeDesign?.notes {
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Notes") {
                            Text(notes)
                                .accessibilityIdentifier("orders.detail.designNotes")
                        }
                    }

                    if let linkedDesignPreview {
                        CloudBakeDetailDivider()
                        Button {
                            isPreviewingLinkedDesign = true
                        } label: {
                            HStack(spacing: 14) {
                                Text("Photo")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                DesignPhotoView(
                                    source: linkedDesignPreview.photoSource,
                                    maximumPixelSize: 240,
                                    contentMode: .fill
                                )
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open linked design photo")
                        .accessibilityIdentifier("orders.detail.designPhotoThumbnail")
                    }
                }
            }
        }
    }

    private var linkedDesignPreview: LinkedDesignPreview? {
        if let design = viewModel.selectedOrderCakeDesign,
            design.photoReference != nil,
            let photoSource = viewModel.designPhotoSource(for: design)
        {
            return LinkedDesignPreview(
                title: design.name,
                sourceName: viewModel.selectedOrderDesignSourceName ?? "My Designs",
                photoSource: photoSource
            )
        }

        if let photo = viewModel.selectedOrderCustomerReferencePhoto,
            let photoSource = viewModel.orderPhotoSource(photo)
        {
            return LinkedDesignPreview(
                title: photo.caption ?? "Customer Reference",
                sourceName: "Customer Reference",
                photoSource: photoSource
            )
        }

        return nil
    }

    private var photosSection: some View {
        OrderDetailPhotosSection(
            customerReferencePhotos: viewModel.selectedCustomerReferencePhotos,
            finalCakePhotos: viewModel.selectedFinalCakePhotos,
            selectedCustomerReferencePhotoItem: $selectedCustomerReferencePhotoItem,
            selectedFinalCakePhotoItem: $selectedFinalCakePhotoItem,
            photoSource: viewModel.orderPhotoSource,
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
                    orderContextRow(
                        "Allergies", value: customer.detailOrderAllergies, identifier: "orders.detail.customerAllergies", tint: .red)
                    orderContextRow(
                        "Dietary Restrictions", value: customer.detailOrderDietaryRestrictions,
                        identifier: "orders.detail.customerDietaryRestrictions")
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

    private func orderDetailBlockRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            content()
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func cakeSpecificationSection(order: Order) -> some View {
        let rows = cakeSpecificationRows(order.cakeSpecification)
        if order.cakeSpecification.summary != nil || !rows.isEmpty {
            CloudBakeSection("Cake Requirements") {
                CloudBakeDetailCard {
                    if let summary = order.cakeSpecification.summary {
                        orderDetailBlockRow("Summary") {
                            Text(summary)
                                .accessibilityIdentifier("orders.detail.cakeSpecification.summary")
                        }
                    }

                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 || order.cakeSpecification.summary != nil {
                            CloudBakeDetailDivider()
                        }
                        CloudBakeDetailRow(row.label) {
                            Text(row.value)
                        }
                    }
                }
            }
        }
    }

    private func cakeSpecificationRows(
        _ specification: OrderCakeSpecification
    ) -> [(label: String, value: String)] {
        [
            ("Occasion", specification.occasion),
            ("Servings", specification.servings.map(String.init)),
            ("Size", specification.size),
            (
                "Weight",
                specification.weightKilograms.map {
                    "\(NSDecimalNumber(decimal: $0).stringValue) kg"
                }
            ),
            ("Shape", specification.shape),
            ("Tiers", specification.tiers),
            ("Sponge", specification.spongeFlavour),
            ("Filling", specification.filling),
            ("Frosting", specification.frosting),
            ("Colour Palette", specification.colourPalette),
            ("Theme", specification.theme),
            ("Topper", meaningfulRequirement(specification.topperRequirements)),
            ("Candles And Accessories", meaningfulRequirement(specification.candlesAndAccessories)),
            ("Packaging", specification.packaging),
        ].compactMap { label, value in
            value.map { (label, $0) }
        }
    }

    private func meaningfulRequirement(_ value: String?) -> String? {
        guard let value, value.caseInsensitiveCompare("None") != .orderedSame else {
            return nil
        }
        return value
    }

    @ViewBuilder
    private func notesSection(order: Order) -> some View {
        if order.cakeNotes != nil || order.cakeMessage != nil {
            CloudBakeSection("Notes") {
                CloudBakeDetailCard {
                    if let cakeNotes = order.cakeNotes {
                        orderDetailBlockRow("Notes") {
                            Text(cakeNotes)
                                .accessibilityIdentifier("orders.detail.cakeNotes")
                        }
                    }

                    if let cakeMessage = order.cakeMessage {
                        if order.cakeNotes != nil {
                            CloudBakeDetailDivider()
                        }

                        orderDetailBlockRow("Message") {
                            Text(cakeMessage)
                                .accessibilityIdentifier("orders.detail.message")
                        }
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
                        Menu {
                            if order.isPaidInFull {
                                Button(action: {}) {
                                    Text("Paid Already")
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .multilineTextAlignment(.center)
                                }
                                .disabled(true)
                                .accessibilityIdentifier("orders.detail.payment.alreadyPaid")
                            } else {
                                Button("Mark Paid") {
                                    isConfirmingMarkPaid = true
                                }
                                .accessibilityIdentifier("orders.detail.payment.paid")

                                Button("Add Partial Payment") {
                                    partialPaymentAmount = ""
                                    partialPaymentNote = ""
                                    isAddingPartialPayment = true
                                }
                                .accessibilityIdentifier("orders.detail.payment.partial")
                            }
                        } label: {
                            Image(systemName: "banknote")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                        .cloudBakeNativeMenuStyle()
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

                if let ingredientCost = viewModel.selectedOrderIngredientCost,
                    !ingredientCost.lines.isEmpty
                {
                    CloudBakeDetailDivider()
                    HStack(spacing: 12) {
                        Text(viewModel.selectedOrderIngredientCostIsActual ? "Actual Ingredient Cost" : "Estimated Ingredient Cost")
                            .foregroundStyle(.primary)
                        Spacer()
                        if !ingredientCost.itemsMissingPrice.isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        Text(formattedMoney(ingredientCost.knownCost))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.isIngredientCostBreakdownExpanded.toggle()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("orders.detail.ingredientCost")
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

                if viewModel.selectedOrderLegacyPaidAmount > 0 {
                    CloudBakeDetailDivider()
                    paymentHistoryRow(
                        title: "Legacy payment — date unknown",
                        amount: viewModel.selectedOrderLegacyPaidAmount,
                        detail: nil,
                        isVoided: false,
                        receipt: nil
                    )
                    .accessibilityIdentifier("orders.detail.payment.legacy")
                }

                ForEach(viewModel.selectedOrderPaymentReceipts, id: \.id) { receipt in
                    CloudBakeDetailDivider()
                    paymentHistoryRow(
                        title: receipt.receivedAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        ),
                        amount: receipt.amount,
                        detail: paymentReceiptDetail(receipt),
                        isVoided: receipt.isVoided,
                        receipt: receipt
                    )
                    .accessibilityIdentifier("orders.detail.payment.receipt.\(receipt.id)")
                }
            }
        }
    }

    private func paymentHistoryRow(
        title: String,
        amount: Decimal,
        detail: String?,
        isVoided: Bool,
        receipt: PaymentReceipt?
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isVoided ? .secondary : .primary)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(isVoided ? .red : .secondary)
                }
            }
            Spacer()
            Text(formattedMoney(amount))
                .font(.subheadline.weight(.semibold))
                .strikethrough(isVoided)
                .foregroundStyle(isVoided ? .secondary : .primary)
            if let receipt, !receipt.isVoided {
                Menu {
                    Button("Void Payment", role: .destructive) {
                        paymentVoidReason = ""
                        receiptPendingVoid = receipt
                    }
                    .accessibilityIdentifier("orders.detail.payment.void.\(receipt.id)")
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .cloudBakeNativeMenuStyle()
                .accessibilityLabel("Payment Actions")
            }
        }
        .padding(.vertical, 12)
    }

    private func paymentReceiptDetail(_ receipt: PaymentReceipt) -> String? {
        var details = [String]()
        if let note = receipt.note {
            details.append(note)
        }
        if let correction = receipt.void {
            var correctionText = "Voided \(correction.voidedAt.formatted(date: .abbreviated, time: .shortened))"
            if let reason = correction.reason {
                correctionText += " — \(reason)"
            }
            details.append(correctionText)
        }
        return details.isEmpty ? nil : details.joined(separator: "\n")
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
        order.status.recordsRecipeUsage(whenChangingTo: status) && order.recipeId != nil && viewModel.selectedOrderRecipeUsage == nil
    }

    private func saveEditedOrder() -> Bool {
        if viewModel.editedOrderRequiresInventoryDeductionConfirmation {
            isConfirmingEditedOrderInventoryDeduction = true
            return false
        }

        let didSave = viewModel.saveEditedOrder()
        if !didSave, !viewModel.pendingInventoryShortages.isEmpty {
            isConfirmingEditedOrderInventoryShortage = true
        }
        return didSave
    }

    private func saveExtraIngredient() -> Bool {
        let didSave = viewModel.addExtraIngredientToSelectedOrder()
        if !didSave, !viewModel.pendingInventoryShortages.isEmpty {
            isConfirmingExtraIngredientInventoryShortage = true
        }
        return didSave
    }

    private func cancelExtraIngredientEdit() {
        isConfirmingExtraIngredientInventoryShortage = false
        viewModel.cancelExtraIngredientEdit()
    }

    private func cancelEditingOrder() {
        isConfirmingEditedOrderInventoryDeduction = false
        isConfirmingEditedOrderInventoryShortage = false
        viewModel.cancelEditingOrder()
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

        Task {
            _ = await viewModel.addOrderPhoto(kind: kind, imageData: imageData)
        }
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

            _ = await viewModel.addOrderPhoto(
                kind: kind,
                imageData: imageData
            )
        } catch {
            viewModel.errorMessage = "Order photo could not be read."
        }
    }

    private func balanceDueText(for order: Order) -> String {
        guard let balanceDue = order.balanceDue else {
            return "Not Set"
        }

        return formattedMoney(balanceDue)
    }

    private var selectedOrderPaymentConfirmationMessage: String {
        guard let balanceDue = viewModel.selectedOrder?.balanceDue, balanceDue > 0 else {
            return "Record this order as fully paid?"
        }
        return "Record the remaining balance of \(MoneyDisplay.formatted(balanceDue)) as paid?"
    }

    private func formattedMoney(_ amount: Decimal) -> String {
        MoneyDisplay.formatted(amount)
    }
}

private struct OrderIngredientCostBreakdownContent: View {
    let summary: OrderIngredientCostSummary
    let isActual: Bool

    var body: some View {
        Group {
            CloudBakeSection("Total") {
                CloudBakeDetailCard {
                    CloudBakeDetailRow("Known Cost") {
                        Text(MoneyDisplay.formatted(summary.knownCost))
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("orders.ingredientCost.total")
                    }
                }
            }

            if !summary.itemsMissingPrice.isEmpty {
                CloudBakeErrorBanner(
                    message:
                        "Missing inventory prices for \(summary.itemsMissingPrice.joined(separator: ", ")). The total includes every ingredient cost that can be calculated.",
                    accessibilityIdentifier: "orders.ingredientCost.warning"
                )
            }

            CloudBakeSection("Ingredients") {
                CloudBakeDetailCard {
                    ForEach(Array(summary.lines.enumerated()), id: \.element.id) { index, line in
                        if index > 0 { CloudBakeDetailDivider() }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(line.inventoryItemName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(MoneyDisplay.formatted(line.knownCost))
                            }
                            Text("\(line.quantity.formatted()) \(line.unit.displayName)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if line.hasMissingPrice {
                                Text("Price missing for \(line.missingPriceQuantity.formatted()) \(line.unit.displayName)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                            if line.hasShortfall {
                                Text("Inventory shortfall: \(line.shortfallQuantity.formatted()) \(line.unit.displayName)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 14)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("orders.ingredientCost.line.\(line.inventoryItemId)")
                    }
                }
            }
        }
    }
}

private struct LinkedDesignPreview {
    let title: String
    let sourceName: String
    let photoSource: CakeDesignPhotoSource?
}

private struct LinkedDesignPhotoPreviewView: View {
    let title: String
    let sourceName: String
    let photoSource: CakeDesignPhotoSource?
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                CloudBakeScreenBackground().ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer(minLength: 20)
                    DesignPhotoView(
                        source: photoSource,
                        maximumPixelSize: 2_400,
                        contentMode: .fit
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .accessibilityLabel("\(title), \(sourceName)")
                    .accessibilityIdentifier("orders.detail.designPhotoPreview")

                    Text(sourceName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("orders.detail.designPhotoPreview.source")
                }
                .padding(CloudBakeTheme.Spacing.screenHorizontal)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                        .accessibilityIdentifier("orders.detail.designPhotoPreview.done")
                }
            }
        }
    }
}

struct OrderExtraIngredientForm: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    let onSave: () -> Bool

    var body: some View {
        Form {
            if viewModel.availableInventoryItems.isEmpty {
                ContentUnavailableView(
                    "No inventory items",
                    systemImage: "shippingbox",
                    description: Text("Add inventory before adding extra ingredients.")
                )
            } else {
                Section("Extra Ingredient") {
                    Picker("Inventory Item", selection: $viewModel.draftExtraIngredientInventoryItemId) {
                        ForEach(viewModel.availableInventoryItems, id: \.id) { item in
                            Text(item.name).tag(item.id)
                        }
                    }
                    .onChange(of: viewModel.draftExtraIngredientInventoryItemId) { _, _ in
                        viewModel.updateDraftExtraIngredientUnitForSelectedInventoryItem()
                    }
                    .accessibilityIdentifier("orders.extraIngredient.inventoryItem")

                    TextField("Quantity", text: $viewModel.draftExtraIngredientQuantity)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("orders.extraIngredient.quantity")

                    Picker("Unit", selection: $viewModel.draftExtraIngredientUnit) {
                        ForEach(InventoryUnit.inventoryInputCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .accessibilityIdentifier("orders.extraIngredient.unit")

                    TextField("Note", text: $viewModel.draftExtraIngredientNote, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("orders.extraIngredient.note")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("orders.extraIngredient.error")
                }
            }
        }
        .cloudBakeFormScreenStyle()
        .navigationTitle("Add Extra Ingredient")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelExtraIngredientEdit()
                    isPresented = false
                }
                .accessibilityIdentifier("orders.extraIngredient.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if onSave() {
                        isPresented = false
                    }
                }
                .disabled(viewModel.availableInventoryItems.isEmpty)
                .accessibilityIdentifier("orders.extraIngredient.save")
            }
        }
    }
}

private struct OrderExtraIngredientListRow: View {
    let row: OrderExtraIngredientRow
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.inventoryItemName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("\(row.ingredient.quantity.formatted()) \(row.ingredient.unit.displayName)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let note = row.ingredient.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .accessibilityLabel("Delete Extra Ingredient")
                .accessibilityIdentifier("orders.detail.extraIngredient.delete.\(row.id)")
            }
        }
        .padding(.vertical, 10)
        .accessibilityIdentifier("orders.detail.extraIngredient.\(row.id)")
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
