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
    @State private var isAddingExtraIngredient = false

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

                TextField("Message", text: $viewModel.draftCakeMessage, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("orders.form.cakeMessage")
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

                    if !viewModel.draftRecipeId.isEmpty {
                        extraIngredientsContent
                    }
                }
            }

            if !viewModel.cakeDesigns.isEmpty
                || !viewModel.designCustomerReferences.isEmpty
                || !viewModel.draftCustomerReferencePhotoId.isEmpty {
                Section("Design") {
                    Button {
                        isSelectingDesign = true
                    } label: {
                        LabeledContent("Linked Design", value: viewModel.draftDesignReferenceName)
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
                if let ingredientCost = viewModel.draftIngredientCost,
                   !ingredientCost.lines.isEmpty {
                    LabeledContent(
                        viewModel.draftIngredientCostIsActual
                            ? "Actual Ingredient Cost"
                            : "Estimated Ingredient Cost"
                    ) {
                        Text(MoneyDisplay.formatted(ingredientCost.knownCost))
                            .fontWeight(.semibold)
                    }
                    .accessibilityIdentifier("orders.form.ingredientCost")

                    if !ingredientCost.itemsMissingPrice.isEmpty {
                        Label(
                            "Partial total — missing prices for \(ingredientCost.itemsMissingPrice.joined(separator: ", "))",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("orders.form.ingredientCost.warning")
                    }
                }

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
            .onChange(of: viewModel.draftRecipeScaleMultiplier) { _, _ in
                viewModel.refreshDraftIngredientCost()
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("orders.form.error")
                }
            }
        }
        .cloudBakeFormScreenStyle()
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
                .disabled(!viewModel.canSubmitOrderDraft)
                .accessibilityIdentifier("orders.form.save")
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
                    onSave: viewModel.addExtraIngredientToDraftOrder
                )
            }
        }
    }

    @ViewBuilder
    private var extraIngredientsContent: some View {
        if !viewModel.draftExtraIngredientRows.isEmpty {
            ForEach(viewModel.draftExtraIngredientRows) { row in
                OrderFormExtraIngredientRow(
                    row: row,
                    canDelete: viewModel.selectedOrderRecipeUsage == nil,
                    onDelete: {
                        viewModel.deleteDraftExtraIngredient(row)
                    }
                )
            }
        } else {
            Text("No extra ingredients")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("orders.form.extraIngredient.empty")
        }

        if viewModel.selectedOrderRecipeUsage == nil {
            Button {
                viewModel.beginAddingExtraIngredient()
                isAddingExtraIngredient = true
            } label: {
                Label("Add Extra Ingredient", systemImage: "plus")
            }
            .foregroundStyle(Color.cloudBakePink)
            .accessibilityIdentifier("orders.form.extraIngredient.add")
        }
    }
}

private struct OrderFormExtraIngredientRow: View {
    let row: OrderExtraIngredientDraftRow
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.inventoryItemName)
                    .font(.subheadline.weight(.semibold))
                Text("\(row.quantity.formatted()) \(row.unit.displayName)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let note = row.note {
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
                .accessibilityIdentifier("orders.form.extraIngredient.delete.\(row.id)")
            }
        }
        .accessibilityIdentifier("orders.form.extraIngredient.\(row.id)")
    }
}

private extension OrderStatus {
    static let addOptions: [OrderStatus] = [.draft, .confirmed]
}
