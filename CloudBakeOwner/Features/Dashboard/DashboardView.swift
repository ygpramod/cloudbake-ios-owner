import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @Environment(\.navigateToAppDestination) private var navigate
    @EnvironmentObject private var orderNotificationRouter: OrderNotificationRouter

    init(viewModel: DashboardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            CloudBakeScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: CloudBakeTheme.Spacing.section) {
                    DashboardHeader()

                    DashboardSection(title: "Today") {
                        DashboardMetricCard(
                            title: "Upcoming orders",
                            count: "\(viewModel.upcomingOrderCount)",
                            detail: upcomingOrdersDetail,
                            systemImage: "calendar",
                            tint: CloudBakeTheme.ColorToken.secondaryAction,
                            artworkSystemImage: "birthday.cake",
                            action: {
                                navigate(.orders)
                            }
                        )
                    }

                    DashboardSection(title: "Needs attention") {
                        VStack(spacing: 0) {
                            DashboardAttentionRow(
                                accessibilityIdentifier: "dashboard.attention.lowInventory",
                                title: "Low inventory",
                                detail: lowInventoryAttentionDetail,
                                systemImage: "shippingbox",
                                tint: CloudBakeTheme.ColorToken.inventoryAccent,
                                isActionable: !viewModel.lowInventoryItems.isEmpty || viewModel.errorMessage != nil,
                                action: {
                                    navigate(.inventory)
                                }
                            )

                            if let overdueAlert = viewModel.overdueOrderAlert {
                                DashboardDivider()

                                DashboardAttentionRow(
                                    accessibilityIdentifier: "dashboard.attention.overdueOrder",
                                    title: "Overdue order",
                                    detail: overdueAlert.message,
                                    systemImage: "clock.badge.exclamationmark",
                                    tint: CloudBakeTheme.ColorToken.primaryAction,
                                    isActionable: true,
                                    action: {
                                        orderNotificationRouter.openOrder(id: overdueAlert.order.id)
                                        navigate(.orders)
                                    }
                                )
                            }
                        }
                        .cloudBakeCardStyle()
                    }

                    DashboardSection(title: "Quick actions") {
                        VStack(spacing: 0) {
                            DashboardActionRow(
                                destination: .reminders,
                                title: "Review reminders",
                                detail: "Payments, today's orders, and inventory alerts",
                                systemImage: "bell",
                                tint: CloudBakeTheme.ColorToken.customerAccent
                            )

                            DashboardDivider()

                            DashboardActionRow(
                                destination: .designs,
                                title: "Designs",
                                detail: "Browse and manage cake design photos",
                                systemImage: "photo.on.rectangle",
                                tint: CloudBakeTheme.ColorToken.primaryAction
                            )
                        }
                        .cloudBakeCardStyle()
                    }
                }
                .padding(.horizontal, CloudBakeTheme.Spacing.screenHorizontal + 4)
                .padding(.top, 29)
                .padding(.bottom, CloudBakeTheme.Spacing.bottomNavigationHeight - 8)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load()
        }
        .accessibilityIdentifier(AppDestination.dashboard.screenAccessibilityIdentifier)
    }

    private var upcomingOrdersDetail: String {
        if let nextOrder = viewModel.nextUpcomingOrder {
            return nextOrder.title
        }

        return "No orders yet"
    }

    private var lowInventoryAttentionDetail: String {
        if let errorMessage = viewModel.errorMessage {
            return errorMessage
        }

        guard let firstItem = viewModel.displayedLowInventoryItems.first else {
            return "No stock alerts"
        }

        if viewModel.additionalLowInventoryCount > 0 {
            return "\(firstItem.name) + \(viewModel.additionalLowInventoryCount) more"
        }

        if viewModel.displayedLowInventoryItems.count > 1 {
            return "\(firstItem.name) and more"
        }

        return "\(firstItem.name) · \(viewModel.lowInventoryDetail(for: firstItem))"
    }
}

private struct DashboardHeader: View {
    @AppStorage(AppSettings.logoRevisionKey) private var logoRevision = 0
    @State private var customLogoImage = AppLogoStore().load()

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CloudBake")
                    .font(CloudBakeTheme.Typography.brandTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Bake. Create. Delight.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(CloudBakeTheme.ColorToken.ownerAccent)
            }

            Spacer(minLength: 20)

            appLogo
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: CloudBakeTheme.Elevation.softShadow, radius: 10, y: 4)
                .accessibilityHidden(true)
        }
        .onChange(of: logoRevision) { _, _ in
            customLogoImage = AppLogoStore().load()
        }
    }

    @ViewBuilder
    private var appLogo: some View {
        if let customLogoImage {
            Image(uiImage: customLogoImage)
                .resizable()
                .scaledToFill()
        } else {
            Image("CloudBakeLogo")
                .resizable()
                .scaledToFit()
        }
    }
}

private struct DashboardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(CloudBakeTheme.Typography.sectionTitle)
                .foregroundStyle(.secondary)

            content
        }
    }
}

private struct DashboardAttentionRow: View {
    let accessibilityIdentifier: String
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let isActionable: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: CloudBakeTheme.Spacing.rowContent) {
                DashboardIcon(systemImage: systemImage, tint: tint)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(CloudBakeTheme.Typography.rowTitle)
                            .foregroundStyle(.primary)

                        if !isActionable {
                            CloudBakeStatusBadge("OK", systemImage: "checkmark", tint: CloudBakeTheme.ColorToken.success)
                        }
                    }

                    Text(detail)
                        .font(CloudBakeTheme.Typography.rowDetail)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                if isActionable {
                    Image(systemName: "chevron.right")
                        .font(CloudBakeTheme.Typography.rowTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, CloudBakeTheme.Spacing.cardPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isActionable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityIdentifier(isActionable ? accessibilityIdentifier : "\(accessibilityIdentifier).empty")
    }
}

private struct DashboardMetricCard: View {
    let title: String
    let count: String
    let detail: String
    let secondaryDetail: String?
    let systemImage: String
    let tint: Color
    let artworkSystemImage: String
    let action: (() -> Void)?

    init(
        title: String,
        count: String,
        detail: String,
        secondaryDetail: String? = nil,
        systemImage: String,
        tint: Color,
        artworkSystemImage: String,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.count = count
        self.detail = detail
        self.secondaryDetail = secondaryDetail
        self.systemImage = systemImage
        self.tint = tint
        self.artworkSystemImage = artworkSystemImage
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(tint))
                .shadow(color: tint.opacity(0.28), radius: 10, y: 5)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(count)
                    .font(CloudBakeTheme.Typography.metricValue)
                    .foregroundStyle(tint)
                    .lineLimit(1)

                Text(detail)
                    .font(CloudBakeTheme.Typography.rowDetail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let secondaryDetail {
                    Text(secondaryDetail)
                        .font(CloudBakeTheme.Typography.metadata)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 178, alignment: .leading)
        .padding(16)
        .background(
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: CloudBakeTheme.Shape.largeCardRadius, style: .continuous)
                    .fill(tint.opacity(0.08))

                Image(systemName: artworkSystemImage)
                    .font(.system(size: 68, weight: .thin))
                    .foregroundStyle(tint.opacity(0.18))
                    .offset(x: 18, y: 20)

                Image(systemName: "sparkle")
                    .font(.headline)
                    .foregroundStyle(tint.opacity(0.32))
                    .offset(x: -20, y: -118)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: CloudBakeTheme.Shape.largeCardRadius, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CloudBakeTheme.Shape.largeCardRadius, style: .continuous))
    }
}

private struct DashboardActionRow: View {
    let destination: AppDestination
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    @Environment(\.navigateToAppDestination) private var navigate

    var body: some View {
        Button {
            navigate(destination)
        } label: {
            HStack(spacing: 18) {
                DashboardIcon(systemImage: systemImage, tint: tint)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(CloudBakeTheme.Typography.rowTitle)
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(CloudBakeTheme.Typography.rowDetail)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(CloudBakeTheme.Typography.rowTitle)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard.quickAction.\(destination.rawValue)")
    }
}

private struct DashboardIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: CloudBakeTheme.Shape.iconRadius, style: .continuous)
                    .fill(tint.gradient)
            )
    }
}

private struct DashboardDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 92)
    }
}

#Preview {
    DashboardView(
        viewModel: DashboardViewModel(
            repository: PreviewDashboardInventoryItemRepository()
        )
    )
    .environmentObject(OrderNotificationRouter())
}

private final class PreviewDashboardInventoryItemRepository: InventoryItemRepository,
    InventoryStockBatchRepository,
    OrderRepository,
    OrderRecipeUsageRepository,
    RecipeComponentRepository,
    RecipeIngredientRepository,
    OrderExtraIngredientRepository {
    func save(_ item: InventoryItem) throws {}

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        nil
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        [
            InventoryItem(
                id: "preview-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 250,
                minimumQuantity: 500,
                createdAt: Date(),
                updatedAt: Date()
            )
        ].filter { !$0.isArchived }
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        []
    }

    func fetchOrder(id: String) throws -> Order? {
        nil
    }

    func save(_ order: Order) throws {}

    func fetchOrders() throws -> [Order] {
        []
    }

    func fetchOrderRecipeUsage(orderId: String) throws -> OrderRecipeUsage? { nil }

    func recordRecipeUsage(
        for order: Order,
        usageId: String,
        usedAt: Date,
        transactionIdProvider: () -> String
    ) throws {}

    func save(_ batch: InventoryStockBatch) throws {}

    func saveBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {}

    func deleteBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {}

    func replaceInventoryStock(item: InventoryItem, batches: [InventoryStockBatch]) throws {}

    func fetchInventoryStockBatches(inventoryItemId: String) throws -> [InventoryStockBatch] { [] }

    func save(_ component: RecipeComponent) throws {}

    func fetchRecipeComponent(id: String) throws -> RecipeComponent? {
        nil
    }

    func fetchRecipeComponents(recipeId: String) throws -> [RecipeComponent] {
        []
    }

    func save(_ ingredient: RecipeIngredient) throws {}

    func fetchRecipeIngredient(id: String) throws -> RecipeIngredient? {
        nil
    }

    func fetchRecipeIngredients(componentId: String) throws -> [RecipeIngredient] {
        []
    }

    func deleteRecipeIngredient(id: String) throws {}

    func save(_ ingredient: OrderExtraIngredient) throws {}

    func fetchOrderExtraIngredients(orderId: String) throws -> [OrderExtraIngredient] {
        []
    }

    func deleteOrderExtraIngredient(id: String) throws {}
}
