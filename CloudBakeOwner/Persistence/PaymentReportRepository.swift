import Foundation
import GRDB

struct ReportDateRange: Equatable {
    let start: Date
    let end: Date

    func validate() throws {
        guard start < end else {
            throw PaymentReportQueryError.invalidDateRange
        }
        guard end.timeIntervalSince(start) <= 366 * 86_400 else {
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
            let statusValues = statuses.map(\.rawValue).sorted()
            let placeholders = Array(repeating: "?", count: statusValues.count)
                .joined(separator: ", ")
            var receivedArguments: [(any DatabaseValueConvertible)?] = [
                dateRange.start.timeIntervalSince1970,
                dateRange.end.timeIntervalSince1970
            ]
            receivedArguments.append(contentsOf: statusValues)
            let receivedRows = try Row.fetchAll(
                db,
                sql: """
                    SELECT payment_receipts.amount_decimal
                    FROM payment_receipts
                    JOIN orders ON orders.id = payment_receipts.order_id
                    LEFT JOIN payment_receipt_voids
                      ON payment_receipt_voids.receipt_id = payment_receipts.id
                    WHERE payment_receipt_voids.id IS NULL
                      AND payment_receipts.received_at_unix_time >= ?
                      AND payment_receipts.received_at_unix_time < ?
                      AND orders.status IN (\(placeholders))
                    """,
                arguments: arguments(receivedArguments)
            )
            var outstandingArguments: [(any DatabaseValueConvertible)?] = [
                dateRange.start.timeIntervalSince1970,
                dateRange.end.timeIntervalSince1970
            ]
            outstandingArguments.append(contentsOf: statusValues)
            let outstandingRows = try Row.fetchAll(
                db,
                sql: """
                    SELECT
                        orders.quoted_price_decimal,
                        orders.deposit_paid_decimal
                    FROM orders
                    WHERE orders.due_at_unix_time >= ?
                      AND orders.due_at_unix_time < ?
                      AND orders.status IN (\(placeholders))
                      AND orders.quoted_price_decimal IS NOT NULL
                    """,
                arguments: arguments(outstandingArguments)
            )
            let receivedAmounts = try receivedRows.map {
                try reportDecimal($0["amount_decimal"])
            }
            let outstandingBalances = try outstandingRows.compactMap { row -> Decimal? in
                let quotedPrice = try reportDecimal(row["quoted_price_decimal"])
                let paid = try optionalReportDecimal(
                    row["deposit_paid_decimal"]
                ) ?? 0
                let balance = quotedPrice - paid
                return balance > 0 ? balance : nil
            }
            return PaymentLedgerSummary(
                receivedTotal: receivedAmounts.reduce(0, +),
                receivedCount: receivedAmounts.count,
                outstandingTotal: outstandingBalances.reduce(0, +),
                outstandingOrderCount: outstandingBalances.count
            )
        }
    }

    func fetchSalesOrderSummary(
        dateRange: ReportDateRange,
        statuses: Set<OrderStatus>
    ) throws -> SalesOrderSummary {
        try dateRange.validate()
        guard !statuses.isEmpty else {
            throw PaymentReportQueryError.noStatuses
        }
        return try writer.read { db in
            let statusValues = statuses.map(\.rawValue).sorted()
            let placeholders = Array(repeating: "?", count: statusValues.count)
                .joined(separator: ", ")
            var values: [(any DatabaseValueConvertible)?] = [
                dateRange.start.timeIntervalSince1970,
                dateRange.end.timeIntervalSince1970
            ]
            values.append(contentsOf: statusValues)
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT
                        orders.status,
                        orders.quoted_price_decimal,
                        orders.deposit_paid_decimal
                    FROM orders
                    WHERE orders.due_at_unix_time >= ?
                      AND orders.due_at_unix_time < ?
                      AND orders.status IN (\(placeholders))
                    """,
                arguments: arguments(values)
            )
            var quotedTotal = Decimal.zero
            var receivedTotal = Decimal.zero
            var outstandingTotal = Decimal.zero
            var statusCounts: [OrderStatus: Int] = [:]
            for row in rows {
                let status = OrderStatus(rawValue: row["status"]) ?? .draft
                statusCounts[status, default: 0] += 1
                let quotedPrice = try optionalReportDecimal(
                    row["quoted_price_decimal"]
                ) ?? 0
                let paid = try optionalReportDecimal(
                    row["deposit_paid_decimal"]
                ) ?? 0
                quotedTotal += quotedPrice
                receivedTotal += paid
                outstandingTotal += max(quotedPrice - paid, 0)
            }
            return SalesOrderSummary(
                orderCount: rows.count,
                quotedTotal: quotedTotal,
                receivedTotal: receivedTotal,
                outstandingTotal: outstandingTotal,
                statusCounts: statusCounts
            )
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
                      AND (
                        CAST(orders.quoted_price_decimal AS REAL)
                        - COALESCE(
                            CAST(orders.deposit_paid_decimal AS REAL),
                            0
                        )
                      ) > 0
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
