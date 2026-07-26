import SwiftUI

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
    let action: CloudBakeSectionAction?
    @ViewBuilder let content: Content

    init(
        _ title: String? = nil,
        action: CloudBakeSectionAction? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CloudBakeTheme.Spacing.sectionContent) {
            if let title {
                HStack(spacing: 12) {
                    Text(title)
                        .font(CloudBakeTheme.Typography.sectionTitle)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let action {
                        Button(action: action.action) {
                            Image(systemName: action.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CloudBakeTheme.ColorToken.primaryAction)
                                .frame(minWidth: 50, minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .accessibilityLabel(action.title)
                        .accessibilityIdentifier(action.accessibilityIdentifier)
                    }
                }
            }

            content
        }
    }
}

struct CloudBakeSectionAction {
    let title: String
    let systemImage: String
    let accessibilityIdentifier: String
    let action: () -> Void
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

struct CloudBakeCompactRowIcon: View {
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
            .accessibilityHidden(true)
    }
}

struct CloudBakeCardDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 104)
    }
}

