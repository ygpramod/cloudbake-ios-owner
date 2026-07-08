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

                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        content()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.black.opacity(0.06), lineWidth: 1)
                    }

                    if showsCancelButton {
                        Button(role: .cancel, action: onCancel) {
                            Text("Cancel")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.cloudBakePink)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .background(Color.cloudBakePink.opacity(0.11), in: Capsule())
                        .contentShape(Capsule())
                            .accessibilityIdentifier(cancelAccessibilityIdentifier)
                    }
                }
                .padding(28)
                .frame(maxWidth: 360)
                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
        Text(title)
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(role == .destructive ? Color.red : Color.primary)
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
