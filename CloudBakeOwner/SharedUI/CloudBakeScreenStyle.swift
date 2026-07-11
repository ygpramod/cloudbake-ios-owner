import SwiftUI
import UIKit

enum CloudBakeTheme {
    enum ColorToken {
        static let appBackground = Color.cloudBakeBlush
        static let appBackgroundWash = Color.white
        static let surface = Color.white
        static let primaryAction = Color.cloudBakePink
        static let secondaryAction = Color.cloudBakePurple
        static let inventoryAccent = Color.cloudBakeOrange
        static let recipeAccent = Color.cloudBakeMint
        static let customerAccent = Color.cloudBakeTeal
        static let ownerAccent = Color.cloudBakeBrown
        static let destructive = Color.red
        static let success = Color.green
    }

    enum Typography {
        static let screenTitle = Font.system(size: 28, weight: .heavy, design: .rounded)
        static let brandTitle = Font.system(size: 28, weight: .heavy, design: .serif)
        static let metricValue = Font.system(size: 28, weight: .bold, design: .rounded)
        static let sectionTitle = Font.headline.weight(.semibold)
        static let rowTitle = Font.headline.weight(.semibold)
        static let rowDetail = Font.footnote
        static let metadata = Font.caption
    }

    enum Spacing {
        static let screenHorizontal: CGFloat = 24
        static let detailHorizontal: CGFloat = 22
        static let screenTop: CGFloat = 18
        static let section: CGFloat = 24
        static let sectionContent: CGFloat = 14
        static let rowContent: CGFloat = 18
        static let cardPadding: CGFloat = 20
        static let compactControl: CGFloat = 12
        static let bottomNavigationHeight: CGFloat = 104
    }

    enum Shape {
        static let cardRadius: CGFloat = 24
        static let largeCardRadius: CGFloat = 28
        static let bannerRadius: CGFloat = 18
        static let iconRadius: CGFloat = 15
    }

    enum Elevation {
        static let softShadow = Color.black.opacity(0.08)
        static let softRadius: CGFloat = 18
        static let softYOffset: CGFloat = 8
        static let controlShadow = Color.black.opacity(0.06)
        static let controlRadius: CGFloat = 12
        static let controlYOffset: CGFloat = 6
    }
}

struct CloudBakeScreenScaffold<Content: View>: View {
    let title: String
    let selectedDestination: AppDestination
    let primaryAction: CloudBakeScreenAction?
    let secondaryActions: [CloudBakeScreenAction]
    let collapsesActionsIntoMenu: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        selectedDestination: AppDestination,
        primaryAction: CloudBakeScreenAction? = nil,
        secondaryActions: [CloudBakeScreenAction] = [],
        collapsesActionsIntoMenu: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.selectedDestination = selectedDestination
        self.primaryAction = primaryAction
        self.secondaryActions = secondaryActions
        self.collapsesActionsIntoMenu = collapsesActionsIntoMenu
        self.content = content()
    }

    var body: some View {
        ZStack {
            CloudBakeScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: CloudBakeTheme.Spacing.section) {
                    CloudBakeScreenHeader(
                        title: title,
                        primaryAction: primaryAction,
                        secondaryActions: secondaryActions,
                        collapsesActionsIntoMenu: collapsesActionsIntoMenu
                    )

                    content
                }
                .padding(.horizontal, CloudBakeTheme.Spacing.screenHorizontal)
                .padding(.top, CloudBakeTheme.Spacing.screenTop)
                .padding(.bottom, CloudBakeTheme.Spacing.bottomNavigationHeight)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct CloudBakeScreenAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let accessibilityIdentifier: String
    let action: () -> Void
}

struct CloudBakeDetailScaffold<Content: View>: View {
    let title: String
    let showsBackButton: Bool
    let backAccessibilityIdentifier: String
    let primaryAction: CloudBakeDetailAction?
    let secondaryActions: [CloudBakeDetailAction]
    let onBack: () -> Void
    @ViewBuilder let content: Content

    init(
        title: String,
        showsBackButton: Bool = true,
        backAccessibilityIdentifier: String,
        primaryAction: CloudBakeDetailAction? = nil,
        secondaryActions: [CloudBakeDetailAction] = [],
        onBack: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.backAccessibilityIdentifier = backAccessibilityIdentifier
        self.primaryAction = primaryAction
        self.secondaryActions = secondaryActions
        self.onBack = onBack
        self.content = content()
    }

    var body: some View {
        ZStack {
            CloudBakeScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: CloudBakeTheme.Spacing.section) {
                    CloudBakeDetailHeader(
                        title: title,
                        showsBackButton: showsBackButton,
                        backAccessibilityIdentifier: backAccessibilityIdentifier,
                        primaryAction: primaryAction,
                        secondaryActions: secondaryActions,
                        onBack: onBack
                    )

                    content
                }
                .padding(.horizontal, CloudBakeTheme.Spacing.detailHorizontal)
                .padding(.top, CloudBakeTheme.Spacing.screenTop)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct CloudBakeDetailAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let accessibilityIdentifier: String
    let action: () -> Void
}

extension View {
    func cloudBakeFormScreenStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(CloudBakeScreenBackground())
            .tint(CloudBakeTheme.ColorToken.primaryAction)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                }
            }
    }
}

struct CloudBakeHeroCard<Content: View>: View {
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            CloudBakeRowIcon(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 8) {
                content
            }

            Spacer(minLength: 0)
        }
        .padding(CloudBakeTheme.Spacing.cardPadding + 2)
        .cloudBakeCardStyle()
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(tint)
                .frame(width: 3)
                .padding(.vertical, 0)
        }
    }
}

struct CloudBakeDetailCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, CloudBakeTheme.Spacing.cardPadding)
        .padding(.vertical, 6)
        .cloudBakeCardStyle()
    }
}

struct CloudBakeDetailRow<Value: View>: View {
    let title: String
    @ViewBuilder let value: Value

    init(_ title: String, @ViewBuilder value: () -> Value) {
        self.title = title
        self.value = value()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            value
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
    }
}

struct CloudBakeDetailDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 0)
    }
}

struct CloudBakeSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CloudBakeTheme.Spacing.sectionContent) {
            if let title {
                Text(title)
                    .font(CloudBakeTheme.Typography.sectionTitle)
                    .foregroundStyle(.secondary)
            }

            content
        }
    }
}

struct CloudBakeListCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .cloudBakeCardStyle()
    }
}

struct CloudBakeSearchField: View {
    @Binding var text: String
    let prompt: String
    let accessibilityIdentifier: String
    let isFocused: FocusState<Bool>.Binding?

    init(
        text: Binding<String>,
        prompt: String,
        accessibilityIdentifier: String,
        isFocused: FocusState<Bool>.Binding? = nil
    ) {
        _text = text
        self.prompt = prompt
        self.accessibilityIdentifier = accessibilityIdentifier
        self.isFocused = isFocused
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .submitLabel(.search)
                .accessibilityIdentifier(accessibilityIdentifier)
                .modifier(CloudBakeSearchFocusModifier(isFocused: isFocused))

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused?.wrappedValue = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("\(accessibilityIdentifier).clear")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.white.opacity(0.88), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(
            color: CloudBakeTheme.Elevation.controlShadow,
            radius: CloudBakeTheme.Elevation.controlRadius,
            y: CloudBakeTheme.Elevation.controlYOffset
        )
    }
}

private struct CloudBakeSearchFocusModifier: ViewModifier {
    let isFocused: FocusState<Bool>.Binding?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let isFocused {
            content.focused(isFocused)
        } else {
            content
        }
    }
}

struct CloudBakeEmptyState: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(CloudBakeTheme.ColorToken.primaryAction)
                .frame(width: 74, height: 74)
                .background(Circle().fill(CloudBakeTheme.ColorToken.primaryAction.opacity(0.10)))

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .cloudBakeCardStyle()
    }
}

struct CloudBakeErrorBanner: View {
    let message: String
    let accessibilityIdentifier: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(CloudBakeTheme.ColorToken.destructive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                CloudBakeTheme.ColorToken.destructive.opacity(0.08),
                in: RoundedRectangle(cornerRadius: CloudBakeTheme.Shape.bannerRadius, style: .continuous)
            )
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct CloudBakeStatusBadge: View {
    let title: String
    let systemImage: String?
    let tint: Color

    init(_ title: String, systemImage: String? = nil, tint: Color) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        Label {
            Text(title)
                .font(CloudBakeTheme.Typography.metadata.weight(.semibold))
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct CloudBakeLabeledField<Value: View>: View {
    let title: String
    @ViewBuilder let value: Value

    init(_ title: String, @ViewBuilder value: () -> Value) {
        self.title = title
        self.value = value()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(CloudBakeTheme.Typography.metadata.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            value
                .font(.body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CloudBakeRowIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 72, height: 72)
            .background(Circle().fill(tint.opacity(0.11)))
            .accessibilityHidden(true)
    }
}

struct CloudBakeCardDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 104)
    }
}

struct CloudBakeInlineActionButton: View {
    enum Prominence {
        case compact
        case prominent
    }

    let title: String
    let systemImage: String
    let tint: Color
    let accessibilityIdentifier: String
    var prominence: Prominence = .compact
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(font)
                .labelStyle(.titleAndIcon)
                .foregroundStyle(tint)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.90)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: prominence == .prominent ? .infinity : nil)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background(backgroundColor, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(tint.opacity(prominence == .prominent ? 0.16 : 0), lineWidth: 1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var font: Font {
        switch prominence {
        case .compact:
            .caption.weight(.semibold)
        case .prominent:
            .subheadline.weight(.semibold)
        }
    }

    private var horizontalPadding: CGFloat {
        prominence == .prominent ? 14 : 10
    }

    private var verticalPadding: CGFloat {
        prominence == .prominent ? 12 : 7
    }

    private var backgroundColor: Color {
        tint.opacity(prominence == .prominent ? 0.12 : 0.10)
    }
}

struct CloudBakeOverflowMenuLabel: View {
    let title: String

    var body: some View {
        Image(systemName: "ellipsis")
            .font(.body.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .background(Color.secondary.opacity(0.08), in: Circle())
            .contentShape(Circle())
            .accessibilityLabel(title)
    }
}

private struct CloudBakeScreenHeader: View {
    let title: String
    let primaryAction: CloudBakeScreenAction?
    let secondaryActions: [CloudBakeScreenAction]
    let collapsesActionsIntoMenu: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(CloudBakeTheme.Typography.screenTitle)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 16)

            if collapsesActionsIntoMenu, !menuActions.isEmpty {
                CloudBakeHeaderActionMenu(actions: menuActions)
            } else {
                ForEach(secondaryActions) { action in
                    CloudBakeHeaderActionButton(action: action)
                }

                if let primaryAction {
                    CloudBakeHeaderActionButton(action: primaryAction)
                }
            }
        }
    }

    private var menuActions: [CloudBakeScreenAction] {
        [primaryAction].compactMap { $0 } + secondaryActions
    }
}

private struct CloudBakeDetailHeader: View {
    let title: String
    let showsBackButton: Bool
    let backAccessibilityIdentifier: String
    let primaryAction: CloudBakeDetailAction?
    let secondaryActions: [CloudBakeDetailAction]
    let onBack: () -> Void

    var body: some View {
        ZStack {
            HStack {
                if showsBackButton {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(CloudBakeTheme.ColorToken.primaryAction)
                            .frame(width: 50, height: 50)
                            .background(.white.opacity(0.92), in: Circle())
                            .shadow(
                                color: CloudBakeTheme.Elevation.softShadow,
                                radius: CloudBakeTheme.Elevation.controlRadius,
                                y: CloudBakeTheme.Elevation.controlYOffset
                            )
                    }
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier(backAccessibilityIdentifier)
                } else {
                    Color.clear
                        .frame(width: 50, height: 50)
                        .accessibilityHidden(true)
                }

                Spacer()

                ForEach(secondaryActions) { action in
                    CloudBakeDetailHeaderButton(action: action, isPrimary: false)
                }

                if let primaryAction {
                    CloudBakeDetailHeaderButton(action: primaryAction, isPrimary: true)
                }
            }

        }
    }
}

private struct CloudBakeDetailHeaderButton: View {
    let action: CloudBakeDetailAction
    let isPrimary: Bool

    var body: some View {
        Button(action: action.action) {
            HStack(spacing: isPrimary ? 8 : 0) {
                Image(systemName: action.systemImage)
                    .font(.subheadline.weight(.semibold))

                if isPrimary {
                    Text(action.title)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(CloudBakeTheme.ColorToken.primaryAction)
            .frame(minWidth: isPrimary ? 86 : 50, minHeight: 50)
            .padding(.horizontal, isPrimary ? 12 : 0)
            .background(.white.opacity(0.92), in: Capsule())
            .shadow(
                color: CloudBakeTheme.Elevation.softShadow,
                radius: CloudBakeTheme.Elevation.controlRadius,
                y: CloudBakeTheme.Elevation.controlYOffset
            )
        }
        .accessibilityLabel(action.title)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }
}

private struct CloudBakeHeaderActionButton: View {
    let action: CloudBakeScreenAction

    var body: some View {
        Button(action: action.action) {
            Image(systemName: action.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(CloudBakeTheme.ColorToken.primaryAction)
                .frame(width: 58, height: 58)
                .background(.white.opacity(0.90), in: Circle())
                .shadow(
                    color: CloudBakeTheme.Elevation.softShadow,
                    radius: CloudBakeTheme.Elevation.controlRadius,
                    y: CloudBakeTheme.Elevation.controlYOffset
                )
        }
        .accessibilityLabel(action.title)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }
}

private struct CloudBakeHeaderActionMenu: View {
    let actions: [CloudBakeScreenAction]

    var body: some View {
        Menu {
            ForEach(actions) { action in
                Button(action: action.action) {
                    Label(action.title, systemImage: action.systemImage)
                }
                .accessibilityIdentifier(action.accessibilityIdentifier)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3.weight(.semibold))
                .foregroundStyle(CloudBakeTheme.ColorToken.primaryAction)
                .frame(width: 58, height: 58)
                .background(.white.opacity(0.90), in: Circle())
                .shadow(
                    color: CloudBakeTheme.Elevation.softShadow,
                    radius: CloudBakeTheme.Elevation.controlRadius,
                    y: CloudBakeTheme.Elevation.controlYOffset
                )
        }
        .accessibilityLabel("More actions")
        .accessibilityIdentifier("screen.actions.more")
    }
}

struct CloudBakeBottomNavigation: View {
    let selectedDestination: AppDestination
    let onSelect: (AppDestination) -> Void

    private let destinations: [AppDestination] = [
        .dashboard,
        .orders,
        .inventory,
        .more
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(destinations) { destination in
                CloudBakeBottomNavigationItem(
                    destination: destination,
                    isSelected: destination == selectedDestination
                        || (destination == .more && selectedDestination.isGroupedUnderMore),
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
    let onSelect: (AppDestination) -> Void

    var body: some View {
        if isSelected {
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
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(destination.bottomNavigationTitle)
            .accessibilityIdentifier(destination.bottomNavigationAccessibilityIdentifier)
            .frame(maxWidth: .infinity)
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
                    CloudBakeTheme.ColorToken.appBackground.opacity(0.34)
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
