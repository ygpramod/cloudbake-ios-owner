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
                VStack(alignment: .leading, spacing: 24) {
                    DashboardHeader()

                    if let overdueAlert = viewModel.overdueOrderAlert {
                        overdueBanner(overdueAlert)
                    }

                    DashboardSection(title: "Today") {
                        HStack(spacing: 16) {
                            DashboardMetricCard(
                                title: "Upcoming orders",
                                count: "\(viewModel.upcomingOrderCount)",
                                detail: upcomingOrdersDetail,
                                systemImage: "calendar",
                                tint: .cloudBakePurple,
                                artworkSystemImage: "birthday.cake",
                                action: {
                                    navigate(.orders)
                                }
                            )

                            LowInventoryMetricCard(viewModel: viewModel) {
                                navigate(.inventory)
                            }
                        }
                    }

                    DashboardSection(title: "Soon") {
                        VStack(spacing: 0) {
                            DashboardActionRow(
                                destination: .reminders,
                                title: "Reminders",
                                detail: "Payments, today's orders, and inventory alerts",
                                systemImage: "bell",
                                tint: .cloudBakeTeal
                            )

                            Divider()
                                .padding(.leading, 92)

                            DashboardActionRow(
                                destination: .designs,
                                title: "Recent designs",
                                detail: "Cake photos will appear here",
                                systemImage: "camera",
                                tint: .cloudBakePink
                            )
                        }
                        .cloudBakeCardStyle()
                    }

                    DashboardSection(title: "Areas") {
                        VStack(spacing: 0) {
                            DashboardAreaRow(destination: .orders, tint: .cloudBakePurple)
                            DashboardDivider()
                            DashboardAreaRow(destination: .inventory, tint: .cloudBakeOrange)
                            DashboardDivider()
                            DashboardAreaRow(destination: .recipes, tint: .cloudBakeMint)
                            DashboardDivider()
                            DashboardAreaRow(destination: .customers, tint: .cloudBakeTeal)
                            DashboardDivider()
                            DashboardAreaRow(destination: .designs, tint: .cloudBakePink)
                            DashboardDivider()
                            DashboardAreaRow(destination: .settings, tint: .gray)
                        }
                        .cloudBakeCardStyle()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 96)
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

    private func overdueBanner(_ alert: OrderOverdueAlert) -> some View {
        Button {
            orderNotificationRouter.openOrder(id: alert.order.id)
            navigate(.orders)
        } label: {
            Label(alert.message, systemImage: "clock.badge.exclamationmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cloudBakePink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.cloudBakePink.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard.overdue.banner")
    }
}

private struct DashboardHeader: View {
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CloudBake")
                    .font(.system(size: 28, weight: .heavy, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Bake. Create. Delight.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.cloudBakeBrown)
            }

            Spacer(minLength: 20)

            Image("CloudBakeLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                .accessibilityHidden(true)
        }
    }
}

private struct DashboardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            content
        }
    }
}

private struct LowInventoryMetricCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onTap: () -> Void

    var body: some View {
        if let errorMessage = viewModel.errorMessage {
            DashboardMetricCard(
                title: "Low inventory",
                count: "!",
                detail: errorMessage,
                systemImage: "shippingbox",
                tint: .cloudBakeOrange,
                artworkSystemImage: "shippingbox"
            )
            .accessibilityIdentifier("dashboard.lowInventory.error")
        } else {
            DashboardMetricCard(
                title: "Low inventory",
                count: "\(viewModel.lowInventoryItems.count)",
                detail: lowInventoryPrimaryDetail,
                secondaryDetail: lowInventorySecondaryDetail,
                systemImage: "shippingbox",
                tint: .cloudBakeOrange,
                artworkSystemImage: "shippingbox",
                action: viewModel.lowInventoryItems.isEmpty ? nil : onTap
            )
            .accessibilityIdentifier(viewModel.lowInventoryItems.isEmpty ? "dashboard.lowInventory.empty" : "dashboard.lowInventory.alerts")
        }
    }

    private var lowInventoryPrimaryDetail: String {
        guard let firstItem = viewModel.displayedLowInventoryItems.first else {
            return "No alerts yet"
        }

        if viewModel.additionalLowInventoryCount > 0 {
            return "\(firstItem.name) + \(viewModel.additionalLowInventoryCount) more"
        }

        if viewModel.displayedLowInventoryItems.count > 1 {
            return "\(firstItem.name) and more"
        }

        return firstItem.name
    }

    private var lowInventorySecondaryDetail: String? {
        guard viewModel.additionalLowInventoryCount == 0,
              viewModel.displayedLowInventoryItems.count == 1,
              let firstItem = viewModel.displayedLowInventoryItems.first
        else {
            return nil
        }

        return firstItem.lowInventoryDetail
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
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let secondaryDetail {
                    Text(secondaryDetail)
                        .font(.caption)
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
                RoundedRectangle(cornerRadius: 28, style: .continuous)
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
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
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
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard.soon.\(destination.rawValue)")
    }
}

private struct DashboardAreaRow: View {
    let destination: AppDestination
    let tint: Color
    @Environment(\.navigateToAppDestination) private var navigate

    var body: some View {
        Button {
            navigate(destination)
        } label: {
            HStack(spacing: 18) {
                DashboardIcon(systemImage: destination.systemImage, tint: tint)

                Text(destination.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(destination.accessibilityIdentifier)
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
                RoundedRectangle(cornerRadius: 15, style: .continuous)
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

private extension InventoryItem {
    var lowInventoryDetail: String {
        if hasExpiredStock {
            return "Expired stock"
        }

        if hasExpiringSoonStock {
            return "Expiring soon"
        }

        return "\(currentQuantity.formatted()) / \(minimumQuantity.formatted()) \(unit.displayName)"
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

private final class PreviewDashboardInventoryItemRepository: InventoryItemRepository, OrderRepository {
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
}
