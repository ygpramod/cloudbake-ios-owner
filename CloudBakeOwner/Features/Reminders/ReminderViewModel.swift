import Foundation

struct PaymentDueReminderItem: Equatable, Identifiable {
    let id: String
    let orderName: String
    let customerName: String
    let firstName: String
    let balanceDueText: String
    let paymentMessage: String
    let whatsappURL: URL?

    var paymentConfirmationMessage: String {
        "Record the remaining balance of \(balanceDueText) as paid?"
    }
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
    @Published private(set) var canLoadMorePaymentDueItems = false
    @Published private(set) var canLoadMoreTodayOrderItems = false
    @Published var errorMessage: String?

    private let repository: any OrderRepository & InventoryItemRepository & CustomerRepository & ProjectedIngredientDemandRepository & PaymentReceiptRepository
    private let dateProvider: () -> Date
    private let calendar: Calendar
    private let onPaymentChanged: () -> Void
    private var paymentDueCursor: OrderPageCursor?
    private var todayOrderCursor: OrderPageCursor?
    private var paymentDueAsOf: Date?
    private var loadedTodayOrderRange: ClosedRange<Date>?
    private var customers: [Customer] = []
    private static let orderPageSize = 25

    init(
        repository: any OrderRepository & InventoryItemRepository & CustomerRepository & ProjectedIngredientDemandRepository & PaymentReceiptRepository,
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        onPaymentChanged: @escaping () -> Void = {}
    ) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.calendar = calendar
        self.onPaymentChanged = onPaymentChanged
    }

    func load() {
        do {
            let customers = try repository.fetchCustomers()
            let inventoryItems = try repository.fetchInventoryItems()
            let now = dateProvider()
            let todayRange = todayOrderRange(at: now)
            let paymentPage = try repository.fetchOrderPage(
                query: .paymentPending(asOf: now),
                after: nil,
                limit: Self.orderPageSize
            )
            let todayPage = try repository.fetchOrderPage(
                query: .active(dueAtRange: todayRange),
                after: nil,
                limit: Self.orderPageSize
            )
            let demandSummary = try repository.fetchProjectedIngredientDemandSummary(at: now)
            let shortages = demandSummary.shortages
            let shortagesByItemId = Dictionary(uniqueKeysWithValues: shortages.map { ($0.id, $0) })
            let lowInventory = InventoryLowInventoryAlertRules.itemsForAlerts(
                inventoryItems: inventoryItems,
                neededInventoryItemIds: demandSummary.neededInventoryItemIds,
                projectedShortageIds: Set(shortages.map(\.inventoryItemId))
            )
            self.customers = customers
            paymentDueItems = paymentDueItems(
                from: paymentPage.orders,
                customers: customers
            )
            todayOrderItems = todayOrderItems(from: todayPage.orders)
            paymentDueCursor = paymentPage.nextCursor
            todayOrderCursor = todayPage.nextCursor
            paymentDueAsOf = now
            loadedTodayOrderRange = todayRange
            canLoadMorePaymentDueItems = paymentPage.nextCursor != nil
            canLoadMoreTodayOrderItems = todayPage.nextCursor != nil
            lowInventoryItems = lowInventory.map {
                Self.lowInventoryItem(from: $0, shortage: shortagesByItemId[$0.id])
            }
            errorMessage = nil
        } catch {
            paymentDueItems = []
            todayOrderItems = []
            lowInventoryItems = []
            paymentDueCursor = nil
            todayOrderCursor = nil
            paymentDueAsOf = nil
            loadedTodayOrderRange = nil
            canLoadMorePaymentDueItems = false
            canLoadMoreTodayOrderItems = false
            errorMessage = "Reminders could not be loaded."
        }
    }

    func loadMorePaymentDueItems() {
        guard let paymentDueCursor, let paymentDueAsOf else {
            return
        }

        do {
            let page = try repository.fetchOrderPage(
                query: .paymentPending(asOf: paymentDueAsOf),
                after: paymentDueCursor,
                limit: Self.orderPageSize
            )
            paymentDueItems.append(
                contentsOf: paymentDueItems(from: page.orders, customers: customers)
            )
            self.paymentDueCursor = page.nextCursor
            canLoadMorePaymentDueItems = page.nextCursor != nil
            errorMessage = nil
        } catch {
            errorMessage = "More payment reminders could not be loaded."
        }
    }

    func loadMoreTodayOrderItems() {
        guard let todayOrderCursor, let loadedTodayOrderRange else {
            return
        }

        do {
            let page = try repository.fetchOrderPage(
                query: .active(dueAtRange: loadedTodayOrderRange),
                after: todayOrderCursor,
                limit: Self.orderPageSize
            )
            todayOrderItems.append(contentsOf: todayOrderItems(from: page.orders))
            self.todayOrderCursor = page.nextCursor
            canLoadMoreTodayOrderItems = page.nextCursor != nil
            errorMessage = nil
        } catch {
            errorMessage = "More order reminders could not be loaded."
        }
    }

    func markPaid(orderId: String) -> Bool {
        let now = dateProvider()
        do {
            _ = try repository.recordRemainingBalancePayment(
                orderId: orderId,
                receivedAt: now,
                note: nil,
                createdAt: now
            )
            load()
            onPaymentChanged()
            return true
        } catch PaymentReceiptPersistenceError.quotedPriceMissing {
            errorMessage = "Add quoted price before recording payment."
            return false
        } catch PaymentReceiptPersistenceError.orderNotFound {
            errorMessage = "Order could not be found."
            return false
        } catch {
            errorMessage = "Payment could not be updated."
            return false
        }
    }

    private func paymentDueItems(from orders: [Order], customers: [Customer]) -> [PaymentDueReminderItem] {
        orders
            .compactMap { order in
                guard let balanceDue = order.balanceDue else {
                    return nil
                }

                let customer = order.customerId.flatMap { customerId in
                    customers.first { $0.id == customerId }
                }
                let customerName = customer?.name ?? order.customerName
                let firstName = Self.firstName(from: customerName)
                let balanceDueText = MoneyDisplay.formatted(balanceDue)
                let paymentMessage = "\(firstName) has \(balanceDueText) balance due for \(order.title)."

                return PaymentDueReminderItem(
                    id: order.id,
                    orderName: order.title,
                    customerName: customerName,
                    firstName: firstName,
                    balanceDueText: balanceDueText,
                    paymentMessage: paymentMessage,
                    whatsappURL: Self.whatsappURL(
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
    }

    private func todayOrderItems(from orders: [Order]) -> [TodayOrderReminderItem] {
        return orders
            .filter(\.hasActiveReminderState)
            .map {
                TodayOrderReminderItem(
                    id: $0.id,
                    orderName: $0.title,
                    customerName: $0.customerName
                )
            }
    }

    private func todayOrderRange(at date: Date) -> ClosedRange<Date> {
        let start = calendar.startOfDay(for: date)
        let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
        return start...exclusiveEnd.addingTimeInterval(-0.001)
    }

    private static func lowInventoryItem(
        from item: InventoryItem,
        shortage: ProjectedIngredientShortage?
    ) -> LowInventoryReminderItem {
        LowInventoryReminderItem(
            id: item.id,
            name: item.name,
            quantityText: shortage.map {
                "\($0.availableQuantity.formatted()) usable / \($0.requiredQuantity.formatted()) needed \($0.unit.displayName)"
            } ?? "\(item.currentQuantity.formatted()) / \(item.minimumQuantity.formatted()) \(item.unit.displayName)"
        )
    }

    private static func firstName(from name: String) -> String {
        TextInputFormatting.trimmed(name)
            .split(separator: " ")
            .first
            .map(String.init) ?? name
    }

    private func whatsappMessage(
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

    private func formattedDueDate(_ dueAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d MMM yyyy, h:mm a"
        return formatter.string(from: dueAt)
    }
}
