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
        XCTAssertEqual(
            policy.result(for: ManualBackupResult.failed(.quotaExceeded)),
            .failed(.quotaExceeded)
        )
        XCTAssertNil(policy.result(for: ManualBackupResult.failed(.cancelled)))
    }

    func testNotificationDispatcherSuppressesIntentionalManualCancellation() async {
        let sender = CloudBackupNotificationSenderSpy()
        let dispatcher = CloudBackupNotificationDispatcher(sender: sender)

        await dispatcher.send(for: ManualBackupResult.failed(.cancelled))
        await dispatcher.send(for: ManualBackupResult.failed(.quotaExceeded))

        let deliveredResults = await sender.deliveredResults
        XCTAssertEqual(deliveredResults, [.failed(.quotaExceeded)])
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

    func testViewModelPresentsVerificationAsDistinctActiveStatus() async {
        let service = CloudBackupSettingsServiceSpy(
            snapshot: settingsSnapshot(state: .verifying)
        )
        let viewModel = CloudBackupSettingsViewModel(service: service)

        await viewModel.refresh()

        XCTAssertEqual(viewModel.statusTitle, "Verifying")
        XCTAssertEqual(
            viewModel.statusGuidance,
            "Verifying the uploaded recovery snapshot before making it current."
        )
        XCTAssertTrue(viewModel.isBusy)
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

        viewModel.setBackupEnabled(false)

        XCTAssertFalse(viewModel.snapshot.isEnabled)
        XCTAssertEqual(viewModel.snapshot.state, .disabled)
        XCTAssertEqual(
            viewModel.actionMessage,
            "Cloud backup is off. Your latest cloud backup is retained."
        )
    }

    func testDisablingNotificationsUpdatesVisibleStateImmediately() async {
        let service = CloudBackupSettingsServiceSpy(
            snapshot: settingsSnapshot(state: .enabled)
        )
        let viewModel = CloudBackupSettingsViewModel(service: service)
        await viewModel.refresh()

        viewModel.setNotificationsEnabled(false)

        XCTAssertFalse(viewModel.snapshot.areNotificationsEnabled)
    }

    func testRapidBackupPreferenceChangesPersistLatestChoiceInOrder() async {
        let service = DelayedCloudBackupSettingsServiceSpy(
            snapshot: settingsSnapshot(state: .enabled)
        )
        let viewModel = CloudBackupSettingsViewModel(service: service)
        await viewModel.refresh()

        viewModel.setBackupEnabled(false)
        await service.waitForBackupCallCount(1)
        viewModel.setBackupEnabled(true)
        await Task.yield()
        let callCountBeforeRelease = await service.backupCallCount()
        XCTAssertEqual(callCountBeforeRelease, 1)
        await service.releaseBackupCall(false)
        await service.waitForBackupCallCount(2)
        await service.releaseBackupCall(true)
        await service.waitForBackupCompletionCount(2)

        let persisted = await service.currentSettings()
        let persistedValues = await service.backupValues
        XCTAssertTrue(persisted.isEnabled)
        XCTAssertEqual(persistedValues, [false, true])
        XCTAssertTrue(viewModel.snapshot.isEnabled)
    }

    func testRapidNotificationPreferenceChangesPersistLatestChoiceInOrder() async {
        let service = DelayedCloudBackupSettingsServiceSpy(
            snapshot: settingsSnapshot(state: .enabled)
        )
        let viewModel = CloudBackupSettingsViewModel(service: service)
        await viewModel.refresh()

        viewModel.setNotificationsEnabled(false)
        await service.waitForNotificationCallCount(1)
        viewModel.setNotificationsEnabled(true)
        await Task.yield()
        let callCountBeforeRelease = await service.notificationCallCount()
        XCTAssertEqual(callCountBeforeRelease, 1)
        await service.releaseNotificationCall(false)
        await service.waitForNotificationCallCount(2)
        await service.releaseNotificationCall(true)
        await service.waitForNotificationCompletionCount(2)

        let persisted = await service.currentSettings()
        let persistedValues = await service.notificationValues
        XCTAssertTrue(persisted.areNotificationsEnabled)
        XCTAssertEqual(persistedValues, [false, true])
        XCTAssertTrue(viewModel.snapshot.areNotificationsEnabled)
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

private actor DelayedCloudBackupSettingsServiceSpy: CloudBackupSettingsServing {
    private var snapshot: CloudBackupSettingsSnapshot
    private var backupCalls: [Bool] = []
    private var notificationCalls: [Bool] = []
    private var backupCompletions = 0
    private var notificationCompletions = 0
    private var backupCallWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var notificationCallWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var backupCompletionWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var notificationCompletionWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var backupReleasePermits: [Bool: Int] = [:]
    private var notificationReleasePermits: [Bool: Int] = [:]
    private var backupReleaseWaiters: [Bool: [CheckedContinuation<Void, Never>]] = [:]
    private var notificationReleaseWaiters: [Bool: [CheckedContinuation<Void, Never>]] = [:]

    init(snapshot: CloudBackupSettingsSnapshot) {
        self.snapshot = snapshot
    }

    var backupValues: [Bool] { backupCalls }
    var notificationValues: [Bool] { notificationCalls }
    func backupCallCount() -> Int { backupCalls.count }
    func notificationCallCount() -> Int { notificationCalls.count }

    func currentSettings() async -> CloudBackupSettingsSnapshot { snapshot }

    func setBackupEnabled(_ isEnabled: Bool) async -> CloudBackupSettingsSnapshot {
        backupCalls.append(isEnabled)
        resumeSatisfiedWaiters(&backupCallWaiters, currentCount: backupCalls.count)
        await waitForBackupRelease(isEnabled)
        snapshot.isEnabled = isEnabled
        snapshot.state = isEnabled ? .enabled : .disabled
        backupCompletions += 1
        resumeSatisfiedWaiters(&backupCompletionWaiters, currentCount: backupCompletions)
        return snapshot
    }

    func setNotificationsEnabled(_ isEnabled: Bool) async -> CloudBackupSettingsSnapshot {
        notificationCalls.append(isEnabled)
        resumeSatisfiedWaiters(&notificationCallWaiters, currentCount: notificationCalls.count)
        await waitForNotificationRelease(isEnabled)
        snapshot.areNotificationsEnabled = isEnabled
        notificationCompletions += 1
        resumeSatisfiedWaiters(
            &notificationCompletionWaiters,
            currentCount: notificationCompletions
        )
        return snapshot
    }

    func waitForBackupCallCount(_ count: Int) async {
        guard backupCalls.count < count else { return }
        await withCheckedContinuation { continuation in
            backupCallWaiters.append((count, continuation))
        }
    }

    func waitForNotificationCallCount(_ count: Int) async {
        guard notificationCalls.count < count else { return }
        await withCheckedContinuation { continuation in
            notificationCallWaiters.append((count, continuation))
        }
    }

    func waitForBackupCompletionCount(_ count: Int) async {
        guard backupCompletions < count else { return }
        await withCheckedContinuation { continuation in
            backupCompletionWaiters.append((count, continuation))
        }
    }

    func waitForNotificationCompletionCount(_ count: Int) async {
        guard notificationCompletions < count else { return }
        await withCheckedContinuation { continuation in
            notificationCompletionWaiters.append((count, continuation))
        }
    }

    func releaseBackupCall(_ value: Bool) {
        release(value, permits: &backupReleasePermits, waiters: &backupReleaseWaiters)
    }

    func releaseNotificationCall(_ value: Bool) {
        release(
            value,
            permits: &notificationReleasePermits,
            waiters: &notificationReleaseWaiters
        )
    }

    func backUpNow() async -> ManualBackupResult { .deferred(.disabled) }

    func confirmCellularBackup(_ proposal: ManualCellularBackupProposal) async -> ManualBackupResult {
        .deferred(.disabled)
    }

    func cancelCellularBackup(_ proposal: ManualCellularBackupProposal) async {}

    private func resumeSatisfiedWaiters(
        _ waiters: inout [(count: Int, continuation: CheckedContinuation<Void, Never>)],
        currentCount: Int
    ) {
        let satisfied = waiters.filter { $0.count <= currentCount }
        waiters.removeAll { $0.count <= currentCount }
        satisfied.forEach { $0.continuation.resume() }
    }

    private func waitForBackupRelease(_ value: Bool) async {
        if backupReleasePermits[value, default: 0] > 0 {
            backupReleasePermits[value, default: 0] -= 1
            return
        }
        await withCheckedContinuation { continuation in
            backupReleaseWaiters[value, default: []].append(continuation)
        }
    }

    private func waitForNotificationRelease(_ value: Bool) async {
        if notificationReleasePermits[value, default: 0] > 0 {
            notificationReleasePermits[value, default: 0] -= 1
            return
        }
        await withCheckedContinuation { continuation in
            notificationReleaseWaiters[value, default: []].append(continuation)
        }
    }

    private func release(
        _ value: Bool,
        permits: inout [Bool: Int],
        waiters: inout [Bool: [CheckedContinuation<Void, Never>]]
    ) {
        if let continuation = waiters[value]?.first {
            waiters[value]?.removeFirst()
            continuation.resume()
        } else {
            permits[value, default: 0] += 1
        }
    }
}

private actor CloudBackupNotificationSenderSpy: CloudBackupNotificationSending {
    private(set) var deliveredResults: [CloudBackupNotificationResult] = []

    func send(for result: CloudBackupNotificationResult) async {
        deliveredResults.append(result)
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
