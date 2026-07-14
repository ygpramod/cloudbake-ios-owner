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

    func body(content: Content) -> some View {
        content.cloudBakeCenteredPopup(
            isPresented: viewModel.prompt != nil,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            showsCancelButton: !offersStartFresh,
            cancelAccessibilityIdentifier: "settings.cloudRestore.cancel",
            onCancel: { Task { await viewModel.cancel() } }
        ) {
            promptActions
                .disabled(viewModel.isWorking)
        }
    }

    @ViewBuilder
    private var promptActions: some View {
        switch viewModel.prompt {
        case .restore:
            centeredPopupButton("Restore Backup") {
                Task { await viewModel.startRestore() }
            }
            .accessibilityIdentifier("settings.cloudRestore.confirm")
        case .replace:
            centeredPopupButton("Replace and Restore", role: .destructive) {
                Task { await viewModel.confirmReplacement() }
            }
            .accessibilityIdentifier("settings.cloudRestore.replace.confirm")
        case .cellular:
            centeredPopupButton("Restore Using Cellular") {
                Task { await viewModel.confirmCellular() }
            }
            .accessibilityIdentifier("settings.cloudRestore.cellular.confirm")
        case .brokenAssets:
            centeredPopupButton("Ignore Broken Photos") {
                Task { await viewModel.resolveBrokenAssets(.ignore) }
            }
            .accessibilityIdentifier("settings.cloudRestore.assets.ignore")

            centeredPopupButton("Remove Photo References", role: .destructive) {
                Task { await viewModel.resolveBrokenAssets(.removeReferences) }
            }
            .accessibilityIdentifier("settings.cloudRestore.assets.remove")
        case nil:
            EmptyView()
        }

        if offersStartFresh {
            centeredPopupButton("Start Fresh") {
                Task { await viewModel.startFresh() }
            }
            .accessibilityIdentifier("settings.cloudRestore.startFresh")
        }
    }

    private var title: String {
        switch viewModel.prompt {
        case .restore: "Restore Cloud Backup?"
        case .replace: "Replace Local Data?"
        case .cellular: "Use Cellular Data?"
        case .brokenAssets: "Some Photos Are Unavailable"
        case nil: "Restore Cloud Backup"
        }
    }

    private var systemImage: String {
        switch viewModel.prompt {
        case .replace, .brokenAssets: "exclamationmark.triangle"
        case .cellular: "antenna.radiowaves.left.and.right"
        default: "icloud.and.arrow.down"
        }
    }

    private var subtitle: String {
        switch viewModel.prompt {
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
