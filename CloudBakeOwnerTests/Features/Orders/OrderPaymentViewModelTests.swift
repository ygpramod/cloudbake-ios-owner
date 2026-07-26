import XCTest
@testable import CloudBakeOwner

@MainActor
final class OrderPaymentViewModelTests: XCTestCase {
    func testMarkSelectedOrderPaidSetsDepositToQuotedPrice() {
        let repository = FakeOrderRepository()
        let updatedAt = Date(timeIntervalSince1970: 1_800_080_000)
        let completedAt = Date(timeIntervalSince1970: 1_800_070_000)
        let order = makeOrder(
            id: "order-vanilla",
            status: .completed,
            dueAt: Date(timeIntervalSince1970: 1_800_150_000),
            quotedPrice: Decimal(200),
            depositPaid: Decimal(50),
            completedAt: completedAt
        )
        repository.orders = [order]
        var reminderRefreshCount = 0
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { updatedAt },
            onReminderDataChanged: { reminderRefreshCount += 1 }
        )

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.markSelectedOrderPaid())
        XCTAssertEqual(viewModel.selectedOrder?.depositPaid, Decimal(200))
        XCTAssertEqual(viewModel.selectedOrder?.balanceDue, Decimal(0))
        XCTAssertEqual(viewModel.selectedOrder?.paymentStatus, "Paid")
        XCTAssertEqual(repository.orders.first?.depositPaid, Decimal(200))
        XCTAssertEqual(repository.orders.first?.updatedAt, updatedAt)
        XCTAssertEqual(viewModel.selectedOrder?.completedAt, completedAt)
        XCTAssertEqual(repository.orders.first?.completedAt, completedAt)
        XCTAssertEqual(repository.paymentReceipts.map(\.amount), [Decimal(150)])
        XCTAssertEqual(repository.paymentReceipts.first?.receivedAt, updatedAt)
        XCTAssertEqual(viewModel.selectedOrderPaymentReceipts, repository.paymentReceipts)
        XCTAssertEqual(reminderRefreshCount, 1)
    }

    func testAddPaymentToSelectedOrderAddsToExistingDeposit() {
        let repository = FakeOrderRepository()
        let updatedAt = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(
            id: "order-vanilla",
            dueAt: Date(timeIntervalSince1970: 1_800_150_000),
            quotedPrice: Decimal(200),
            depositPaid: Decimal(50)
        )
        repository.orders = [order]
        let viewModel = OrderListViewModel(repository: repository, dateProvider: { updatedAt })

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.addPaymentToSelectedOrder(amountText: "75"))
        XCTAssertEqual(viewModel.selectedOrder?.depositPaid, Decimal(125))
        XCTAssertEqual(viewModel.selectedOrder?.balanceDue, Decimal(75))
        XCTAssertEqual(viewModel.selectedOrder?.paymentStatus, "Part Paid")
        XCTAssertEqual(repository.orders.first?.depositPaid, Decimal(125))
        XCTAssertEqual(repository.paymentReceipts.map(\.amount), [Decimal(75)])
        XCTAssertEqual(repository.paymentReceipts.first?.receivedAt, updatedAt)
        XCTAssertEqual(viewModel.selectedOrderPaymentReceipts, repository.paymentReceipts)
    }

    func testAddPaymentRejectsInvalidOrExcessAmount() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-vanilla",
            dueAt: Date(timeIntervalSince1970: 1_800_150_000),
            quotedPrice: Decimal(200),
            depositPaid: Decimal(150)
        )
        repository.orders = [order]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertFalse(viewModel.addPaymentToSelectedOrder(amountText: ""))
        XCTAssertEqual(viewModel.errorMessage, "Payment amount must be greater than zero.")

        XCTAssertFalse(viewModel.addPaymentToSelectedOrder(amountText: "75"))
        XCTAssertEqual(viewModel.errorMessage, "Payment received cannot be more than balance due.")
        XCTAssertEqual(repository.orders, [order])
        XCTAssertEqual(repository.paymentReceipts, [])
    }

    func testBeginViewingOrderLoadsReceiptsAndLegacyAmount() {
        let repository = FakeOrderRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(
            id: "legacy-payment-order",
            dueAt: timestamp,
            quotedPrice: 200,
            depositPaid: 75
        )
        let receipt = PaymentReceipt(
            id: "receipt-one",
            orderId: order.id,
            amount: 25,
            receivedAt: timestamp,
            note: "Transfer",
            createdAt: timestamp,
            void: nil
        )
        repository.orders = [order]
        repository.paymentReceipts = [receipt]
        repository.legacyPaidAmounts[order.id] = 50
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(viewModel.selectedOrderPaymentReceipts, [receipt])
        XCTAssertEqual(viewModel.selectedOrderLegacyPaidAmount, 50)
    }
}
