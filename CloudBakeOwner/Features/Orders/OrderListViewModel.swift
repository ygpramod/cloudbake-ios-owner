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
    @Published private(set) var selectedOrderChecklistItems: [OrderChecklistItem] = []
    @Published private(set) var selectedOrderPhotos: [OrderPhoto] = []
    @Published private(set) var editingOrder: Order?
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
    @Published var draftQuotedPrice = ""
    @Published var draftDepositPaid = ""
    @Published var draftPaymentNotes = ""
    @Published var errorMessage: String?

    private let repository: any OrderRepository & CustomerRepository & RecipeRepository & CakeDesignRepository & OrderRecipeUsageRepository & OrderStatusChangeRepository & OrderChecklistRepository & OrderPhotoRepository
    private let photoFileStore: OrderPhotoFileStore
    private let idGenerator: () -> String
    private let dateProvider: () -> Date
    private let presentation: OrderListPresentation

    init(
        repository: any OrderRepository & CustomerRepository & RecipeRepository & CakeDesignRepository & OrderRecipeUsageRepository & OrderStatusChangeRepository & OrderChecklistRepository & OrderPhotoRepository,
        photoFileStore: OrderPhotoFileStore = LocalOrderPhotoFileStore(),
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.photoFileStore = photoFileStore
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
        self.presentation = OrderListPresentation(
            dateProvider: dateProvider,
            calendar: calendar
        )
    }

    var calendarDays: [OrderCalendarDay] {
        presentation.calendarDays(for: orders)
    }

    var activeOrders: [Order] {
        presentation.activeOrders(from: orders)
    }

    var completedOrders: [Order] {
        presentation.completedOrders(from: orders)
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
            errorMessage = nil
        } catch {
            errorMessage = "Orders could not be loaded."
        }
    }

    func beginAddingOrder() {
        resetDraft()
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
        loadSelectedOrderChecklistItems(for: order)
        loadSelectedOrderPhotos(for: order)
    }

    func closeOrderDetail() {
        selectedOrder = nil
        selectedOrderCustomer = nil
        selectedOrderRecipe = nil
        selectedOrderCakeDesign = nil
        selectedOrderRecipeUsage = nil
        selectedOrderChecklistItems = []
        selectedOrderPhotos = []
        draftChecklistItemTitle = ""
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
            quotedPrice: draft.quotedPrice,
            depositPaid: draft.depositPaid,
            paymentNotes: TextInputFormatting.optionalText(draftPaymentNotes),
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.save(order)
            resetDraft()
            load()
            return true
        } catch {
            errorMessage = "Order could not be saved."
            return false
        }
    }

    func cancelAddOrder() {
        resetDraft()
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
        draftQuotedPrice = TextInputFormatting.decimalText(selectedOrder.quotedPrice)
        draftDepositPaid = TextInputFormatting.decimalText(selectedOrder.depositPaid)
        draftPaymentNotes = selectedOrder.paymentNotes ?? ""
        errorMessage = nil
        loadFormReferences()
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
                    transactionIdProvider: idGenerator
                )
            } else {
                try repository.save(order)
                savedOrder = order
            }
            selectedOrder = savedOrder
            self.editingOrder = nil
            resetDraft()
            load()
            loadSelectedOrderCustomer(for: savedOrder)
            loadSelectedOrderRecipe(for: savedOrder)
            loadSelectedOrderCakeDesign(for: savedOrder)
            loadSelectedOrderRecipeUsage(for: savedOrder)
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

    private func refreshAfterSavingOrder(_ order: Order) {
        if selectedOrder?.id == order.id {
            selectedOrder = order
            loadSelectedOrderCustomer(for: order)
            loadSelectedOrderRecipe(for: order)
            loadSelectedOrderCakeDesign(for: order)
            loadSelectedOrderRecipeUsage(for: order)
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

    func promoteFinalCakePhotoToDesign(_ photo: OrderPhoto, name: String, notes: String) -> Bool {
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

        let now = dateProvider()
        let designId = idGenerator()
        let design = CakeDesign(
            id: designId,
            name: designName,
            notes: TextInputFormatting.optionalText(notes),
            photoReference: photo.localPhotoPath,
            createdAt: now,
            updatedAt: now
        )
        let updatedOrder = copy(
            selectedOrder,
            cakeDesignId: designId,
            updatedAt: now
        )

        do {
            try repository.save(design)
            try repository.save(updatedOrder)
            refreshAfterSavingOrder(updatedOrder)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Design could not be saved."
            return false
        }
    }

    func orderPhotoURL(_ photo: OrderPhoto) -> URL {
        photoFileStore.fileURL(for: photo.localPhotoPath)
    }

    func cancelEditingOrder() {
        editingOrder = nil
        resetDraft()
        errorMessage = nil
    }

    private func loadFormReferences() {
        do {
            customers = try repository.fetchCustomers()
            recipes = try repository.fetchRecipes()
            cakeDesigns = try repository.fetchCakeDesigns()
        } catch {
            customers = []
            recipes = []
            cakeDesigns = []
            errorMessage = "Order form references could not be loaded."
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
        draftQuotedPrice = ""
        draftDepositPaid = ""
        draftPaymentNotes = ""
    }

    private func validatedDraft() -> (
        title: String,
        customerName: String,
        recipeScaleMultiplier: Decimal,
        quotedPrice: Decimal?,
        depositPaid: Decimal?
    )? {
        let title = TextInputFormatting.trimmed(draftTitle)
        guard !title.isEmpty else {
            errorMessage = "Order title is required."
            return nil
        }

        let customerName = TextInputFormatting.trimmed(draftCustomerName)
        guard !customerName.isEmpty else {
            errorMessage = "Customer name is required."
            return nil
        }

        guard let quotedPrice = decimalAmount(from: draftQuotedPrice, fieldName: "Quoted price") else {
            return nil
        }
        guard let depositPaid = decimalAmount(from: draftDepositPaid, fieldName: "Deposit paid") else {
            return nil
        }
        guard let recipeScaleMultiplier = requiredPositiveDecimalAmount(
            from: draftRecipeScaleMultiplier,
            fieldName: "Recipe multiplier"
        ) else {
            return nil
        }
        if let quotedPrice, let depositPaid, depositPaid > quotedPrice {
            errorMessage = "Deposit paid cannot be more than quoted price."
            return nil
        }

        return (title, customerName, recipeScaleMultiplier, quotedPrice, depositPaid)
    }

    private func decimalAmount(from text: String, fieldName: String) -> Decimal?? {
        let trimmed = TextInputFormatting.trimmed(text)
        guard !trimmed.isEmpty else {
            return .some(nil)
        }

        guard let amount = Decimal(string: trimmed), amount >= 0 else {
            errorMessage = "\(fieldName) must be a positive number."
            return nil
        }

        return .some(amount)
    }

    private func requiredPositiveDecimalAmount(from text: String, fieldName: String) -> Decimal? {
        let trimmed = TextInputFormatting.trimmed(text)
        guard let amount = Decimal(string: trimmed), amount > 0 else {
            errorMessage = "\(fieldName) must be greater than zero."
            return nil
        }

        return amount
    }

}
