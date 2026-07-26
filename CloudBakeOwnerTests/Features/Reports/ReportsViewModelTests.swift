import GRDB
import XCTest
@testable import CloudBakeOwner

@MainActor
final class ReportsViewModelTests: XCTestCase {
    func testRollingYearDefaultRemainsValidAcrossLeapYear() throws {
        let calendar = utcCalendar()
        let now = try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: 2025, month: 1, day: 1, hour: 12)
            )
        )
        let viewModel = ReportsViewModel(
            repository: try makeRepository(),
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.load()

        XCTAssertNil(viewModel.errorMessage)
    }

    func testRollingYearDefaultRemainsValidAcrossDaylightSavingFallback() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(
            TimeZone(identifier: "America/Los_Angeles")
        )
        let now = try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: 2025, month: 11, day: 2, hour: 12)
            )
        )
        let viewModel = ReportsViewModel(
            repository: try makeRepository(),
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.load()

        XCTAssertNil(viewModel.errorMessage)
    }

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
        XCTAssertEqual(viewModel.receivedPaymentSections.count, 1)
        XCTAssertEqual(viewModel.receivedPaymentSections.first?.rows.count, 1)
        XCTAssertEqual(
            viewModel.delayText(for: viewModel.receivedPayments[0]),
            "1 day late"
        )
    }

    func testDateOnlyFilterIncludesTheWholeSelectedEndDay() throws {
        let calendar = utcCalendar()
        let selectedDay = try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: 2027,
                    month: 1,
                    day: 15,
                    hour: 9
                )
            )
        )
        let lateOnSelectedDay = try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: 2027,
                    month: 1,
                    day: 15,
                    hour: 23,
                    minute: 45
                )
            )
        )
        let repository = try makeRepository()
        let order = makeOrder(
            id: "late-on-end-day",
            status: .confirmed,
            dueAt: lateOnSelectedDay,
            quotedPrice: 100
        )
        try repository.save(order)
        let viewModel = ReportsViewModel(
            repository: repository,
            dateProvider: { selectedDay },
            calendar: calendar
        )
        viewModel.rangeStart = selectedDay
        viewModel.rangeEnd = selectedDay

        viewModel.load()

        XCTAssertEqual(viewModel.outstandingOrders.map(\.id), [order.id])
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

        viewModel.loadSalesDrillDown(populatedBucket)
        XCTAssertEqual(viewModel.salesDrillDownOrders.map(\.id), [order.id])
        XCTAssertFalse(viewModel.canLoadMoreSalesDrillDown)
    }

    func testProfitabilityUsesEstimatesUntilOrderIsCompleted() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let readyOrder = makeOrder(
            id: "ready-with-consumption",
            status: .ready,
            dueAt: now,
            quotedPrice: 100
        )
        let completedOrder = makeOrder(
            id: "completed-with-consumption",
            status: .completed,
            dueAt: now,
            quotedPrice: 100
        )
        let legacyCompletedOrder = makeOrder(
            id: "completed-without-consumption",
            status: .completed,
            dueAt: now,
            quotedPrice: 100
        )
        let inventoryItem = InventoryItem(
            id: "report-flour",
            name: "Flour",
            aliases: [],
            type: .perishable,
            unit: .gram,
            currentQuantity: 0,
            minimumQuantity: 0,
            createdAt: now,
            updatedAt: now
        )
        try repository.save(inventoryItem)
        try repository.save(readyOrder)
        try repository.save(completedOrder)
        try repository.save(legacyCompletedOrder)
        try queue.write { db in
            for orderId in [readyOrder.id, completedOrder.id] {
                try db.execute(
                    sql: """
                        INSERT INTO order_ingredient_costs
                        (
                            id, order_id, inventory_item_id, quantity, unit,
                            known_cost_decimal, missing_price_quantity,
                            shortfall_quantity, recorded_at_unix_time
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        "cost-\(orderId)",
                        orderId,
                        inventoryItem.id,
                        100,
                        InventoryUnit.gram.rawValue,
                        "42",
                        0,
                        0,
                        now.timeIntervalSince1970
                    ]
                )
            }
        }
        let viewModel = ReportsViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: utcCalendar()
        )
        viewModel.selectedReport = .orderProfitability

        viewModel.load()

        let rows = Dictionary(uniqueKeysWithValues: viewModel.profitabilityRows.map {
            ($0.id, $0)
        })
        XCTAssertEqual(rows[readyOrder.id]?.ingredientCost, 0)
        XCTAssertFalse(try XCTUnwrap(rows[readyOrder.id]).hasIncompleteCost)
        XCTAssertEqual(rows[completedOrder.id]?.ingredientCost, 42)
        XCTAssertFalse(try XCTUnwrap(rows[completedOrder.id]).hasIncompleteCost)
        XCTAssertNil(rows[legacyCompletedOrder.id]?.ingredientCost)
        XCTAssertTrue(try XCTUnwrap(rows[legacyCompletedOrder.id]).hasIncompleteCost)
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
