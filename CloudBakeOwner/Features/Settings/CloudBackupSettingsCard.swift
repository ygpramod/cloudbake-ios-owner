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
                    Text("Create a complete recovery snapshot in your private iCloud storage.")
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
}
