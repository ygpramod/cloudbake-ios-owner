import GRDB
import XCTest
@testable import CloudBakeOwner

@MainActor
final class ReportsViewModelTests: XCTestCase {
    func testPaymentLedgerDefaultsToOutstandingForRollingYear() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = try makeRepository()
        let order = makeOrder(
            id: "outstanding-order",
            status: .completed,
            dueAt: now.addingTimeInterval(-86_400),
            quotedPrice: 100
        )
        try repository.save(order)
        _ = try repository.recordPayment(
            orderId: order.id,
            amount: 25,
            receivedAt: now.addingTimeInterval(-86_400),
            note: nil,
            createdAt: now.addingTimeInterval(-86_400)
        )
        let viewModel = ReportsViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: utcCalendar()
        )

        viewModel.load()

        XCTAssertEqual(viewModel.selectedReport, .paymentLedger)
        XCTAssertEqual(viewModel.paymentScope, .outstanding)
        XCTAssertEqual(viewModel.grouping, .month)
        XCTAssertEqual(viewModel.outstandingOrders.map(\.id), [order.id])
        XCTAssertEqual(viewModel.paymentSummary.outstandingTotal, 75)
        XCTAssertEqual(viewModel.overdueText(for: order), "1 day overdue")
    }

    func testReceivedLedgerUsesEachReceiptDateForDelay() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = try makeRepository()
        let dueAt = now.addingTimeInterval(-2 * 86_400)
        let order = makeOrder(
            id: "received-order",
            status: .completed,
            dueAt: dueAt,
            quotedPrice: 100
        )
        try repository.save(order)
        _ = try repository.recordPayment(
            orderId: order.id,
            amount: 40,
            receivedAt: dueAt.addingTimeInterval(86_400),
            note: nil,
            createdAt: dueAt.addingTimeInterval(86_400)
        )
        let viewModel = ReportsViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: utcCalendar()
        )
        viewModel.paymentScope = .received

        viewModel.load()

        XCTAssertEqual(viewModel.receivedPayments.count, 1)
        XCTAssertEqual(
            viewModel.delayText(for: viewModel.receivedPayments[0]),
            "1 day late"
        )
    }

    func testProfitabilityAndSalesUseOrderDueDate() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = try makeRepository()
        let order = makeOrder(
            id: "report-order",
            status: .confirmed,
            dueAt: now.addingTimeInterval(-86_400),
            quotedPrice: 120
        )
        try repository.save(order)
        _ = try repository.recordPayment(
            orderId: order.id,
            amount: 20,
            receivedAt: now.addingTimeInterval(-86_400),
            note: nil,
            createdAt: now.addingTimeInterval(-86_400)
        )
        let viewModel = ReportsViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: utcCalendar()
        )

        viewModel.selectedReport = .orderProfitability
        viewModel.load()
        XCTAssertEqual(viewModel.profitabilityRows.first?.ingredientCost, 0)
        XCTAssertEqual(viewModel.profitabilityRows.first?.ingredientMargin, 120)

        viewModel.selectedReport = .salesAndOrders
        viewModel.load()
        let populatedBucket = try XCTUnwrap(
            viewModel.salesBuckets.first { $0.summary.orderCount == 1 }
        )
        XCTAssertEqual(populatedBucket.summary.quotedTotal, 120)
        XCTAssertEqual(populatedBucket.summary.receivedTotal, 20)
        XCTAssertEqual(populatedBucket.summary.outstandingTotal, 100)
    }

    private func makeRepository() throws -> GRDBCoreDataRepository {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        return GRDBCoreDataRepository(
            writer: queue,
            idProvider: makeIncrementingIdGenerator(prefix: "report")
        )
    }
}
