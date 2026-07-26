import SwiftUI

struct ReportsView: View {
    @StateObject private var viewModel: ReportsViewModel
    @State private var orderDetailRequest: ReportOrderDetailRequest?
    @State private var selectedSalesBucket: SalesOrderBucket?
    private let makeOrderViewModel: () -> OrderListViewModel

    init(
        viewModel: ReportsViewModel,
        makeOrderViewModel: @escaping () -> OrderListViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.makeOrderViewModel = makeOrderViewModel
    }

    var body: some View {
        CloudBakeScreenScaffold(
            title: "Reports",
            selectedDestination: .reports
        ) {
            VStack(alignment: .leading, spacing: 24) {
                reportPicker
                filterCard
                reportContent
                if viewModel.canLoadMore {
                    Button("Load More", action: viewModel.loadMore)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.cloudBakePink)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("reports.loadMore")
                }
                if let errorMessage = viewModel.errorMessage {
                    CloudBakeErrorBanner(
                        message: errorMessage,
                        accessibilityIdentifier: "reports.error"
                    )
                }
            }
        }
        .onAppear(perform: viewModel.load)
        .onChange(of: viewModel.selectedReport) { _, _ in viewModel.load() }
        .onChange(of: viewModel.paymentScope) { _, _ in viewModel.load() }
        .onChange(of: viewModel.grouping) { _, _ in
            if viewModel.selectedReport == .salesAndOrders {
                viewModel.load()
            }
        }
        .sheet(item: $orderDetailRequest, onDismiss: closeOrderDetail) { request in
            NavigationStack {
                OrderDetailView(
                    viewModel: request.viewModel,
                    isPresented: orderDetailPresentedBinding
                )
            }
        }
        .sheet(
            item: $selectedSalesBucket,
            onDismiss: viewModel.closeSalesDrillDown
        ) { bucket in
            NavigationStack {
                SalesOrderDrillDownView(
                    title: viewModel.bucketTitle(bucket),
                    orders: viewModel.salesDrillDownOrders,
                    canLoadMore: viewModel.canLoadMoreSalesDrillDown,
                    onOpenOrder: { order in
                        selectedSalesBucket = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            openOrder(order)
                        }
                    },
                    onLoadMore: viewModel.loadMoreSalesDrillDown
                )
            }
        }
        .accessibilityIdentifier(AppDestination.reports.screenAccessibilityIdentifier)
    }

    private var reportPicker: some View {
        Picker("Report", selection: $viewModel.selectedReport) {
            ForEach(ReportKind.allCases) { report in
                Text(report.title).tag(report)
            }
        }
        .pickerStyle(.menu)
        .tint(Color.cloudBakePink)
        .accessibilityIdentifier("reports.kind")
    }

    private var filterCard: some View {
        CloudBakeListCard {
            VStack(spacing: 14) {
                HStack {
                    DatePicker(
                        "From",
                        selection: $viewModel.rangeStart,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "To",
                        selection: $viewModel.rangeEnd,
                        displayedComponents: .date
                    )
                }
                .font(.subheadline)

                HStack {
                    Menu {
                        ForEach(OrderStatus.allCases, id: \.self) { status in
                            Button {
                                if viewModel.selectedStatuses.contains(status) {
                                    viewModel.selectedStatuses.remove(status)
                                } else {
                                    viewModel.selectedStatuses.insert(status)
                                }
                            } label: {
                                if viewModel.selectedStatuses.contains(status) {
                                    Label(status.displayName, systemImage: "checkmark")
                                } else {
                                    Text(status.displayName)
                                }
                            }
                        }
                    } label: {
                        Label(
                            "\(viewModel.selectedStatuses.count) Statuses",
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                    }

                    Spacer()

                    if viewModel.selectedReport != .orderProfitability {
                        Picker("Group", selection: $viewModel.grouping) {
                            ForEach(ReportGrouping.allCases) { grouping in
                                Text(grouping.title).tag(grouping)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Button("Apply", action: viewModel.load)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .tint(Color.cloudBakePink)
            }
            .padding(16)
        }
        .accessibilityIdentifier("reports.filters")
    }

    @ViewBuilder
    private var reportContent: some View {
        switch viewModel.selectedReport {
        case .paymentLedger:
            paymentLedger
        case .orderProfitability:
            profitability
        case .salesAndOrders:
            salesAndOrders
        }
    }

    private var paymentLedger: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Payment Scope", selection: $viewModel.paymentScope) {
                ForEach(PaymentLedgerScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("reports.payment.scope")

            HStack(spacing: 12) {
                reportMetric(
                    title: "Received",
                    value: MoneyDisplay.formatted(viewModel.paymentSummary.receivedTotal),
                    detail: "\(viewModel.paymentSummary.receivedCount) payments"
                )
                reportMetric(
                    title: "Outstanding",
                    value: MoneyDisplay.formatted(viewModel.paymentSummary.outstandingTotal),
                    detail: "\(viewModel.paymentSummary.outstandingOrderCount) orders"
                )
            }

            if viewModel.paymentScope == .outstanding {
                if viewModel.outstandingOrderSections.isEmpty {
                    CloudBakeListCard {
                        reportEmpty("No outstanding orders in this period.")
                    }
                } else {
                    ForEach(viewModel.outstandingOrderSections) { section in
                        CloudBakeSection(section.title) {
                            reportOrderList(section.orders) { order in
                                VStack(alignment: .leading, spacing: 5) {
                                    reportRowHeader(order.title, value: MoneyDisplay.formatted(order.balanceDue ?? 0))
                                    Text("\(order.customerName) • Due \(order.dueAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let overdue = viewModel.overdueText(for: order) {
                                        Text(overdue)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                reportReceiptList
            }
        }
    }

    private var reportReceiptList: some View {
        Group {
            if viewModel.receivedPaymentSections.isEmpty {
                CloudBakeListCard {
                    reportEmpty("No received payments in this period.")
                }
            } else {
                ForEach(viewModel.receivedPaymentSections) { section in
                    CloudBakeSection(section.title) {
                        CloudBakeListCard {
                            ForEach(Array(section.rows.enumerated()), id: \.element.receipt.id) { index, row in
                                Button {
                                    openOrder(row.order)
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        reportRowHeader(
                                            row.order.title,
                                            value: MoneyDisplay.formatted(row.receipt.amount)
                                        )
                                        Text(row.receipt.receivedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let note = row.receipt.note {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(viewModel.delayText(for: row))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.cloudBakePink)
                                    }
                                    .padding(16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if index < section.rows.count - 1 {
                                    CloudBakeDetailDivider().padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var profitability: some View {
        CloudBakeListCard {
            if viewModel.profitabilityRows.isEmpty {
                reportEmpty("No orders in this period.")
            } else {
                ForEach(Array(viewModel.profitabilityRows.enumerated()), id: \.element.id) { index, row in
                    Button {
                        openOrder(row.order)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            reportRowHeader(
                                row.order.title,
                                value: row.ingredientMargin.map {
                                    MoneyDisplay.formatted($0)
                                }
                                    ?? "Unavailable"
                            )
                            Text("\(row.order.customerName) • \(row.order.status.displayName) • Due \(row.order.dueAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("Quoted \(MoneyDisplay.formatted(row.order.quotedPrice ?? 0))")
                                Text("Cost \(row.ingredientCost.map { MoneyDisplay.formatted($0) } ?? "Unavailable")")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            HStack {
                                Text("Paid \(MoneyDisplay.formatted(row.order.depositPaid ?? 0))")
                                Text("Balance \(MoneyDisplay.formatted(row.order.balanceDue ?? 0))")
                                if let percentage = row.ingredientMarginPercentage {
                                    Text("\(TextInputFormatting.decimalText(percentage))% margin")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            if row.hasIncompleteCost {
                                Label("Ingredient cost is incomplete", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < viewModel.profitabilityRows.count - 1 {
                        CloudBakeDetailDivider().padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    private var salesAndOrders: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.salesBuckets.isEmpty {
                CloudBakeListCard {
                    reportEmpty("No orders in this period.")
                }
            } else {
                ForEach(viewModel.salesBuckets) { bucket in
                    Button {
                        viewModel.loadSalesDrillDown(bucket)
                        selectedSalesBucket = bucket
                    } label: {
                        CloudBakeListCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(viewModel.bucketTitle(bucket))
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                HStack {
                                    reportValue("Orders", "\(bucket.summary.orderCount)")
                                    reportValue("Quoted", MoneyDisplay.formatted(bucket.summary.quotedTotal))
                                    reportValue(
                                        "Average",
                                        bucket.summary.averageQuotedValue.map {
                                            MoneyDisplay.formatted($0)
                                        }
                                            ?? "—"
                                    )
                                }
                                HStack {
                                    reportValue("Received", MoneyDisplay.formatted(bucket.summary.receivedTotal))
                                    reportValue("Outstanding", MoneyDisplay.formatted(bucket.summary.outstandingTotal))
                                }
                                let statusText = bucket.summary.statusCounts
                                    .sorted { $0.key.rawValue < $1.key.rawValue }
                                    .map { "\($0.key.displayName) \($0.value)" }
                                    .joined(separator: " • ")
                                if !statusText.isEmpty {
                                    Text(statusText)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(16)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func reportOrderList<Content: View>(
        _ orders: [Order],
        @ViewBuilder content: @escaping (Order) -> Content
    ) -> some View {
        CloudBakeListCard {
            if orders.isEmpty {
                reportEmpty("No outstanding orders in this period.")
            } else {
                ForEach(Array(orders.enumerated()), id: \.element.id) { index, order in
                    Button {
                        openOrder(order)
                    } label: {
                        content(order)
                            .padding(16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < orders.count - 1 {
                        CloudBakeDetailDivider().padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    private func reportMetric(title: String, value: String, detail: String) -> some View {
        CloudBakeListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    private func reportRowHeader(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text(value).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.primary)
    }

    private func reportValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reportEmpty(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(24)
    }

    private func openOrder(_ order: Order) {
        let detailViewModel = makeOrderViewModel()
        detailViewModel.load()
        guard let loadedOrder = detailViewModel.order(id: order.id) else {
            return
        }
        detailViewModel.beginViewingOrder(loadedOrder)
        orderDetailRequest = ReportOrderDetailRequest(
            id: order.id,
            viewModel: detailViewModel
        )
    }

    private var orderDetailPresentedBinding: Binding<Bool> {
        Binding(
            get: { orderDetailRequest != nil },
            set: { isPresented in
                if !isPresented {
                    closeOrderDetail()
                }
            }
        )
    }

    private func closeOrderDetail() {
        orderDetailRequest?.viewModel.closeOrderDetail()
        orderDetailRequest = nil
        viewModel.load()
    }
}

private struct SalesOrderDrillDownView: View {
    let title: String
    let orders: [Order]
    let canLoadMore: Bool
    let onOpenOrder: (Order) -> Void
    let onLoadMore: () -> Void

    var body: some View {
        List {
            ForEach(orders, id: \.id) { order in
                Button {
                    onOpenOrder(order)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(order.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(MoneyDisplay.formatted(order.quotedPrice ?? 0))
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("\(order.customerName) • \(order.status.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            if canLoadMore {
                Button("Load More", action: onLoadMore)
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReportOrderDetailRequest: Identifiable {
    let id: String
    let viewModel: OrderListViewModel
}
