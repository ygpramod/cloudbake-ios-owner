import XCTest
@testable import CloudBakeOwner

final class OrderPaymentUpdateTests: XCTestCase {
    func testMarkingPaidSetsDepositToQuotedPrice() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_800_090_000)
        let order = makePaymentOrder(quotedPrice: Decimal(200), depositPaid: Decimal(50))

        let updatedOrder = try OrderPaymentUpdate.markingPaid(order, updatedAt: updatedAt).get()

        XCTAssertEqual(updatedOrder.depositPaid, Decimal(200))
        XCTAssertEqual(updatedOrder.balanceDue, Decimal(0))
        XCTAssertEqual(updatedOrder.updatedAt, updatedAt)
    }

    func testAddingPaymentAddsToExistingDeposit() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_800_090_000)
        let order = makePaymentOrder(quotedPrice: Decimal(200), depositPaid: Decimal(50))

        let updatedOrder = try OrderPaymentUpdate.addingPayment(" 75 ", to: order, updatedAt: updatedAt).get()

        XCTAssertEqual(updatedOrder.depositPaid, Decimal(125))
        XCTAssertEqual(updatedOrder.balanceDue, Decimal(75))
        XCTAssertEqual(updatedOrder.updatedAt, updatedAt)
    }

    func testPaymentUpdatesRequireQuotedPrice() {
        let order = makePaymentOrder(quotedPrice: nil, depositPaid: nil)

        XCTAssertEqual(
            paymentErrorMessage(OrderPaymentUpdate.markingPaid(order, updatedAt: Date())),
            "Add quoted price before recording payment."
        )
        XCTAssertEqual(
            paymentErrorMessage(OrderPaymentUpdate.addingPayment("25", to: order, updatedAt: Date())),
            "Add quoted price before recording payment."
        )
    }

    func testAddingPaymentRejectsInvalidOrExcessAmount() {
        let order = makePaymentOrder(quotedPrice: Decimal(200), depositPaid: Decimal(150))

        XCTAssertEqual(
            paymentErrorMessage(OrderPaymentUpdate.addingPayment("", to: order, updatedAt: Date())),
            "Payment amount must be greater than zero."
        )
        XCTAssertEqual(
            paymentErrorMessage(OrderPaymentUpdate.addingPayment("75", to: order, updatedAt: Date())),
            "Payment received cannot be more than balance due."
        )
    }
}

private func paymentErrorMessage(_ result: Result<Order, OrderPaymentUpdateError>) -> String? {
    guard case .failure(let error) = result else {
        return nil
    }

    return error.message
}

private func makePaymentOrder(
    quotedPrice: Decimal?,
    depositPaid: Decimal?
) -> Order {
    let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
    return Order(
        id: "order-vanilla",
        customerId: nil,
        cakeDesignId: nil,
        recipeId: nil,
        title: "Vanilla Birthday",
        customerName: "Amy",
        status: .confirmed,
        dueAt: Date(timeIntervalSince1970: 1_800_150_000),
        fulfillmentType: .pickup,
        deliveryAddress: nil,
        cakeNotes: nil,
        quotedPrice: quotedPrice,
        depositPaid: depositPaid,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}
