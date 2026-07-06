import SwiftUI

struct OrderListView: View {
    @StateObject private var viewModel: OrderListViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isAddingOrder = false
    @State private var isViewingOrder = false
    @State private var orderScope: OrderScope = .active

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
                            OrderRow(order: order) {
                                openOrder(order)
                            }
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
                            OrderRow(order: order, showsDate: false) {
                                openOrder(order)
                            }
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

    private func openOrder(_ order: Order) {
        viewModel.beginViewingOrder(order)
        if horizontalSizeClass != .regular {
            isViewingOrder = true
        }
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

private struct OrderRow: View {
    let order: Order
    let showsDate: Bool
    let action: () -> Void

    init(order: Order, showsDate: Bool = true, action: @escaping () -> Void) {
        self.order = order
        self.showsDate = showsDate
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
                        Text(order.paymentStatus)
                            .accessibilityIdentifier("orders.detail.paymentStatus")
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
        .confirmationDialog(
            "Change status",
            isPresented: $isSelectingStatus,
            titleVisibility: .visible
        ) {
            if let order = viewModel.selectedOrder {
                ForEach(OrderStatus.allCases, id: \.self) { status in
                    Button(status.displayName) {
                        changeStatus(status, for: order)
                    }
                    .accessibilityIdentifier("orders.detail.status.\(status.rawValue)")
                }
            }

            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Deduct inventory?",
            isPresented: Binding(
                get: { statusPendingInventoryDeduction != nil },
                set: { isPresented in
                    if !isPresented {
                        statusPendingInventoryDeduction = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let status = statusPendingInventoryDeduction {
                Button("Mark \(status.displayName)") {
                    _ = viewModel.changeSelectedOrderStatus(to: status)
                    statusPendingInventoryDeduction = nil
                }
                .accessibilityIdentifier("orders.detail.confirmInventoryDeduction")
            }

            Button("Cancel", role: .cancel) {}
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

    private func formattedMoney(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
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
