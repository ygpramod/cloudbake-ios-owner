import SwiftUI

struct OrderListView: View {
    @StateObject private var viewModel: OrderListViewModel
    @State private var isAddingOrder = false
    @State private var isViewingOrder = false
    @State private var displayMode: OrderDisplayMode = .list

    init(viewModel: OrderListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if !viewModel.dueReminderGroups.isEmpty {
                Section {
                    ForEach(viewModel.dueReminderGroups, id: \.order.id) { group in
                        Button {
                            viewModel.beginViewingOrder(group.order)
                            isViewingOrder = true
                        } label: {
                            OrderReminderDueRow(group: group)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("orders.reminder.\(group.order.id)")
                        .accessibilityLabel("Reminder due for \(group.order.title)")
                    }
                } header: {
                    Text("Reminders Due")
                        .accessibilityIdentifier("orders.remindersDue.header")
                }
            }

            Section {
                Picker("Order View", selection: $displayMode) {
                    ForEach(OrderDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("orders.displayMode")
            }

            if viewModel.orders.isEmpty {
                ContentUnavailableView(
                    "No orders yet",
                    systemImage: "calendar",
                    description: Text("Add accepted or draft cake orders to track due dates and customer requests.")
                )
            } else {
                switch displayMode {
                case .list:
                    Section("Orders") {
                        ForEach(viewModel.orders, id: \.id) { order in
                            OrderRow(order: order) {
                                viewModel.beginViewingOrder(order)
                                isViewingOrder = true
                            }
                        }
                    }
                case .calendar:
                    ForEach(viewModel.calendarDays, id: \.day) { calendarDay in
                        Section(calendarDay.day.formatted(date: .complete, time: .omitted)) {
                            ForEach(calendarDay.orders, id: \.id) { order in
                                OrderRow(order: order, showsDate: false) {
                                    viewModel.beginViewingOrder(order)
                                    isViewingOrder = true
                                }
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
        .navigationTitle("Orders")
        .toolbar {
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
}

private enum OrderDisplayMode: CaseIterable {
    case list
    case calendar

    var title: String {
        switch self {
        case .list:
            return "List"
        case .calendar:
            return "Calendar"
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
                Text(order.title)
                    .font(.headline)
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
    @State private var isEditingOrder = false

    var body: some View {
        List {
            if let order = viewModel.selectedOrder {
                Section("Order") {
                    LabeledContent("Cake") {
                        Text(order.title)
                            .accessibilityIdentifier("orders.detail.cake")
                    }
                    LabeledContent("Status") {
                        Text(order.status.displayName)
                            .accessibilityIdentifier("orders.detail.status")
                    }
                    LabeledContent("Due") {
                        Text(order.dueAt.formatted(date: .abbreviated, time: .shortened))
                            .accessibilityIdentifier("orders.detail.due")
                    }
                }

                Section("Reminders") {
                    ForEach(viewModel.reminderPlan(for: order), id: \.offsetDays) { reminder in
                        LabeledContent(reminder.title) {
                            Text(reminder.remindAt.formatted(date: .abbreviated, time: .shortened))
                                .accessibilityIdentifier("orders.detail.reminder.\(reminder.offsetDays)")
                        }
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

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("orders.detail.done")
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
                    onSave: viewModel.saveEditedOrder
                )
            }
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
