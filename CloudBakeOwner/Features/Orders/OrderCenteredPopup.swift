import SwiftUI

extension View {
    func cloudBakeCenteredPopup<PopupContent: View>(
        isPresented: Bool,
        title: String,
        subtitle: String,
        systemImage: String,
        showsCancelButton: Bool = true,
        cancelAccessibilityIdentifier: String = "cloudBake.popup.cancel",
        onCancel: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> PopupContent
    ) -> some View {
        overlay(alignment: .center) {
            if isPresented {
                CloudBakeCenteredPopup(
                    title: title,
                    subtitle: subtitle,
                    systemImage: systemImage,
                    showsCancelButton: showsCancelButton,
                    cancelAccessibilityIdentifier: cancelAccessibilityIdentifier,
                    onCancel: onCancel,
                    content: content
                )
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPresented)
    }

    func centeredOrderPopup<PopupContent: View>(
        isPresented: Bool,
        title: String,
        showsCancelButton: Bool = true,
        onCancel: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> PopupContent
    ) -> some View {
        cloudBakeCenteredPopup(
            isPresented: isPresented,
            title: title,
            subtitle: orderPopupSubtitle(for: title),
            systemImage: orderPopupIconName(for: title),
            showsCancelButton: showsCancelButton,
            cancelAccessibilityIdentifier: "orders.popup.cancel",
            onCancel: onCancel,
            content: content
        )
    }
}

private struct CloudBakeCenteredPopup<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let showsCancelButton: Bool
    let cancelAccessibilityIdentifier: String
    let onCancel: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.56)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onCancel)

                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        Image(systemName: systemImage)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.cloudBakePink)
                            .accessibilityHidden(true)

                        Text(title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)

                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("cloudBake.popup.subtitle")
                        }
                    }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                        .padding(.bottom, 24)

                    Rectangle()
                        .fill(Color.cloudBakePink.opacity(0.24))
                        .frame(height: 1)
                        .padding(.horizontal, 30)

                    VStack(spacing: 0) {
                        content()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, showsCancelButton ? 16 : 24)

                    if showsCancelButton {
                        Rectangle()
                            .fill(.black.opacity(0.10))
                            .frame(height: 1)
                            .padding(.horizontal, 30)

                        Button(role: .cancel, action: onCancel) {
                            Text("Cancel")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.cloudBakePink)
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier(cancelAccessibilityIdentifier)
                    }
                }
                .frame(maxWidth: 360)
                .background(.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.20), radius: 24, y: 14)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(10)
    }
}

private func orderPopupIconName(for title: String) -> String {
    if title.localizedCaseInsensitiveContains("payment") {
        return "banknote"
    }

    if title.localizedCaseInsensitiveContains("inventory") {
        return "shippingbox"
    }

    if title.localizedCaseInsensitiveContains("partial") {
        return "plus.circle"
    }

    return "arrow.triangle.2.circlepath"
}

private func orderPopupSubtitle(for title: String) -> String {
    if title.localizedCaseInsensitiveContains("payment") {
        return "Update the order payment"
    }

    if title.localizedCaseInsensitiveContains("inventory") {
        return "Confirm stock deduction"
    }

    if title.localizedCaseInsensitiveContains("partial") {
        return "Add the amount received"
    }

    return "Update the order status"
}

func centeredPopupButton(
    _ title: String,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
) -> some View {
    Button(role: role, action: action) {
        popupRow(
            title: title,
            systemImage: popupIconName(for: title, role: role),
            iconTint: role == .destructive ? .red : Color.cloudBakePink,
            isSelected: false,
            showsRadio: false
        )
    }
    .buttonStyle(.plain)
    .foregroundStyle(role == .destructive ? Color.red : Color.primary)
}

func centeredPopupSelectionButton(
    _ title: String,
    isSelected: Bool,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        popupRow(
            title: title,
            systemImage: popupIconName(for: title),
            iconTint: popupIconTint(for: title),
            isSelected: isSelected,
            showsRadio: true
        )
    }
    .buttonStyle(.plain)
    .foregroundStyle(isSelected ? Color.cloudBakePink : Color.primary)
    .accessibilityValue(isSelected ? "Selected" : "")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
}

func centeredPopupPillButton(
    _ title: String,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.cloudBakePink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .background(Color.cloudBakePink.opacity(0.11), in: Capsule())
    .contentShape(Capsule())
}

private func popupRow(
    title: String,
    systemImage: String,
    iconTint: Color,
    isSelected: Bool,
    showsRadio: Bool
) -> some View {
    HStack(spacing: 14) {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(iconTint)
            .frame(width: 38, height: 38)
            .background(iconTint.opacity(0.12), in: Circle())
            .accessibilityHidden(true)

        Text(title)
            .font(.body.weight(isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? Color.cloudBakePink : .primary)
            .lineLimit(2)
            .minimumScaleFactor(0.85)

        Spacer(minLength: 12)

        if showsRadio {
            Image(systemName: isSelected ? "smallcircle.filled.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? Color.cloudBakePink : Color.secondary.opacity(0.55))
                .accessibilityHidden(true)
        }
    }
    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    .padding(.horizontal, 14)
    .background(isSelected ? Color.cloudBakePink.opacity(0.10) : Color.clear)
    .overlay(alignment: .bottom) {
        Rectangle()
            .fill(.black.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 66)
    }
    .contentShape(Rectangle())
}

private func popupIconName(for title: String, role: ButtonRole? = nil) -> String {
    if role == .destructive {
        return "exclamationmark.triangle"
    }

    switch title {
    case "Draft":
        return "doc.text"
    case "Confirmed":
        return "checkmark.circle"
    case "In Progress":
        return "clock"
    case "Ready":
        return "takeoutbag.and.cup.and.straw"
    case "Completed":
        return "party.popper"
    case "Cancelled":
        return "xmark"
    case "Mark Paid":
        return "checkmark.seal"
    case "Add Partial Payment":
        return "plus.circle"
    case "Import From Contacts":
        return "person.crop.circle.badge.plus"
    case "Enter Manually":
        return "square.and.pencil"
    default:
        return "arrow.right.circle"
    }
}

private func popupIconTint(for title: String) -> Color {
    switch title {
    case "Draft":
        return .secondary
    case "Confirmed":
        return .green
    case "In Progress":
        return .blue
    case "Ready":
        return Color.cloudBakePink
    case "Completed":
        return .purple
    case "Cancelled":
        return .red
    default:
        return Color.cloudBakePink
    }
}
