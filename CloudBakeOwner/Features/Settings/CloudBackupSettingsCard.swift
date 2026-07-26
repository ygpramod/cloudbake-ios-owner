import SwiftUI

struct CloudBackupSettingsCard: View {
    @ObservedObject var viewModel: CloudBackupSettingsViewModel

    var body: some View {
        CloudBakeDetailCard {
            Toggle(
                "Cloud Backup",
                isOn: Binding(
                    get: { viewModel.snapshot.isEnabled },
                    set: { viewModel.setBackupEnabled($0) }
                )
            )
            .padding(.vertical, 12)
            .accessibilityIdentifier("settings.cloudBackup.enabled")

            CloudBakeDetailDivider()

            CloudBakeDetailRow("Status") {
                Text(viewModel.statusTitle)
            }
            .accessibilityIdentifier("settings.cloudBackup.status")

            Text(viewModel.statusGuidance)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
                .accessibilityIdentifier("settings.cloudBackup.guidance")

            CloudBakeDetailDivider()

            CloudBakeDetailRow("iCloud") {
                Text(
                    viewModel.snapshot.accountAvailability == .available
                        ? "Available"
                        : "Unavailable"
                )
            }

            CloudBakeDetailDivider()

            CloudBakeDetailRow("Last Successful Backup") {
                Text(viewModel.lastSuccessDescription)
                    .accessibilityIdentifier("settings.cloudBackup.lastSuccess")
            }

            if viewModel.snapshot.omittedAssetCount > 0 {
                CloudBakeDetailDivider()

                CloudBakeDetailRow("Backup Contents") {
                    let count = viewModel.snapshot.omittedAssetCount
                    Text("Without \(count) unavailable photo\(count == 1 ? "" : "s")")
                        .accessibilityIdentifier("settings.cloudBackup.omittedPhotos")
                }
            }

            CloudBakeDetailDivider()

            CloudBakeDetailRow("Estimated Size") {
                Text(viewModel.estimatedSizeDescription)
            }

            CloudBakeDetailDivider()

            Toggle(
                "Backup Notifications",
                isOn: Binding(
                    get: { viewModel.snapshot.areNotificationsEnabled },
                    set: { viewModel.setNotificationsEnabled($0) }
                )
            )
            .padding(.vertical, 12)
            .accessibilityIdentifier("settings.cloudBackup.notifications")

            CloudBakeDetailDivider()

            backupAction

            if let actionMessage = viewModel.actionMessage {
                Text(actionMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
                    .accessibilityIdentifier("settings.cloudBackup.actionMessage")
            }
        }
        .cloudBakeCenteredPopup(
            isPresented: viewModel.pendingAccountProposal != nil,
            title: "Use This iCloud Account?",
            subtitle: "CloudBake will publish a complete recovery backup to the private iCloud account currently signed in on this iPhone. Confirm only if this is the intended account.",
            systemImage: "person.crop.circle.badge.checkmark",
            cancelAccessibilityIdentifier: "settings.cloudBackup.account.cancel",
            onCancel: {
                Task { await viewModel.cancelAccountBackup() }
            }
        ) {
            centeredPopupButton("Confirm iCloud Account") {
                Task { await viewModel.confirmAccountBackup() }
            }
            .accessibilityIdentifier("settings.cloudBackup.account.confirm")
        }
        .cloudBakeCenteredPopup(
            isPresented: viewModel.pendingCellularProposal != nil,
            title: "Use Cellular Data?",
            subtitle: cellularConfirmationDescription,
            systemImage: "antenna.radiowaves.left.and.right",
            cancelAccessibilityIdentifier: "settings.cloudBackup.cellular.cancel",
            onCancel: {
                Task { await viewModel.cancelCellularBackup() }
            }
        ) {
            centeredPopupButton("Back Up Using Cellular") {
                Task { await viewModel.confirmCellularBackup() }
            }
            .accessibilityIdentifier("settings.cloudBackup.cellular.confirm")
        }
        .cloudBakeCenteredPopup(
            isPresented: viewModel.pendingUnavailablePhotoProposal != nil
                && !viewModel.isConfirmingUnavailablePhotoRemoval,
            title: "Unavailable Photos",
            subtitle: unavailablePhotoDescription,
            systemImage: "photo.badge.exclamationmark",
            cancelAccessibilityIdentifier: "settings.cloudBackup.photos.cancel",
            onCancel: {
                Task { await viewModel.cancelUnavailablePhotoDecision() }
            }
        ) {
            centeredPopupButton("Back Up Without Photos") {
                Task { await viewModel.approveUnavailablePhotoOmissions() }
            }
            .accessibilityIdentifier("settings.cloudBackup.photos.omit")

            centeredPopupButton("Remove From CloudBake And Back Up", role: .destructive) {
                viewModel.requestUnavailablePhotoRemoval()
            }
            .accessibilityIdentifier("settings.cloudBackup.photos.remove")
        }
        .cloudBakeCenteredPopup(
            isPresented: viewModel.isConfirmingUnavailablePhotoRemoval,
            title: "Remove Broken References?",
            subtitle: "This removes only the unavailable photo references from CloudBake. It never deletes photos from the iPhone Photos library.",
            systemImage: "trash",
            cancelAccessibilityIdentifier: "settings.cloudBackup.photos.remove.cancel",
            onCancel: { viewModel.cancelUnavailablePhotoRemoval() }
        ) {
            centeredPopupButton("Remove And Back Up", role: .destructive) {
                Task { await viewModel.confirmUnavailablePhotoRemoval() }
            }
            .accessibilityIdentifier("settings.cloudBackup.photos.remove.confirm")
        }
    }

    private var backupAction: some View {
        Button {
            Task { await viewModel.backUpNow() }
        } label: {
            HStack(spacing: 16) {
                CloudBakeRowIcon(systemImage: "icloud.and.arrow.up", tint: .cloudBakePink)

                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.isBusy ? "Backup in Progress…" : "Back Up Now")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Create a fresh recovery snapshot, even when nothing has changed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canBackUpNow)
        .accessibilityIdentifier("settings.cloudBackup.backUpNow")
    }

    private var cellularConfirmationDescription: String {
        guard let proposal = viewModel.pendingCellularProposal else {
            return "CloudBake needs your confirmation before using cellular data."
        }
        let size = ByteCountFormatter.string(
            fromByteCount: proposal.estimatedUploadByteCount,
            countStyle: .file
        )
        return "This backup is approximately \(size). Cellular charges may apply."
    }

    private var unavailablePhotoDescription: String {
        let count = viewModel.pendingUnavailablePhotoProposal?.unavailablePhotoCount ?? 0
        return "CloudBake found \(count) linked photo\(count == 1 ? "" : "s") that no longer exist\(count == 1 ? "s" : "") in Photos. Continue without \(count == 1 ? "it" : "them"), remove the broken CloudBake references, or cancel. Your previous backup is unchanged."
    }
}
