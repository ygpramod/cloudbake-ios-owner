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
    @Published private(set) var selectedOrder: Order?
    @Published private(set) var selectedOrderCustomer: Customer?
    @Published private(set) var selectedOrderRecipe: Recipe?
    @Published private(set) var editingOrder: Order?
    @Published var draftTitle = ""
    @Published var draftCustomerName = ""
    @Published var draftCustomerId = ""
    @Published var draftRecipeId = ""
    @Published var draftDueAt = Date()
    @Published var draftStatus: OrderStatus = .draft
    @Published var draftFulfillmentType: OrderFulfillmentType = .pickup
    @Published var draftDeliveryAddress = ""
    @Published var draftCakeNotes = ""
    @Published var errorMessage: String?

    private let repository: any OrderRepository & CustomerRepository & RecipeRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date
    private let calendar: Calendar

    init(
        repository: any OrderRepository & CustomerRepository & RecipeRepository,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    var calendarDays: [OrderCalendarDay] {
        let groupedOrders = Dictionary(grouping: orders) { order in
            calendar.startOfDay(for: order.dueAt)
        }

        return groupedOrders.keys.sorted().map { day in
            OrderCalendarDay(
                day: day,
                orders: groupedOrders[day, default: []].sorted { lhs, rhs in
                    lhs.dueAt == rhs.dueAt ? lhs.title < rhs.title : lhs.dueAt < rhs.dueAt
                }
            )
        }
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

                return OrderReminderDueGroup(order: order, reminders: dueReminders)
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

    func load() {
        do {
            orders = try repository.fetchOrders()
            customers = try repository.fetchCustomers()
            recipes = try repository.fetchRecipes()
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
    }

    func closeOrderDetail() {
        selectedOrder = nil
        selectedOrderCustomer = nil
        selectedOrderRecipe = nil
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
    }

    func draftRecipeName() -> String {
        guard !draftRecipeId.isEmpty,
              let recipe = recipes.first(where: { $0.id == draftRecipeId }) else {
            return "No Linked Recipe"
        }

        return recipe.name
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

    func addOrder() -> Bool {
        guard let draft = validatedDraft() else {
            return false
        }

        let now = dateProvider()
        let order = Order(
            id: idGenerator(),
            customerId: draftCustomerId.isEmpty ? nil : draftCustomerId,
            cakeDesignId: nil,
            recipeId: draftRecipeId.isEmpty ? nil : draftRecipeId,
            title: draft.title,
            customerName: draft.customerName,
            status: draftStatus,
            dueAt: draftDueAt,
            fulfillmentType: draftFulfillmentType,
            deliveryAddress: optionalText(draftDeliveryAddress),
            cakeNotes: optionalText(draftCakeNotes),
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
        draftDueAt = selectedOrder.dueAt
        draftStatus = selectedOrder.status
        draftFulfillmentType = selectedOrder.fulfillmentType
        draftDeliveryAddress = selectedOrder.deliveryAddress ?? ""
        draftCakeNotes = selectedOrder.cakeNotes ?? ""
        errorMessage = nil
        loadFormReferences()
    }

    func saveEditedOrder() -> Bool {
        guard let editingOrder else {
            errorMessage = "Order could not be found."
            return false
        }
        guard let draft = validatedDraft() else {
            return false
        }

        let order = Order(
            id: editingOrder.id,
            customerId: draftCustomerId.isEmpty ? nil : draftCustomerId,
            cakeDesignId: editingOrder.cakeDesignId,
            recipeId: draftRecipeId.isEmpty ? nil : draftRecipeId,
            title: draft.title,
            customerName: draft.customerName,
            status: draftStatus,
            dueAt: draftDueAt,
            fulfillmentType: draftFulfillmentType,
            deliveryAddress: optionalText(draftDeliveryAddress),
            cakeNotes: optionalText(draftCakeNotes),
            createdAt: editingOrder.createdAt,
            updatedAt: dateProvider()
        )

        do {
            try repository.save(order)
            selectedOrder = order
            self.editingOrder = nil
            resetDraft()
            load()
            loadSelectedOrderCustomer(for: order)
            loadSelectedOrderRecipe(for: order)
            return true
        } catch {
            errorMessage = "Order could not be saved."
            return false
        }
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
        } catch {
            customers = []
            recipes = []
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

    private func resetDraft() {
        draftTitle = ""
        draftCustomerName = ""
        draftCustomerId = ""
        draftRecipeId = ""
        draftDueAt = dateProvider()
        draftStatus = .draft
        draftFulfillmentType = .pickup
        draftDeliveryAddress = ""
        draftCakeNotes = ""
    }

    private func validatedDraft() -> (title: String, customerName: String)? {
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

        return (title, customerName)
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
}

private extension Order {
    var hasActiveReminderState: Bool {
        status != .completed && status != .cancelled
    }
}
