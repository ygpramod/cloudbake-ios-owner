import XCTest
@testable import CloudBakeOwner

@MainActor
extension OrderListViewModelTests {
    func testMarkSelectedOrderPaidSetsDepositToQuotedPrice() {
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

        XCTAssertTrue(viewModel.markSelectedOrderPaid())
        XCTAssertEqual(viewModel.selectedOrder?.depositPaid, Decimal(200))
        XCTAssertEqual(viewModel.selectedOrder?.balanceDue, Decimal(0))
        XCTAssertEqual(viewModel.selectedOrder?.paymentStatus, "Paid")
        XCTAssertEqual(repository.orders.first?.depositPaid, Decimal(200))
        XCTAssertEqual(repository.orders.first?.updatedAt, updatedAt)
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
    }
}
