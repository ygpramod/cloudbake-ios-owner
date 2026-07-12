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
    @State private var isPreviewingLinkedDesign = false
    @State private var isAddingExtraIngredient = false
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
                           let deliveryAddress = order.deliveryAddress {
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

                customerSection(order: order)
                recipeSection(order: order)
                designSection(order: order)
                photosSection
                customerContextSection
                notesSection(order: order)
                paymentSection(order: order)
                if viewModel.isIngredientCostBreakdownExpanded,
                   let summary = viewModel.selectedOrderIngredientCost {
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
            onDismiss: viewModel.cancelExtraIngredientEdit
        ) {
            NavigationStack {
                OrderExtraIngredientForm(
                    viewModel: viewModel,
                    isPresented: $isAddingExtraIngredient,
                    onSave: viewModel.addExtraIngredientToSelectedOrder
                )
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
                              let updatedPhoto = viewModel.selectedOrderPhotos.first(where: { $0.id == previewingPhoto.id }) else {
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
        .centeredOrderPopup(
            isPresented: isSelectingStatus,
            title: "Change Status",
            onCancel: { isSelectingStatus = false }
        ) {
            if let order = viewModel.selectedOrder {
                ForEach(OrderStatus.allCases, id: \.self) { status in
                    centeredPopupSelectionButton(
                        status.displayName,
                        isSelected: status == order.status
                    ) {
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
            showsCancelButton: false,
            onCancel: {
                isAddingPartialPayment = false
                partialPaymentAmount = ""
            }
        ) {
            TextField("Amount", text: $partialPaymentAmount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("orders.detail.payment.partial.amount")

            HStack(spacing: 16) {
                centeredPopupPillButton("Cancel") {
                    isAddingPartialPayment = false
                    partialPaymentAmount = ""
                }
                .accessibilityIdentifier("orders.detail.payment.partial.cancel")

                centeredPopupPillButton("Save") {
                    if viewModel.addPaymentToSelectedOrder(amountText: partialPaymentAmount) {
                        isAddingPartialPayment = false
                        partialPaymentAmount = ""
                    }
                }
                .accessibilityIdentifier("orders.detail.payment.partial.save")
            }
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
           let photoSource = viewModel.designPhotoSource(for: design) {
            return LinkedDesignPreview(
                title: design.name,
                sourceName: viewModel.selectedOrderDesignSourceName ?? "My Designs",
                photoSource: photoSource
            )
        }

        if let photo = viewModel.selectedOrderCustomerReferencePhoto,
           let photoSource = viewModel.orderPhotoSource(photo) {
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

                if let ingredientCost = viewModel.selectedOrderIngredientCost,
                   !ingredientCost.lines.isEmpty {
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
                    message: "Missing inventory prices for \(summary.itemsMissingPrice.joined(separator: ", ")). The total includes every ingredient cost that can be calculated.",
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
