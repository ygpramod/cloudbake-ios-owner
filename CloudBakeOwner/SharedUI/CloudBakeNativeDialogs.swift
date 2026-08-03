import SwiftUI

struct CloudBakePopupAction: Identifiable {
    var id: String { accessibilityIdentifier }

    let title: String
    let systemImage: String
    let tint: Color
    let accessibilityIdentifier: String
    let action: () -> Void
}

struct CloudBakeAnchoredActionPopup: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let title: String
    let actions: [CloudBakeScreenMenuAction]
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
            popupContent
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 270)
        .frame(maxHeight: verticalSizeClass == .compact ? 320 : 520)
        .presentationBackground(CloudBakeTheme.ColorToken.surface.opacity(0.97))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cloudBake.anchoredPopup")
        .accessibilityAction(.escape) {
            isPresented = false
        }
    }

    private var popupContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline.weight(.bold))
                .padding(.horizontal, CloudBakeTheme.Spacing.rowContent)
                .padding(.top, CloudBakeTheme.Spacing.rowContent)
                .padding(.bottom, CloudBakeTheme.Spacing.compactControl)

            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                Button {
                    if action.dismissesPopup {
                        isPresented = false
                    }
                    Task { @MainActor in
                        await Task.yield()
                        action.action()
                    }
                } label: {
                    HStack(spacing: CloudBakeTheme.Spacing.sectionContent) {
                        Image(systemName: action.systemImage)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(action.tint)
                            .frame(width: 30)

                        Text(action.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer(minLength: CloudBakeTheme.Spacing.compactControl)

                        Image(systemName: action.isSelected ? "checkmark" : "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(action.isSelected ? action.tint : .secondary)
                    }
                    .padding(.horizontal, CloudBakeTheme.Spacing.rowContent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(action.accessibilityIdentifier)
                .accessibilityValue(action.isSelected ? "Selected" : "")
                .accessibilityAddTraits(action.isSelected ? .isSelected : [])

                if index < actions.count - 1 {
                    Divider()
                        .padding(.leading, 62)
                        .padding(.trailing, CloudBakeTheme.Spacing.rowContent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, CloudBakeTheme.Spacing.compactControl)
    }
}

struct CloudBakeAnchoredPopupButton<Label: View>: View {
    let title: String
    let actions: [CloudBakeScreenMenuAction]
    let accessibilityLabel: String
    var accessibilityValue = ""
    let accessibilityIdentifier: String
    @ViewBuilder let label: () -> Label

    @State private var isPresented = false
    @State private var feedbackTrigger = 0

    var body: some View {
        Button {
            feedbackTrigger += 1
            isPresented = true
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityIdentifier)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .popover(
            isPresented: $isPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            CloudBakeAnchoredActionPopup(
                title: title,
                actions: actions,
                isPresented: $isPresented
            )
            .presentationCompactAdaptation(.popover)
        }
    }
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

    func cloudBakeInputPopup<Fields: View>(
        isPresented: Binding<Bool>,
        title: String,
        message: String = "",
        primaryTitle: String,
        primaryRole: ButtonRole? = nil,
        primaryAccessibilityIdentifier: String,
        cancelAccessibilityIdentifier: String,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping () -> Void,
        @ViewBuilder fields: @escaping () -> Fields
    ) -> some View {
        modifier(
            CloudBakeInputPopupModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                primaryTitle: primaryTitle,
                primaryRole: primaryRole,
                primaryAccessibilityIdentifier: primaryAccessibilityIdentifier,
                cancelAccessibilityIdentifier: cancelAccessibilityIdentifier,
                onCancel: onCancel,
                onSubmit: onSubmit,
                fields: fields
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

private struct CloudBakeInputPopupModifier<Fields: View>: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let primaryTitle: String
    let primaryRole: ButtonRole?
    let primaryAccessibilityIdentifier: String
    let cancelAccessibilityIdentifier: String
    let onCancel: () -> Void
    let onSubmit: () -> Void
    let fields: () -> Fields
    @AccessibilityFocusState private var isPopupFocused: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(isPresented)
            .overlay {
                if isPresented {
                    GeometryReader { proxy in
                        ZStack {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture(perform: cancel)
                                .accessibilityHidden(true)

                            ScrollView {
                                popupCard
                            }
                            .scrollBounceBehavior(.basedOnSize)
                            .frame(maxHeight: max(220, proxy.size.height - 48))
                            .padding(CloudBakeTheme.Spacing.screenHorizontal)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                        }
                    }
                    .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.18), value: isPresented)
            .onChange(of: isPresented) { _, presented in
                guard presented else {
                    isPopupFocused = false
                    return
                }
                Task { @MainActor in
                    await Task.yield()
                    isPopupFocused = true
                }
            }
    }

    private var popupCard: some View {
        VStack(alignment: .leading, spacing: CloudBakeTheme.Spacing.sectionContent) {
            Text(title)
                .font(.title3.weight(.bold))

            if !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: CloudBakeTheme.Spacing.compactControl) {
                fields()
                    .textFieldStyle(.plain)
                    .padding(.horizontal, CloudBakeTheme.Spacing.sectionContent)
                    .frame(minHeight: 48)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))

                Button(role: primaryRole) {
                    onSubmit()
                } label: {
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryTint)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(primaryTint.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(primaryAccessibilityIdentifier)
            }

            Button("Cancel", action: cancel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityIdentifier(cancelAccessibilityIdentifier)
        }
        .padding(CloudBakeTheme.Spacing.cardPadding)
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
        .accessibilityIdentifier("cloudBake.inputPopup")
        .accessibilityFocused($isPopupFocused)
        .accessibilityAction(.escape, cancel)
    }

    private var primaryTint: Color {
        primaryRole == .destructive ? .red : CloudBakeTheme.ColorToken.primaryAction
    }

    private func cancel() {
        isPresented = false
        onCancel()
    }
}

private struct CloudBakeActionPopupModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let accessibilityIdentifier: String
    let actions: [CloudBakePopupAction]
    @AccessibilityFocusState private var isPopupFocused: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(isPresented)
            .overlay {
                if isPresented {
                    GeometryReader { proxy in
                        ZStack {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture(perform: dismiss)
                                .accessibilityHidden(true)

                            ViewThatFits(in: .vertical) {
                                popupCard

                                ScrollView {
                                    popupCard
                                }
                                .scrollBounceBehavior(.basedOnSize)
                            }
                            .frame(maxHeight: max(180, proxy.size.height - 48))
                            .padding(CloudBakeTheme.Spacing.screenHorizontal)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                        }
                    }
                    .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.18), value: isPresented)
            .onChange(of: isPresented) { _, presented in
                guard presented else {
                    isPopupFocused = false
                    return
                }
                Task { @MainActor in
                    await Task.yield()
                    isPopupFocused = true
                }
            }
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
                .frame(maxWidth: .infinity, minHeight: 44)
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
        .accessibilityFocused($isPopupFocused)
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

    @State private var isPresented = false
    @AccessibilityFocusState private var isPopupFocused: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(isPresented)
            .overlay {
                if isPresented {
                    GeometryReader { proxy in
                        ZStack {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if showsCancelButton {
                                        dismissAsCancellation()
                                    }
                                }
                                .accessibilityHidden(true)

                            ViewThatFits(in: .vertical) {
                                popupCard

                                ScrollView {
                                    popupCard
                                }
                                .scrollBounceBehavior(.basedOnSize)
                            }
                            .frame(maxHeight: max(180, proxy.size.height - 48))
                            .padding(CloudBakeTheme.Spacing.screenHorizontal)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                        }
                    }
                    .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.18), value: isPresented)
            .onAppear {
                isPresented = externalIsPresented
            }
            .onChange(of: externalIsPresented) { _, presented in
                isPresented = presented
            }
            .onChange(of: isPresented) { _, presented in
                guard presented else {
                    isPopupFocused = false
                    return
                }
                Task { @MainActor in
                    await Task.yield()
                    isPopupFocused = true
                }
            }
    }

    private var popupCard: some View {
        VStack(spacing: CloudBakeTheme.Spacing.sectionContent) {
            VStack(alignment: .leading, spacing: CloudBakeTheme.Spacing.compactControl) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                if !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(messageAccessibilityIdentifier)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: CloudBakeTheme.Spacing.compactControl) {
                actions()
            }

            if showsCancelButton {
                Button("Cancel", action: dismissAsCancellation)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier(cancelAccessibilityIdentifier)
            }
        }
        .padding(CloudBakeTheme.Spacing.cardPadding)
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
        .accessibilityIdentifier("cloudBake.confirmationPopup")
        .accessibilityFocused($isPopupFocused)
        .accessibilityAction(.escape) {
            if showsCancelButton {
                dismissAsCancellation()
            }
        }
    }

    private func dismissAsCancellation() {
        isPresented = false
        Task { @MainActor in
            await Task.yield()
            onCancel()
        }
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
    let title: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role) {
            action()
        } label: {
            HStack(spacing: CloudBakeTheme.Spacing.compactControl) {
                Image(systemName: role == .destructive ? "exclamationmark.triangle" : "checkmark.circle")
                    .font(.subheadline.weight(.semibold))

                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 0)
            }
            .foregroundStyle(actionTint)
            .padding(.horizontal, CloudBakeTheme.Spacing.sectionContent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(actionTint.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var actionTint: Color {
        role == .destructive ? .red : CloudBakeTheme.ColorToken.primaryAction
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
