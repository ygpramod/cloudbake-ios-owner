import SwiftUI
import UIKit

struct CloudBakeScreenScaffold<Content: View>: View {
    let title: String
    let selectedDestination: AppDestination
    let primaryAction: CloudBakeScreenAction?
    let secondaryActions: [CloudBakeScreenAction]
    let collapsesActionsIntoMenu: Bool
    let showsHeader: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        selectedDestination: AppDestination,
        primaryAction: CloudBakeScreenAction? = nil,
        secondaryActions: [CloudBakeScreenAction] = [],
        collapsesActionsIntoMenu: Bool = false,
        showsHeader: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.selectedDestination = selectedDestination
        self.primaryAction = primaryAction
        self.secondaryActions = secondaryActions
        self.collapsesActionsIntoMenu = collapsesActionsIntoMenu
        self.showsHeader = showsHeader
        self.content = content()
    }

    var body: some View {
        ZStack {
            CloudBakeScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: CloudBakeTheme.Spacing.section) {
                    if showsHeader {
                        CloudBakeScreenHeader(
                            title: title,
                            primaryAction: primaryAction,
                            secondaryActions: secondaryActions,
                            collapsesActionsIntoMenu: collapsesActionsIntoMenu
                        )
                    }

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
                .padding(.bottom, CloudBakeTheme.Spacing.bottomNavigationHeight)
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
