import SwiftUI

extension View {
    func centeredOrderPopup<PopupContent: View>(
        isPresented: Bool,
        title: String,
        onCancel: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> PopupContent
    ) -> some View {
        overlay(alignment: .center) {
            if isPresented {
                CenteredOrderPopup(
                    title: title,
                    onCancel: onCancel,
                    content: content
                )
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPresented)
    }
}

struct CenteredOrderPopup<Content: View>: View {
    let title: String
    let onCancel: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onCancel)

                VStack(spacing: 14) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 10) {
                        content()
                    }

                    Divider()

                    Button("Cancel", role: .cancel, action: onCancel)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .accessibilityIdentifier("orders.popup.cancel")
                }
                .padding(18)
                .frame(maxWidth: 340)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 0.5)
                }
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.22), radius: 20, y: 10)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(10)
    }
}

func centeredPopupButton(
    _ title: String,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
) -> some View {
    Button(role: role, action: action) {
        Text(title)
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 40)
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(role == .destructive ? Color.red : Color.accentColor)
}
