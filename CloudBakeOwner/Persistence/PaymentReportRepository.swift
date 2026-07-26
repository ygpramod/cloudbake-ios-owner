import Foundation
import GRDB

struct ReportDateRange: Equatable {
    let start: Date
    let end: Date

    func validate() throws {
        guard start < end else {
            throw PaymentReportQueryError.invalidDateRange
        }
        // The UI supplies at most 366 complete calendar dates. A half-open
        // range spanning a daylight-saving fall-back can be one hour longer
        // than 366 fixed 24-hour periods, so reject only at 367 full days.
        guard end.timeIntervalSince(start) < 367 * 86_400 else {
            throw PaymentReportQueryError.dateRangeTooLarge
        }
    }
}

struct PaymentReceiptPageCursor: Equatable {
    let receivedAt: Date
    let receiptId: String
}

struct PaymentReceiptReportRow: Equatable {
    let receipt: PaymentReceipt
    let order: Order
}

struct PaymentReceiptReportPage: Equatable {
    let rows: [PaymentReceiptReportRow]
    let nextCursor: PaymentReceiptPageCursor?
}

struct ReportOrderPage: Equatable {
    let orders: [Order]
    let nextCursor: OrderPageCursor?
}

struct PaymentLedgerSummary: Equatable {
    let receivedTotal: Decimal
    let receivedCount: Int
    let outstandingTotal: Decimal
    let outstandingOrderCount: Int
}

struct SalesOrderSummary: Equatable {
    let orderCount: Int
    let quotedTotal: Decimal
    let receivedTotal: Decimal
    let outstandingTotal: Decimal
    let statusCounts: [OrderStatus: Int]

    var averageQuotedValue: Decimal? {
        guard orderCount > 0 else {
            return nil
        }
        return quotedTotal / Decimal(orderCount)
    }
}

enum PaymentReportQueryError: Error, Equatable {
    case invalidDateRange
    case dateRangeTooLarge
    case invalidLimit
    case noStatuses
    case invalidStoredAmount
}

protocol PaymentReportRepository {
    func fetchReceivedPaymentPage(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>,
        after cursor: PaymentReceiptPageCursor?,
        limit: Int
    ) throws -> PaymentReceiptReportPage
    func fetchOutstandingPaymentOrderPage(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>,
        after cursor: OrderPageCursor?,
        limit: Int
    ) throws -> ReportOrderPage
    func fetchReportOrderPage(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>,
        after cursor: OrderPageCursor?,
        limit: Int
    ) throws -> ReportOrderPage
    func fetchPaymentLedgerSummary(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>
    ) throws -> PaymentLedgerSummary
    func fetchSalesOrderSummary(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>
    ) throws -> SalesOrderSummary
    func fetchSalesOrderSummaries(
        dateRanges: [ReportDateRange],
        statuses: Set<OrderStatus>
    ) throws -> [SalesOrderSummary]
}

extension GRDBCoreDataRepository: PaymentReportRepository {
    func fetchReceivedPaymentPage(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>,
        after cursor: PaymentReceiptPageCursor?,
        limit: Int
    ) throws -> PaymentReceiptReportPage {
        try validateReportQuery(dateRange: dateRange, limit: limit)
        guard !statuses.isEmpty else {
            throw PaymentReportQueryError.noStatuses
        }
        return try writer.read { db in
            let statusValues = statuses.map(\.rawValue).sorted()
            let placeholders = Array(repeating: "?", count: statusValues.count)
                .joined(separator: ", ")
            var sql = """
                SELECT
                    orders.*,
                    payment_receipts.id AS report_receipt_id,
                    payment_receipts.order_id AS report_receipt_order_id,
                    payment_receipts.amount_decimal AS report_receipt_amount_decimal,
                    payment_receipts.received_at_unix_time AS report_receipt_received_at,
                    payment_receipts.note AS report_receipt_note,
                    payment_receipts.created_at_unix_time AS report_receipt_created_at
                FROM payment_receipts
                JOIN orders ON orders.id = payment_receipts.order_id
                LEFT JOIN payment_receipt_voids
                  ON payment_receipt_voids.receipt_id = payment_receipts.id
                WHERE payment_receipt_voids.id IS NULL
                  AND payment_receipts.received_at_unix_time >= ?
                  AND payment_receipts.received_at_unix_time < ?
                  AND orders.status IN (\(placeholders))
                """
            var values: [(any DatabaseValueConvertible)?] = [
                dateRange.start.timeIntervalSince1970,
                dateRange.end.timeIntervalSince1970
            ]
            values.append(contentsOf: statusValues)
            if let cursor {
                sql += """

                      AND (
                        payment_receipts.received_at_unix_time < ?
                        OR (
                          payment_receipts.received_at_unix_time = ?
                          AND payment_receipts.id < ?
                        )
                      )
                    """
                values.append(cursor.receivedAt.timeIntervalSince1970)
                values.append(cursor.receivedAt.timeIntervalSince1970)
                values.append(cursor.receiptId)
            }
            sql += """

                ORDER BY payment_receipts.received_at_unix_time DESC,
                         payment_receipts.id DESC
                LIMIT ?
                """
            values.append(limit + 1)
            let fetchedRows = try Row.fetchAll(
                db,
                sql: sql,
                arguments: arguments(values)
            )
            let pageRows = Array(fetchedRows.prefix(limit))
            let reportRows = try pageRows.map(paymentReceiptReportRow(from:))
            return PaymentReceiptReportPage(
                rows: reportRows,
                nextCursor: fetchedRows.count > limit
                    ? reportRows.last.map {
                        PaymentReceiptPageCursor(
                            receivedAt: $0.receipt.receivedAt,
                            receiptId: $0.receipt.id
                        )
                    }
                    : nil
            )
        }
    }

    func fetchOutstandingPaymentOrderPage(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>,
        after cursor: OrderPageCursor?,
        limit: Int
    ) throws -> ReportOrderPage {
        try fetchReportOrderPage(
            dateRange: dateRange,
            statuses: statuses,
            after: cursor,
            limit: limit,
            requiresOutstandingBalance: true
        )
    }

    func fetchReportOrderPage(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>,
        after cursor: OrderPageCursor?,
        limit: Int
    ) throws -> ReportOrderPage {
        try fetchReportOrderPage(
            dateRange: dateRange,
            statuses: statuses,
            after: cursor,
            limit: limit,
            requiresOutstandingBalance: false
        )
    }

    func fetchPaymentLedgerSummary(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>
    ) throws -> PaymentLedgerSummary {
        try dateRange.validate()
        guard !statuses.isEmpty else {
            throw PaymentReportQueryError.noStatuses
        }
        return try writer.read { db in
            registerReportDecimalFunctions(in: db)
            let statusValues = statuses.map(\.rawValue).sorted()
            let placeholders = Array(repeating: "?", count: statusValues.count)
                .joined(separator: ", ")
            var values: [(any DatabaseValueConvertible)?] = [
                dateRange.start.timeIntervalSince1970,
                dateRange.end.timeIntervalSince1970
            ]
            values.append(contentsOf: statusValues)
            values.append(dateRange.start.timeIntervalSince1970)
            values.append(dateRange.end.timeIntervalSince1970)
            values.append(contentsOf: statusValues)
            values.append(dateRange.start.timeIntervalSince1970)
            values.append(dateRange.end.timeIntervalSince1970)
            values.append(contentsOf: statusValues)
            guard let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT
                        (
                            SELECT cloudbake_decimal_sum(
                                payment_receipts.amount_decimal
                            )
                            FROM payment_receipts
                            JOIN orders
                              ON orders.id = payment_receipts.order_id
                            LEFT JOIN payment_receipt_voids
                              ON payment_receipt_voids.receipt_id =
                                    payment_receipts.id
                            WHERE payment_receipt_voids.id IS NULL
                              AND payment_receipts.received_at_unix_time >= ?
                              AND payment_receipts.received_at_unix_time < ?
                              AND orders.status IN (\(placeholders))
                        ) AS received_total,
                        (
                            SELECT COUNT(*)
                            FROM payment_receipts
                            JOIN orders
                              ON orders.id = payment_receipts.order_id
                            LEFT JOIN payment_receipt_voids
                              ON payment_receipt_voids.receipt_id =
                                    payment_receipts.id
                            WHERE payment_receipt_voids.id IS NULL
                              AND payment_receipts.received_at_unix_time >= ?
                              AND payment_receipts.received_at_unix_time < ?
                              AND orders.status IN (\(placeholders))
                        ) AS received_count,
                        cloudbake_outstanding_sum(
                            orders.quoted_price_decimal,
                            orders.deposit_paid_decimal
                        ) AS outstanding_total,
                        COUNT(*) FILTER (
                            WHERE cloudbake_has_outstanding(
                                orders.quoted_price_decimal,
                                orders.deposit_paid_decimal
                            ) = 1
                        ) AS outstanding_order_count
                    FROM orders
                    WHERE orders.due_at_unix_time >= ?
                      AND orders.due_at_unix_time < ?
                      AND orders.status IN (\(placeholders))
                      AND orders.quoted_price_decimal IS NOT NULL
                    """,
                arguments: arguments(values)
            ) else {
                return PaymentLedgerSummary(
                    receivedTotal: 0,
                    receivedCount: 0,
                    outstandingTotal: 0,
                    outstandingOrderCount: 0
                )
            }
            return PaymentLedgerSummary(
                receivedTotal: try reportDecimal(row["received_total"]),
                receivedCount: row["received_count"],
                outstandingTotal: try reportDecimal(row["outstanding_total"]),
                outstandingOrderCount: row["outstanding_order_count"]
            )
        }
    }

    func fetchSalesOrderSummary(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>
    ) throws -> SalesOrderSummary {
        try fetchSalesOrderSummaries(
            dateRanges: [dateRange],
            statuses: statuses
        )[0]
    }

    func fetchSalesOrderSummaries(
        dateRanges: [ReportDateRange],
        statuses: Set<OrderStatus>
    ) throws -> [SalesOrderSummary] {
        guard (1...366).contains(dateRanges.count) else {
            throw PaymentReportQueryError.invalidDateRange
        }
        try dateRanges.forEach { try $0.validate() }
        guard !statuses.isEmpty else {
            throw PaymentReportQueryError.noStatuses
        }
        return try writer.read { db in
            registerReportDecimalFunctions(in: db)
            let statusValues = statuses.map(\.rawValue).sorted()
            let placeholders = Array(repeating: "?", count: statusValues.count)
                .joined(separator: ", ")
            let bucketPayload = dateRanges.enumerated().map { index, range in
                [
                    "index": index,
                    "start": range.start.timeIntervalSince1970,
                    "end": range.end.timeIntervalSince1970
                ] as [String: Any]
            }
            let bucketData = try JSONSerialization.data(
                withJSONObject: bucketPayload
            )
            guard let bucketJSON = String(data: bucketData, encoding: .utf8) else {
                throw PaymentReportQueryError.invalidDateRange
            }
            var values: [(any DatabaseValueConvertible)?] = [bucketJSON]
            values.append(contentsOf: statusValues)
            let rows = try Row.fetchAll(
                db,
                sql: """
                    WITH buckets AS (
                        SELECT
                            CAST(
                                json_extract(value, '$.index') AS INTEGER
                            ) AS bucket_index,
                            CAST(
                                json_extract(value, '$.start') AS REAL
                            ) AS bucket_start,
                            CAST(
                                json_extract(value, '$.end') AS REAL
                            ) AS bucket_end
                        FROM json_each(?)
                    )
                    SELECT
                        buckets.bucket_index,
                        orders.status,
                        COUNT(orders.id) AS order_count,
                        cloudbake_decimal_sum(
                            orders.quoted_price_decimal
                        ) AS quoted_total,
                        cloudbake_decimal_sum(
                            orders.deposit_paid_decimal
                        ) AS received_total,
                        cloudbake_outstanding_sum(
                            orders.quoted_price_decimal,
                            orders.deposit_paid_decimal
                        ) AS outstanding_total
                    FROM buckets
                    LEFT JOIN orders
                      ON orders.due_at_unix_time >= buckets.bucket_start
                     AND orders.due_at_unix_time < buckets.bucket_end
                     AND orders.status IN (\(placeholders))
                    GROUP BY buckets.bucket_index, orders.status
                    ORDER BY buckets.bucket_index
                    """,
                arguments: arguments(values)
            )
            var summaries = Array(
                repeating: SalesOrderSummary(
                    orderCount: 0,
                    quotedTotal: 0,
                    receivedTotal: 0,
                    outstandingTotal: 0,
                    statusCounts: [:]
                ),
                count: dateRanges.count
            )
            for row in rows {
                let bucketIndex: Int = row["bucket_index"]
                let count: Int = row["order_count"]
                guard count > 0,
                      let statusValue: String = row["status"],
                      let status = OrderStatus(rawValue: statusValue) else {
                    continue
                }
                let current = summaries[bucketIndex]
                var statusCounts = current.statusCounts
                statusCounts[status] = count
                summaries[bucketIndex] = SalesOrderSummary(
                    orderCount: current.orderCount + count,
                    quotedTotal: current.quotedTotal
                        + (try reportDecimal(row["quoted_total"])),
                    receivedTotal: current.receivedTotal
                        + (try reportDecimal(row["received_total"])),
                    outstandingTotal: current.outstandingTotal
                        + (try reportDecimal(row["outstanding_total"])),
                    statusCounts: statusCounts
                )
            }
            return summaries
        }
    }

    private func fetchReportOrderPage(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>,
        after cursor: OrderPageCursor?,
        limit: Int,
        requiresOutstandingBalance: Bool
    ) throws -> ReportOrderPage {
        try validateReportQuery(dateRange: dateRange, limit: limit)
        guard !statuses.isEmpty else {
            throw PaymentReportQueryError.noStatuses
        }
        return try writer.read { db in
            registerReportDecimalFunctions(in: db)
            let statusValues = statuses.map(\.rawValue).sorted()
            let placeholders = Array(repeating: "?", count: statusValues.count)
                .joined(separator: ", ")
            var sql = """
                SELECT orders.*
                FROM orders
                WHERE orders.due_at_unix_time >= ?
                  AND orders.due_at_unix_time < ?
                  AND orders.status IN (\(placeholders))
                """
            var values: [(any DatabaseValueConvertible)?] = [
                dateRange.start.timeIntervalSince1970,
                dateRange.end.timeIntervalSince1970
            ]
            values.append(contentsOf: statusValues)
            if requiresOutstandingBalance {
                sql += """

                      AND orders.quoted_price_decimal IS NOT NULL
                      AND cloudbake_has_outstanding(
                        orders.quoted_price_decimal,
                        orders.deposit_paid_decimal
                      ) = 1
                    """
            }
            if let cursor {
                sql += """

                      AND (
                        orders.due_at_unix_time < ?
                        OR (
                          orders.due_at_unix_time = ?
                          AND orders.id < ?
                        )
                      )
                    """
                values.append(cursor.dueAt.timeIntervalSince1970)
                values.append(cursor.dueAt.timeIntervalSince1970)
                values.append(cursor.orderId)
            }
            sql += """

                ORDER BY orders.due_at_unix_time DESC, orders.id DESC
                LIMIT ?
                """
            values.append(limit + 1)
            let fetchedRows = try Row.fetchAll(
                db,
                sql: sql,
                arguments: arguments(values)
            )
            let orders = Array(fetchedRows.prefix(limit)).map(order(from:))
            return ReportOrderPage(
                orders: orders,
                nextCursor: fetchedRows.count > limit
                    ? orders.last.map {
                        OrderPageCursor(dueAt: $0.dueAt, orderId: $0.id)
                    }
                    : nil
            )
        }
    }

    private func validateReportQuery(
        dateRange: ReportDateRange,
        limit: Int
    ) throws {
        try dateRange.validate()
        guard (1...50).contains(limit) else {
            throw PaymentReportQueryError.invalidLimit
        }
    }

    private func paymentReceiptReportRow(from row: Row) throws -> PaymentReceiptReportRow {
        guard let amount = optionalDecimal(row["report_receipt_amount_decimal"]) else {
            throw PaymentReportQueryError.invalidStoredAmount
        }
        return PaymentReceiptReportRow(
            receipt: PaymentReceipt(
                id: row["report_receipt_id"],
                orderId: row["report_receipt_order_id"],
                amount: amount,
                receivedAt: date(row["report_receipt_received_at"]),
                note: row["report_receipt_note"],
                createdAt: date(row["report_receipt_created_at"]),
                void: nil
            ),
            order: order(from: row)
        )
    }

    private func registerReportDecimalFunctions(in db: Database) {
        db.add(
            function: DatabaseFunction(
                "cloudbake_decimal_sum",
                argumentCount: 1,
                pure: true,
                aggregate: ReportDecimalSum.self
            )
        )
        db.add(
            function: DatabaseFunction(
                "cloudbake_outstanding_sum",
                argumentCount: 2,
                pure: true,
                aggregate: ReportOutstandingSum.self
            )
        )
        db.add(
            function: DatabaseFunction(
                "cloudbake_has_outstanding",
                argumentCount: 2,
                pure: true
            ) { values in
                guard let quoted = try reportDecimalValue(values[0]) else {
                    return 0
                }
                let paid = try reportDecimalValue(values[1]) ?? 0
                return quoted > paid ? 1 : 0
            }
        )
    }

    private func reportDecimal(_ value: String?) throws -> Decimal {
        guard let value,
              let decimal = Decimal(string: value) else {
            throw PaymentReportQueryError.invalidStoredAmount
        }
        return decimal
    }

    private func optionalReportDecimal(_ value: String?) throws -> Decimal? {
        guard let value else {
            return nil
        }
        guard let decimal = Decimal(string: value) else {
            throw PaymentReportQueryError.invalidStoredAmount
        }
        return decimal
    }
}

private struct ReportDecimalSum: DatabaseAggregate {
    private var total = Decimal.zero

    init() {}

    mutating func step(_ values: [DatabaseValue]) throws {
        if let value = try reportDecimalValue(values[0]) {
            total += value
        }
    }

    func finalize() -> (any DatabaseValueConvertible)? {
        NSDecimalNumber(decimal: total).stringValue
    }
}

private struct ReportOutstandingSum: DatabaseAggregate {
    private var total = Decimal.zero

    init() {}

    mutating func step(_ values: [DatabaseValue]) throws {
        guard let quoted = try reportDecimalValue(values[0]) else {
            return
        }
        let paid = try reportDecimalValue(values[1]) ?? 0
        total += max(quoted - paid, 0)
    }

    func finalize() -> (any DatabaseValueConvertible)? {
        NSDecimalNumber(decimal: total).stringValue
    }
}

private func reportDecimalValue(_ value: DatabaseValue) throws -> Decimal? {
    guard !value.isNull else {
        return nil
    }
    guard let string = String.fromDatabaseValue(value),
          let decimal = Decimal(string: string) else {
        throw PaymentReportQueryError.invalidStoredAmount
    }
    return decimal
}
