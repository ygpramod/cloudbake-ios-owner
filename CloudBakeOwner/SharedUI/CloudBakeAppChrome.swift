import SwiftUI

struct CloudBakeBottomNavigation: View {
    let selectedDestination: AppDestination
    let onSelect: (AppDestination) -> Void

    private let destinations: [AppDestination] = [
        .dashboard,
        .orders,
        .inventory,
        .more,
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(destinations) { destination in
                CloudBakeBottomNavigationItem(
                    destination: destination,
                    isSelected: destination == selectedDestination
                        || (destination == .more && selectedDestination.isGroupedUnderMore),
                    isCurrentDestination: destination == selectedDestination,
                    onSelect: onSelect
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26)
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    CloudBakeTheme.ColorToken.primaryAction.opacity(0.18)
                        .frame(height: 1)
                }
        )
    }
}

private struct CloudBakeBottomNavigationItem: View {
    let destination: AppDestination
    let isSelected: Bool
    let isCurrentDestination: Bool
    let onSelect: (AppDestination) -> Void

    var body: some View {
        if isCurrentDestination {
            itemContent
                .foregroundStyle(CloudBakeTheme.ColorToken.primaryAction)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(destination.bottomNavigationTitle)
                .accessibilityIdentifier(destination.bottomNavigationAccessibilityIdentifier)
                .frame(maxWidth: .infinity)
        } else {
            Button {
                onSelect(destination)
            } label: {
                itemContent
                    .foregroundStyle(
                        isSelected
                            ? CloudBakeTheme.ColorToken.primaryAction
                            : .secondary
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(destination.bottomNavigationTitle)
            .accessibilityIdentifier(destination.bottomNavigationAccessibilityIdentifier)
        }
    }

    private var itemContent: some View {
        VStack(spacing: 6) {
            Image(systemName: destination.bottomNavigationSystemImage)
                .font(.headline.weight(isSelected ? .semibold : .medium))
                .accessibilityHidden(true)

            Text(destination.bottomNavigationTitle)
                .font(.caption2)
                .accessibilityHidden(true)

            Circle()
                .fill(isSelected ? CloudBakeTheme.ColorToken.primaryAction : .clear)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
        }
    }
}

struct CloudBakeScreenBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CloudBakeTheme.ColorToken.appBackground.opacity(0.48),
                    CloudBakeTheme.ColorToken.appBackgroundWash,
                    CloudBakeTheme.ColorToken.appBackground.opacity(0.34),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(CloudBakeTheme.ColorToken.primaryAction.opacity(0.10))
                .frame(width: 190, height: 190)
                .blur(radius: 8)
                .offset(x: -200, y: -330)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func cloudBakeCardStyle(cornerRadius: CGFloat = CloudBakeTheme.Shape.cardRadius) -> some View {
        background(
            CloudBakeTheme.ColorToken.surface.opacity(0.90),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(
            color: CloudBakeTheme.Elevation.softShadow,
            radius: CloudBakeTheme.Elevation.softRadius,
            y: CloudBakeTheme.Elevation.softYOffset
        )
    }
}

extension Color {
    static let cloudBakeBlush = Color(red: 1.00, green: 0.91, blue: 0.92)
    static let cloudBakeBrown = Color(red: 0.64, green: 0.39, blue: 0.30)
    static let cloudBakeMint = Color(red: 0.43, green: 0.82, blue: 0.76)
    static let cloudBakeOrange = Color(red: 0.96, green: 0.60, blue: 0.13)
    static let cloudBakePink = Color(red: 0.93, green: 0.22, blue: 0.47)
    static let cloudBakePurple = Color(red: 0.55, green: 0.31, blue: 0.91)
    static let cloudBakeTeal = Color(red: 0.27, green: 0.75, blue: 0.78)
}

private extension AppDestination {
    var bottomNavigationTitle: String {
        switch self {
        case .dashboard:
            return "Home"
        default:
            return title
        }
    }

    var bottomNavigationSystemImage: String {
        switch self {
        case .dashboard:
            return "house"
        default:
            return systemImage
        }
    }

    var bottomNavigationAccessibilityIdentifier: String {
        "bottom.navigation.\(rawValue)"
    }
}
