import Foundation

@MainActor
final class OrderListViewModel: ObservableObject {
    @Published private(set) var orders: [Order] = []
    @Published private(set) var customers: [Customer] = []
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var cakeDesigns: [CakeDesign] = []
    @Published private(set) var selectedOrder: Order?
    @Published private(set) var selectedOrderCustomer: Customer?
    @Published private(set) var selectedOrderRecipe: Recipe?
    @Published private(set) var selectedOrderCakeDesign: CakeDesign?
    @Published private(set) var selectedOrderRecipeUsage: OrderRecipeUsage?
    @Published private(set) var selectedOrderExtraIngredients: [OrderExtraIngredientRow] = []
    @Published private(set) var selectedOrderChecklistItems: [OrderChecklistItem] = []
    @Published private(set) var selectedOrderPhotos: [OrderPhoto] = []
    @Published private(set) var editingOrder: Order?
    @Published private(set) var availableInventoryItems: [InventoryItem] = []
    @Published var draftTitle = ""
    @Published var draftCustomerName = ""
    @Published var draftCustomerId = ""
    @Published var draftRecipeId = ""
    @Published var draftRecipeScaleMultiplier = "1"
    @Published var draftCakeDesignId = ""
    @Published var draftChecklistItemTitle = ""
    @Published var draftDueAt = Date()
    @Published var draftStatus: OrderStatus = .draft
    @Published var draftFulfillmentType: OrderFulfillmentType = .pickup
    @Published var draftDeliveryAddress = ""
    @Published var draftCakeNotes = ""
    @Published var draftCakeMessage = ""
    @Published var draftQuotedPrice = ""
    @Published var draftDepositPaid = ""
    @Published var draftPaymentNotes = ""
    @Published var draftExtraIngredientInventoryItemId = ""
    @Published var draftExtraIngredientQuantity = ""
    @Published var draftExtraIngredientUnit: InventoryUnit = .gram
    @Published var draftExtraIngredientNote = ""
    @Published private(set) var draftExtraIngredientRows: [OrderExtraIngredientDraftRow] = []
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published private(set) var isPromotingDesign = false

    private let repository: any OrderRepository & CustomerRepository & CustomerImportantDateRepository & RecipeRepository & CakeDesignRepository & InventoryItemRepository & OrderRecipeUsageRepository & OrderStatusChangeRepository & OrderExtraIngredientRepository & OrderChecklistRepository & OrderPhotoRepository
    private let photoFileStore: OrderPhotoFileStore
    private let designPhotoLibrary: DesignPhotoLibrary
    private let idGenerator: () -> String
    private let dateProvider: () -> Date
    private let presentation: OrderListPresentation

    init(
        repository: any OrderRepository & CustomerRepository & CustomerImportantDateRepository & RecipeRepository & CakeDesignRepository & InventoryItemRepository & OrderRecipeUsageRepository & OrderStatusChangeRepository & OrderExtraIngredientRepository & OrderChecklistRepository & OrderPhotoRepository,
        photoFileStore: OrderPhotoFileStore = LocalOrderPhotoFileStore(),
        designPhotoLibrary: DesignPhotoLibrary = PhotoKitDesignPhotoLibrary(),
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.photoFileStore = photoFileStore
        self.designPhotoLibrary = designPhotoLibrary
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
        self.presentation = OrderListPresentation(
            dateProvider: dateProvider,
            calendar: calendar
        )
    }

    var calendarDays: [OrderCalendarDay] {
        presentation.calendarDays(for: visibleActiveOrders)
    }

    var activeOrders: [Order] {
        presentation.activeOrders(from: orders)
    }

    var completedOrders: [Order] {
        presentation.completedOrders(from: orders)
    }

    var visibleActiveOrders: [Order] {
        filteredOrders(activeOrders)
    }

    var visibleCompletedOrders: [Order] {
        filteredOrders(completedOrders)
    }

    var canSubmitOrderDraft: Bool {
        let input = OrderDraftValidationInput(
            title: draftTitle,
            customerName: draftCustomerName,
            recipeScaleMultiplier: draftRecipeScaleMultiplier,
            quotedPrice: draftQuotedPrice,
            depositPaid: draftDepositPaid
        )

        guard case .success = OrderDraftValidation.validate(input) else {
            return false
        }

        return true
    }

    var overdueAlert: OrderOverdueAlert? {
        presentation.primaryOverdueAlert(from: orders)
    }

    func order(id: String) -> Order? {
        orders.first { $0.id == id }
    }

    private func filteredOrders(_ source: [Order]) -> [Order] {
        let query = TextInputFormatting.normalizedSearchKey(searchText)
        guard !query.isEmpty else {
            return source
        }

        return source.filter { order in
            [
                order.title,
                order.customerName,
                order.status.displayName,
                order.fulfillmentType.displayName,
                order.deliveryAddress,
                order.cakeNotes,
                order.cakeMessage,
                order.paymentNotes
            ]
            .compactMap { $0 }
            .map(TextInputFormatting.normalizedSearchKey)
            .contains { $0.contains(query) }
        }
    }

    func whatsappMessageURL(for order: Order) -> URL? {
        guard let customerId = order.customerId,
              let customer = customers.first(where: { $0.id == customerId }) else {
            return nil
        }

        let phone = normalizedPhoneNumber(customer.phone)
        guard !phone.isEmpty else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "whatsapp"
        components.host = "send"
        components.queryItems = [
            URLQueryItem(name: "phone", value: phone),
            URLQueryItem(name: "text", value: orderMessage(for: order, customer: customer))
        ]
        return components.url
    }

    func isOverdue(_ order: Order) -> Bool {
        presentation.isOverdue(order)
    }

    var selectedCustomerReferencePhotos: [OrderPhoto] {
        presentation.customerReferencePhotos(from: selectedOrderPhotos)
    }

    var selectedFinalCakePhotos: [OrderPhoto] {
        presentation.finalCakePhotos(from: selectedOrderPhotos)
    }

    var dueReminderGroups: [OrderReminderDueGroup] {
        presentation.dueReminderGroups(for: orders)
    }

    func reminderPlan(for order: Order) -> [OrderReminderPlanItem] {
        presentation.reminderPlan(for: order)
    }

    func nextReminder(for order: Order) -> OrderReminderPlanItem? {
        presentation.nextReminder(for: order)
    }

    func load() {
        do {
            orders = try repository.fetchOrders()
            customers = try repository.fetchCustomers()
            recipes = try repository.fetchRecipes()
            cakeDesigns = try repository.fetchCakeDesigns()
            errorMessage = retryPendingDesignPhotoCleanups()
                ? nil
                : "A previous design photo cleanup will be retried automatically."
        } catch {
            errorMessage = "Orders could not be loaded."
        }
    }

    func makeCustomerListViewModel() -> CustomerListViewModel {
        CustomerListViewModel(
            repository: repository,
            idGenerator: idGenerator,
            dateProvider: dateProvider
        )
    }

    func reloadCustomers() {
        do {
            customers = try repository.fetchCustomers()
            errorMessage = nil
        } catch {
            errorMessage = "Customers could not be loaded."
        }
    }

    func beginAddingOrder() {
        resetDraft()
        draftExtraIngredientRows = []
        errorMessage = nil
        loadFormReferences()
    }

    func beginViewingOrder(_ order: Order) {
        selectedOrder = order
        errorMessage = nil
        loadSelectedOrderCustomer(for: order)
        loadSelectedOrderRecipe(for: order)
        loadSelectedOrderCakeDesign(for: order)
        loadSelectedOrderRecipeUsage(for: order)
        loadSelectedOrderExtraIngredients(for: order)
        loadSelectedOrderChecklistItems(for: order)
        loadSelectedOrderPhotos(for: order)
    }

    func closeOrderDetail() {
        selectedOrder = nil
        selectedOrderCustomer = nil
        selectedOrderRecipe = nil
        selectedOrderCakeDesign = nil
        selectedOrderRecipeUsage = nil
        selectedOrderExtraIngredients = []
        selectedOrderChecklistItems = []
        selectedOrderPhotos = []
        draftChecklistItemTitle = ""
        resetExtraIngredientDraft()
        editingOrder = nil
        errorMessage = nil
    }

    func applySelectedCustomer() {
        guard !draftCustomerId.isEmpty,
              let customer = customers.first(where: { $0.id == draftCustomerId }) else {
            return
        }

        draftCustomerName = customer.name
        if TextInputFormatting.trimmed(draftDeliveryAddress).isEmpty,
           let address = customer.address {
            draftDeliveryAddress = address
        }
    }

    func selectDraftCustomer(id: String) {
        draftCustomerId = id
        applySelectedCustomer()
    }

    func clearDraftCustomerLink() {
        draftCustomerId = ""
    }

    func draftCustomerRecordName() -> String {
        OrderReferenceSelection.customerName(for: draftCustomerId, customers: customers)
    }

    func selectDraftRecipe(id: String) {
        draftRecipeId = id
    }

    func clearDraftRecipeLink() {
        draftRecipeId = ""
        draftRecipeScaleMultiplier = "1"
        draftExtraIngredientRows = []
    }

    func draftRecipeName() -> String {
        OrderReferenceSelection.recipeName(for: draftRecipeId, recipes: recipes)
    }

    func selectDraftCakeDesign(id: String) {
        draftCakeDesignId = id
    }

    func clearDraftCakeDesignLink() {
        draftCakeDesignId = ""
    }

    func draftCakeDesignName() -> String {
        OrderReferenceSelection.cakeDesignName(for: draftCakeDesignId, cakeDesigns: cakeDesigns)
    }

    func customers(matching searchText: String) -> [Customer] {
        OrderReferenceSelection.customers(customers, matching: searchText)
    }

    func recipes(matching searchText: String) -> [Recipe] {
        OrderReferenceSelection.recipes(recipes, matching: searchText)
    }

    func cakeDesigns(matching searchText: String) -> [CakeDesign] {
        OrderReferenceSelection.cakeDesigns(cakeDesigns, matching: searchText)
    }

    func addOrder() -> Bool {
        guard let draft = validatedDraft() else {
            return false
        }

        let now = dateProvider()
        let order = Order(
            id: idGenerator(),
            customerId: draftCustomerId.isEmpty ? nil : draftCustomerId,
            cakeDesignId: draftCakeDesignId.isEmpty ? nil : draftCakeDesignId,
            recipeId: draftRecipeId.isEmpty ? nil : draftRecipeId,
            recipeScaleMultiplier: draftRecipeId.isEmpty ? 1 : draft.recipeScaleMultiplier,
            title: draft.title,
            customerName: draft.customerName,
            status: draftStatus,
            dueAt: draftDueAt,
            fulfillmentType: draftFulfillmentType,
            deliveryAddress: TextInputFormatting.optionalText(draftDeliveryAddress),
            cakeNotes: TextInputFormatting.optionalText(draftCakeNotes),
            cakeMessage: TextInputFormatting.optionalText(draftCakeMessage),
            quotedPrice: draft.quotedPrice,
            depositPaid: draft.depositPaid,
            paymentNotes: TextInputFormatting.optionalText(draftPaymentNotes),
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.save(order)
            try saveDraftExtraIngredients(for: order, updatedAt: now)
            resetDraft()
            draftExtraIngredientRows = []
            load()
            return true
        } catch {
            errorMessage = "Order could not be saved."
            return false
        }
    }

    func cancelAddOrder() {
        resetDraft()
        draftExtraIngredientRows = []
        errorMessage = nil
    }

    func beginEditingOrder() {
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return
        }

        editingOrder = selectedOrder
        draftTitle = selectedOrder.title
        draftCustomerName = selectedOrder.customerName
        draftCustomerId = selectedOrder.customerId ?? ""
        draftRecipeId = selectedOrder.recipeId ?? ""
        draftRecipeScaleMultiplier = TextInputFormatting.decimalText(selectedOrder.recipeScaleMultiplier)
        draftCakeDesignId = selectedOrder.cakeDesignId ?? ""
        draftDueAt = selectedOrder.dueAt
        draftStatus = selectedOrder.status
        draftFulfillmentType = selectedOrder.fulfillmentType
        draftDeliveryAddress = selectedOrder.deliveryAddress ?? ""
        draftCakeNotes = selectedOrder.cakeNotes ?? ""
        draftCakeMessage = selectedOrder.cakeMessage ?? ""
        draftQuotedPrice = TextInputFormatting.decimalText(selectedOrder.quotedPrice)
        draftDepositPaid = TextInputFormatting.decimalText(selectedOrder.depositPaid)
        draftPaymentNotes = selectedOrder.paymentNotes ?? ""
        errorMessage = nil
        loadFormReferences()
        loadSelectedOrderExtraIngredients(for: selectedOrder)
        draftExtraIngredientRows = selectedOrderExtraIngredients.map { OrderExtraIngredientDraftRow(row: $0) }
    }

    var editedOrderRequiresInventoryDeductionConfirmation: Bool {
        guard let editingOrder else {
            return false
        }

        return shouldRecordRecipeUsage(from: editingOrder.status, to: draftStatus) &&
            !draftRecipeId.isEmpty &&
            selectedOrderRecipeUsage == nil
    }

    func saveEditedOrder(confirmingRecipeUsage: Bool = false) -> Bool {
        guard let editingOrder else {
            errorMessage = "Order could not be found."
            return false
        }
        guard let draft = validatedDraft() else {
            return false
        }

        if editedOrderRequiresInventoryDeductionConfirmation && !confirmingRecipeUsage {
            errorMessage = "Confirm inventory deduction before saving."
            return false
        }

        let now = dateProvider()
        let order = Order(
            id: editingOrder.id,
            customerId: draftCustomerId.isEmpty ? nil : draftCustomerId,
            cakeDesignId: draftCakeDesignId.isEmpty ? nil : draftCakeDesignId,
            recipeId: draftRecipeId.isEmpty ? nil : draftRecipeId,
            recipeScaleMultiplier: draftRecipeId.isEmpty ? 1 : draft.recipeScaleMultiplier,
            title: draft.title,
            customerName: draft.customerName,
            status: draftStatus,
            dueAt: draftDueAt,
            fulfillmentType: draftFulfillmentType,
            deliveryAddress: TextInputFormatting.optionalText(draftDeliveryAddress),
            cakeNotes: TextInputFormatting.optionalText(draftCakeNotes),
            cakeMessage: TextInputFormatting.optionalText(draftCakeMessage),
            quotedPrice: draft.quotedPrice,
            depositPaid: draft.depositPaid,
            paymentNotes: TextInputFormatting.optionalText(draftPaymentNotes),
            createdAt: editingOrder.createdAt,
            updatedAt: now
        )

        do {
            let savedOrder: Order
            if shouldRecordRecipeUsage(from: editingOrder.status, to: order.status), order.recipeId != nil {
                let orderBeforeStatusChange = Order(
                    id: order.id,
                    customerId: order.customerId,
                    cakeDesignId: order.cakeDesignId,
                    recipeId: order.recipeId,
                    recipeScaleMultiplier: order.recipeScaleMultiplier,
                    title: order.title,
                    customerName: order.customerName,
                    status: editingOrder.status,
                    dueAt: order.dueAt,
                    fulfillmentType: order.fulfillmentType,
                    deliveryAddress: order.deliveryAddress,
                    cakeNotes: order.cakeNotes,
                    cakeMessage: order.cakeMessage,
                    quotedPrice: order.quotedPrice,
                    depositPaid: order.depositPaid,
                    paymentNotes: order.paymentNotes,
                    createdAt: order.createdAt,
                    updatedAt: order.updatedAt
                )
                savedOrder = try repository.changeOrderStatus(
                    order: orderBeforeStatusChange,
                    status: order.status,
                    updatedAt: now,
                    usageId: idGenerator(),
                    extraIngredients: draftExtraIngredients(for: orderBeforeStatusChange, updatedAt: now),
                    transactionIdProvider: idGenerator
                )
            } else {
                try repository.save(order)
                try saveDraftExtraIngredients(for: order, updatedAt: now)
                savedOrder = order
            }
            selectedOrder = savedOrder
            self.editingOrder = nil
            resetDraft()
            draftExtraIngredientRows = []
            load()
            loadSelectedOrderCustomer(for: savedOrder)
            loadSelectedOrderRecipe(for: savedOrder)
            loadSelectedOrderCakeDesign(for: savedOrder)
            loadSelectedOrderRecipeUsage(for: savedOrder)
            loadSelectedOrderExtraIngredients(for: savedOrder)
            loadSelectedOrderChecklistItems(for: savedOrder)
            loadSelectedOrderPhotos(for: savedOrder)
            return true
        } catch let error as OrderRecipeUsageError {
            errorMessage = recipeUsageErrorMessage(for: error)
            return false
        } catch {
            errorMessage = "Order could not be saved."
            return false
        }
    }

    func changeSelectedOrderStatus(to status: OrderStatus) -> Bool {
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return false
        }

        return changeOrderStatus(selectedOrder, to: status)
    }

    func changeOrderStatus(_ order: Order, to status: OrderStatus) -> Bool {
        guard order.status != status else {
            return true
        }

        do {
            let now = dateProvider()
            let updatedOrder = try repository.changeOrderStatus(
                order: order,
                status: status,
                updatedAt: now,
                usageId: idGenerator(),
                extraIngredients: nil,
                transactionIdProvider: idGenerator
            )
            refreshAfterSavingOrder(updatedOrder)
            errorMessage = nil
            return true
        } catch let error as OrderRecipeUsageError {
            errorMessage = recipeUsageErrorMessage(for: error)
            return false
        } catch {
            errorMessage = "Order status could not be updated."
            return false
        }
    }

    func markOrderPaid(_ order: Order) -> Bool {
        switch OrderPaymentUpdate.markingPaid(order, updatedAt: dateProvider()) {
        case .success(let updatedOrder):
            return savePaymentUpdate(updatedOrder)
        case .failure(let error):
            errorMessage = error.message
            return false
        }
    }

    func markSelectedOrderPaid() -> Bool {
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return false
        }

        return markOrderPaid(selectedOrder)
    }

    func addPayment(to order: Order, amountText: String) -> Bool {
        switch OrderPaymentUpdate.addingPayment(
            amountText,
            to: order,
            updatedAt: dateProvider()
        ) {
        case .success(let updatedOrder):
            return savePaymentUpdate(updatedOrder)
        case .failure(let error):
            errorMessage = error.message
            return false
        }
    }

    private func savePaymentUpdate(_ updatedOrder: Order) -> Bool {
        do {
            try repository.save(updatedOrder)
            refreshAfterSavingOrder(updatedOrder)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Payment could not be updated."
            return false
        }
    }

    func addPaymentToSelectedOrder(amountText: String) -> Bool {
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return false
        }

        return addPayment(to: selectedOrder, amountText: amountText)
    }

    func beginAddingExtraIngredient() {
        loadAvailableInventoryItems()
        resetExtraIngredientDraft(keepingInventoryItems: true)
        if let firstItem = availableInventoryItems.first {
            draftExtraIngredientInventoryItemId = firstItem.id
            draftExtraIngredientUnit = firstItem.unit
        }
        errorMessage = nil
    }

    func updateDraftExtraIngredientUnitForSelectedInventoryItem() {
        guard let item = availableInventoryItems.first(where: { $0.id == draftExtraIngredientInventoryItemId }) else {
            return
        }

        draftExtraIngredientUnit = item.unit
    }

    func addExtraIngredientToSelectedOrder() -> Bool {
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return false
        }
        guard let draft = validatedExtraIngredientDraft() else {
            return false
        }

        let now = dateProvider()
        let ingredient = OrderExtraIngredient(
            id: idGenerator(),
            orderId: selectedOrder.id,
            inventoryItemId: draft.inventoryItemId,
            quantity: draft.quantity,
            unit: draft.unit,
            note: draft.note,
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.save(ingredient)
            resetExtraIngredientDraft()
            loadSelectedOrderExtraIngredients(for: selectedOrder)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Extra ingredient could not be saved."
            return false
        }
    }

    func addExtraIngredientToDraftOrder() -> Bool {
        guard let draft = validatedExtraIngredientDraft() else {
            return false
        }

        let inventoryItemName = availableInventoryItems
            .first(where: { $0.id == draft.inventoryItemId })?
            .name ?? "Inventory item unavailable"
        draftExtraIngredientRows.append(
            OrderExtraIngredientDraftRow(
                id: idGenerator(),
                existingIngredient: nil,
                inventoryItemId: draft.inventoryItemId,
                inventoryItemName: inventoryItemName,
                quantity: draft.quantity,
                unit: draft.unit,
                note: draft.note
            )
        )
        resetExtraIngredientDraft(keepingInventoryItems: true)
        errorMessage = nil
        return true
    }

    func deleteDraftExtraIngredient(_ row: OrderExtraIngredientDraftRow) {
        draftExtraIngredientRows.removeAll { $0.id == row.id }
    }

    func deleteExtraIngredient(_ row: OrderExtraIngredientRow) -> Bool {
        do {
            try repository.deleteOrderExtraIngredient(id: row.ingredient.id)
            if let selectedOrder {
                loadSelectedOrderExtraIngredients(for: selectedOrder)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Extra ingredient could not be deleted."
            return false
        }
    }

    func cancelExtraIngredientEdit() {
        resetExtraIngredientDraft()
        errorMessage = nil
    }

    private func refreshAfterSavingOrder(_ order: Order) {
        if selectedOrder?.id == order.id {
            selectedOrder = order
            loadSelectedOrderCustomer(for: order)
            loadSelectedOrderRecipe(for: order)
            loadSelectedOrderCakeDesign(for: order)
            loadSelectedOrderRecipeUsage(for: order)
            loadSelectedOrderExtraIngredients(for: order)
            loadSelectedOrderChecklistItems(for: order)
            loadSelectedOrderPhotos(for: order)
        }

        load()
    }

    private func copy(
        _ order: Order,
        status: OrderStatus? = nil,
        cakeDesignId: String? = nil,
        depositPaid: Decimal? = nil,
        updatedAt: Date
    ) -> Order {
        Order(
            id: order.id,
            customerId: order.customerId,
            cakeDesignId: cakeDesignId ?? order.cakeDesignId,
            recipeId: order.recipeId,
            recipeScaleMultiplier: order.recipeScaleMultiplier,
            title: order.title,
            customerName: order.customerName,
            status: status ?? order.status,
            dueAt: order.dueAt,
            fulfillmentType: order.fulfillmentType,
            deliveryAddress: order.deliveryAddress,
            cakeNotes: order.cakeNotes,
            cakeMessage: order.cakeMessage,
            quotedPrice: order.quotedPrice,
            depositPaid: depositPaid ?? order.depositPaid,
            paymentNotes: order.paymentNotes,
            createdAt: order.createdAt,
            updatedAt: updatedAt
        )
    }

    func addChecklistItemToSelectedOrder() -> Bool {
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return false
        }

        let title = TextInputFormatting.trimmed(draftChecklistItemTitle)
        guard !title.isEmpty else {
            errorMessage = "Checklist item is required."
            return false
        }

        let now = dateProvider()
        let nextSortOrder = (selectedOrderChecklistItems.map(\.sortOrder).max() ?? -1) + 1
        let item = OrderChecklistItem(
            id: idGenerator(),
            orderId: selectedOrder.id,
            title: title,
            isCompleted: false,
            sortOrder: nextSortOrder,
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.save(item)
            draftChecklistItemTitle = ""
            loadSelectedOrderChecklistItems(for: selectedOrder)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Checklist item could not be saved."
            return false
        }
    }

    func toggleChecklistItem(_ item: OrderChecklistItem) -> Bool {
        let updatedItem = OrderChecklistItem(
            id: item.id,
            orderId: item.orderId,
            title: item.title,
            isCompleted: !item.isCompleted,
            sortOrder: item.sortOrder,
            createdAt: item.createdAt,
            updatedAt: dateProvider()
        )

        do {
            try repository.save(updatedItem)
            if let selectedOrder {
                loadSelectedOrderChecklistItems(for: selectedOrder)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Checklist item could not be updated."
            return false
        }
    }

    func updateChecklistItemTitle(_ item: OrderChecklistItem, title: String) -> Bool {
        let trimmedTitle = TextInputFormatting.trimmed(title)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Checklist item is required."
            return false
        }

        let updatedItem = OrderChecklistItem(
            id: item.id,
            orderId: item.orderId,
            title: trimmedTitle,
            isCompleted: item.isCompleted,
            sortOrder: item.sortOrder,
            createdAt: item.createdAt,
            updatedAt: dateProvider()
        )

        do {
            try repository.save(updatedItem)
            if let selectedOrder {
                loadSelectedOrderChecklistItems(for: selectedOrder)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Checklist item could not be updated."
            return false
        }
    }

    func deleteChecklistItem(_ item: OrderChecklistItem) -> Bool {
        do {
            try repository.deleteOrderChecklistItem(id: item.id)
            if let selectedOrder {
                loadSelectedOrderChecklistItems(for: selectedOrder)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Checklist item could not be deleted."
            return false
        }
    }

    func addOrderPhoto(kind: OrderPhotoKind, imageData: Data, caption: String? = nil) -> Bool {
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return false
        }
        guard !imageData.isEmpty else {
            errorMessage = "Order photo is required."
            return false
        }

        let photoId = idGenerator()
        let now = dateProvider()
        var savedRelativePath: String?

        do {
            let relativePath = try photoFileStore.saveOrderPhoto(
                data: imageData,
                orderId: selectedOrder.id,
                photoId: photoId
            )
            savedRelativePath = relativePath
            let photo = OrderPhoto(
                id: photoId,
                orderId: selectedOrder.id,
                kind: kind,
                localPhotoPath: relativePath,
                caption: TextInputFormatting.optionalText(caption ?? ""),
                createdAt: now,
                updatedAt: now
            )
            try repository.save(photo)
            loadSelectedOrderPhotos(for: selectedOrder)
            errorMessage = nil
            return true
        } catch {
            if let savedRelativePath {
                try? photoFileStore.deleteOrderPhoto(relativePath: savedRelativePath)
            }
            errorMessage = "Order photo could not be saved."
            return false
        }
    }

    func deleteOrderPhoto(_ photo: OrderPhoto) -> Bool {
        do {
            try repository.deleteOrderPhoto(id: photo.id)
            try photoFileStore.deleteOrderPhoto(relativePath: photo.localPhotoPath)
            if let selectedOrder {
                loadSelectedOrderPhotos(for: selectedOrder)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Order photo could not be deleted."
            return false
        }
    }

    func updateOrderPhotoCaption(_ photo: OrderPhoto, caption: String) -> Bool {
        let updatedPhoto = OrderPhoto(
            id: photo.id,
            orderId: photo.orderId,
            kind: photo.kind,
            localPhotoPath: photo.localPhotoPath,
            caption: TextInputFormatting.optionalText(caption),
            createdAt: photo.createdAt,
            updatedAt: dateProvider()
        )

        do {
            try repository.save(updatedPhoto)
            if let selectedOrder {
                loadSelectedOrderPhotos(for: selectedOrder)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Order photo caption could not be saved."
            return false
        }
    }

    func promoteFinalCakePhotoToDesign(_ photo: OrderPhoto, name: String, notes: String) async -> Bool {
        guard let selectedOrder, selectedOrder.id == photo.orderId else {
            errorMessage = "Order could not be found."
            return false
        }
        guard photo.kind == .finalCake else {
            errorMessage = "Only final cake photos can be saved as designs."
            return false
        }
        guard let designName = TextInputFormatting.optionalText(name) else {
            errorMessage = "Design name is required."
            return false
        }
        guard !isPromotingDesign else {
            errorMessage = "Design is already being saved."
            return false
        }
        isPromotingDesign = true
        defer { isPromotingDesign = false }

        let photoReference: String
        do {
            photoReference = try await designPhotoLibrary.savePhoto(at: orderPhotoURL(photo))
        } catch {
            errorMessage = "Design photo could not be saved to Photos."
            return false
        }

        let now = dateProvider()
        let designId = idGenerator()
        let design = CakeDesign(
            id: designId,
            name: designName,
            notes: TextInputFormatting.optionalText(notes),
            photoReference: photoReference,
            sourceKind: .ownerMade,
            originatingOrderPhotoId: photo.id,
            originatingOrderId: selectedOrder.id,
            createdAt: now,
            updatedAt: now
        )
        let updatedOrder = copy(
            selectedOrder,
            cakeDesignId: designId,
            updatedAt: now
        )
        let migratedPhoto = OrderPhoto(
            id: photo.id,
            orderId: photo.orderId,
            kind: photo.kind,
            localPhotoPath: photoReference,
            caption: photo.caption,
            createdAt: photo.createdAt,
            updatedAt: now
        )

        do {
            try repository.savePromotedDesign(
                design,
                linking: updatedOrder,
                photo: migratedPhoto,
                cleanupRelativePath: photo.localPhotoPath
            )
            let didCleanup = cleanupDesignPhoto(at: photo.localPhotoPath)
            refreshAfterSavingOrder(updatedOrder)
            errorMessage = didCleanup
                ? nil
                : "Design saved. The old local photo copy will be removed automatically."
            return true
        } catch {
            errorMessage = "Design could not be saved."
            return false
        }
    }

    func orderPhotoURL(_ photo: OrderPhoto) -> URL {
        photoFileStore.fileURL(for: photo.localPhotoPath)
    }

    func orderPhotoSource(_ photo: OrderPhoto) -> CakeDesignPhotoSource? {
        if let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(from: photo.localPhotoPath) {
            return designPhotoLibrary.containsAsset(identifier: identifier) ? .photosAsset(identifier) : nil
        }
        let url = orderPhotoURL(photo)
        return FileManager.default.fileExists(atPath: url.path) ? .legacyFile(url) : nil
    }

    private func retryPendingDesignPhotoCleanups() -> Bool {
        guard let paths = try? repository.fetchPendingDesignPhotoCleanupPaths() else {
            return false
        }
        return paths.reduce(true) { result, path in
            cleanupDesignPhoto(at: path) && result
        }
    }

    private func cleanupDesignPhoto(at relativePath: String) -> Bool {
        do {
            try photoFileStore.deleteOrderPhoto(relativePath: relativePath)
            try repository.deletePendingDesignPhotoCleanupPath(relativePath)
            return true
        } catch {
            return false
        }
    }

    func cancelEditingOrder() {
        editingOrder = nil
        resetDraft()
        resetExtraIngredientDraft()
        draftExtraIngredientRows = []
        errorMessage = nil
    }

    private func loadFormReferences() {
        do {
            customers = try repository.fetchCustomers()
            recipes = try repository.fetchRecipes()
            cakeDesigns = try repository.fetchCakeDesigns()
            availableInventoryItems = try repository.fetchInventoryItems()
        } catch {
            customers = []
            recipes = []
            cakeDesigns = []
            availableInventoryItems = []
            errorMessage = "Order form references could not be loaded."
        }
    }

    private func loadAvailableInventoryItems() {
        do {
            availableInventoryItems = try repository.fetchInventoryItems()
        } catch {
            availableInventoryItems = []
            errorMessage = "Inventory items could not be loaded."
        }
    }

    private func loadSelectedOrderCustomer(for order: Order) {
        guard let customerId = order.customerId else {
            selectedOrderCustomer = nil
            return
        }

        do {
            selectedOrderCustomer = try repository.fetchCustomer(id: customerId)
        } catch {
            selectedOrderCustomer = nil
            errorMessage = "Customer details could not be loaded."
        }
    }

    private func orderMessage(for order: Order, customer: Customer) -> String {
        """
        Hi \(firstName(from: customer.name)), this is regarding your CloudBake order.

        Order: \(order.title)
        Due: \(order.dueAt.formatted(date: .abbreviated, time: .shortened))

        Thank you!
        """
    }

    private func firstName(from name: String) -> String {
        TextInputFormatting.trimmed(name)
            .split(separator: " ")
            .first
            .map(String.init) ?? name
    }

    private func normalizedPhoneNumber(_ phone: String) -> String {
        let trimmed = TextInputFormatting.trimmed(phone)
        let digits = trimmed.filter(\.isNumber)
        guard !digits.isEmpty else {
            return ""
        }

        if trimmed.hasPrefix("+") {
            return "+" + digits
        }

        return String(digits)
    }

    private func loadSelectedOrderRecipe(for order: Order) {
        guard let recipeId = order.recipeId else {
            selectedOrderRecipe = nil
            return
        }

        do {
            selectedOrderRecipe = try repository.fetchRecipe(id: recipeId)
        } catch {
            selectedOrderRecipe = nil
            errorMessage = "Recipe details could not be loaded."
        }
    }

    private func loadSelectedOrderCakeDesign(for order: Order) {
        guard let cakeDesignId = order.cakeDesignId else {
            selectedOrderCakeDesign = nil
            return
        }

        do {
            selectedOrderCakeDesign = try repository.fetchCakeDesign(id: cakeDesignId)
        } catch {
            selectedOrderCakeDesign = nil
            errorMessage = "Design reference could not be loaded."
        }
    }

    private func loadSelectedOrderRecipeUsage(for order: Order) {
        do {
            selectedOrderRecipeUsage = try repository.fetchOrderRecipeUsage(orderId: order.id)
        } catch {
            selectedOrderRecipeUsage = nil
            errorMessage = "Recipe usage details could not be loaded."
        }
    }

    private func loadSelectedOrderExtraIngredients(for order: Order) {
        do {
            let inventoryItems = try repository.fetchInventoryItems()
            let itemNamesById = Dictionary(uniqueKeysWithValues: inventoryItems.map { ($0.id, $0.name) })
            selectedOrderExtraIngredients = try repository.fetchOrderExtraIngredients(orderId: order.id).map { ingredient in
                OrderExtraIngredientRow(
                    ingredient: ingredient,
                    inventoryItemName: itemNamesById[ingredient.inventoryItemId] ?? "Inventory item unavailable"
                )
            }
            availableInventoryItems = inventoryItems
        } catch {
            selectedOrderExtraIngredients = []
            errorMessage = "Extra ingredients could not be loaded."
        }
    }

    private func saveDraftExtraIngredients(for order: Order, updatedAt: Date) throws {
        let existingIngredients = try repository.fetchOrderExtraIngredients(orderId: order.id)
        guard order.recipeId != nil else {
            for ingredient in existingIngredients {
                try repository.deleteOrderExtraIngredient(id: ingredient.id)
            }
            return
        }

        let keptExistingIds = Set(draftExtraIngredientRows.compactMap { $0.existingIngredient?.id })
        for ingredient in existingIngredients where !keptExistingIds.contains(ingredient.id) {
            try repository.deleteOrderExtraIngredient(id: ingredient.id)
        }

        for row in draftExtraIngredientRows where row.existingIngredient == nil {
            try repository.save(draftExtraIngredient(from: row, order: order, updatedAt: updatedAt))
        }
    }

    private func draftExtraIngredients(for order: Order, updatedAt: Date) -> [OrderExtraIngredient] {
        guard order.recipeId != nil else {
            return []
        }

        return draftExtraIngredientRows.map { row in
            draftExtraIngredient(from: row, order: order, updatedAt: updatedAt)
        }
    }

    private func draftExtraIngredient(
        from row: OrderExtraIngredientDraftRow,
        order: Order,
        updatedAt: Date
    ) -> OrderExtraIngredient {
        OrderExtraIngredient(
            id: row.id,
            orderId: order.id,
            inventoryItemId: row.inventoryItemId,
            quantity: row.quantity,
            unit: row.unit,
            note: row.note,
            createdAt: row.existingIngredient?.createdAt ?? updatedAt,
            updatedAt: updatedAt
        )
    }

    private func loadSelectedOrderChecklistItems(for order: Order) {
        do {
            selectedOrderChecklistItems = try repository.fetchOrderChecklistItems(orderId: order.id)
                .sorted(by: OrderListPresentation.checklistItemWasEnteredBefore)
        } catch {
            selectedOrderChecklistItems = []
            errorMessage = "Checklist could not be loaded."
        }
    }

    private func loadSelectedOrderPhotos(for order: Order) {
        do {
            selectedOrderPhotos = try repository.fetchOrderPhotos(orderId: order.id)
        } catch {
            selectedOrderPhotos = []
            errorMessage = "Order photos could not be loaded."
        }
    }

    private func shouldRecordRecipeUsage(from currentStatus: OrderStatus, to newStatus: OrderStatus) -> Bool {
        currentStatus == .confirmed && (newStatus == .ready || newStatus == .completed)
    }

    private func recipeUsageErrorMessage(for error: OrderRecipeUsageError) -> String {
        switch error {
        case .orderHasNoLinkedRecipe:
            return "Link a recipe before using it."
        case .alreadyRecorded:
            return "Recipe has already been used for this order."
        case .recipeHasNoIngredients:
            return "Recipe has no ingredients to deduct."
        case .missingInventoryItem:
            return "Recipe ingredient inventory item could not be found."
        case .incompatibleIngredientUnit(let itemName):
            return "\(itemName) has an incompatible recipe unit."
        case .insufficientStock(let itemName):
            return "Not enough \(itemName) in inventory."
        }
    }

    private func resetDraft() {
        draftTitle = ""
        draftCustomerName = ""
        draftCustomerId = ""
        draftRecipeId = ""
        draftRecipeScaleMultiplier = "1"
        draftCakeDesignId = ""
        draftDueAt = dateProvider()
        draftStatus = .draft
        draftFulfillmentType = .pickup
        draftDeliveryAddress = ""
        draftCakeNotes = ""
        draftCakeMessage = ""
        draftQuotedPrice = ""
        draftDepositPaid = ""
        draftPaymentNotes = ""
    }

    private func resetExtraIngredientDraft(keepingInventoryItems: Bool = false) {
        if !keepingInventoryItems {
            availableInventoryItems = []
        }
        draftExtraIngredientInventoryItemId = ""
        draftExtraIngredientQuantity = ""
        draftExtraIngredientUnit = .gram
        draftExtraIngredientNote = ""
    }

    private func validatedDraft() -> ValidatedOrderDraft? {
        let input = OrderDraftValidationInput(
            title: draftTitle,
            customerName: draftCustomerName,
            recipeScaleMultiplier: draftRecipeScaleMultiplier,
            quotedPrice: draftQuotedPrice,
            depositPaid: draftDepositPaid
        )

        switch OrderDraftValidation.validate(input) {
        case .success(let draft):
            return draft
        case .failure(let error):
            errorMessage = error.message
            return nil
        }
    }

    private func validatedExtraIngredientDraft() -> ValidatedOrderExtraIngredientDraft? {
        guard availableInventoryItems.contains(where: { $0.id == draftExtraIngredientInventoryItemId }) else {
            errorMessage = "Choose an inventory item."
            return nil
        }

        guard let quantity = Double(TextInputFormatting.trimmed(draftExtraIngredientQuantity)), quantity > 0 else {
            errorMessage = "Extra ingredient quantity must be greater than zero."
            return nil
        }

        return ValidatedOrderExtraIngredientDraft(
            inventoryItemId: draftExtraIngredientInventoryItemId,
            quantity: quantity,
            unit: draftExtraIngredientUnit,
            note: TextInputFormatting.optionalText(draftExtraIngredientNote)
        )
    }
}

struct OrderExtraIngredientRow: Identifiable, Equatable {
    let ingredient: OrderExtraIngredient
    let inventoryItemName: String

    var id: String {
        ingredient.id
    }
}

struct OrderExtraIngredientDraftRow: Identifiable, Equatable {
    let id: String
    let existingIngredient: OrderExtraIngredient?
    let inventoryItemId: String
    let inventoryItemName: String
    let quantity: Double
    let unit: InventoryUnit
    let note: String?

    init(
        id: String,
        existingIngredient: OrderExtraIngredient?,
        inventoryItemId: String,
        inventoryItemName: String,
        quantity: Double,
        unit: InventoryUnit,
        note: String?
    ) {
        self.id = id
        self.existingIngredient = existingIngredient
        self.inventoryItemId = inventoryItemId
        self.inventoryItemName = inventoryItemName
        self.quantity = quantity
        self.unit = unit
        self.note = note
    }

    init(row: OrderExtraIngredientRow) {
        self.id = row.ingredient.id
        self.existingIngredient = row.ingredient
        self.inventoryItemId = row.ingredient.inventoryItemId
        self.inventoryItemName = row.inventoryItemName
        self.quantity = row.ingredient.quantity
        self.unit = row.ingredient.unit
        self.note = row.ingredient.note
    }
}

private struct ValidatedOrderExtraIngredientDraft {
    let inventoryItemId: String
    let quantity: Double
    let unit: InventoryUnit
    let note: String?
}
