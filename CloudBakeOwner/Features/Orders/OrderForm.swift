import SwiftUI

struct OrderForm: View {
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

                    TextField("Recipe Multiplier", text: $viewModel.draftRecipeScaleMultiplier)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("orders.form.recipeScaleMultiplier")
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

private extension OrderStatus {
    static let addOptions: [OrderStatus] = [.draft, .confirmed]
}
