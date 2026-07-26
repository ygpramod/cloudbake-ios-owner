import SwiftUI

extension View {
    func cloudRestorePrompts(
        viewModel: CloudRestoreSettingsViewModel,
        offersStartFresh: Bool = false
    ) -> some View {
        modifier(
            CloudRestorePromptModifier(
                viewModel: viewModel,
                offersStartFresh: offersStartFresh
            )
        )
    }
}

private struct CloudRestorePromptModifier: ViewModifier {
    @ObservedObject var viewModel: CloudRestoreSettingsViewModel
    let offersStartFresh: Bool
    @State private var presentedPrompt: CloudRestorePrompt?

    func body(content: Content) -> some View {
        content.cloudBakeConfirmationDialog(
            isPresented: Binding(
                get: { presentedPrompt != nil },
                set: { isPresented in
                    if !isPresented {
                        presentedPrompt = nil
                    }
                }
            ),
            title: title(for: presentedPrompt),
            message: message(for: presentedPrompt),
            showsCancelButton: !offersStartFresh && !viewModel.isWorking,
            cancelAccessibilityIdentifier: "settings.cloudRestore.cancel",
            onCancel: {
                guard !viewModel.isWorking else { return }
                presentedPrompt = nil
                Task { await viewModel.cancel() }
            }
        ) {
            promptActions(for: presentedPrompt)
                .disabled(viewModel.isWorking)
        }
        .onAppear {
            presentedPrompt = viewModel.prompt
        }
        .onChange(of: viewModel.prompt) { _, prompt in
            presentedPrompt = prompt
        }
    }

    @ViewBuilder
    private func promptActions(for prompt: CloudRestorePrompt?) -> some View {
        switch prompt {
        case .restore:
            nativeDialogButton("Restore Backup") {
                presentedPrompt = nil
                Task { await viewModel.startRestore() }
            }
            .accessibilityIdentifier("settings.cloudRestore.confirm")
        case .replace:
            nativeDialogButton("Replace and Restore", role: .destructive) {
                presentedPrompt = nil
                Task { await viewModel.confirmReplacement() }
            }
            .accessibilityIdentifier("settings.cloudRestore.replace.confirm")
        case .cellular:
            nativeDialogButton("Restore Using Cellular") {
                presentedPrompt = nil
                Task { await viewModel.confirmCellular() }
            }
            .accessibilityIdentifier("settings.cloudRestore.cellular.confirm")
        case .brokenAssets:
            nativeDialogButton("Ignore Broken Photos") {
                presentedPrompt = nil
                Task { await viewModel.resolveBrokenAssets(.ignore) }
            }
            .accessibilityIdentifier("settings.cloudRestore.assets.ignore")

            nativeDialogButton("Remove Photo References", role: .destructive) {
                presentedPrompt = nil
                Task { await viewModel.resolveBrokenAssets(.removeReferences) }
            }
            .accessibilityIdentifier("settings.cloudRestore.assets.remove")
        case nil:
            EmptyView()
        }

        if offersStartFresh {
            nativeDialogButton("Start Fresh") {
                presentedPrompt = nil
                Task { await viewModel.startFresh() }
            }
            .accessibilityIdentifier("settings.cloudRestore.startFresh")
        }
    }

    private func title(for prompt: CloudRestorePrompt?) -> String {
        switch prompt {
        case .restore: "Restore Cloud Backup?"
        case .replace: "Replace Local Data?"
        case .cellular: "Use Cellular Data?"
        case .brokenAssets: "Some Photos Are Unavailable"
        case nil: "Restore Cloud Backup"
        }
    }

    private func message(for prompt: CloudRestorePrompt?) -> String {
        switch prompt {
        case .restore(let proposal):
            "Backup from \(date(proposal)), \(size(proposal)), with \(proposal.snapshot.assetCount) photos. Integrity: \(integrity(proposal))."
        case .replace(let proposal):
            "Backup from \(date(proposal)), \(size(proposal)), with \(proposal.snapshot.assetCount) photos. Integrity: \(integrity(proposal)). This replaces all current CloudBake data after creating a rollback copy."
        case .cellular(let proposal):
            "This restore is approximately \(size(proposal)). Cellular charges may apply."
        case .brokenAssets(let proposal):
            "\(proposal.assets.count) photo \(proposal.assets.count == 1 ? "asset is" : "assets are") missing or damaged. Ignore them, or remove their references before restoring."
        case nil:
            ""
        }
    }

    private func date(_ proposal: RestoreProposal) -> String {
        proposal.snapshot.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func size(_ proposal: RestoreProposal) -> String {
        ByteCountFormatter.string(
            fromByteCount: proposal.snapshot.totalByteCount,
            countStyle: .file
        )
    }

    private func integrity(_ proposal: RestoreProposal) -> String {
        switch proposal.snapshot.integrity {
        case .verified: "Verified"
        case .brokenAssets(let count): "\(count) unavailable"
        }
    }
}
