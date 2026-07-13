import XCTest
import UserNotifications
@testable import CloudBakeOwner

@MainActor
final class CloudBackupSettingsTests: XCTestCase {
    func testNotificationPreferenceStartsEnabledAndPersistsOwnerChoice() {
        let suiteName = "CloudBackupSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = CloudBackupNotificationPreferences(defaults: defaults)

        XCTAssertTrue(preferences.isEnabled)

        preferences.isEnabled = false

        XCTAssertFalse(CloudBackupNotificationPreferences(defaults: defaults).isEnabled)
    }

    func testNotificationPolicyReportsCompletionAndOnlyActionableAutomaticFailures() {
        let policy = CloudBackupNotificationPolicy()
        let publication = CloudBackupPublicationResult(
            generationID: "generation-1",
            replacedGenerationID: nil,
            wasAlreadyCurrent: false,
            cleanupPending: false
        )

        XCTAssertEqual(
            policy.result(for: AutomaticBackupResult.published(publication)),
            .completed
        )
        XCTAssertEqual(
            policy.result(for: AutomaticBackupResult.failed(.quotaExceeded)),
            .failed(.quotaExceeded)
        )
        XCTAssertNil(policy.result(for: AutomaticBackupResult.failed(.networkUnavailable)))
        XCTAssertNil(policy.result(for: AutomaticBackupResult.deferred(.waitingForWiFi)))
    }

    func testDisabledBackupNotificationsDoNotRequestAuthorizationOrDeliver() async {
        let suiteName = "CloudBackupSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = CloudBackupNotificationPreferences(defaults: defaults)
        preferences.isEnabled = false
        let notificationCenter = CloudBackupNotificationCenterSpy()
        let sender = SystemCloudBackupNotificationSender(
            preferences: preferences,
            notificationCenter: notificationCenter
        )

        await sender.send(for: .completed)

        XCTAssertEqual(notificationCenter.authorizationRequestCount, 0)
        XCTAssertTrue(notificationCenter.requests.isEmpty)
    }

    func testBackupFailureNotificationContainsOnlySafeOperationalCopy() async throws {
        let suiteName = "CloudBackupSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let notificationCenter = CloudBackupNotificationCenterSpy()
        let sender = SystemCloudBackupNotificationSender(
            preferences: CloudBackupNotificationPreferences(defaults: defaults),
            notificationCenter: notificationCenter
        )

        await sender.send(for: .failed(.quotaExceeded))

        let request = try XCTUnwrap(notificationCenter.requests.first)
        XCTAssertEqual(request.content.title, "CloudBake backup needs attention")
        XCTAssertEqual(
            request.content.body,
            "Open Backup in Settings for safe guidance and try again."
        )
    }

    func testViewModelPresentsSafeFailureGuidanceWithoutPrivateDetails() async {
        let service = CloudBackupSettingsServiceSpy(
            snapshot: settingsSnapshot(state: .enabled),
            backupResult: .failed(.quotaExceeded)
        )
        let viewModel = CloudBackupSettingsViewModel(service: service)

        await viewModel.refresh()
        await viewModel.backUpNow()

        XCTAssertEqual(viewModel.statusTitle, "Enabled")
        XCTAssertEqual(
            viewModel.actionMessage,
            "Free some iCloud storage, then try again."
        )
    }

    func testViewModelRequiresCellularConfirmationWithExactProposal() async {
        let proposal = ManualCellularBackupProposal(
            id: "proposal-1",
            generationID: "generation-1",
            estimatedUploadByteCount: 5_000_000
        )
        let service = CloudBackupSettingsServiceSpy(
            snapshot: settingsSnapshot(state: .enabled),
            backupResult: .requiresCellularConfirmation(proposal)
        )
        let viewModel = CloudBackupSettingsViewModel(service: service)

        await viewModel.refresh()
        await viewModel.backUpNow()

        XCTAssertEqual(viewModel.pendingCellularProposal, proposal)
        XCTAssertEqual(viewModel.snapshot.state, .awaitingCellularConfirmation)
        XCTAssertFalse(viewModel.canBackUpNow)
    }

    func testDisablingBackupExplainsThatLatestSnapshotIsRetained() async {
        let service = CloudBackupSettingsServiceSpy(
            snapshot: settingsSnapshot(state: .enabled)
        )
        let viewModel = CloudBackupSettingsViewModel(service: service)
        await viewModel.refresh()

        await viewModel.setBackupEnabled(false)

        XCTAssertFalse(viewModel.snapshot.isEnabled)
        XCTAssertEqual(viewModel.snapshot.state, .disabled)
        XCTAssertEqual(
            viewModel.actionMessage,
            "Cloud backup is off. Your latest cloud backup is retained."
        )
    }

    private func settingsSnapshot(
        state: CloudBackupSettingsState
    ) -> CloudBackupSettingsSnapshot {
        CloudBackupSettingsSnapshot(
            isEnabled: true,
            areNotificationsEnabled: true,
            accountAvailability: .available,
            state: state,
            lastSuccessAt: nil,
            estimatedUploadByteCount: nil
        )
    }
}

private actor CloudBackupSettingsServiceSpy: CloudBackupSettingsServing {
    private var snapshot: CloudBackupSettingsSnapshot
    private let backupResult: ManualBackupResult

    init(
        snapshot: CloudBackupSettingsSnapshot,
        backupResult: ManualBackupResult = .deferred(.disabled)
    ) {
        self.snapshot = snapshot
        self.backupResult = backupResult
    }

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

    func backUpNow() async -> ManualBackupResult { backupResult }

    func confirmCellularBackup(_ proposal: ManualCellularBackupProposal) async -> ManualBackupResult {
        .deferred(.disabled)
    }

    func cancelCellularBackup(_ proposal: ManualCellularBackupProposal) async {}
}

private final class CloudBackupNotificationCenterSpy: LocalNotificationCenter {
    private(set) var authorizationRequestCount = 0
    private(set) var requests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequestCount += 1
        return true
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}

    func add(_ request: UNNotificationRequest) async throws {
        requests.append(request)
    }
}
