import XCTest

@testable import CloudBakeOwner

@MainActor
final class ReminderViewModelTests: XCTestCase {
    func testLoadShowsPaymentDueOnlyForOverdueCompletedOrdersWithBalanceDue() throws {
        let repository = FakeReminderRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        let dueAt = calendar.date(from: DateComponents(year: 2026, month: 7, day: 8, hour: 18))!
        repository.customers = [
            makeCustomer(id: "customer-amy", name: "Amy Rao", phone: "+65 9123 4567")
        ]
        repository.orders = [
            makeOrder(
                id: "order-confirmed",
                title: "Confirmed Cake",
                status: .confirmed,
                dueAt: dueAt,
                quotedPrice: decimal("150"),
                depositPaid: decimal("50")
            ),
            makeOrder(
                id: "order-ready",
                title: "Chocolate Truffle Cake",
                customerId: "customer-amy",
                status: .completed,
                dueAt: dueAt,
                quotedPrice: decimal("150"),
                depositPaid: decimal("50")
            ),
            makeOrder(
                id: "order-completed",
                title: "Completed Cake",
                status: .completed,
                dueAt: dueAt,
                quotedPrice: decimal("80"),
                depositPaid: decimal("20")
            ),
            makeOrder(
                id: "order-paid",
                title: "Paid Cake",
                status: .completed,
                dueAt: dueAt,
                quotedPrice: decimal("75"),
                depositPaid: decimal("75")
            ),
            makeOrder(
                id: "order-ready-unpaid",
                title: "Ready Cake",
                status: .ready,
                dueAt: dueAt,
                quotedPrice: decimal("75"),
                depositPaid: nil
            ),
        ]
        let viewModel = ReminderViewModel(repository: repository, calendar: calendar)

        viewModel.load()

        XCTAssertEqual(viewModel.paymentDueItems.count, 2)
        XCTAssertEqual(
            viewModel.paymentDueItems.map(\.id),
            ["order-completed", "order-ready"]
        )
        let linkedPayment = try XCTUnwrap(
            viewModel.paymentDueItems.first { $0.id == "order-ready" }
        )
        let unlinkedPayment = try XCTUnwrap(
            viewModel.paymentDueItems.first { $0.id == "order-completed" }
        )
        XCTAssertEqual(linkedPayment.orderName, "Chocolate Truffle Cake")
        XCTAssertEqual(linkedPayment.customerName, "Amy Rao")
        XCTAssertEqual(linkedPayment.firstName, "Amy")
        XCTAssertEqual(linkedPayment.balanceDueText, MoneyDisplay.formatted(decimal("100")))
        XCTAssertEqual(
            linkedPayment.paymentConfirmationMessage,
            "Record the remaining balance of \(MoneyDisplay.formatted(decimal("100"))) as paid?"
        )
        XCTAssertEqual(
            linkedPayment.paymentMessage,
            "Amy has \(MoneyDisplay.formatted(decimal("100"))) balance due for Chocolate Truffle Cake."
        )
        XCTAssertNil(unlinkedPayment.whatsappURL)
        let whatsappURL = try XCTUnwrap(linkedPayment.whatsappURL)
        let components = try XCTUnwrap(URLComponents(url: whatsappURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "whatsapp")
        XCTAssertEqual(components.host, "send")
        XCTAssertEqual(components.queryItems?.first { $0.name == "phone" }?.value, "+6591234567")
        XCTAssertEqual(
            components.queryItems?.first { $0.name == "text" }?.value,
            """
            Hi Amy, this is a reminder for your CloudBake order.

            Balance due: \(MoneyDisplay.formatted(decimal("100")))
            Order: Chocolate Truffle Cake
            Due: 8 Jul 2026, 6:00 PM

            You can make the payment when convenient. Thank you!
            """
        )
    }

    func testLoadShowsActiveOrdersForTodayOnly() {
        let repository = FakeReminderRepository()
        let calendar = utcCalendar()
        let now = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 10))!
        let todayMorning = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 9))!
        let todayEvening = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10, hour: 18))!
        let tomorrow = calendar.date(from: DateComponents(year: 2027, month: 2, day: 11, hour: 9))!
        repository.orders = [
            makeOrder(id: "order-evening", title: "Evening Cake", status: .ready, dueAt: todayEvening),
            makeOrder(id: "order-tomorrow", title: "Tomorrow Cake", status: .confirmed, dueAt: tomorrow),
            makeOrder(id: "order-morning", title: "Morning Cake", status: .confirmed, dueAt: todayMorning),
            makeOrder(id: "order-cancelled", title: "Cancelled Cake", status: .cancelled, dueAt: todayMorning),
        ]
        let viewModel = ReminderViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.load()

        XCTAssertEqual(
            viewModel.todayOrderItems,
            [
                TodayOrderReminderItem(id: "order-morning", orderName: "Morning Cake", customerName: "Amy"),
                TodayOrderReminderItem(id: "order-evening", orderName: "Evening Cake", customerName: "Amy"),
            ]
        )
    }

    func testReminderListsLoadIndependentBoundedPages() {
        let repository = FakeReminderRepository()
        let calendar = utcCalendar()
        let now = calendar.date(
            from: DateComponents(year: 2027, month: 2, day: 10, hour: 12)
        )!
        let paymentOrders = (0..<26).map { index in
            makeOrder(
                id: String(format: "payment-%02d", index),
                status: .completed,
                dueAt: now.addingTimeInterval(TimeInterval(-3_600 - index)),
                quotedPrice: decimal("100"),
                depositPaid: decimal("25")
            )
        }
        let todayOrders = (0..<26).map { index in
            makeOrder(
                id: String(format: "today-%02d", index),
                status: .confirmed,
                dueAt: now.addingTimeInterval(TimeInterval(index))
            )
        }
        repository.orders = paymentOrders + todayOrders
        let viewModel = ReminderViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.load()

        XCTAssertEqual(viewModel.paymentDueItems.count, 25)
        XCTAssertEqual(viewModel.todayOrderItems.count, 25)
        XCTAssertTrue(viewModel.canLoadMorePaymentDueItems)
        XCTAssertTrue(viewModel.canLoadMoreTodayOrderItems)

        viewModel.loadMorePaymentDueItems()
        viewModel.loadMoreTodayOrderItems()

        XCTAssertEqual(viewModel.paymentDueItems.count, 26)
        XCTAssertEqual(viewModel.todayOrderItems.count, 26)
        XCTAssertFalse(viewModel.canLoadMorePaymentDueItems)
        XCTAssertFalse(viewModel.canLoadMoreTodayOrderItems)
    }

    func testLoadShowsLowInventoryWithCurrentAndMinimumQuantity() {
        let repository = FakeReminderRepository()
        repository.items = [
            makeInventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                currentQuantity: 250,
                minimumQuantity: 500
            ),
            makeInventoryItem(
                id: "inventory-sugar",
                name: "Sugar",
                currentQuantity: 1000,
                minimumQuantity: 500
            ),
        ]
        let viewModel = ReminderViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(
            viewModel.lowInventoryItems,
            [
                LowInventoryReminderItem(
                    id: "inventory-flour",
                    name: "Cake flour",
                    quantityText: "250 / 500 g"
                )
            ]
        )
    }

    func testLoadSuppressesPerishableLowInventoryUntilActiveOrderNeedsIt() {
        let repository = FakeReminderRepository()
        repository.items = [
            makeInventoryItem(
                id: "inventory-strawberry",
                name: "Strawberry",
                type: .perishable,
                currentQuantity: 0,
                minimumQuantity: 10
            )
        ]
        let viewModel = ReminderViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.lowInventoryItems, [])
    }

    func testLoadShowsPerishableLowInventoryWhenActiveOrderExtraIngredientNeedsIt() {
        let repository = FakeReminderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        repository.items = [
            makeInventoryItem(
                id: "inventory-strawberry",
                name: "Strawberry",
                type: .perishable,
                currentQuantity: 0,
                minimumQuantity: 10
            )
        ]
        repository.orders = [
            makeOrder(id: "order-strawberry-cake", status: .confirmed, dueAt: dueAt)
        ]
        repository.extraIngredients = [
            makeOrderExtraIngredient(
                id: "extra-strawberry",
                orderId: "order-strawberry-cake",
                inventoryItemId: "inventory-strawberry"
            )
        ]
        let viewModel = ReminderViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(
            viewModel.lowInventoryItems,
            [
                LowInventoryReminderItem(
                    id: "inventory-strawberry",
                    name: "Strawberry",
                    quantityText: "0 usable / 1 needed g"
                )
            ]
        )
    }

    func testLoadShowsProjectedShortageAcrossOrderExtras() {
        let repository = FakeReminderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        repository.items = [
            makeInventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                currentQuantity: 10,
                minimumQuantity: 5
            )
        ]
        repository.orders = [
            makeOrder(id: "order-one", status: .confirmed, dueAt: dueAt),
            makeOrder(id: "order-two", status: .confirmed, dueAt: dueAt),
        ]
        repository.extraIngredients = [
            makeOrderExtraIngredient(
                id: "extra-one",
                orderId: "order-one",
                inventoryItemId: "inventory-flour",
                quantity: 6
            ),
            makeOrderExtraIngredient(
                id: "extra-two",
                orderId: "order-two",
                inventoryItemId: "inventory-flour",
                quantity: 6
            ),
        ]

        let viewModel = ReminderViewModel(repository: repository)
        viewModel.load()

        XCTAssertEqual(viewModel.lowInventoryItems.map(\.id), ["inventory-flour"])
        XCTAssertEqual(repository.planningSnapshotFetchCount, 1)
        XCTAssertEqual(Set(repository.lastPlanningOrderIds), ["order-one", "order-two"])
    }

    func testMarkPaidUpdatesOrderAndRemovesPaymentDueReminder() {
        let repository = FakeReminderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        var paymentChangeCount = 0
        repository.orders = [
            makeOrder(
                id: "order-ready",
                title: "Chocolate Cake",
                status: .completed,
                dueAt: dueAt,
                quotedPrice: decimal("150"),
                depositPaid: decimal("50")
            )
        ]
        let viewModel = ReminderViewModel(
            repository: repository,
            dateProvider: { dueAt.addingTimeInterval(1) },
            onPaymentChanged: { paymentChangeCount += 1 }
        )
        viewModel.load()

        XCTAssertTrue(viewModel.markPaid(orderId: "order-ready"))

        XCTAssertEqual(repository.orders.first?.depositPaid, decimal("150"))
        XCTAssertEqual(viewModel.paymentDueItems, [])
        XCTAssertEqual(paymentChangeCount, 1)
    }
}

private final class FakeReminderRepository: OrderRepository,
    ProjectedIngredientDemandRepository,
    OrderRecipeUsageRepository,
    OrderInventoryReservationRepository,
    InventoryItemRepository,
    InventoryStockBatchRepository,
    CustomerRepository,
    RecipeComponentRepository,
    RecipeIngredientRepository,
    OrderExtraIngredientRepository,
    PaymentReceiptRepository
{
    var orders: [Order] = []
    var items: [InventoryItem] = []
    var customers: [Customer] = []
    var components: [RecipeComponent] = []
    var ingredients: [RecipeIngredient] = []
    var extraIngredients: [OrderExtraIngredient] = []
    var batches: [InventoryStockBatch] = []
    var usages: [OrderRecipeUsage] = []
    var reservations: [OrderInventoryReservation] = []
    var reservationRepairs: [OrderInventoryReservationRepair] = []
    var planningSnapshotFetchCount = 0
    var lastPlanningOrderIds: [String] = []

    func save(_ order: Order) throws {
        if let existingIndex = orders.firstIndex(where: { $0.id == order.id }) {
            orders[existingIndex] = order
        } else {
            orders.append(order)
        }
    }

    func recordPayment(
        orderId: String,
        amount: Decimal,
        receivedAt _: Date,
        note _: String?,
        createdAt: Date
    ) throws -> PaymentReceipt {
        guard let index = orders.firstIndex(where: { $0.id == orderId }) else {
            throw PaymentReceiptPersistenceError.orderNotFound
        }
        guard let quotedPrice = orders[index].quotedPrice else {
            throw PaymentReceiptPersistenceError.quotedPriceMissing
        }
        let paid = (orders[index].depositPaid ?? 0) + amount
        guard amount > 0 else {
            throw PaymentReceiptPersistenceError.invalidAmount
        }
        guard paid <= quotedPrice else {
            throw PaymentReceiptPersistenceError.exceedsBalance
        }
        orders[index] = orderWithPayment(
            orders[index],
            depositPaid: paid,
            updatedAt: createdAt
        )
        return PaymentReceipt(
            id: "receipt-\(orderId)",
            orderId: orderId,
            amount: amount,
            receivedAt: createdAt,
            note: nil,
            createdAt: createdAt,
            void: nil
        )
    }

    func recordRemainingBalancePayment(
        orderId: String,
        receivedAt: Date,
        note: String?,
        createdAt: Date
    ) throws -> PaymentReceipt {
        guard let order = orders.first(where: { $0.id == orderId }) else {
            throw PaymentReceiptPersistenceError.orderNotFound
        }
        guard let balance = order.balanceDue else {
            throw PaymentReceiptPersistenceError.quotedPriceMissing
        }
        return try recordPayment(
            orderId: orderId,
            amount: balance,
            receivedAt: receivedAt,
            note: note,
            createdAt: createdAt
        )
    }

    func voidPaymentReceipt(
        receiptId _: String,
        reason _: String?,
        voidedAt _: Date,
        createdAt _: Date
    ) throws -> PaymentReceiptVoid {
        throw PaymentReceiptPersistenceError.receiptNotFound
    }

    func fetchPaymentReceipts(orderId _: String) throws -> [PaymentReceipt] {
        []
    }

    func fetchLegacyPaidAmount(orderId: String) throws -> Decimal {
        guard orders.contains(where: { $0.id == orderId }) else {
            throw PaymentReceiptPersistenceError.orderNotFound
        }
        return 0
    }

    func fetchOrder(id: String) throws -> Order? {
        orders.first { $0.id == id }
    }

    func fetchOrders() throws -> [Order] {
        orders
    }

    func fetchOrderRecipeUsage(orderId: String) throws -> OrderRecipeUsage? {
        usages.first { $0.orderId == orderId }
    }

    func recordRecipeUsage(
        for order: Order,
        usageId: String,
        usedAt: Date,
        transactionIdProvider: () -> String
    ) throws {}

    func fetchOrderInventoryReservations(
        orderId: String
    ) throws -> [OrderInventoryReservation] {
        reservations.filter { $0.orderId == orderId }
    }

    func fetchInventoryReservationTotal(
        inventoryItemId: String,
        excludingOrderId: String?
    ) throws -> Double {
        reservations
            .filter {
                $0.inventoryItemId == inventoryItemId
                    && $0.orderId != excludingOrderId
            }
            .reduce(0) { $0 + $1.requiredQuantity }
    }

    func fetchOrderInventoryReservationEvents(
        orderId _: String,
        limit _: Int
    ) throws -> [OrderInventoryReservationEvent] {
        []
    }

    func fetchOrderInventoryReservationRepair(
        orderId: String
    ) throws -> OrderInventoryReservationRepair? {
        reservationRepairs.first { $0.orderId == orderId }
    }

    func fetchOrderInventoryReservationPlanningSnapshot(
        orderIds: [String]
    ) throws -> OrderInventoryReservationPlanningSnapshot {
        planningSnapshotFetchCount += 1
        lastPlanningOrderIds = orderIds
        return makeInventoryReservationPlanningSnapshot(
            orderIds: orderIds,
            orders: orders,
            usages: usages,
            reservations: reservations,
            repairs: reservationRepairs,
            components: components,
            ingredients: ingredients,
            extras: extraIngredients,
            batches: batches
        )
    }

    func save(_ batch: InventoryStockBatch) throws {}
    func saveBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {}
    func deleteBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {}
    func replaceInventoryStock(item: InventoryItem, batches: [InventoryStockBatch]) throws {
        self.batches = batches
    }
    func fetchInventoryStockBatches(inventoryItemId: String) throws -> [InventoryStockBatch] {
        batches.filter { $0.inventoryItemId == inventoryItemId }
    }

    func save(_ item: InventoryItem) throws {}

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        items.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        items.filter { !$0.isArchived }
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        items.filter(\.isArchived)
    }

    func save(_ customer: Customer) throws {
        if let existingIndex = customers.firstIndex(where: { $0.id == customer.id }) {
            customers[existingIndex] = customer
        } else {
            customers.append(customer)
        }
    }

    func fetchCustomer(id: String) throws -> Customer? {
        customers.first { $0.id == id }
    }

    func fetchCustomers() throws -> [Customer] {
        customers
    }

    func deleteCustomer(id: String) throws {
        customers.removeAll { $0.id == id }
    }

    func save(_ component: RecipeComponent) throws {}

    func fetchRecipeComponent(id: String) throws -> RecipeComponent? {
        components.first { $0.id == id }
    }

    func fetchRecipeComponents(recipeId: String) throws -> [RecipeComponent] {
        components.filter { $0.recipeId == recipeId }
    }

    func save(_ ingredient: RecipeIngredient) throws {}

    func fetchRecipeIngredient(id: String) throws -> RecipeIngredient? {
        ingredients.first { $0.id == id }
    }

    func fetchRecipeIngredients(componentId: String) throws -> [RecipeIngredient] {
        ingredients.filter { $0.componentId == componentId }
    }

    func deleteRecipeIngredient(id: String) throws {}

    func save(_ ingredient: OrderExtraIngredient) throws {}

    func fetchOrderExtraIngredients(orderId: String) throws -> [OrderExtraIngredient] {
        extraIngredients.filter { $0.orderId == orderId }
    }

    func deleteOrderExtraIngredient(id: String) throws {}
}

private func makeInventoryItem(
    id: String,
    name: String,
    type: InventoryItemType = .standard,
    currentQuantity: Double,
    minimumQuantity: Double
) -> InventoryItem {
    let timestamp = Date(timeIntervalSince1970: 1_800_040_000)
    return InventoryItem(
        id: id,
        name: name,
        type: type,
        unit: .gram,
        currentQuantity: currentQuantity,
        minimumQuantity: minimumQuantity,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

private func makeOrderExtraIngredient(
    id: String,
    orderId: String,
    inventoryItemId: String,
    quantity: Double = 1
) -> OrderExtraIngredient {
    let timestamp = Date(timeIntervalSince1970: 1_800_040_000)
    return OrderExtraIngredient(
        id: id,
        orderId: orderId,
        inventoryItemId: inventoryItemId,
        quantity: quantity,
        unit: .gram,
        note: nil,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}
