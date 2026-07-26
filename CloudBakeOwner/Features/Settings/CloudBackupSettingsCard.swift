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
}

extension View {
    func cloudBackupPrompts(
        viewModel: CloudBackupSettingsViewModel
    ) -> some View {
        cloudBakeConfirmationDialog(
            isPresented: Binding(
                get: { viewModel.pendingAccountProposal != nil },
                set: { isPresented in
                    guard !isPresented,
                          viewModel.pendingAccountProposal != nil else { return }
                    Task { await viewModel.cancelAccountBackup() }
                }
            ),
            title: "Use This iCloud Account?",
            message: "CloudBake will publish a complete recovery backup to the private iCloud account currently signed in on this iPhone. Confirm only if this is the intended account.",
            cancelAccessibilityIdentifier: "settings.cloudBackup.account.cancel",
            onCancel: {
                Task { await viewModel.cancelAccountBackup() }
            }
        ) {
            nativeDialogButton("Confirm iCloud Account") {
                Task { await viewModel.confirmAccountBackup() }
            }
            .accessibilityIdentifier("settings.cloudBackup.account.confirm")
        }
        .cloudBakeConfirmationDialog(
            isPresented: Binding(
                get: { viewModel.pendingCellularProposal != nil },
                set: { isPresented in
                    guard !isPresented,
                          viewModel.pendingCellularProposal != nil else { return }
                    Task { await viewModel.cancelCellularBackup() }
                }
            ),
            title: "Use Cellular Data?",
            message: cellularConfirmationDescription(for: viewModel),
            cancelAccessibilityIdentifier: "settings.cloudBackup.cellular.cancel",
            onCancel: {
                Task { await viewModel.cancelCellularBackup() }
            }
        ) {
            nativeDialogButton("Back Up Using Cellular") {
                Task { await viewModel.confirmCellularBackup() }
            }
            .accessibilityIdentifier("settings.cloudBackup.cellular.confirm")
        }
        .cloudBakeConfirmationDialog(
            isPresented: Binding(
                get: {
                    viewModel.pendingUnavailablePhotoProposal != nil
                        && !viewModel.isConfirmingUnavailablePhotoRemoval
                },
                set: { isPresented in
                    guard !isPresented,
                          viewModel.pendingUnavailablePhotoProposal != nil,
                          !viewModel.isConfirmingUnavailablePhotoRemoval else { return }
                    Task { await viewModel.cancelUnavailablePhotoDecision() }
                }
            ),
            title: "Unavailable Photos",
            message: unavailablePhotoDescription(for: viewModel),
            cancelAccessibilityIdentifier: "settings.cloudBackup.photos.cancel",
            onCancel: {
                Task { await viewModel.cancelUnavailablePhotoDecision() }
            }
        ) {
            nativeDialogButton("Back Up Without Photos") {
                Task { await viewModel.approveUnavailablePhotoOmissions() }
            }
            .accessibilityIdentifier("settings.cloudBackup.photos.omit")

            nativeDialogButton("Remove From CloudBake And Back Up", role: .destructive) {
                viewModel.requestUnavailablePhotoRemoval()
            }
            .accessibilityIdentifier("settings.cloudBackup.photos.remove")
        }
        .cloudBakeConfirmationDialog(
            isPresented: Binding(
                get: { viewModel.isConfirmingUnavailablePhotoRemoval },
                set: { viewModel.isConfirmingUnavailablePhotoRemoval = $0 }
            ),
            title: "Remove Broken References?",
            message: "This removes only the unavailable photo references from CloudBake. It never deletes photos from the iPhone Photos library.",
            cancelAccessibilityIdentifier: "settings.cloudBackup.photos.remove.cancel",
            onCancel: { viewModel.cancelUnavailablePhotoRemoval() }
        ) {
            nativeDialogButton("Remove And Back Up", role: .destructive) {
                Task { await viewModel.confirmUnavailablePhotoRemoval() }
            }
            .accessibilityIdentifier("settings.cloudBackup.photos.remove.confirm")
        }
    }

    private func cellularConfirmationDescription(
        for viewModel: CloudBackupSettingsViewModel
    ) -> String {
        guard let proposal = viewModel.pendingCellularProposal else {
            return "CloudBake needs your confirmation before using cellular data."
        }
        let size = ByteCountFormatter.string(
            fromByteCount: proposal.estimatedUploadByteCount,
            countStyle: .file
        )
        return "This backup is approximately \(size). Cellular charges may apply."
    }

    private func unavailablePhotoDescription(
        for viewModel: CloudBackupSettingsViewModel
    ) -> String {
        let count = viewModel.pendingUnavailablePhotoProposal?.unavailablePhotoCount ?? 0
        return "CloudBake found \(count) linked photo\(count == 1 ? "" : "s") that no longer exist\(count == 1 ? "s" : "") in Photos. Continue without \(count == 1 ? "it" : "them"), remove the broken CloudBake references, or cancel. Your previous backup is unchanged."
    }
}
