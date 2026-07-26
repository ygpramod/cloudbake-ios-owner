import Foundation

private actor DesignPromotionCoordinator {
    static let shared = DesignPromotionCoordinator()
    private var lockedPhotoIds: Set<String> = []
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    func acquire(photoId: String) async {
        guard lockedPhotoIds.contains(photoId) else {
            lockedPhotoIds.insert(photoId)
            return
        }
        await withCheckedContinuation { continuation in
            waiters[photoId, default: []].append(continuation)
        }
    }

    func release(photoId: String) {
        if var queued = waiters[photoId], !queued.isEmpty {
            let next = queued.removeFirst()
            waiters[photoId] = queued.isEmpty ? nil : queued
            next.resume()
        } else {
            lockedPhotoIds.remove(photoId)
        }
    }
}

@MainActor
final class OrderListViewModel: ObservableObject {
    @Published private(set) var orders: [Order] = []
    @Published private(set) var orderReminderConfigurations: [String: OrderReminderConfiguration] = [:]
    @Published private(set) var customers: [Customer] = []
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var cakeDesigns: [CakeDesign] = []
    @Published private(set) var selectedOrder: Order?
    @Published private(set) var selectedOrderCustomer: Customer?
    @Published private(set) var selectedOrderRecipe: Recipe?
    @Published private(set) var selectedOrderCakeDesign: CakeDesign?
    @Published private(set) var selectedOrderCustomerReferencePhoto: OrderPhoto?
    @Published private(set) var selectedOrderRecipeUsage: OrderRecipeUsage?
    @Published private(set) var selectedOrderExtraIngredients: [OrderExtraIngredientRow] = []
    @Published private(set) var selectedOrderIngredientShortages: [ProjectedIngredientShortage] = []
    @Published private(set) var selectedOrderIngredientCost: OrderIngredientCostSummary?
    @Published private(set) var selectedOrderIngredientCostIsActual = false
    @Published private(set) var selectedOrderInventoryReservationRepair: OrderInventoryReservationRepair?
    @Published private(set) var selectedOrderInventoryReservations: [OrderInventoryReservationRow] = []
    @Published var isIngredientCostBreakdownExpanded = false
    @Published private(set) var selectedOrderChecklistItems: [OrderChecklistItem] = []
    @Published private(set) var selectedOrderPhotos: [OrderPhoto] = []
    @Published private(set) var selectedOrderPaymentReceipts: [PaymentReceipt] = []
    @Published private(set) var selectedOrderLegacyPaidAmount: Decimal = 0
    @Published private(set) var editingOrder: Order?
    @Published private(set) var availableInventoryItems: [InventoryItem] = []
    @Published var draftTitle = ""
    @Published var draftCustomerName = ""
    @Published var draftCustomerId = ""
    @Published var draftRecipeId = ""
    @Published var draftRecipeScaleMultiplier = "1"
    @Published var draftCakeDesignId = ""
    @Published private(set) var draftCustomerReferencePhotoId = ""
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
    @Published var draftReminderMode: OrderReminderDraftMode = .useDefaults
    @Published var draftReminderDayOffsets = "3, 2, 1"
    @Published var draftReminderIncludesDueTime = true
    @Published var draftExtraIngredientInventoryItemId = ""
    @Published var draftExtraIngredientQuantity = ""
    @Published var draftExtraIngredientUnit: InventoryUnit = .gram
    @Published var draftExtraIngredientNote = ""
    @Published private(set) var draftExtraIngredientRows: [OrderExtraIngredientDraftRow] = []
    @Published private(set) var draftIngredientCost: OrderIngredientCostSummary?
    @Published private(set) var draftIngredientCostIsActual = false
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published private(set) var isPromotingDesign = false
    @Published private(set) var pendingInventoryShortages: [OrderInventoryShortage] = []
    @Published private(set) var canLoadMoreActiveOrders = false
    @Published private(set) var canLoadMoreCompletedOrders = false

    private let repository: any OrderRepository & OrderReminderConfigurationRepository & CustomerRepository & CustomerImportantDateRepository & RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & CakeDesignRepository & InventoryItemRepository & InventoryStockBatchRepository & OrderRecipeUsageRepository & OrderIngredientCostRepository & OrderStatusChangeRepository & OrderExtraIngredientRepository & OrderInventoryReservationRepository & ProjectedIngredientDemandRepository & OrderInventoryReservationMutationRepository & OrderReminderPlanOrderMutationRepository & OrderChecklistRepository & OrderPhotoRepository & PaymentReceiptRepository
    private let photoFileStore: OrderPhotoFileStore
    private let designPhotoLibrary: DesignPhotoLibrary
    private let idGenerator: () -> String
    private let dateProvider: () -> Date
    private let onReminderDataChanged: () -> Void
    private let presentation: OrderListPresentation
    private let paymentWorkflow: OrderPaymentWorkflow
    private var pendingSelectedOrderExtraIngredientId: String?
    private var activeOrderCursor: OrderPageCursor?
    private var completedOrderCursor: OrderPageCursor?
    private static let orderPageSize = 25

    init(
        repository: any OrderRepository & OrderReminderConfigurationRepository & CustomerRepository & CustomerImportantDateRepository & RecipeRepository & RecipeComponentRepository & RecipeIngredientRepository & CakeDesignRepository & InventoryItemRepository & InventoryStockBatchRepository & OrderRecipeUsageRepository & OrderIngredientCostRepository & OrderStatusChangeRepository & OrderExtraIngredientRepository & OrderInventoryReservationRepository & ProjectedIngredientDemandRepository & OrderInventoryReservationMutationRepository & OrderReminderPlanOrderMutationRepository & OrderChecklistRepository & OrderPhotoRepository & PaymentReceiptRepository,
        photoFileStore: OrderPhotoFileStore = LocalOrderPhotoFileStore(),
        designPhotoLibrary: DesignPhotoLibrary = PhotoKitDesignPhotoLibrary(),
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init,
        onReminderDataChanged: @escaping () -> Void = {},
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.photoFileStore = photoFileStore
        self.designPhotoLibrary = designPhotoLibrary
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
        self.onReminderDataChanged = onReminderDataChanged
        self.presentation = OrderListPresentation(
            dateProvider: dateProvider,
            calendar: calendar
        )
        self.paymentWorkflow = OrderPaymentWorkflow(
            repository: repository,
            dateProvider: dateProvider
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
        if let loadedOrder = orders.first(where: { $0.id == id }) {
            return loadedOrder
        }

        do {
            return try repository.fetchOrder(id: id)
        } catch {
            errorMessage = "The requested order could not be loaded."
            return nil
        }
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
        presentation.dueReminderGroups(
            for: orders,
            configurations: orderReminderConfigurations
        )
    }

    func reminderPlan(for order: Order) -> [OrderReminderPlanItem] {
        presentation.reminderPlan(
            for: order,
            configuration: orderReminderConfigurations[order.id] ?? .initialDefault
        )
    }

    func nextReminder(for order: Order) -> OrderReminderPlanItem? {
        presentation.nextReminder(
            for: order,
            configuration: orderReminderConfigurations[order.id] ?? .initialDefault
        )
    }

    func load() {
        do {
            let activePage = try repository.fetchOrderPage(
                query: .active(dueAtRange: nil),
                after: nil,
                limit: Self.orderPageSize
            )
            let completedPage = try repository.fetchOrderPage(
                query: .completed,
                after: nil,
                limit: Self.orderPageSize
            )
            let loadedOrders = activePage.orders + completedPage.orders
            let loadedConfigurations =
                try repository.fetchOrderReminderConfigurations(orderIds: loadedOrders.map(\.id))
            let loadedCustomers = try repository.fetchCustomers()
            let loadedRecipes = try repository.fetchRecipes()
            let loadedCakeDesigns = try repository.fetchCakeDesigns().filter {
                $0.sourceKind == .ownerMade || $0.sourceKind == .customerReference
            }

            orders = loadedOrders
            activeOrderCursor = activePage.nextCursor
            completedOrderCursor = completedPage.nextCursor
            canLoadMoreActiveOrders = activePage.nextCursor != nil
            canLoadMoreCompletedOrders = completedPage.nextCursor != nil
            orderReminderConfigurations = loadedConfigurations
            customers = loadedCustomers
            recipes = loadedRecipes
            cakeDesigns = loadedCakeDesigns
            errorMessage = retryPendingDesignPhotoCleanups()
                ? nil
                : "A previous design photo cleanup will be retried automatically."
        } catch {
            errorMessage = "Orders could not be loaded."
        }
    }

    func loadMoreActiveOrders() {
        loadMoreOrders(
            query: .active(dueAtRange: nil),
            cursor: activeOrderCursor,
            updateCursor: { activeOrderCursor = $0 },
            updateAvailability: { canLoadMoreActiveOrders = $0 }
        )
    }

    func loadMoreCompletedOrders() {
        loadMoreOrders(
            query: .completed,
            cursor: completedOrderCursor,
            updateCursor: { completedOrderCursor = $0 },
            updateAvailability: { canLoadMoreCompletedOrders = $0 }
        )
    }

    func makeCustomerListViewModel() -> CustomerListViewModel {
        CustomerListViewModel(
            repository: repository,
            idGenerator: idGenerator,
            dateProvider: dateProvider
        )
    }

    private func loadMoreOrders(
        query: OrderPageQuery,
        cursor: OrderPageCursor?,
        updateCursor: (OrderPageCursor?) -> Void,
        updateAvailability: (Bool) -> Void
    ) {
        guard let cursor else {
            return
        }

        do {
            let page = try repository.fetchOrderPage(
                query: query,
                after: cursor,
                limit: Self.orderPageSize
            )
            let configurations =
                try repository.fetchOrderReminderConfigurations(orderIds: page.orders.map(\.id))
            orders.append(contentsOf: page.orders)
            orderReminderConfigurations.merge(configurations) { _, latest in latest }
            updateCursor(page.nextCursor)
            updateAvailability(page.nextCursor != nil)
            errorMessage = nil
        } catch {
            errorMessage = "More orders could not be loaded."
        }
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
        loadDefaultReminderDraft()
        draftExtraIngredientRows = []
        pendingInventoryShortages = []
        errorMessage = nil
        loadFormReferences()
    }

    func selectDraftReminderMode(_ mode: OrderReminderDraftMode) {
        draftReminderMode = mode
        if mode == .useDefaults {
            loadDefaultReminderDraft()
        }
    }

    func beginViewingOrder(_ order: Order) {
        selectedOrder = order
        pendingInventoryShortages = []
        errorMessage = nil
        if orderReminderConfigurations[order.id] == nil {
            orderReminderConfigurations[order.id] =
                try? repository.fetchOrderReminderConfiguration(orderId: order.id)
        }
        loadSelectedOrderCustomer(for: order)
        loadSelectedOrderRecipe(for: order)
        loadSelectedOrderCakeDesign(for: order)
        loadSelectedOrderRecipeUsage(for: order)
        loadSelectedOrderInventoryReservationRepair(for: order)
        loadSelectedOrderInventoryReservations(for: order)
        loadSelectedOrderExtraIngredients(for: order)
        loadSelectedOrderChecklistItems(for: order)
        loadSelectedOrderPhotos(for: order)
        loadSelectedOrderPayments(for: order)
    }

    func closeOrderDetail() {
        selectedOrder = nil
        selectedOrderCustomer = nil
        selectedOrderRecipe = nil
        selectedOrderCakeDesign = nil
        selectedOrderCustomerReferencePhoto = nil
        selectedOrderRecipeUsage = nil
        selectedOrderInventoryReservationRepair = nil
        selectedOrderInventoryReservations = []
        selectedOrderExtraIngredients = []
        selectedOrderIngredientShortages = []
        selectedOrderIngredientCost = nil
        selectedOrderIngredientCostIsActual = false
        isIngredientCostBreakdownExpanded = false
        selectedOrderChecklistItems = []
        selectedOrderPhotos = []
        selectedOrderPaymentReceipts = []
        selectedOrderLegacyPaidAmount = 0
        draftChecklistItemTitle = ""
        resetExtraIngredientDraft()
        editingOrder = nil
        pendingInventoryShortages = []
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
        refreshDraftIngredientCost()
    }

    func clearDraftRecipeLink() {
        draftRecipeId = ""
        draftRecipeScaleMultiplier = "1"
        draftExtraIngredientRows = []
        refreshDraftIngredientCost()
    }

    func draftRecipeName() -> String {
        OrderReferenceSelection.recipeName(for: draftRecipeId, recipes: recipes)
    }

    func selectDraftCakeDesign(id: String) {
        draftCakeDesignId = id
        draftCustomerReferencePhotoId = ""
    }

    func clearDraftCakeDesignLink() {
        draftCakeDesignId = ""
        draftCustomerReferencePhotoId = ""
    }

    func selectDraftCustomerReference(photoId: String) {
        draftCakeDesignId = ""
        draftCustomerReferencePhotoId = photoId
    }

    var draftDesignReferenceName: String {
        if !draftCustomerReferencePhotoId.isEmpty {
            return "Customer Reference"
        }
        return draftCakeDesignName()
    }

    func draftCakeDesignName() -> String {
        OrderReferenceSelection.cakeDesignName(for: draftCakeDesignId, cakeDesigns: cakeDesigns)
    }

    var selectedOrderDesignSourceName: String? {
        if selectedOrderCustomerReferencePhoto != nil {
            return "Customer Reference"
        }
        switch selectedOrderCakeDesign?.sourceKind {
        case .ownerMade: return "My Designs"
        case .internetInspiration: return "Internet Inspiration"
        case .customerReference: return "Reference"
        case nil: return nil
        }
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

    func cakeDesigns(matching searchText: String, tag: String?) -> [CakeDesign] {
        cakeDesigns(matching: searchText).filter { design in
            guard design.sourceKind == .ownerMade else { return false }
            guard let tag else { return true }
            let selectedKey = TextInputFormatting.normalizedSearchKey(tag)
            return design.tags.contains {
                TextInputFormatting.normalizedSearchKey($0) == selectedKey
            }
        }
    }

    var mostUsedDesignTags: [String] {
        DesignTagRanking.mostUsed(
            in: cakeDesigns
                .filter { $0.sourceKind == .ownerMade || $0.sourceKind == .customerReference }
                .map(\.tags)
        )
    }

    func references(matching searchText: String, tag: String?) -> [CakeDesign] {
        OrderReferenceSelection.cakeDesigns(cakeDesigns, matching: searchText).filter { design in
            guard design.sourceKind == .customerReference else { return false }
            guard let tag else { return true }
            let selectedKey = TextInputFormatting.normalizedSearchKey(tag)
            return design.tags.contains {
                TextInputFormatting.normalizedSearchKey($0) == selectedKey
            }
        }
    }

    func designPhotoSource(for design: CakeDesign) -> CakeDesignPhotoSource? {
        guard let reference = design.photoReference else { return nil }
        if let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(from: reference) {
            return designPhotoLibrary.containsAsset(identifier: identifier)
                ? .photosAsset(identifier)
                : nil
        }
        let url = photoFileStore.fileURL(for: reference)
        return FileManager.default.fileExists(atPath: url.path) ? .legacyFile(url) : nil
    }

    func addOrder(allowingInventoryShortage: Bool = false) -> Bool {
        if !allowingInventoryShortage {
            pendingInventoryShortages = []
        }
        guard let draft = validatedDraft() else {
            return false
        }

        let now = dateProvider()
        let order = Order(
            id: idGenerator(),
            customerId: draftCustomerId.isEmpty ? nil : draftCustomerId,
            cakeDesignId: draftCakeDesignId.isEmpty ? nil : draftCakeDesignId,
            customerReferencePhotoId: draftCustomerReferencePhotoId.isEmpty ? nil : draftCustomerReferencePhotoId,
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
            depositPaid: nil,
            paymentNotes: TextInputFormatting.optionalText(draftPaymentNotes),
            createdAt: now,
            updatedAt: now
        )

        do {
            let reminderConfiguration = try draftReminderConfiguration()
            try repository.saveOrder(
                order,
                replacingExtraIngredients: draftExtraIngredients(for: order, updatedAt: now),
                reminderConfiguration: reminderConfiguration,
                openingPayment: draft.depositPaid.map {
                    NewPaymentReceipt(
                        amount: $0,
                        receivedAt: now,
                        note: draftPaymentNotes,
                        createdAt: now
                    )
                },
                allowInventoryShortage: allowingInventoryShortage
            )
            resetDraft()
            draftExtraIngredientRows = []
            load()
            pendingInventoryShortages = []
            onReminderDataChanged()
            return true
        } catch OrderRecipeUsageError.insufficientStock(let shortages) where !allowingInventoryShortage {
            pendingInventoryShortages = shortages
            errorMessage = nil
            return false
        } catch is OrderDraftValidationError {
            return false
        } catch let error as OrderRecipeUsageError {
            errorMessage = recipeUsageErrorMessage(for: error)
            return false
        } catch {
            errorMessage = "Order could not be saved."
            return false
        }
    }

    func cancelAddOrder() {
        resetDraft()
        draftExtraIngredientRows = []
        pendingInventoryShortages = []
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
        draftCustomerReferencePhotoId = selectedOrder.customerReferencePhotoId ?? ""
        draftDueAt = selectedOrder.dueAt
        draftStatus = selectedOrder.status
        draftFulfillmentType = selectedOrder.fulfillmentType
        draftDeliveryAddress = selectedOrder.deliveryAddress ?? ""
        draftCakeNotes = selectedOrder.cakeNotes ?? ""
        draftCakeMessage = selectedOrder.cakeMessage ?? ""
        draftQuotedPrice = TextInputFormatting.decimalText(selectedOrder.quotedPrice)
        draftDepositPaid = TextInputFormatting.decimalText(selectedOrder.depositPaid)
        draftPaymentNotes = selectedOrder.paymentNotes ?? ""
        applyReminderConfiguration(
            orderReminderConfigurations[selectedOrder.id] ?? .initialDefault
        )
        errorMessage = nil
        loadFormReferences()
        loadSelectedOrderExtraIngredients(for: selectedOrder)
        draftExtraIngredientRows = selectedOrderExtraIngredients.map { OrderExtraIngredientDraftRow(row: $0) }
        if selectedOrderIngredientCostIsActual {
            draftIngredientCost = selectedOrderIngredientCost
            draftIngredientCostIsActual = true
        } else {
            refreshDraftIngredientCost()
        }
    }

    var editedOrderRequiresInventoryDeductionConfirmation: Bool {
        guard let editingOrder else {
            return false
        }

        return shouldRecordRecipeUsage(from: editingOrder.status, to: draftStatus) &&
            !draftRecipeId.isEmpty &&
            selectedOrderRecipeUsage == nil
    }

    func saveEditedOrder(
        confirmingRecipeUsage: Bool = false,
        allowingInventoryShortage: Bool = false
    ) -> Bool {
        if !allowingInventoryShortage {
            pendingInventoryShortages = []
        }
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
            customerReferencePhotoId: draftCustomerReferencePhotoId.isEmpty ? nil : draftCustomerReferencePhotoId,
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
            depositPaid: editingOrder.depositPaid,
            paymentNotes: TextInputFormatting.optionalText(draftPaymentNotes),
            completedAt: editingOrder.completedAt,
            createdAt: editingOrder.createdAt,
            updatedAt: now
        )

        do {
            let reminderConfiguration = try draftReminderConfiguration()
            let savedOrder: Order
            if shouldRecordRecipeUsage(from: editingOrder.status, to: order.status), order.recipeId != nil {
                let orderBeforeStatusChange = Order(
                    id: order.id,
                    customerId: order.customerId,
                    cakeDesignId: order.cakeDesignId,
                    customerReferencePhotoId: order.customerReferencePhotoId,
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
                    completedAt: editingOrder.completedAt,
                    createdAt: order.createdAt,
                    updatedAt: order.updatedAt
                )
                savedOrder = try repository.changeOrderStatus(
                    order: orderBeforeStatusChange,
                    status: order.status,
                    updatedAt: now,
                    usageId: idGenerator(),
                    extraIngredients: draftExtraIngredients(for: orderBeforeStatusChange, updatedAt: now),
                    reminderConfiguration: reminderConfiguration,
                    allowInventoryShortage: allowingInventoryShortage,
                    transactionIdProvider: idGenerator
                )
            } else {
                try repository.saveOrder(
                    order,
                    replacingExtraIngredients: draftExtraIngredients(for: order, updatedAt: now),
                    reminderConfiguration: reminderConfiguration,
                    allowInventoryShortage: allowingInventoryShortage
                )
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
            loadSelectedOrderInventoryReservationRepair(for: savedOrder)
            loadSelectedOrderInventoryReservations(for: savedOrder)
            loadSelectedOrderExtraIngredients(for: savedOrder)
            loadSelectedOrderChecklistItems(for: savedOrder)
            loadSelectedOrderPhotos(for: savedOrder)
            pendingInventoryShortages = []
            onReminderDataChanged()
            return true
        } catch OrderRecipeUsageError.insufficientStock(let shortages) where !allowingInventoryShortage {
            pendingInventoryShortages = shortages
            errorMessage = nil
            return false
        } catch is OrderDraftValidationError {
            return false
        } catch let error as OrderRecipeUsageError {
            errorMessage = recipeUsageErrorMessage(for: error)
            return false
        } catch {
            errorMessage = "Order could not be saved."
            return false
        }
    }

    func changeSelectedOrderStatus(
        to status: OrderStatus,
        allowingInventoryShortage: Bool = false
    ) -> Bool {
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return false
        }

        return changeOrderStatus(
            selectedOrder,
            to: status,
            allowingInventoryShortage: allowingInventoryShortage
        )
    }

    func changeOrderStatus(
        _ order: Order,
        to status: OrderStatus,
        allowingInventoryShortage: Bool = false
    ) -> Bool {
        if !allowingInventoryShortage {
            pendingInventoryShortages = []
        }
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
                allowInventoryShortage: allowingInventoryShortage,
                transactionIdProvider: idGenerator
            )
            refreshAfterSavingOrder(updatedOrder)
            pendingInventoryShortages = []
            errorMessage = nil
            onReminderDataChanged()
            return true
        } catch OrderRecipeUsageError.insufficientStock(let shortages) where !allowingInventoryShortage {
            pendingInventoryShortages = shortages
            errorMessage = nil
            return false
        } catch let error as OrderRecipeUsageError {
            errorMessage = recipeUsageErrorMessage(for: error)
            return false
        } catch {
            errorMessage = "Order status could not be updated."
            return false
        }
    }

    func cancelInventoryShortageOverride() {
        pendingInventoryShortages = []
    }

    var inventoryShortageWarningMessage: String {
        pendingInventoryShortages.map { shortage in
            "\(shortage.inventoryItemName): short by \(shortage.shortfallQuantity.formatted()) \(shortage.unit.displayName)"
        }.joined(separator: "\n")
    }

    var selectedOrderInventoryReservationRepairWarning: String? {
        guard let repair = selectedOrderInventoryReservationRepair else {
            return nil
        }
        switch repair.state {
        case .complete:
            return nil
        case .pending:
            return "CloudBake is preparing this order’s inventory reservation. Availability may be incomplete until repair finishes."
        case .failed:
            switch repair.failureCode {
            case .missingInventoryItem:
                return "This order’s reservation needs attention because a recipe inventory item is missing."
            case .incompatibleUnit:
                return "This order’s reservation needs attention because an ingredient unit is incompatible."
            case .invalidRequirements, nil:
                return "This order’s reservation needs attention because its ingredient requirements are invalid."
            }
        }
    }

    func requiresInventoryDeductionConfirmation(for order: Order, to status: OrderStatus) -> Bool {
        guard order.status.recordsRecipeUsage(whenChangingTo: status),
              order.recipeId != nil else {
            return false
        }

        do {
            return try repository.fetchOrderRecipeUsage(orderId: order.id) == nil
        } catch {
            return true
        }
    }

    func markOrderPaid(_ order: Order) -> Bool {
        applyPaymentResult(paymentWorkflow.markPaid(order))
    }

    func markSelectedOrderPaid() -> Bool {
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return false
        }

        return markOrderPaid(selectedOrder)
    }

    func addPayment(
        to order: Order,
        amountText: String,
        note: String = ""
    ) -> Bool {
        applyPaymentResult(
            paymentWorkflow.record(
                order: order,
                amountText: amountText,
                note: note
            )
        )
    }

    private func applyPaymentResult(
        _ result: Result<Order, OrderPaymentWorkflowError>
    ) -> Bool {
        switch result {
        case .success(let updatedOrder):
            refreshAfterSavingOrder(updatedOrder)
            onReminderDataChanged()
            errorMessage = nil
            return true
        case .failure(let error):
            errorMessage = error.ownerMessage
            return false
        }
    }

    func addPaymentToSelectedOrder(
        amountText: String,
        note: String = ""
    ) -> Bool {
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return false
        }

        return addPayment(
            to: selectedOrder,
            amountText: amountText,
            note: note
        )
    }

    func voidPaymentReceipt(_ receipt: PaymentReceipt, reason: String) -> Bool {
        applyPaymentResult(
            paymentWorkflow.void(
                receipt,
                reason: reason
            )
        )
    }

    func beginAddingExtraIngredient() {
        loadAvailableInventoryItems()
        resetExtraIngredientDraft(keepingInventoryItems: true)
        pendingSelectedOrderExtraIngredientId = nil
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

    func addExtraIngredientToSelectedOrder(
        allowingInventoryShortage: Bool = false
    ) -> Bool {
        if !allowingInventoryShortage {
            pendingInventoryShortages = []
        }
        guard let selectedOrder else {
            errorMessage = "Order could not be found."
            return false
        }
        guard let draft = validatedExtraIngredientDraft() else {
            return false
        }

        let now = dateProvider()
        let ingredientId = pendingSelectedOrderExtraIngredientId ?? idGenerator()
        pendingSelectedOrderExtraIngredientId = ingredientId
        let ingredient = OrderExtraIngredient(
            id: ingredientId,
            orderId: selectedOrder.id,
            inventoryItemId: draft.inventoryItemId,
            quantity: draft.quantity,
            unit: draft.unit,
            note: draft.note,
            createdAt: now,
            updatedAt: now
        )
        let updatedOrder = copy(selectedOrder, updatedAt: now)
        let replacement = selectedOrderExtraIngredients.map(\.ingredient) + [ingredient]

        do {
            try repository.saveOrder(
                updatedOrder,
                replacingExtraIngredients: replacement,
                allowInventoryShortage: allowingInventoryShortage
            )
            pendingSelectedOrderExtraIngredientId = nil
            resetExtraIngredientDraft()
            refreshAfterSavingOrder(updatedOrder)
            pendingInventoryShortages = []
            errorMessage = nil
            return true
        } catch OrderRecipeUsageError.insufficientStock(let shortages) where !allowingInventoryShortage {
            pendingInventoryShortages = shortages
            errorMessage = nil
            return false
        } catch let error as OrderRecipeUsageError {
            pendingInventoryShortages = []
            errorMessage = extraIngredientErrorMessage(for: error)
            return false
        } catch {
            pendingInventoryShortages = []
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
        refreshDraftIngredientCost()
        resetExtraIngredientDraft(keepingInventoryItems: true)
        errorMessage = nil
        return true
    }

    func deleteDraftExtraIngredient(_ row: OrderExtraIngredientDraftRow) {
        draftExtraIngredientRows.removeAll { $0.id == row.id }
        refreshDraftIngredientCost()
    }

    func refreshDraftIngredientCost() {
        if editingOrder != nil, selectedOrderIngredientCostIsActual {
            draftIngredientCost = selectedOrderIngredientCost
            draftIngredientCostIsActual = true
            return
        }

        draftIngredientCostIsActual = false
        guard !draftRecipeId.isEmpty,
              let scale = Decimal(string: TextInputFormatting.trimmed(draftRecipeScaleMultiplier)),
              scale > 0 else {
            draftIngredientCost = nil
            return
        }

        let now = dateProvider()
        let orderId = editingOrder?.id ?? "draft-order-cost"
        let draftOrder = Order(
            id: orderId,
            customerId: nil,
            cakeDesignId: nil,
            recipeId: draftRecipeId,
            recipeScaleMultiplier: scale,
            title: draftTitle,
            customerName: draftCustomerName,
            status: draftStatus,
            dueAt: draftDueAt,
            fulfillmentType: draftFulfillmentType,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: now,
            updatedAt: now
        )
        let extras = draftExtraIngredientRows.map { row in
            OrderExtraIngredient(
                id: row.id,
                orderId: orderId,
                inventoryItemId: row.inventoryItemId,
                quantity: row.quantity,
                unit: row.unit,
                note: row.note,
                createdAt: now,
                updatedAt: now
            )
        }

        do {
            let requirements = try OrderIngredientRequirements.requirements(
                for: draftOrder,
                inventoryItems: availableInventoryItems,
                recipeComponents: repository.fetchRecipeComponents(recipeId:),
                recipeIngredients: repository.fetchRecipeIngredients(componentId:),
                orderExtraIngredients: { _ in extras }
            )
            draftIngredientCost = try OrderIngredientCostCalculation.summary(
                requirements: requirements,
                batches: repository.fetchInventoryStockBatches(inventoryItemId:),
                at: now
            )
        } catch {
            draftIngredientCost = nil
        }
    }

    func deleteExtraIngredient(_ row: OrderExtraIngredientRow) -> Bool {
        do {
            try repository.deleteOrderExtraIngredient(
                id: row.ingredient.id,
                updatedAt: dateProvider()
            )
            if let selectedOrder {
                loadSelectedOrderExtraIngredients(for: selectedOrder)
                loadSelectedOrderInventoryReservations(for: selectedOrder)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Extra ingredient could not be deleted."
            return false
        }
    }

    func cancelExtraIngredientEdit() {
        pendingSelectedOrderExtraIngredientId = nil
        resetExtraIngredientDraft()
        pendingInventoryShortages = []
        errorMessage = nil
    }

    private func refreshAfterSavingOrder(_ order: Order) {
        if selectedOrder?.id == order.id {
            selectedOrder = order
            loadSelectedOrderCustomer(for: order)
            loadSelectedOrderRecipe(for: order)
            loadSelectedOrderCakeDesign(for: order)
            loadSelectedOrderRecipeUsage(for: order)
            loadSelectedOrderInventoryReservationRepair(for: order)
            loadSelectedOrderInventoryReservations(for: order)
            loadSelectedOrderExtraIngredients(for: order)
            loadSelectedOrderChecklistItems(for: order)
            loadSelectedOrderPhotos(for: order)
            loadSelectedOrderPayments(for: order)
        }

        load()
    }

    private func loadSelectedOrderPayments(for order: Order) {
        switch paymentWorkflow.history(orderId: order.id) {
        case .success(let history):
            selectedOrderPaymentReceipts = history.receipts
            selectedOrderLegacyPaidAmount = history.legacyPaidAmount
        case .failure(let error):
            selectedOrderPaymentReceipts = []
            selectedOrderLegacyPaidAmount = 0
            errorMessage = error.ownerMessage
        }
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
            customerReferencePhotoId: order.customerReferencePhotoId,
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
            completedAt: order.completedAt,
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

    func addOrderPhoto(kind: OrderPhotoKind, imageData: Data, caption: String? = nil) async -> Bool {
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
        do {
            let photoReference = try await designPhotoLibrary.savePhoto(data: imageData)
            let photo = OrderPhoto(
                id: photoId,
                orderId: selectedOrder.id,
                kind: kind,
                localPhotoPath: photoReference,
                caption: TextInputFormatting.optionalText(caption ?? ""),
                createdAt: now,
                updatedAt: now
            )
            try repository.save(photo)
            loadSelectedOrderPhotos(for: selectedOrder)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Order photo could not be saved."
            return false
        }
    }

    func deleteOrderPhoto(_ photo: OrderPhoto) -> Bool {
        do {
            try repository.deleteOrderPhoto(id: photo.id)
            if PhotoKitDesignPhotoLibrary.assetIdentifier(from: photo.localPhotoPath) == nil {
                try photoFileStore.deleteOrderPhoto(relativePath: photo.localPhotoPath)
            }
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
        do {
            guard let currentPhoto = try repository.fetchOrderPhoto(id: photo.id) else {
                errorMessage = "Order photo could not be found."
                return false
            }
            let updatedPhoto = OrderPhoto(
                id: currentPhoto.id,
                orderId: currentPhoto.orderId,
                kind: currentPhoto.kind,
                localPhotoPath: currentPhoto.localPhotoPath,
                caption: TextInputFormatting.optionalText(caption),
                tags: currentPhoto.tags,
                isFavorite: currentPhoto.isFavorite,
                createdAt: currentPhoto.createdAt,
                updatedAt: dateProvider()
            )
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
        guard !cakeDesigns.contains(where: { $0.originatingOrderPhotoId == photo.id }) else {
            errorMessage = "This final cake photo is already saved as a design."
            return false
        }
        guard !isPromotingDesign else {
            errorMessage = "Design is already being saved."
            return false
        }
        isPromotingDesign = true
        defer { isPromotingDesign = false }
        await DesignPromotionCoordinator.shared.acquire(photoId: photo.id)
        defer {
            Task { await DesignPromotionCoordinator.shared.release(photoId: photo.id) }
        }
        do {
            if try repository.fetchCakeDesign(originatingOrderPhotoId: photo.id) != nil {
                errorMessage = "This final cake photo is already saved as a design."
                return false
            }
        } catch {
            errorMessage = "Design history could not be checked."
            return false
        }

        let photoReference: String
        let cleanupRelativePath: String?
        if let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(from: photo.localPhotoPath) {
            guard designPhotoLibrary.containsAsset(identifier: identifier) else {
                errorMessage = "Design photo is no longer available in Photos."
                return false
            }
            photoReference = photo.localPhotoPath
            cleanupRelativePath = nil
        } else {
            do {
                photoReference = try await designPhotoLibrary.savePhoto(at: orderPhotoURL(photo))
                cleanupRelativePath = photo.localPhotoPath
            } catch {
                errorMessage = "Design photo could not be saved to Photos."
                return false
            }
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
            tags: photo.tags,
            isFavorite: photo.isFavorite,
            createdAt: photo.createdAt,
            updatedAt: now
        )

        do {
            try repository.savePromotedDesign(
                design,
                linking: updatedOrder,
                photo: migratedPhoto,
                cleanupRelativePath: cleanupRelativePath
            )
            let didCleanup = cleanupRelativePath.map(cleanupDesignPhoto(at:)) ?? true
            refreshAfterSavingOrder(updatedOrder)
            errorMessage = didCleanup
                ? nil
                : "Design saved. The old local photo copy will be removed automatically."
            return true
        } catch CakeDesignPromotionError.originatingPhotoAlreadyPromoted {
            errorMessage = "This final cake photo is already saved as a design."
            return false
        } catch {
            errorMessage = "Design could not be saved."
            return false
        }
    }

    func addCustomerReferencePhotoToDesignReferences(
        _ photo: OrderPhoto,
        tags: String
    ) async -> Bool {
        guard let selectedOrder, selectedOrder.id == photo.orderId else {
            errorMessage = "Order could not be found."
            return false
        }
        guard photo.kind == .customerReference else {
            errorMessage = "Only customer reference photos can be added to References."
            return false
        }
        guard !isPromotingDesign else {
            errorMessage = "Reference is already being saved."
            return false
        }
        isPromotingDesign = true
        defer { isPromotingDesign = false }
        await DesignPromotionCoordinator.shared.acquire(photoId: photo.id)
        defer { Task { await DesignPromotionCoordinator.shared.release(photoId: photo.id) } }

        do {
            if try repository.fetchCakeDesign(originatingOrderPhotoId: photo.id) != nil {
                errorMessage = "This photo is already in Design References."
                return false
            }
        } catch {
            errorMessage = "Reference history could not be checked."
            return false
        }

        let photoReference: String
        let cleanupRelativePath: String?
        if let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(from: photo.localPhotoPath) {
            guard designPhotoLibrary.containsAsset(identifier: identifier) else {
                errorMessage = "Reference photo is no longer available in Photos."
                return false
            }
            photoReference = photo.localPhotoPath
            cleanupRelativePath = nil
        } else {
            do {
                photoReference = try await designPhotoLibrary.savePhoto(at: orderPhotoURL(photo))
                cleanupRelativePath = photo.localPhotoPath
            } catch {
                errorMessage = "Reference photo could not be saved to Photos."
                return false
            }
        }

        let now = dateProvider()
        let design = CakeDesign(
            id: idGenerator(),
            name: photo.caption ?? "Reference",
            notes: nil,
            photoReference: photoReference,
            sourceKind: .customerReference,
            originatingOrderPhotoId: photo.id,
            originatingOrderId: selectedOrder.id,
            tags: DesignTags.parsed(tags),
            createdAt: now,
            updatedAt: now
        )
        let migratedPhoto = OrderPhoto(
            id: photo.id,
            orderId: photo.orderId,
            kind: photo.kind,
            localPhotoPath: photoReference,
            caption: photo.caption,
            tags: photo.tags,
            isFavorite: photo.isFavorite,
            createdAt: photo.createdAt,
            updatedAt: now
        )

        do {
            try repository.savePromotedDesign(
                design,
                linking: selectedOrder,
                photo: migratedPhoto,
                cleanupRelativePath: cleanupRelativePath
            )
            let didCleanup = cleanupRelativePath.map(cleanupDesignPhoto(at:)) ?? true
            loadFormReferences()
            loadSelectedOrderPhotos(for: selectedOrder)
            errorMessage = didCleanup
                ? nil
                : "Reference saved. The old local photo copy will be removed automatically."
            return true
        } catch CakeDesignPromotionError.originatingPhotoAlreadyPromoted {
            errorMessage = "This photo is already in Design References."
            return false
        } catch {
            errorMessage = "Reference could not be saved."
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
        pendingInventoryShortages = []
        errorMessage = nil
    }

    private func loadFormReferences() {
        do {
            customers = try repository.fetchCustomers()
            recipes = try repository.fetchRecipes()
            cakeDesigns = try repository.fetchCakeDesigns().filter {
                $0.sourceKind == .ownerMade || $0.sourceKind == .customerReference
            }
            if let linkedDesignId = editingOrder?.cakeDesignId,
               !cakeDesigns.contains(where: { $0.id == linkedDesignId }),
               let linkedDesign = try repository.fetchCakeDesign(id: linkedDesignId) {
                cakeDesigns.append(linkedDesign)
            }
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
        if let photoId = order.customerReferencePhotoId {
            do {
                selectedOrderCustomerReferencePhoto = try repository.fetchOrderPhoto(id: photoId)
            } catch {
                selectedOrderCustomerReferencePhoto = nil
                errorMessage = "Customer reference could not be loaded."
            }
        } else {
            selectedOrderCustomerReferencePhoto = nil
        }
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

    private func loadSelectedOrderInventoryReservationRepair(for order: Order) {
        do {
            selectedOrderInventoryReservationRepair =
                try repository.fetchOrderInventoryReservationRepair(orderId: order.id)
        } catch {
            selectedOrderInventoryReservationRepair = nil
            errorMessage = "Inventory reservation status could not be loaded."
        }
    }

    private func loadSelectedOrderInventoryReservations(for order: Order) {
        do {
            let inventoryItems =
                try repository.fetchInventoryItems()
                + repository.fetchArchivedInventoryItems()
            let itemNamesById = Dictionary(
                uniqueKeysWithValues: inventoryItems.map { ($0.id, $0.name) }
            )
            selectedOrderInventoryReservations =
                try repository.fetchOrderInventoryReservations(orderId: order.id)
                .map { reservation in
                    OrderInventoryReservationRow(
                        reservation: reservation,
                        inventoryItemName: itemNamesById[reservation.inventoryItemId]
                            ?? "Missing inventory item"
                    )
                }
                .sorted {
                    $0.inventoryItemName.localizedCaseInsensitiveCompare(
                        $1.inventoryItemName
                    ) == .orderedAscending
                }
        } catch {
            selectedOrderInventoryReservations = []
            errorMessage = "Reserved inventory could not be loaded."
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
            loadSelectedOrderIngredientShortages(for: order)
            loadSelectedOrderIngredientCost(for: order, inventoryItems: inventoryItems)
        } catch {
            selectedOrderExtraIngredients = []
            selectedOrderIngredientShortages = []
            selectedOrderIngredientCost = nil
            errorMessage = "Extra ingredients could not be loaded."
        }
    }

    private func loadSelectedOrderIngredientCost(
        for order: Order,
        inventoryItems: [InventoryItem]
    ) {
        do {
            let actualCosts = try repository.fetchOrderIngredientCosts(orderId: order.id)
            if !actualCosts.isEmpty {
                let archivedItems = try repository.fetchArchivedInventoryItems()
                let itemsById = Dictionary(
                    uniqueKeysWithValues: (inventoryItems + archivedItems).map { ($0.id, $0) }
                )
                selectedOrderIngredientCost = OrderIngredientCostSummary(
                    lines: actualCosts.compactMap { cost in
                        guard let item = itemsById[cost.inventoryItemId] else { return nil }
                        return OrderIngredientCostLine(
                            inventoryItemId: item.id,
                            inventoryItemName: item.name,
                            quantity: cost.quantity,
                            unit: cost.unit,
                            knownCost: cost.knownCost,
                            missingPriceQuantity: cost.missingPriceQuantity,
                            shortfallQuantity: cost.shortfallQuantity
                        )
                    }
                )
                selectedOrderIngredientCostIsActual = true
                return
            }

            if try repository.fetchOrderRecipeUsage(orderId: order.id) != nil {
                selectedOrderIngredientCost = nil
                selectedOrderIngredientCostIsActual = true
                return
            }

            let requirements = try OrderIngredientRequirements.requirements(
                for: order,
                inventoryItems: inventoryItems,
                recipeComponents: repository.fetchRecipeComponents(recipeId:),
                recipeIngredients: repository.fetchRecipeIngredients(componentId:),
                orderExtraIngredients: repository.fetchOrderExtraIngredients(orderId:)
            )
            selectedOrderIngredientCost = try OrderIngredientCostCalculation.summary(
                requirements: requirements,
                batches: repository.fetchInventoryStockBatches(inventoryItemId:),
                at: dateProvider()
            )
            selectedOrderIngredientCostIsActual = false
        } catch {
            selectedOrderIngredientCost = nil
            selectedOrderIngredientCostIsActual = false
            errorMessage = "Ingredient cost could not be loaded."
        }
    }

    private func loadSelectedOrderIngredientShortages(for order: Order) {
        do {
            selectedOrderIngredientShortages =
                try repository.fetchProjectedIngredientDemandSummary(at: dateProvider())
                .shortages.filter { $0.orderIds.contains(order.id) }
        } catch {
            selectedOrderIngredientShortages = []
            errorMessage = "Projected ingredient availability could not be loaded."
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
        currentStatus.recordsRecipeUsage(whenChangingTo: newStatus)
    }

    private func recipeUsageErrorMessage(for error: OrderRecipeUsageError) -> String {
        switch error {
        case .orderNotFound:
            return "Order could not be found."
        case .orderHasNoLinkedRecipe:
            return "Link a recipe before using it."
        case .alreadyRecorded:
            return "Recipe has already been used for this order."
        case .inventoryConsumptionRequired:
            return "Confirm inventory deduction before saving."
        case .recipeHasNoIngredients:
            return "Recipe has no ingredients to deduct."
        case .missingInventoryItem:
            return "Recipe ingredient inventory item could not be found."
        case .incompatibleIngredientUnit(let itemName):
            return "\(itemName) has an incompatible recipe unit."
        case .invalidIngredientQuantity(let itemName):
            return "\(itemName) has an invalid recipe quantity."
        case .insufficientStock(let shortages):
            let itemNames = shortages.map(\.inventoryItemName).joined(separator: ", ")
            return "Not enough \(itemNames) in inventory."
        }
    }

    private func extraIngredientErrorMessage(for error: OrderRecipeUsageError) -> String {
        switch error {
        case .orderNotFound:
            return "Order could not be found."
        case .orderHasNoLinkedRecipe:
            return "Link a recipe before adding this ingredient."
        case .alreadyRecorded:
            return "Inventory has already been deducted for this order."
        case .inventoryConsumptionRequired:
            return "Confirm inventory deduction before adding this ingredient."
        case .recipeHasNoIngredients:
            return "The order has no ingredients to reserve."
        case .missingInventoryItem:
            return "An inventory item required by this order could not be found."
        case .incompatibleIngredientUnit(let itemName):
            return "\(itemName) has an incompatible unit for this order ingredient."
        case .invalidIngredientQuantity(let itemName):
            return "\(itemName) has an invalid quantity."
        case .insufficientStock(let shortages):
            let itemNames = shortages.map(\.inventoryItemName).joined(separator: ", ")
            return "Not enough \(itemNames) in inventory."
        }
    }

    private func resetDraft() {
        draftTitle = ""
        draftCustomerName = ""
        draftCustomerId = ""
        draftRecipeId = ""
        draftRecipeScaleMultiplier = "1"
        draftCakeDesignId = ""
        draftCustomerReferencePhotoId = ""
        draftDueAt = dateProvider()
        draftStatus = .draft
        draftFulfillmentType = .pickup
        draftDeliveryAddress = ""
        draftCakeNotes = ""
        draftCakeMessage = ""
        draftQuotedPrice = ""
        draftDepositPaid = ""
        draftPaymentNotes = ""
        draftReminderMode = .useDefaults
        draftReminderDayOffsets = "3, 2, 1"
        draftReminderIncludesDueTime = true
        draftIngredientCost = nil
        draftIngredientCostIsActual = false
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

    private func loadDefaultReminderDraft() {
        do {
            applyReminderConfiguration(
                try repository.fetchDefaultOrderReminderConfiguration()
            )
            errorMessage = nil
        } catch {
            applyReminderConfiguration(.initialDefault)
            errorMessage = "Order reminder defaults could not be loaded."
        }
    }

    private func applyReminderConfiguration(
        _ configuration: OrderReminderConfiguration
    ) {
        switch configuration.mode {
        case .defaultSnapshot:
            draftReminderMode = .useDefaults
        case .custom:
            draftReminderMode = .custom
        case .disabled:
            draftReminderMode = .disabled
        }
        draftReminderDayOffsets = configuration.dayOffsets
            .map(String.init)
            .joined(separator: ", ")
        draftReminderIncludesDueTime = configuration.includesDueTime
    }

    private func draftReminderConfiguration() throws -> OrderReminderConfiguration {
        do {
            return try OrderReminderDraftValidation.configuration(
                mode: draftReminderMode,
                dayOffsetsText: draftReminderDayOffsets,
                includesDueTime: draftReminderIncludesDueTime
            )
        } catch let error as OrderDraftValidationError {
            errorMessage = error.message
            throw error
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

struct OrderInventoryReservationRow: Identifiable, Equatable {
    let reservation: OrderInventoryReservation
    let inventoryItemName: String

    var id: String {
        reservation.id
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
