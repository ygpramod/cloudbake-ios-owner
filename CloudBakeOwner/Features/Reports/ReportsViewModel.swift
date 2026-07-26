import Foundation

enum ReportKind: String, CaseIterable, Identifiable {
    case paymentLedger
    case orderProfitability
    case salesAndOrders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paymentLedger: "Payment Ledger"
        case .orderProfitability: "Order Profitability"
        case .salesAndOrders: "Sales & Orders"
        }
    }
}

enum PaymentLedgerScope: String, CaseIterable, Identifiable {
    case outstanding
    case received

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ReportGrouping: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct OrderProfitabilityRow: Equatable, Identifiable {
    let order: Order
    let ingredientCost: Decimal?
    let hasIncompleteCost: Bool

    var id: String { order.id }

    var ingredientMargin: Decimal? {
        guard let quotedPrice = order.quotedPrice,
              let ingredientCost else {
            return nil
        }
        return quotedPrice - ingredientCost
    }

    var ingredientMarginPercentage: Decimal? {
        guard let quotedPrice = order.quotedPrice,
              quotedPrice != 0,
              let ingredientMargin else {
            return nil
        }
        return ingredientMargin / quotedPrice * 100
    }
}

struct SalesOrderBucket: Equatable, Identifiable {
    let dateRange: ReportDateRange
    let summary: SalesOrderSummary

    var id: Date { dateRange.start }
}

struct ReceivedPaymentSection: Identifiable {
    let id: Date
    let title: String
    let rows: [PaymentReceiptReportRow]
}

struct OutstandingOrderSection: Identifiable {
    let id: Date
    let title: String
    let orders: [Order]
}

@MainActor
final class ReportsViewModel: ObservableObject {
    typealias Repository = PaymentReportRepository
        & OrderIngredientCostRepository
        & InventoryItemRepository
        & InventoryStockBatchRepository
        & RecipeComponentRepository
        & RecipeIngredientRepository
        & OrderExtraIngredientRepository
        & OrderRecipeUsageRepository

    @Published var selectedReport: ReportKind = .paymentLedger
    @Published var paymentScope: PaymentLedgerScope = .outstanding
    @Published var grouping: ReportGrouping = .month
    @Published var rangeStart: Date
    @Published var rangeEnd: Date
    @Published var selectedStatuses: Set<OrderStatus> = [
        .confirmed, .inProgress, .ready, .completed
    ]
    @Published private(set) var paymentSummary = PaymentLedgerSummary(
        receivedTotal: 0,
        receivedCount: 0,
        outstandingTotal: 0,
        outstandingOrderCount: 0
    )
    @Published private(set) var receivedPayments: [PaymentReceiptReportRow] = []
    @Published private(set) var outstandingOrders: [Order] = []
    @Published private(set) var profitabilityRows: [OrderProfitabilityRow] = []
    @Published private(set) var salesBuckets: [SalesOrderBucket] = []
    @Published private(set) var salesDrillDownOrders: [Order] = []
    @Published private(set) var canLoadMoreSalesDrillDown = false
    @Published private(set) var canLoadMore = false
    @Published var errorMessage: String?

    private let repository: any Repository
    private let dateProvider: () -> Date
    private let calendar: Calendar
    private var paymentCursor: PaymentReceiptPageCursor?
    private var orderCursor: OrderPageCursor?
    private var salesDrillDownCursor: OrderPageCursor?
    private var salesDrillDownRange: ReportDateRange?
    private static let pageSize = 25
    static let defaultStatuses: Set<OrderStatus> = [
        .confirmed, .inProgress, .ready, .completed
    ]

    init(
        repository: any Repository,
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.calendar = calendar
        let end = dateProvider()
        rangeEnd = end
        rangeStart = calendar.date(byAdding: .day, value: -365, to: end)
            ?? end.addingTimeInterval(-365 * 86_400)
    }

    func load() {
        paymentCursor = nil
        orderCursor = nil
        canLoadMore = false
        errorMessage = nil
        do {
            let range = try selectedDateRange()
            switch selectedReport {
            case .paymentLedger:
                try loadPaymentLedger(dateRange: range)
            case .orderProfitability:
                try loadProfitability(dateRange: range)
            case .salesAndOrders:
                try loadSales(dateRange: range)
            }
        } catch PaymentReportQueryError.dateRangeTooLarge {
            errorMessage = "Choose a date range of 366 days or less."
            clearRows()
        } catch PaymentReportQueryError.invalidDateRange {
            errorMessage = "The report start date must be before the end date."
            clearRows()
        } catch {
            errorMessage = "The report could not be loaded."
            clearRows()
        }
    }

    func loadMore() {
        do {
            let range = try selectedDateRange()
            switch selectedReport {
            case .paymentLedger where paymentScope == .received:
                guard let paymentCursor else { return }
                let page = try repository.fetchReceivedPaymentPage(
                    dateRange: range,
                    statuses: selectedStatuses,
                    after: paymentCursor,
                    limit: Self.pageSize
                )
                receivedPayments.append(contentsOf: page.rows)
                self.paymentCursor = page.nextCursor
                canLoadMore = page.nextCursor != nil
            case .paymentLedger:
                guard let orderCursor else { return }
                let page = try repository.fetchOutstandingPaymentOrderPage(
                    dateRange: range,
                    statuses: selectedStatuses,
                    after: orderCursor,
                    limit: Self.pageSize
                )
                outstandingOrders.append(contentsOf: page.orders)
                self.orderCursor = page.nextCursor
                canLoadMore = page.nextCursor != nil
            case .orderProfitability:
                guard let orderCursor else { return }
                let page = try repository.fetchReportOrderPage(
                    dateRange: range,
                    statuses: selectedStatuses,
                    after: orderCursor,
                    limit: Self.pageSize
                )
                profitabilityRows.append(
                    contentsOf: try page.orders.map(profitabilityRow(for:))
                )
                self.orderCursor = page.nextCursor
                canLoadMore = page.nextCursor != nil
            case .salesAndOrders:
                return
            }
            errorMessage = nil
        } catch {
            errorMessage = "More report rows could not be loaded."
        }
    }

    func loadSalesDrillDown(_ bucket: SalesOrderBucket) {
        do {
            let page = try repository.fetchReportOrderPage(
                dateRange: bucket.dateRange,
                statuses: selectedStatuses,
                after: nil,
                limit: Self.pageSize
            )
            salesDrillDownOrders = page.orders
            salesDrillDownCursor = page.nextCursor
            salesDrillDownRange = bucket.dateRange
            canLoadMoreSalesDrillDown = page.nextCursor != nil
            errorMessage = nil
        } catch {
            salesDrillDownOrders = []
            salesDrillDownCursor = nil
            salesDrillDownRange = nil
            canLoadMoreSalesDrillDown = false
            errorMessage = "Sales order details could not be loaded."
        }
    }

    func loadMoreSalesDrillDown() {
        guard let salesDrillDownCursor,
              let salesDrillDownRange else {
            return
        }
        do {
            let page = try repository.fetchReportOrderPage(
                dateRange: salesDrillDownRange,
                statuses: selectedStatuses,
                after: salesDrillDownCursor,
                limit: Self.pageSize
            )
            salesDrillDownOrders.append(contentsOf: page.orders)
            self.salesDrillDownCursor = page.nextCursor
            canLoadMoreSalesDrillDown = page.nextCursor != nil
            errorMessage = nil
        } catch {
            errorMessage = "More sales order details could not be loaded."
        }
    }

    func closeSalesDrillDown() {
        salesDrillDownOrders = []
        salesDrillDownCursor = nil
        salesDrillDownRange = nil
        canLoadMoreSalesDrillDown = false
    }

    func delayText(for row: PaymentReceiptReportRow) -> String {
        let dueDay = calendar.startOfDay(for: row.order.dueAt)
        let receivedDay = calendar.startOfDay(for: row.receipt.receivedAt)
        let days = calendar.dateComponents(
            [.day],
            from: dueDay,
            to: receivedDay
        ).day ?? 0
        switch days {
        case ..<0:
            return "\(abs(days)) day\(abs(days) == 1 ? "" : "s") early"
        case 0:
            return "On time"
        default:
            return "\(days) day\(days == 1 ? "" : "s") late"
        }
    }

    func overdueText(for order: Order) -> String? {
        let today = calendar.startOfDay(for: dateProvider())
        let dueDay = calendar.startOfDay(for: order.dueAt)
        let days = calendar.dateComponents([.day], from: dueDay, to: today).day ?? 0
        guard days > 0 else {
            return nil
        }
        return "\(days) day\(days == 1 ? "" : "s") overdue"
    }

    func bucketTitle(_ bucket: SalesOrderBucket) -> String {
        groupingTitle(for: bucket.dateRange.start)
    }

    var receivedPaymentSections: [ReceivedPaymentSection] {
        Dictionary(grouping: receivedPayments) {
            bucketStart(containing: $0.receipt.receivedAt)
        }
        .map {
            ReceivedPaymentSection(
                id: $0.key,
                title: groupingTitle(for: $0.key),
                rows: $0.value
            )
        }
        .sorted { $0.id > $1.id }
    }

    var outstandingOrderSections: [OutstandingOrderSection] {
        Dictionary(grouping: outstandingOrders) {
            bucketStart(containing: $0.dueAt)
        }
        .map {
            OutstandingOrderSection(
                id: $0.key,
                title: groupingTitle(for: $0.key),
                orders: $0.value
            )
        }
        .sorted { $0.id > $1.id }
    }

    private func groupingTitle(for date: Date) -> String {
        switch grouping {
        case .day:
            return date.formatted(date: .abbreviated, time: .omitted)
        case .week:
            return "Week of \(date.formatted(date: .abbreviated, time: .omitted))"
        case .month:
            return date.formatted(.dateTime.month(.wide).year())
        }
    }

    private func selectedDateRange() throws -> ReportDateRange {
        let start = calendar.startOfDay(for: rangeStart)
        guard let end = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: rangeEnd)
        ) else {
            throw PaymentReportQueryError.invalidDateRange
        }
        let range = ReportDateRange(start: start, end: end)
        try range.validate()
        guard !selectedStatuses.isEmpty else {
            throw PaymentReportQueryError.noStatuses
        }
        return range
    }

    private func loadPaymentLedger(dateRange: ReportDateRange) throws {
        paymentSummary = try repository.fetchPaymentLedgerSummary(
            dateRange: dateRange,
            statuses: selectedStatuses
        )
        profitabilityRows = []
        salesBuckets = []
        switch paymentScope {
        case .outstanding:
            receivedPayments = []
            let page = try repository.fetchOutstandingPaymentOrderPage(
                dateRange: dateRange,
                statuses: selectedStatuses,
                after: nil,
                limit: Self.pageSize
            )
            outstandingOrders = page.orders
            orderCursor = page.nextCursor
            canLoadMore = page.nextCursor != nil
        case .received:
            outstandingOrders = []
            let page = try repository.fetchReceivedPaymentPage(
                dateRange: dateRange,
                statuses: selectedStatuses,
                after: nil,
                limit: Self.pageSize
            )
            receivedPayments = page.rows
            paymentCursor = page.nextCursor
            canLoadMore = page.nextCursor != nil
        }
    }

    private func loadProfitability(dateRange: ReportDateRange) throws {
        receivedPayments = []
        outstandingOrders = []
        salesBuckets = []
        let page = try repository.fetchReportOrderPage(
            dateRange: dateRange,
            statuses: selectedStatuses,
            after: nil,
            limit: Self.pageSize
        )
        profitabilityRows = try page.orders.map(profitabilityRow(for:))
        orderCursor = page.nextCursor
        canLoadMore = page.nextCursor != nil
    }

    private func loadSales(dateRange: ReportDateRange) throws {
        receivedPayments = []
        outstandingOrders = []
        profitabilityRows = []
        let ranges = bucketRanges(in: dateRange)
        let summaries = try repository.fetchSalesOrderSummaries(
            dateRanges: ranges,
            statuses: selectedStatuses
        )
        salesBuckets = zip(ranges, summaries).map {
            SalesOrderBucket(dateRange: $0.0, summary: $0.1)
        }
        canLoadMore = false
    }

    private func profitabilityRow(for order: Order) throws -> OrderProfitabilityRow {
        if order.status == .completed {
            let actualCosts = try repository.fetchOrderIngredientCosts(orderId: order.id)
            guard !actualCosts.isEmpty else {
                return OrderProfitabilityRow(
                    order: order,
                    ingredientCost: nil,
                    hasIncompleteCost: true
                )
            }
            return OrderProfitabilityRow(
                order: order,
                ingredientCost: actualCosts.reduce(0) { $0 + $1.knownCost },
                hasIncompleteCost: actualCosts.contains {
                    $0.missingPriceQuantity > 0
                }
            )
        }
        let inventoryItems = try repository.fetchInventoryItems()
        let requirements = try OrderIngredientRequirements.requirements(
            for: order,
            inventoryItems: inventoryItems,
            recipeComponents: repository.fetchRecipeComponents(recipeId:),
            recipeIngredients: repository.fetchRecipeIngredients(componentId:),
            orderExtraIngredients: repository.fetchOrderExtraIngredients(orderId:)
        )
        let summary = try OrderIngredientCostCalculation.summary(
            requirements: requirements,
            batches: repository.fetchInventoryStockBatches(inventoryItemId:),
            at: dateProvider()
        )
        return OrderProfitabilityRow(
            order: order,
            ingredientCost: summary.knownCost,
            hasIncompleteCost: !summary.itemsMissingPrice.isEmpty
        )
    }

    private func bucketRanges(in range: ReportDateRange) -> [ReportDateRange] {
        var buckets = [ReportDateRange]()
        var cursor = bucketStart(containing: range.start)
        while cursor < range.end {
            guard let next = nextBucketStart(after: cursor) else {
                break
            }
            let start = max(cursor, range.start)
            let end = min(next, range.end)
            if start < end {
                buckets.append(ReportDateRange(start: start, end: end))
            }
            cursor = next
        }
        return buckets
    }

    private func bucketStart(containing date: Date) -> Date {
        switch grouping {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        }
    }

    private func nextBucketStart(after date: Date) -> Date? {
        switch grouping {
        case .day:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }

    private func clearRows() {
        receivedPayments = []
        outstandingOrders = []
        profitabilityRows = []
        salesBuckets = []
        canLoadMore = false
    }
}
