import SwiftUI

struct CloudBakePopupAction: Identifiable {
    var id: String { accessibilityIdentifier }

    let title: String
    let systemImage: String
    let tint: Color
    let accessibilityIdentifier: String
    let action: () -> Void
}

extension View {
    func cloudBakeActionPopup(
        isPresented: Binding<Bool>,
        title: String,
        accessibilityIdentifier: String,
        actions: [CloudBakePopupAction]
    ) -> some View {
        modifier(
            CloudBakeActionPopupModifier(
                isPresented: isPresented,
                title: title,
                accessibilityIdentifier: accessibilityIdentifier,
                actions: actions
            )
        )
    }

    func cloudBakeConfirmationDialog<Actions: View>(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        messageAccessibilityIdentifier: String = "cloudBake.popup.subtitle",
        showsCancelButton: Bool = true,
        cancelAccessibilityIdentifier: String = "cloudBake.popup.cancel",
        onCancel: @escaping () -> Void,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        modifier(
            CloudBakeConfirmationDialogModifier(
                externalIsPresented: isPresented,
                title: title,
                message: message,
                messageAccessibilityIdentifier: messageAccessibilityIdentifier,
                showsCancelButton: showsCancelButton,
                cancelAccessibilityIdentifier: cancelAccessibilityIdentifier,
                onCancel: onCancel,
                actions: actions
            )
        )
    }

    func orderConfirmationDialog<Actions: View>(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        messageAccessibilityIdentifier: String = "cloudBake.popup.subtitle",
        showsCancelButton: Bool = true,
        cancelAccessibilityIdentifier: String = "orders.popup.cancel",
        onCancel: @escaping () -> Void,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        cloudBakeConfirmationDialog(
            isPresented: isPresented,
            title: title,
            message: message ?? orderDialogMessage(for: title),
            messageAccessibilityIdentifier: messageAccessibilityIdentifier,
            showsCancelButton: showsCancelButton,
            cancelAccessibilityIdentifier: cancelAccessibilityIdentifier,
            onCancel: onCancel,
            actions: actions
        )
    }
}

private struct CloudBakeActionPopupModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let accessibilityIdentifier: String
    let actions: [CloudBakePopupAction]

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture(perform: dismiss)
                            .accessibilityHidden(true)

                        popupCard
                            .padding(CloudBakeTheme.Spacing.screenHorizontal)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                    }
                    .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.18), value: isPresented)
    }

    private var popupCard: some View {
        VStack(spacing: CloudBakeTheme.Spacing.sectionContent) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    actionRow(action)

                    if index < actions.count - 1 {
                        Divider()
                            .padding(.leading, 66)
                    }
                }
            }
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(CloudBakeTheme.ColorToken.primaryAction.opacity(0.10), lineWidth: 1)
            }

            Button("Cancel", action: dismiss)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(Rectangle())
                .accessibilityIdentifier("\(accessibilityIdentifier).cancel")
        }
        .padding(.horizontal, CloudBakeTheme.Spacing.rowContent)
        .padding(.top, CloudBakeTheme.Spacing.cardPadding)
        .padding(.bottom, CloudBakeTheme.Spacing.compactControl)
        .frame(maxWidth: 340)
        .background(CloudBakeTheme.ColorToken.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .stroke(CloudBakeTheme.ColorToken.primaryAction.opacity(0.18), lineWidth: 1)
        }
        .shadow(
            color: CloudBakeTheme.Elevation.softShadow,
            radius: CloudBakeTheme.Elevation.softRadius,
            y: CloudBakeTheme.Elevation.softYOffset
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAction(.escape, dismiss)
    }

    private func actionRow(_ action: CloudBakePopupAction) -> some View {
        Button {
            dismiss()
            Task { @MainActor in
                await Task.yield()
                action.action()
            }
        } label: {
            HStack(spacing: CloudBakeTheme.Spacing.sectionContent) {
                Image(systemName: action.systemImage)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(action.tint)
                    .frame(width: 34)

                Text(action.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: CloudBakeTheme.Spacing.compactControl)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, CloudBakeTheme.Spacing.rowContent)
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }

    private func dismiss() {
        isPresented = false
    }
}

private struct CloudBakeConfirmationDialogModifier<Actions: View>: ViewModifier {
    @Binding var externalIsPresented: Bool
    let title: String
    let message: String
    let messageAccessibilityIdentifier: String
    let showsCancelButton: Bool
    let cancelAccessibilityIdentifier: String
    let onCancel: () -> Void
    let actions: () -> Actions

    @State private var nativeIsPresented = false
    @State private var didSelectAction = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                title,
                isPresented: nativePresentation,
                titleVisibility: .visible
            ) {
                actions()
                    .environment(\.nativeDialogActionSelection, $didSelectAction)

                if showsCancelButton {
                    Button("Cancel", role: .cancel) {
                        dismissAsCancellation()
                    }
                    .accessibilityIdentifier(cancelAccessibilityIdentifier)
                }
            } message: {
                if !message.isEmpty {
                    Text(message)
                        .accessibilityIdentifier(messageAccessibilityIdentifier)
                }
            }
            .onAppear {
                nativeIsPresented = externalIsPresented
            }
            .onChange(of: externalIsPresented) { _, isPresented in
                if !isPresented {
                    didSelectAction = false
                }
                nativeIsPresented = isPresented
            }
    }

    private var nativePresentation: Binding<Bool> {
        Binding(
            get: { nativeIsPresented },
            set: { isPresented in
                guard isPresented != nativeIsPresented else { return }
                guard !isPresented else {
                    nativeIsPresented = true
                    return
                }
                nativeIsPresented = false
                if didSelectAction {
                    didSelectAction = false
                    return
                }
                guard showsCancelButton else {
                    nativeIsPresented = externalIsPresented
                    return
                }
                scheduleCancellation()
            }
        )
    }

    private func dismissAsCancellation() {
        guard nativeIsPresented else { return }
        nativeIsPresented = false
        didSelectAction = false
        scheduleCancellation()
    }

    private func scheduleCancellation() {
        Task { @MainActor in
            await Task.yield()
            onCancel()
        }
    }
}

private struct NativeDialogActionSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

private extension EnvironmentValues {
    var nativeDialogActionSelection: Binding<Bool>? {
        get { self[NativeDialogActionSelectionKey.self] }
        set { self[NativeDialogActionSelectionKey.self] = newValue }
    }
}

func optionalPresentationBinding<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
    Binding(
        get: { value.wrappedValue != nil },
        set: { isPresented in
            if !isPresented {
                value.wrappedValue = nil
            }
        }
    )
}

func nativeDialogButton(
    _ title: String,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
) -> some View {
    NativeDialogButton(title: title, role: role, action: action)
}

func nativeDialogSelectionButton(
    _ title: String,
    isSelected: Bool,
    action: @escaping () -> Void
) -> some View {
    NativeDialogButton(
        title: isSelected ? "✓ \(title)" : title,
        action: action
    )
    .accessibilityValue(isSelected ? "Selected" : "")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
}

private struct NativeDialogButton: View {
    @Environment(\.nativeDialogActionSelection) private var actionSelection

    let title: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(title, role: role) {
            actionSelection?.wrappedValue = true
            action()
        }
    }
}

private func orderDialogMessage(for title: String) -> String {
    if title.localizedCaseInsensitiveContains("payment") {
        return "Update the order payment."
    }

    if title.localizedCaseInsensitiveContains("shortage") {
        return "Review available stock before continuing."
    }

    if title.localizedCaseInsensitiveContains("inventory")
        || title.localizedCaseInsensitiveContains("deduct")
    {
        return "Confirm the inventory deduction."
    }

    if title.localizedCaseInsensitiveContains("partial") {
        return "Add the amount received."
    }

    return "Update the order status."
}
