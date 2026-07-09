import Foundation

struct PaymentDueReminderItem: Equatable, Identifiable {
    let id: String
    let orderName: String
    let customerName: String
    let balanceDueText: String
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

    private let repository: any OrderRepository & InventoryItemRepository
    private let dateProvider: () -> Date
    private let calendar: Calendar

    init(
        repository: any OrderRepository & InventoryItemRepository,
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
            let lowInventory = try repository.fetchInventoryItems().filter(\.isLowStock)
            paymentDueItems = Self.paymentDueItems(from: orders)
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

    private static func paymentDueItems(from orders: [Order]) -> [PaymentDueReminderItem] {
        orders
            .filter(\.hasActiveReminderState)
            .compactMap { order in
                guard let balanceDue = order.balanceDue,
                      balanceDue > 0 else {
                    return nil
                }

                return PaymentDueReminderItem(
                    id: order.id,
                    orderName: order.title,
                    customerName: order.customerName,
                    balanceDueText: MoneyDisplay.formatted(balanceDue)
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
}
