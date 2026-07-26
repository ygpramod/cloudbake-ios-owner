import SwiftUI

extension View {
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
        confirmationDialog(
            title,
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            actions()

            if showsCancelButton {
                Button("Cancel", role: .cancel, action: onCancel)
                    .accessibilityIdentifier(cancelAccessibilityIdentifier)
            }
        } message: {
            if !message.isEmpty {
                Text(message)
                    .accessibilityIdentifier(messageAccessibilityIdentifier)
            }
        }
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
    Button(title, role: role, action: action)
}

func nativeDialogSelectionButton(
    _ title: String,
    isSelected: Bool,
    action: @escaping () -> Void
) -> some View {
    Button(isSelected ? "✓ \(title)" : title, action: action)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
}

private func orderDialogMessage(for title: String) -> String {
    if title.localizedCaseInsensitiveContains("payment") {
        return "Update the order payment."
    }

    if title.localizedCaseInsensitiveContains("shortage") {
        return "Review available stock before continuing."
    }

    if title.localizedCaseInsensitiveContains("inventory")
        || title.localizedCaseInsensitiveContains("deduct") {
        return "Confirm the inventory deduction."
    }

    if title.localizedCaseInsensitiveContains("partial") {
        return "Add the amount received."
    }

    return "Update the order status."
}
