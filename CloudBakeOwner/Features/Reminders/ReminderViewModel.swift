import Foundation

struct PaymentDueReminderItem: Equatable, Identifiable {
    let id: String
    let orderName: String
    let customerName: String
    let firstName: String
    let balanceDueText: String
    let paymentMessage: String
    let whatsappURL: URL?
}

struct TodayOrderReminderItem: Equatable, Identifiable {
    let id: String
    let orderName: String
    let customerName: String
}

struct LowInventoryReminderItem: Equatable, Identifiable {
    let id: String
    let name: String
    let quantityText: String
}

@MainActor
final class ReminderViewModel: ObservableObject {
    @Published private(set) var paymentDueItems: [PaymentDueReminderItem] = []
    @Published private(set) var todayOrderItems: [TodayOrderReminderItem] = []
    @Published private(set) var lowInventoryItems: [LowInventoryReminderItem] = []
    @Published var errorMessage: String?

    private let repository: any OrderRepository & InventoryItemRepository & CustomerRepository
    private let dateProvider: () -> Date
    private let calendar: Calendar

    init(
        repository: any OrderRepository & InventoryItemRepository & CustomerRepository,
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func load() {
        do {
            let orders = try repository.fetchOrders()
            let customers = try repository.fetchCustomers()
            let lowInventory = try repository.fetchInventoryItems().filter(\.isLowStock)
            paymentDueItems = Self.paymentDueItems(from: orders, customers: customers)
            todayOrderItems = todayOrderItems(from: orders)
            lowInventoryItems = lowInventory.map(Self.lowInventoryItem)
            errorMessage = nil
        } catch {
            paymentDueItems = []
            todayOrderItems = []
            lowInventoryItems = []
            errorMessage = "Reminders could not be loaded."
        }
    }

    func markPaid(orderId: String) -> Bool {
        do {
            guard let order = try repository.fetchOrder(id: orderId) else {
                errorMessage = "Order could not be found."
                return false
            }

            switch OrderPaymentUpdate.markingPaid(order, updatedAt: dateProvider()) {
            case .success(let updatedOrder):
                try repository.save(updatedOrder)
                load()
                return true
            case .failure(let error):
                errorMessage = error.message
                return false
            }
        } catch {
            errorMessage = "Payment could not be updated."
            return false
        }
    }

    private static func paymentDueItems(from orders: [Order], customers: [Customer]) -> [PaymentDueReminderItem] {
        orders
            .filter { $0.status == .ready || $0.status == .completed }
            .compactMap { order in
                guard let balanceDue = order.balanceDue,
                      balanceDue > 0 else {
                    return nil
                }

                let customer = order.customerId.flatMap { customerId in
                    customers.first { $0.id == customerId }
                }
                let customerName = customer?.name ?? order.customerName
                let firstName = firstName(from: customerName)
                let balanceDueText = MoneyDisplay.formatted(balanceDue)
                let paymentMessage = "\(firstName) has \(balanceDueText) balance due for \(order.title)."

                return PaymentDueReminderItem(
                    id: order.id,
                    orderName: order.title,
                    customerName: customerName,
                    firstName: firstName,
                    balanceDueText: balanceDueText,
                    paymentMessage: paymentMessage,
                    whatsappURL: whatsappURL(
                        phone: customer?.phone,
                        message: whatsappMessage(
                            firstName: firstName,
                            balanceDueText: balanceDueText,
                            orderName: order.title,
                            dueAt: order.dueAt
                        )
                    )
                )
            }
            .sorted { lhs, rhs in
                lhs.orderName.localizedCaseInsensitiveCompare(rhs.orderName) == .orderedAscending
            }
    }

    private func todayOrderItems(from orders: [Order]) -> [TodayOrderReminderItem] {
        let today = dateProvider()
        return orders
            .filter(\.hasActiveReminderState)
            .filter { calendar.isDate($0.dueAt, inSameDayAs: today) }
            .sorted { lhs, rhs in
                if lhs.dueAt == rhs.dueAt {
                    return lhs.title < rhs.title
                }

                return lhs.dueAt < rhs.dueAt
            }
            .map {
                TodayOrderReminderItem(
                    id: $0.id,
                    orderName: $0.title,
                    customerName: $0.customerName
                )
            }
    }

    private static func lowInventoryItem(from item: InventoryItem) -> LowInventoryReminderItem {
        LowInventoryReminderItem(
            id: item.id,
            name: item.name,
            quantityText: "\(item.currentQuantity.formatted()) / \(item.minimumQuantity.formatted()) \(item.unit.displayName)"
        )
    }

    private static func firstName(from name: String) -> String {
        TextInputFormatting.trimmed(name)
            .split(separator: " ")
            .first
            .map(String.init) ?? name
    }

    private static func whatsappMessage(
        firstName: String,
        balanceDueText: String,
        orderName: String,
        dueAt: Date
    ) -> String {
        """
        Hi \(firstName), this is a reminder for your CloudBake order.

        Balance due: \(balanceDueText)
        Order: \(orderName)
        Due: \(formattedDueDate(dueAt))

        You can make the payment when convenient. Thank you!
        """
    }

    private static func whatsappURL(phone: String?, message: String) -> URL? {
        guard let phone,
              !TextInputFormatting.trimmed(phone).isEmpty else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "whatsapp"
        components.host = "send"
        components.queryItems = [
            URLQueryItem(name: "phone", value: normalizedPhoneNumber(phone)),
            URLQueryItem(name: "text", value: message)
        ]
        return components.url
    }

    private static func normalizedPhoneNumber(_ phone: String) -> String {
        let trimmed = TextInputFormatting.trimmed(phone)
        let digits = trimmed.filter(\.isNumber)
        if trimmed.hasPrefix("+") {
            return "+" + digits
        }

        return String(digits)
    }

    private static func formattedDueDate(_ dueAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "d MMM yyyy, h:mm a"
        return formatter.string(from: dueAt)
    }
}
