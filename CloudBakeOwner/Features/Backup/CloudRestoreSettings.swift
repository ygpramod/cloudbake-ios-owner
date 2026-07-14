import Combine
import Foundation

protocol CloudRestoreSettingsServing: Sendable {
    func inspectRestore() async -> RestoreResult
    func proceedRestore(proposalID: String, approval: RestoreApproval) async -> RestoreResult
    func cancelRestore(proposalID: String) async
}

enum CloudRestorePrompt: Equatable {
    case restore(RestoreProposal)
    case replace(RestoreProposal)
    case cellular(RestoreProposal)
    case brokenAssets(BrokenRestoreAssetProposal)

    var proposalID: String {
        switch self {
        case .restore(let proposal), .replace(let proposal), .cellular(let proposal):
            proposal.id
        case .brokenAssets(let proposal):
            proposal.restoreProposalID
        }
    }
}

@MainActor
final class CloudRestoreSettingsViewModel: ObservableObject {
    @Published private(set) var prompt: CloudRestorePrompt?
    @Published private(set) var actionMessage: String?
    @Published private(set) var isWorking = false
    @Published private(set) var didChooseStartFresh = false
    @Published private(set) var didCompleteRestore = false

    private let service: any CloudRestoreSettingsServing

    init(service: any CloudRestoreSettingsServing) {
        self.service = service
    }

    @discardableResult
    func inspect() async -> Bool {
        isWorking = true
        actionMessage = nil
        defer { isWorking = false }
        let result = await service.inspectRestore()
        handle(result)
        return prompt != nil
    }

    func startRestore() async {
        guard case .restore(let proposal) = prompt else { return }
        await proceed(proposal: proposal, approval: .start)
    }

    func confirmReplacement() async {
        guard case .replace(let proposal) = prompt else { return }
        await proceed(proposal: proposal, approval: .replaceExistingData)
    }

    func confirmCellular() async {
        guard case .cellular(let proposal) = prompt else { return }
        await proceed(
            proposal: proposal,
            approval: .useCellular(displayedByteCount: proposal.snapshot.totalByteCount)
        )
    }

    func resolveBrokenAssets(_ decision: BrokenRestoreAssetDecision) async {
        guard case .brokenAssets(let brokenProposal) = prompt else { return }
        isWorking = true
        let result = await service.proceedRestore(
            proposalID: brokenProposal.restoreProposalID,
            approval: .brokenAssets(decision)
        )
        isWorking = false
        handle(result)
    }

    func cancel() async {
        guard let prompt else { return }
        self.prompt = nil
        await service.cancelRestore(proposalID: prompt.proposalID)
    }

    func startFresh() async {
        guard let prompt else { return }
        self.prompt = nil
        await service.cancelRestore(proposalID: prompt.proposalID)
        didChooseStartFresh = true
        actionMessage = "Starting fresh. Your cloud backup was not changed."
    }

    private func proceed(proposal: RestoreProposal, approval: RestoreApproval) async {
        isWorking = true
        let result = await service.proceedRestore(proposalID: proposal.id, approval: approval)
        isWorking = false
        handle(result)
    }

    private func handle(_ result: RestoreResult) {
        switch result {
        case .ready(let proposal):
            prompt = .restore(proposal)
        case .requiresReplacementConfirmation(let proposal):
            prompt = .replace(proposal)
        case .requiresCellularConfirmation(let proposal):
            prompt = .cellular(proposal)
        case .requiresBrokenAssetDecision(let proposal):
            prompt = .brokenAssets(proposal)
        case .completed:
            prompt = nil
            didCompleteRestore = true
            actionMessage = "Cloud backup restored successfully."
        case .noBackup:
            prompt = nil
            actionMessage = "No cloud backup is available for this iCloud account."
        case .busy:
            prompt = nil
            actionMessage = "Another backup or restore is already in progress."
        case .invalidApproval:
            actionMessage = "That confirmation could not be applied. Please retry or cancel."
        case .failed(let failure):
            prompt = nil
            actionMessage = Self.message(for: failure)
        }
    }

    private static func message(for failure: RestoreFailure) -> String {
        switch failure.category {
        case .iCloudUnavailable:
            "Cloud restore is unavailable. Check your iCloud sign-in."
        case .networkUnavailable:
            "Cloud restore needs an internet connection."
        case .noBackup:
            "No cloud backup is available for this iCloud account."
        case .updateRequired(let minimumVersion):
            "Update CloudBake to version \(minimumVersion) or later before restoring this backup."
        case .unsupportedFormat:
            "This backup format is not supported by this version of CloudBake."
        case .corruptBackup:
            "The cloud backup could not be validated. Your local data was not changed."
        case .insufficientStorage:
            "Free some iPhone storage before restoring this backup."
        case .migrationFailed:
            "The backup could not be upgraded safely. Your local data was not changed."
        case .activationFailed, .verificationFailed:
            failure.didRollBack
                ? "Restore failed, and CloudBake returned to your previous local data."
                : "Restore failed. Reopen CloudBake to complete recovery before making changes."
        case .cancelled:
            "Restore was cancelled. Your local data was not changed."
        case .unknown:
            "CloudBake could not restore this backup. Your local data was not changed."
        }
    }
}

struct UnavailableCloudRestoreSettingsService: CloudRestoreSettingsServing {
    func inspectRestore() async -> RestoreResult {
        .failed(RestoreFailure(category: .iCloudUnavailable, didRollBack: false))
    }

    func proceedRestore(proposalID: String, approval: RestoreApproval) async -> RestoreResult {
        .failed(RestoreFailure(category: .iCloudUnavailable, didRollBack: false))
    }

    func cancelRestore(proposalID: String) async {}
}

#if DEBUG
actor CloudRestoreSettingsUITestService: CloudRestoreSettingsServing {
    private let snapshot = CloudRestoreSnapshot(
        generationID: "ui-restore-generation",
        createdAt: Date(timeIntervalSince1970: 1_788_739_200),
        totalByteCount: 4_000_000,
        assetCount: 12,
        compatibility: .compatible,
        integrity: .verified
    )
    private var replacementApproved = false
    private var cellularApproved = false

    func inspectRestore() async -> RestoreResult {
        let proposal = makeProposal()
        switch ProcessInfo.processInfo.environment["CLOUDBAKE_TEST_CLOUD_RESTORE_FAILURE"] {
        case "update-required":
            return .failed(
                RestoreFailure(
                    category: .updateRequired(minimumVersion: "2.0"),
                    didRollBack: false
                )
            )
        default:
            break
        }
        if ProcessInfo.processInfo.environment["CLOUDBAKE_TEST_EMPTY_RESTORE"] == "1" {
            return .ready(proposal)
        }
        return .requiresReplacementConfirmation(proposal)
    }

    func proceedRestore(proposalID: String, approval: RestoreApproval) async -> RestoreResult {
        guard proposalID == "ui-restore-proposal" else { return .invalidApproval }
        switch approval {
        case .start:
            return .completed
        case .replaceExistingData:
            if ProcessInfo.processInfo.environment["CLOUDBAKE_TEST_CLOUD_RESTORE_FAILURE"] == "rollback" {
                return .failed(
                    RestoreFailure(category: .activationFailed, didRollBack: true)
                )
            }
            replacementApproved = true
            return .requiresCellularConfirmation(makeProposal())
        case .useCellular(let byteCount):
            guard replacementApproved, byteCount == snapshot.totalByteCount else {
                return .invalidApproval
            }
            cellularApproved = true
            return .requiresBrokenAssetDecision(
                BrokenRestoreAssetProposal(
                    restoreProposalID: proposalID,
                    assets: [BrokenRestoreAsset(originalRelativePath: "OrderPhotos/missing.jpg")]
                )
            )
        case .brokenAssets:
            return cellularApproved ? .completed : .invalidApproval
        }
    }

    func cancelRestore(proposalID: String) async {}

    private func makeProposal() -> RestoreProposal {
        RestoreProposal(
            id: "ui-restore-proposal",
            snapshot: snapshot,
            replacesExistingData: ProcessInfo.processInfo.environment["CLOUDBAKE_TEST_EMPTY_RESTORE"] != "1"
        )
    }
}
#endif
