import Foundation

@MainActor
final class OrderListViewModel: ObservableObject {
    @Published private(set) var orders: [Order] = []
    @Published private(set) var customers: [Customer] = []
    @Published private(set) var selectedOrder: Order?
    @Published var draftTitle = ""
    @Published var draftCustomerName = ""
    @Published var draftCustomerId = ""
    @Published var draftDueAt = Date()
    @Published var draftStatus: OrderStatus = .draft
    @Published var draftFulfillmentType: OrderFulfillmentType = .pickup
    @Published var draftDeliveryAddress = ""
    @Published var draftCakeNotes = ""
    @Published var errorMessage: String?

    private let repository: any OrderRepository & CustomerRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date

    init(
        repository: any OrderRepository & CustomerRepository,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    func load() {
        do {
            orders = try repository.fetchOrders()
            customers = try repository.fetchCustomers()
            errorMessage = nil
        } catch {
            errorMessage = "Orders could not be loaded."
        }
    }

    func beginAddingOrder() {
        resetDraft()
        errorMessage = nil
        loadCustomers()
    }

    func beginViewingOrder(_ order: Order) {
        selectedOrder = order
        errorMessage = nil
    }

    func closeOrderDetail() {
        selectedOrder = nil
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

    func addOrder() -> Bool {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            errorMessage = "Order title is required."
            return false
        }

        let customerName = draftCustomerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !customerName.isEmpty else {
            errorMessage = "Customer name is required."
            return false
        }

        let now = dateProvider()
        let order = Order(
            id: idGenerator(),
            customerId: draftCustomerId.isEmpty ? nil : draftCustomerId,
            cakeDesignId: nil,
            title: title,
            customerName: customerName,
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

    private func loadCustomers() {
        do {
            customers = try repository.fetchCustomers()
        } catch {
            customers = []
            errorMessage = "Customers could not be loaded."
        }
    }

    private func resetDraft() {
        draftTitle = ""
        draftCustomerName = ""
        draftCustomerId = ""
        draftDueAt = dateProvider()
        draftStatus = .draft
        draftFulfillmentType = .pickup
        draftDeliveryAddress = ""
        draftCakeNotes = ""
    }

    private func optionalText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
