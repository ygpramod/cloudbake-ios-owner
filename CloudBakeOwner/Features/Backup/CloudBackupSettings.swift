import Combine
import Foundation

enum CloudBackupSettingsState: Equatable, Sendable {
    case enabled
    case disabled
    case unavailable
    case waitingForWiFi
    case preparing
    case uploading
    case verifying
    case awaitingCellularConfirmation
    case successful
    case failed(CloudBackupErrorCategory)
}

struct CloudBackupSettingsSnapshot: Equatable, Sendable {
    var isEnabled: Bool
    var areNotificationsEnabled: Bool
    var accountAvailability: BackupAccountAvailability
    var state: CloudBackupSettingsState
    var lastSuccessAt: Date?
    var estimatedUploadByteCount: Int64?

    static let unavailable = CloudBackupSettingsSnapshot(
        isEnabled: true,
        areNotificationsEnabled: true,
        accountAvailability: .unavailable,
        state: .unavailable,
        lastSuccessAt: nil,
        estimatedUploadByteCount: nil
    )
}

protocol CloudBackupSettingsServing: Sendable {
    func currentSettings() async -> CloudBackupSettingsSnapshot
    func setBackupEnabled(_ isEnabled: Bool) async -> CloudBackupSettingsSnapshot
    func setNotificationsEnabled(_ isEnabled: Bool) async -> CloudBackupSettingsSnapshot
    func backUpNow() async -> ManualBackupResult
    func confirmCellularBackup(_ proposal: ManualCellularBackupProposal) async -> ManualBackupResult
    func cancelCellularBackup(_ proposal: ManualCellularBackupProposal) async
}

@MainActor
final class CloudBackupSettingsViewModel: ObservableObject {
    @Published private(set) var snapshot: CloudBackupSettingsSnapshot
    @Published private(set) var pendingCellularProposal: ManualCellularBackupProposal?
    @Published private(set) var actionMessage: String?

    private let service: any CloudBackupSettingsServing

    init(
        service: any CloudBackupSettingsServing,
        initialSnapshot: CloudBackupSettingsSnapshot = .unavailable
    ) {
        self.service = service
        snapshot = initialSnapshot
    }

    func refresh() async {
        snapshot = await service.currentSettings()
    }

    func setBackupEnabled(_ isEnabled: Bool) async {
        snapshot.isEnabled = isEnabled
        snapshot.state = isEnabled ? .enabled : .disabled
        snapshot = await service.setBackupEnabled(isEnabled)
        actionMessage = isEnabled
            ? "Cloud backup is enabled. CloudBake will back up when eligible."
            : "Cloud backup is off. Your latest cloud backup is retained."
    }

    func setNotificationsEnabled(_ isEnabled: Bool) async {
        snapshot.areNotificationsEnabled = isEnabled
        snapshot = await service.setNotificationsEnabled(isEnabled)
    }

    func backUpNow() async {
        actionMessage = nil
        snapshot.state = .preparing
        let statusRefresh = makeActiveStatusRefreshTask()
        let result = await service.backUpNow()
        statusRefresh.cancel()
        await handle(result)
    }

    func confirmCellularBackup() async {
        guard let proposal = pendingCellularProposal else { return }
        pendingCellularProposal = nil
        snapshot.state = .uploading
        let statusRefresh = makeActiveStatusRefreshTask()
        let result = await service.confirmCellularBackup(proposal)
        statusRefresh.cancel()
        await handle(result)
    }

    func cancelCellularBackup() async {
        guard let proposal = pendingCellularProposal else { return }
        pendingCellularProposal = nil
        await service.cancelCellularBackup(proposal)
        snapshot = await service.currentSettings()
    }

    var statusTitle: String {
        switch snapshot.state {
        case .enabled: "Enabled"
        case .disabled: "Disabled"
        case .unavailable: "Backup Unavailable"
        case .waitingForWiFi: "Waiting for Wi-Fi"
        case .preparing: "Preparing"
        case .uploading: "Uploading"
        case .verifying: "Verifying"
        case .awaitingCellularConfirmation: "Confirmation Required"
        case .successful: "Up to Date"
        case .failed: "Backup Failed"
        }
    }

    var statusGuidance: String {
        switch snapshot.state {
        case .enabled:
            "CloudBake will keep one complete recovery backup in your private iCloud storage."
        case .disabled:
            "Automatic and manual cloud backups are off. The latest successful backup is retained."
        case .unavailable:
            "Sign in to iCloud and check your connection. CloudBake continues to work locally."
        case .waitingForWiFi:
            "Automatic backup will continue when this iPhone connects to Wi-Fi."
        case .preparing:
            "Creating a consistent snapshot of app data and photos."
        case .uploading:
            "Uploading the recovery snapshot to your private iCloud storage."
        case .verifying:
            "Verifying the uploaded recovery snapshot before making it current."
        case .awaitingCellularConfirmation:
            "Approve the estimated transfer size to continue on cellular data."
        case .successful:
            "The latest complete recovery snapshot is safely stored in iCloud."
        case .failed(let category):
            Self.failureGuidance(for: category)
        }
    }

    var lastSuccessDescription: String {
        snapshot.lastSuccessAt?.formatted(date: .abbreviated, time: .shortened) ?? "Never"
    }

    var estimatedSizeDescription: String {
        guard let byteCount = snapshot.estimatedUploadByteCount else { return "Not available yet" }
        return ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    var canBackUpNow: Bool {
        snapshot.isEnabled && !isBusy
    }

    var isBusy: Bool {
        switch snapshot.state {
        case .preparing, .uploading, .verifying, .awaitingCellularConfirmation:
            true
        default:
            false
        }
    }

    private func handle(_ result: ManualBackupResult) async {
        switch result {
        case .published:
            actionMessage = "Cloud backup completed successfully."
        case .requiresCellularConfirmation(let proposal):
            pendingCellularProposal = proposal
        case .busy:
            actionMessage = "Another backup is already in progress."
        case .deferred(let reason):
            actionMessage = Self.guidance(for: reason)
        case .invalidCellularApproval:
            actionMessage = "The cellular approval expired. Start the backup again."
        case .failed(let category):
            actionMessage = Self.failureGuidance(for: category)
        }
        snapshot = await service.currentSettings()
        if pendingCellularProposal != nil {
            snapshot.state = .awaitingCellularConfirmation
        }
    }

    private func makeActiveStatusRefreshTask() -> Task<Void, Never> {
        Task { [weak self, service] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                snapshot = await service.currentSettings()
            }
        }
    }

    private static func guidance(for reason: BackupDeferralReason) -> String {
        switch reason {
        case .disabled:
            "Enable cloud backup before starting a manual backup."
        case .accountConfirmationRequired:
            "Confirm this iCloud account before publishing its first backup."
        case .waitingForWiFi:
            "Connect to Wi-Fi, or start a manual backup and approve cellular data."
        case .networkUnavailable:
            "Connect this iPhone to the internet and try again."
        case .iCloudUnavailable:
            "Sign in to iCloud and try again. Your local data is unchanged."
        case .powerRestricted:
            "Turn off Low Power Mode and try again."
        case .insufficientStorage:
            "Free some iPhone storage before creating the backup."
        }
    }

    private static func failureGuidance(for category: CloudBackupErrorCategory) -> String {
        switch category {
        case .iCloudUnavailable, .authenticationRequired:
            "Check your iCloud sign-in and try again. Your previous backup is unchanged."
        case .networkUnavailable, .temporarilyUnavailable:
            "Check the connection and try again. Your previous backup is unchanged."
        case .quotaExceeded:
            "Free some iCloud storage, then try again."
        case .cancelled:
            "The backup was cancelled. Your previous backup is unchanged."
        case .permissionDenied:
            "CloudBake cannot access its private iCloud storage. Check iCloud settings."
        case .conflict:
            "The cloud backup changed during publication. Try again."
        case .corruptRemoteData:
            "The cloud backup could not be verified. Try creating a new backup."
        case .unknown:
            "Try again later. Your previous backup and local data are unchanged."
        }
    }
}

struct UnavailableCloudBackupSettingsService: CloudBackupSettingsServing {
    func currentSettings() async -> CloudBackupSettingsSnapshot { .unavailable }
    func setBackupEnabled(_ isEnabled: Bool) async -> CloudBackupSettingsSnapshot { .unavailable }
    func setNotificationsEnabled(_ isEnabled: Bool) async -> CloudBackupSettingsSnapshot { .unavailable }
    func backUpNow() async -> ManualBackupResult { .deferred(.iCloudUnavailable) }
    func confirmCellularBackup(_ proposal: ManualCellularBackupProposal) async -> ManualBackupResult {
        .deferred(.iCloudUnavailable)
    }
    func cancelCellularBackup(_ proposal: ManualCellularBackupProposal) async {}
}

#if DEBUG
actor CloudBackupSettingsUITestService: CloudBackupSettingsServing {
    private var snapshot = CloudBackupSettingsSnapshot(
        isEnabled: true,
        areNotificationsEnabled: true,
        accountAvailability: .available,
        state: .enabled,
        lastSuccessAt: Date(timeIntervalSince1970: 1_788_739_200),
        estimatedUploadByteCount: 4_000_000
    )

    func currentSettings() async -> CloudBackupSettingsSnapshot { snapshot }

    func setBackupEnabled(_ isEnabled: Bool) async -> CloudBackupSettingsSnapshot {
        snapshot.isEnabled = isEnabled
        snapshot.state = isEnabled ? .enabled : .disabled
        return snapshot
    }

    func setNotificationsEnabled(_ isEnabled: Bool) async -> CloudBackupSettingsSnapshot {
        snapshot.areNotificationsEnabled = isEnabled
        return snapshot
    }

    func backUpNow() async -> ManualBackupResult {
        let proposal = ManualCellularBackupProposal(
            id: "ui-test-proposal",
            generationID: "ui-test-generation",
            estimatedUploadByteCount: snapshot.estimatedUploadByteCount ?? 0
        )
        snapshot.state = .awaitingCellularConfirmation
        return .requiresCellularConfirmation(proposal)
    }

    func confirmCellularBackup(_ proposal: ManualCellularBackupProposal) async -> ManualBackupResult {
        snapshot.state = .successful
        snapshot.lastSuccessAt = Date(timeIntervalSince1970: 1_788_739_200)
        return .published(
            CloudBackupPublicationResult(
                generationID: proposal.generationID,
                replacedGenerationID: nil,
                wasAlreadyCurrent: false,
                cleanupPending: false
            )
        )
    }

    func cancelCellularBackup(_ proposal: ManualCellularBackupProposal) async {
        snapshot.state = .enabled
    }
}
#endif
