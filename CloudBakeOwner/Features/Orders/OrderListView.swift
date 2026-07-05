import SwiftUI

struct OrderListView: View {
    @StateObject private var viewModel: OrderListViewModel
    @State private var isAddingOrder = false
    @State private var isViewingOrder = false

    init(viewModel: OrderListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if viewModel.orders.isEmpty {
                ContentUnavailableView(
                    "No orders yet",
                    systemImage: "calendar",
                    description: Text("Add accepted or draft cake orders to track due dates and customer requests.")
                )
            } else {
                Section("Orders") {
                    ForEach(viewModel.orders, id: \.id) { order in
                        Button {
                            viewModel.beginViewingOrder(order)
                            isViewingOrder = true
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(order.title)
                                    .font(.headline)
                                Text(order.customerName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text(order.dueAt.formatted(date: .abbreviated, time: .shortened))
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
                    isPresented: $isAddingOrder
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

private struct OrderDetailView: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        List {
            if let order = viewModel.selectedOrder {
                Section("Order") {
                    LabeledContent("Cake", value: order.title)
                    LabeledContent("Status", value: order.status.displayName)
                    LabeledContent("Due", value: order.dueAt.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Customer") {
                    LabeledContent("Name", value: order.customerName)
                    if order.customerId != nil {
                        LabeledContent("Record", value: "Linked")
                    }
                }

                Section("Fulfillment") {
                    LabeledContent("Type", value: order.fulfillmentType.displayName)
                    if let deliveryAddress = order.deliveryAddress {
                        LabeledContent("Address", value: deliveryAddress)
                    }
                }

                if let cakeNotes = order.cakeNotes {
                    Section("Cake Notes") {
                        Text(cakeNotes)
                    }
                }
            }
        }
        .navigationTitle(viewModel.selectedOrder?.title ?? "Order")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("orders.detail.done")
            }
        }
    }
}

private struct OrderForm: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            Section("Cake") {
                TextField("Cake Name", text: $viewModel.draftTitle)
                    .accessibilityIdentifier("orders.form.title")

                TextField("Cake Notes", text: $viewModel.draftCakeNotes, axis: .vertical)
                    .lineLimit(2...5)
                    .accessibilityIdentifier("orders.form.cakeNotes")
            }

            Section("Customer") {
                if !viewModel.customers.isEmpty {
                    Picker("Customer Record", selection: $viewModel.draftCustomerId) {
                        Text("No Linked Customer").tag("")
                        ForEach(viewModel.customers, id: \.id) { customer in
                            Text(customer.name).tag(customer.id)
                        }
                    }
                    .onChange(of: viewModel.draftCustomerId) { _, _ in
                        viewModel.applySelectedCustomer()
                    }
                    .accessibilityIdentifier("orders.form.customerRecord")
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
                    ForEach(OrderStatus.formOptions, id: \.self) { status in
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
        .navigationTitle("Add Order")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelAddOrder()
                    isPresented = false
                }
                .accessibilityIdentifier("orders.form.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.addOrder() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("orders.form.save")
            }
        }
    }
}

private extension OrderStatus {
    static let formOptions: [OrderStatus] = [.draft, .confirmed]

    var displayName: String {
        switch self {
        case .draft:
            return "Draft"
        case .confirmed:
            return "Confirmed"
        case .inProgress:
            return "In Progress"
        case .ready:
            return "Ready"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }
}

private extension OrderFulfillmentType {
    var displayName: String {
        switch self {
        case .pickup:
            return "Pickup"
        case .delivery:
            return "Delivery"
        }
    }
}
