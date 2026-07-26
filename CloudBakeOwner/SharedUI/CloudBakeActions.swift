import SwiftUI

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

struct CloudBakeAdaptiveActionButton: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let title: String
    let systemImage: String
    let tint: Color
    let accessibilityIdentifier: String
    var isCompact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isCompact {
                CloudBakeCompactAdaptiveActionLabel(
                    title: title,
                    systemImage: systemImage,
                    tint: tint,
                    showsTitle: verticalSizeClass == .compact
                )
            } else if verticalSizeClass == .compact {
                Label(title, systemImage: systemImage)
                    .font(CloudBakeTheme.Typography.rowDetail.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(tint.opacity(0.12), in: Capsule())
            } else {
                CloudBakeIconActionLabel(
                    title: title,
                    systemImage: systemImage,
                    tint: tint
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct CloudBakeAdaptiveActionMenu<Content: View>: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let title: String
    let systemImage: String
    let tint: Color
    let accessibilityIdentifier: String
    var isCompact = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu(content: content) {
            if isCompact {
                CloudBakeCompactAdaptiveActionLabel(
                    title: title,
                    systemImage: systemImage,
                    tint: tint,
                    showsTitle: verticalSizeClass == .compact
                )
            } else if verticalSizeClass == .compact {
                Label(title, systemImage: systemImage)
                    .font(CloudBakeTheme.Typography.rowDetail.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(tint.opacity(0.12), in: Capsule())
            } else {
                CloudBakeIconActionLabel(
                    title: title,
                    systemImage: systemImage,
                    tint: tint
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CloudBakeCompactAdaptiveActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color
    let showsTitle: Bool

    var body: some View {
        Group {
            if showsTitle {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            } else {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
        .background(tint.opacity(0.10), in: Capsule())
        .padding(.vertical, 5)
    }
}

struct CloudBakeIconActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CloudBakeIconActionLabel(
                title: title,
                systemImage: systemImage,
                tint: tint
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CloudBakeIconActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(tint.opacity(0.12), in: Capsule())
            .accessibilityHidden(true)
    }
}
