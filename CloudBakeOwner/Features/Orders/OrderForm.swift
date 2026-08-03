import SwiftUI

struct OrderForm: View {
    let title: String
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    let statusOptions: [OrderStatus]
    let templateName: Binding<String>?
    let onCancel: () -> Void
    let onSave: () -> Bool
    @State private var isSelectingCustomer = false
    @State private var isSelectingRecipe = false
    @State private var isSelectingDesign = false
    @State private var isAddingExtraIngredient = false
    @State private var isSelectingTemplate = false
    @State private var isNamingTemplate = false
    @State private var savedTemplateName = ""

    init(
        title: String = "Add Order",
        viewModel: OrderListViewModel,
        isPresented: Binding<Bool>,
        statusOptions: [OrderStatus] = OrderStatus.addOptions,
        templateName: Binding<String>? = nil,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Bool
    ) {
        self.title = title
        self.viewModel = viewModel
        _isPresented = isPresented
        self.statusOptions = statusOptions
        self.templateName = templateName
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            if let templateName {
                Section("Template") {
                    TextField("Template Name", text: templateName)
                        .accessibilityIdentifier("orders.template.form.name")
                }
            } else if viewModel.editingOrder == nil {
                Section("Template") {
                    Button {
                        isSelectingTemplate = true
                    } label: {
                        Label(
                            viewModel.orderTemplates.isEmpty
                                ? "Manage Templates" : "Use Order Template",
                            systemImage: "square.on.square"
                        )
                    }
                    .accessibilityIdentifier("orders.form.template.choose")
                    .sheet(isPresented: $isSelectingTemplate) {
                        NavigationStack {
                            OrderTemplateLibraryView(
                                viewModel: viewModel,
                                isPresented: $isSelectingTemplate
                            )
                        }
                    }

                    Button {
                        savedTemplateName = ""
                        isNamingTemplate = true
                    } label: {
                        Label("Save Current as Template", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("orders.form.template.save")
                }
            }

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

            OrderCakeSpecificationSection(viewModel: viewModel)

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

            if !viewModel.cakeDesigns.isEmpty || !viewModel.draftCustomerReferencePhotoId.isEmpty {
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

            if templateName == nil {
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
            }

            Section("Reminders") {
                Picker(
                    "Reminder Plan",
                    selection: Binding(
                        get: { viewModel.draftReminderMode },
                        set: viewModel.selectDraftReminderMode
                    )
                ) {
                    ForEach(OrderReminderDraftMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("orders.form.reminderMode")

                if viewModel.draftReminderMode == .custom {
                    TextField(
                        "Days Before",
                        text: $viewModel.draftReminderDayOffsets
                    )
                    .keyboardType(.numbersAndPunctuation)
                    .accessibilityIdentifier("orders.form.reminderDayOffsets")

                    Toggle(
                        "Remind at the order due time",
                        isOn: $viewModel.draftReminderIncludesDueTime
                    )
                    .accessibilityIdentifier("orders.form.reminderDueTime")

                    Text("Use unique whole days from 1 to 30, separated by commas.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if viewModel.draftReminderMode == .useDefaults {
                    LabeledContent(
                        "Reminder Days",
                        value: viewModel.draftReminderDayOffsets.isEmpty
                            ? "Due time only"
                            : viewModel.draftReminderDayOffsets
                    )
                    LabeledContent(
                        "Due-time Reminder",
                        value: viewModel.draftReminderIncludesDueTime ? "On" : "Off"
                    )
                    Text("This order keeps its own copy of the default plan.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Reminders are off for this order.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Fulfillment") {
                Picker("Type", selection: $viewModel.draftFulfillmentType) {
                    ForEach(OrderFulfillmentType.allCases, id: \.self) { fulfillmentType in
                        Text(fulfillmentType.displayName).tag(fulfillmentType)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("orders.form.fulfillmentType")

                if viewModel.draftFulfillmentType == .delivery, templateName == nil {
                    TextField("Delivery Address", text: $viewModel.draftDeliveryAddress, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("orders.form.deliveryAddress")
                }
            }

            if viewModel.editingOrder == nil {
                Section("Checklist") {
                    if viewModel.draftChecklistItems.isEmpty {
                        Text("No checklist items")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("orders.form.checklist.empty")
                    } else {
                        ForEach(viewModel.draftChecklistItems) { item in
                            HStack(spacing: 12) {
                                Text(item.title)
                                Spacer()
                                Button {
                                    viewModel.deleteDraftChecklistItem(item)
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(minWidth: 44, minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Delete \(item.title)")
                                .accessibilityIdentifier("orders.form.checklist.delete.\(item.id)")
                            }
                            .accessibilityIdentifier("orders.form.checklist.item.\(item.id)")
                        }
                    }

                    HStack(spacing: 12) {
                        TextField(
                            "Checklist Item",
                            text: $viewModel.draftNewChecklistItemTitle
                        )
                        .submitLabel(.done)
                        .onSubmit(viewModel.addChecklistItemToDraftOrder)
                        .accessibilityIdentifier("orders.form.checklist.title")

                        Button(action: viewModel.addChecklistItemToDraftOrder) {
                            Image(systemName: "plus")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.cloudBakePink)
                        .disabled(
                            viewModel.draftNewChecklistItemTitle
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                        )
                        .accessibilityLabel("Add Checklist Item")
                        .accessibilityIdentifier("orders.form.checklist.add")
                    }
                }
            }

            if templateName == nil {
                Section("Pricing And Payment") {
                    if let ingredientCost = viewModel.draftIngredientCost,
                        !ingredientCost.lines.isEmpty
                    {
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

                    if viewModel.editingOrder == nil {
                        TextField("Initial Payment", text: $viewModel.draftDepositPaid)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("orders.form.depositPaid")
                    } else {
                        LabeledContent("Amount Paid") {
                            Text(
                                MoneyDisplay.formatted(
                                    viewModel.editingOrder?.depositPaid ?? 0
                                )
                            )
                        }
                        .accessibilityIdentifier("orders.form.amountPaid")
                    }

                    TextField("Payment Notes", text: $viewModel.draftPaymentNotes, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("orders.form.paymentNotes")
                }
                .onChange(of: viewModel.draftRecipeScaleMultiplier) { _, _ in
                    viewModel.refreshDraftIngredientCost()
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
                .disabled(
                    templateName.map {
                        $0.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    } ?? !viewModel.canSubmitOrderDraft
                )
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
        .cloudBakeInputPopup(
            isPresented: $isNamingTemplate,
            title: "Save Order Template",
            message: "Customer, due date, quoted price, payments, and photos are not included.",
            primaryTitle: "Save",
            primaryAccessibilityIdentifier: "orders.form.template.confirmSave",
            cancelAccessibilityIdentifier: "orders.form.template.cancelSave",
            onCancel: {
                isNamingTemplate = false
            },
            onSubmit: {
                _ = viewModel.saveCurrentDraftAsTemplate(named: savedTemplateName)
                isNamingTemplate = false
            }
        ) {
            TextField("Template Name", text: $savedTemplateName)
                .accessibilityIdentifier("orders.form.template.name")
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

private struct OrderTemplateLibraryView: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    @State private var templateBeingRenamed: OrderTemplate?
    @State private var renamedTemplateName = ""
    @State private var templatePendingDeletion: OrderTemplate?

    var body: some View {
        List {
            if viewModel.orderTemplates.isEmpty {
                ContentUnavailableView(
                    "No Order Templates",
                    systemImage: "square.on.square",
                    description: Text("Configure an order and save it as a named template.")
                )
            } else {
                ForEach(viewModel.orderTemplates) { template in
                    Button {
                        viewModel.applyOrderTemplate(template)
                        isPresented = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if !template.cakeTitle.isEmpty {
                                Text(template.cakeTitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("orders.template.use.\(template.id)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            templatePendingDeletion = template
                        }
                        .accessibilityIdentifier("orders.template.delete.\(template.id)")

                        Button("Rename") {
                            renamedTemplateName = template.name
                            templateBeingRenamed = template
                        }
                        .tint(Color.cloudBakePink)
                        .accessibilityIdentifier("orders.template.rename.\(template.id)")
                    }
                }
            }
        }
        .navigationTitle("Order Templates")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("orders.template.done")
            }
        }
        .cloudBakeInputPopup(
            isPresented: Binding(
                get: { templateBeingRenamed != nil },
                set: { if !$0 { templateBeingRenamed = nil } }
            ),
            title: "Rename Order Template",
            primaryTitle: "Save",
            primaryAccessibilityIdentifier: "orders.template.rename.save",
            cancelAccessibilityIdentifier: "orders.template.rename.cancel",
            onCancel: {
                templateBeingRenamed = nil
            },
            onSubmit: {
                if let templateBeingRenamed,
                    viewModel.renameOrderTemplate(templateBeingRenamed, to: renamedTemplateName)
                {
                    self.templateBeingRenamed = nil
                }
            }
        ) {
            TextField("Template Name", text: $renamedTemplateName)
                .accessibilityIdentifier("orders.template.rename.name")
        }
        .cloudBakeConfirmationDialog(
            isPresented: Binding(
                get: { templatePendingDeletion != nil },
                set: { if !$0 { templatePendingDeletion = nil } }
            ),
            title: "Delete Order Template?",
            message: "Existing orders are not changed.",
            cancelAccessibilityIdentifier: "orders.template.delete.cancel",
            onCancel: {
                templatePendingDeletion = nil
            }
        ) {
            nativeDialogButton("Delete", role: .destructive) {
                if let templatePendingDeletion,
                    viewModel.deleteOrderTemplate(templatePendingDeletion)
                {
                    self.templatePendingDeletion = nil
                }
            }
            .accessibilityIdentifier("orders.template.delete.confirm")
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
