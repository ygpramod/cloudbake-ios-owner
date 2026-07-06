import Foundation

struct OrderCalendarDay: Equatable {
    let day: Date
    let orders: [Order]
}

struct OrderReminderPlanItem: Equatable {
    let offsetDays: Int
    let remindAt: Date

    var title: String {
        "\(offsetDays) \(offsetDays == 1 ? "Day" : "Days") Before"
    }
}

struct OrderReminderDueGroup: Equatable {
    let order: Order
    let reminders: [OrderReminderPlanItem]

    var earliestRemindAt: Date? {
        reminders.map(\.remindAt).min()
    }
}

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
    private let calendar: Calendar

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
        self.calendar = calendar
    }

    var calendarDays: [OrderCalendarDay] {
        let groupedOrders = Dictionary(grouping: activeOrders) { order in
            calendar.startOfDay(for: order.dueAt)
        }

        return groupedOrders.keys.sorted().map { day in
            OrderCalendarDay(
                day: day,
                orders: groupedOrders[day, default: []].sorted(by: orderIsDueBefore)
            )
        }
    }

    var activeOrders: [Order] {
        orders
            .filter(\.hasActiveReminderState)
            .sorted(by: orderIsDueBefore)
    }

    var completedOrders: [Order] {
        orders
            .filter(\.hasCompletedHistoryState)
            .sorted(by: orderWasDueAfter)
    }

    var selectedCustomerReferencePhotos: [OrderPhoto] {
        selectedOrderPhotos.filter { $0.kind == .customerReference }
    }

    var selectedFinalCakePhotos: [OrderPhoto] {
        selectedOrderPhotos.filter { $0.kind == .finalCake }
    }

    var dueReminderGroups: [OrderReminderDueGroup] {
        let now = dateProvider()
        return orders
            .filter(\.hasActiveReminderState)
            .compactMap { order in
                let dueReminders = reminderPlan(for: order)
                    .filter { $0.remindAt <= now }

                guard !dueReminders.isEmpty else {
                    return nil
                }

                guard let nextDueReminder = dueReminders.max(by: { $0.remindAt < $1.remindAt }) else {
                    return nil
                }

                return OrderReminderDueGroup(order: order, reminders: [nextDueReminder])
            }
            .sorted { lhs, rhs in
                if lhs.earliestRemindAt == rhs.earliestRemindAt {
                    if lhs.order.dueAt == rhs.order.dueAt {
                        return lhs.order.title < rhs.order.title
                    }

                    return lhs.order.dueAt < rhs.order.dueAt
                }

                return (lhs.earliestRemindAt ?? lhs.order.dueAt) < (rhs.earliestRemindAt ?? rhs.order.dueAt)
            }
    }

    func reminderPlan(for order: Order) -> [OrderReminderPlanItem] {
        [3, 2, 1].compactMap { offsetDays in
            guard let remindAt = calendar.date(byAdding: .day, value: -offsetDays, to: order.dueAt) else {
                return nil
            }

            return OrderReminderPlanItem(offsetDays: offsetDays, remindAt: remindAt)
        }
    }

    func nextReminder(for order: Order) -> OrderReminderPlanItem? {
        let now = dateProvider()
        let reminders = reminderPlan(for: order)
        return reminders.first { $0.remindAt > now } ?? reminders.last
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
        if draftDeliveryAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
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
        guard !draftCustomerId.isEmpty,
              let customer = customers.first(where: { $0.id == draftCustomerId }) else {
            return "No Linked Customer"
        }

        return customer.name
    }

    func selectDraftRecipe(id: String) {
        draftRecipeId = id
    }

    func clearDraftRecipeLink() {
        draftRecipeId = ""
        draftRecipeScaleMultiplier = "1"
    }

    func draftRecipeName() -> String {
        guard !draftRecipeId.isEmpty,
              let recipe = recipes.first(where: { $0.id == draftRecipeId }) else {
            return "No Linked Recipe"
        }

        return recipe.name
    }

    func selectDraftCakeDesign(id: String) {
        draftCakeDesignId = id
    }

    func clearDraftCakeDesignLink() {
        draftCakeDesignId = ""
    }

    func draftCakeDesignName() -> String {
        guard !draftCakeDesignId.isEmpty,
              let design = cakeDesigns.first(where: { $0.id == draftCakeDesignId }) else {
            return "No Linked Design"
        }

        return design.name
    }

    func customers(matching searchText: String) -> [Customer] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return customers
        }

        let query = normalizedSearchText(trimmed)
        return customers.filter { customer in
            [customer.name, customer.phone, customer.email, customer.address]
                .compactMap { $0 }
                .map(normalizedSearchText)
                .contains { $0.contains(query) }
        }
    }

    func recipes(matching searchText: String) -> [Recipe] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return recipes
        }

        let query = normalizedSearchText(trimmed)
        return recipes.filter { recipe in
            [recipe.name, recipe.notes]
                .compactMap { $0 }
                .map(normalizedSearchText)
                .contains { $0.contains(query) }
        }
    }

    func cakeDesigns(matching searchText: String) -> [CakeDesign] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return cakeDesigns
        }

        let query = normalizedSearchText(trimmed)
        return cakeDesigns.filter { design in
            [design.name, design.notes, design.photoReference]
                .compactMap { $0 }
                .map(normalizedSearchText)
                .contains { $0.contains(query) }
        }
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
            deliveryAddress: optionalText(draftDeliveryAddress),
            cakeNotes: optionalText(draftCakeNotes),
            quotedPrice: draft.quotedPrice,
            depositPaid: draft.depositPaid,
            paymentNotes: optionalText(draftPaymentNotes),
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
        draftRecipeScaleMultiplier = decimalText(selectedOrder.recipeScaleMultiplier)
        draftCakeDesignId = selectedOrder.cakeDesignId ?? ""
        draftDueAt = selectedOrder.dueAt
        draftStatus = selectedOrder.status
        draftFulfillmentType = selectedOrder.fulfillmentType
        draftDeliveryAddress = selectedOrder.deliveryAddress ?? ""
        draftCakeNotes = selectedOrder.cakeNotes ?? ""
        draftQuotedPrice = decimalText(selectedOrder.quotedPrice)
        draftDepositPaid = decimalText(selectedOrder.depositPaid)
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
            deliveryAddress: optionalText(draftDeliveryAddress),
            cakeNotes: optionalText(draftCakeNotes),
            quotedPrice: draft.quotedPrice,
            depositPaid: draft.depositPaid,
            paymentNotes: optionalText(draftPaymentNotes),
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
        guard let quotedPrice = order.quotedPrice else {
            errorMessage = "Add quoted price before recording payment."
            return false
        }

        let updatedOrder = copy(
            order,
            depositPaid: quotedPrice,
            updatedAt: dateProvider()
        )

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

    func markSelectedOrderPaid() -> Bool {
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return false
        }

        return markOrderPaid(selectedOrder)
    }

    func addPayment(to order: Order, amountText: String) -> Bool {
        guard let quotedPrice = order.quotedPrice else {
            errorMessage = "Add quoted price before recording payment."
            return false
        }

        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Decimal(string: trimmed), amount > 0 else {
            errorMessage = "Payment amount must be greater than zero."
            return false
        }

        let existingPaid = order.depositPaid ?? 0
        let updatedPaid = existingPaid + amount
        guard updatedPaid <= quotedPrice else {
            errorMessage = "Payment received cannot be more than balance due."
            return false
        }

        let updatedOrder = copy(
            order,
            depositPaid: updatedPaid,
            updatedAt: dateProvider()
        )

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

        let title = draftChecklistItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
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
                caption: optionalText(caption ?? ""),
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
            caption: optionalText(caption),
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
        guard let designName = optionalText(name) else {
            errorMessage = "Design name is required."
            return false
        }

        let now = dateProvider()
        let designId = idGenerator()
        let design = CakeDesign(
            id: designId,
            name: designName,
            notes: optionalText(notes),
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
                .sorted(by: checklistItemWasEnteredBefore)
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

    private func orderWasEnteredBefore(_ lhs: Order, _ rhs: Order) -> Bool {
        if lhs.createdAt == rhs.createdAt {
            return lhs.id < rhs.id
        }

        return lhs.createdAt < rhs.createdAt
    }

    private func orderIsDueBefore(_ lhs: Order, _ rhs: Order) -> Bool {
        if lhs.dueAt == rhs.dueAt {
            return orderWasEnteredBefore(lhs, rhs)
        }

        return lhs.dueAt < rhs.dueAt
    }

    private func orderWasDueAfter(_ lhs: Order, _ rhs: Order) -> Bool {
        if lhs.dueAt == rhs.dueAt {
            if lhs.createdAt == rhs.createdAt {
                return lhs.id < rhs.id
            }

            return lhs.createdAt > rhs.createdAt
        }

        return lhs.dueAt > rhs.dueAt
    }

    private func shouldRecordRecipeUsage(from currentStatus: OrderStatus, to newStatus: OrderStatus) -> Bool {
        currentStatus == .confirmed && (newStatus == .ready || newStatus == .completed)
    }

    private func checklistItemWasEnteredBefore(_ lhs: OrderChecklistItem, _ rhs: OrderChecklistItem) -> Bool {
        if lhs.sortOrder == rhs.sortOrder {
            if lhs.createdAt == rhs.createdAt {
                return lhs.id < rhs.id
            }

            return lhs.createdAt < rhs.createdAt
        }

        return lhs.sortOrder < rhs.sortOrder
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
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            errorMessage = "Order title is required."
            return nil
        }

        let customerName = draftCustomerName.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func optionalText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedSearchText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func decimalAmount(from text: String, fieldName: String) -> Decimal?? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Decimal(string: trimmed), amount > 0 else {
            errorMessage = "\(fieldName) must be greater than zero."
            return nil
        }

        return amount
    }

    private func decimalText(_ value: Decimal?) -> String {
        guard let value else {
            return ""
        }

        return NSDecimalNumber(decimal: value).stringValue
    }
}
