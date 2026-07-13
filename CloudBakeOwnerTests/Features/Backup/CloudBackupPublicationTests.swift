import Foundation
import XCTest
@testable import CloudBakeOwner

final class CloudBackupPublicationTests: XCTestCase {
    func testPublisherAppliesExplicitTransferPolicy() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.remove() }
        let store = FakeCloudBackupStore(
            currentGenerationID: nil,
            generationIDs: []
        )

        _ = try await CloudBackupPublisher(store: store).publish(
            fixture.package,
            transferPolicy: .cellularAllowed
        )

        let policy = await store.configuredTransferPolicy()
        XCTAssertEqual(policy, .cellularAllowed)
    }

    func testUploadPlanUsesOpaqueDeterministicRecordsAndVerifiedFiles() throws {
        let fixture = try PublicationFixture()
        defer { fixture.remove() }

        let plan = try CloudBackupGenerationPlan.make(package: fixture.package)

        XCTAssertEqual(plan.generationID, "generation-new")
        XCTAssertEqual(plan.payloadByteCount, 14)
        XCTAssertEqual(plan.files.map(\.role), [.manifest, .database, .asset])
        XCTAssertEqual(
            plan.files.map(\.recordName),
            [
                "generation-new-manifest",
                "generation-new-database",
                "generation-new-asset-000000"
            ]
        )
        XCTAssertFalse(plan.files[2].recordName.contains("customer"))
        XCTAssertEqual(plan.uploadByteCount, plan.files.reduce(0) { $0 + $1.byteCount })
    }

    func testUploadPlanRejectsManifestThatChangedAfterSnapshotValidation() throws {
        let fixture = try PublicationFixture()
        defer { fixture.remove() }
        try Data("{}".utf8).write(to: fixture.package.manifestURL)

        XCTAssertThrowsError(try CloudBackupGenerationPlan.make(package: fixture.package)) { error in
            XCTAssertEqual(error as? CloudBackupPlanError, .manifestMismatch)
        }
    }

    func testSuccessfulPublicationReplacesPointerAndRemovesOtherGenerations() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.remove() }
        let store = FakeCloudBackupStore(
            currentGenerationID: "generation-old",
            generationIDs: ["generation-old", "generation-abandoned"]
        )

        let result = try await CloudBackupPublisher(store: store).publish(fixture.package)

        XCTAssertEqual(
            result,
            CloudBackupPublicationResult(
                generationID: "generation-new",
                replacedGenerationID: "generation-old",
                wasAlreadyCurrent: false,
                cleanupPending: false
            )
        )
        let currentGeneration = await store.current()
        let generationIDs = await store.allGenerationIDs()
        let isComplete = await store.isGenerationComplete("generation-new")
        XCTAssertEqual(currentGeneration, "generation-new")
        XCTAssertEqual(generationIDs, ["generation-new"])
        XCTAssertTrue(isComplete)
    }

    func testPartialAttemptIsRemovedBeforeIdempotentRetry() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.remove() }
        let store = FakeCloudBackupStore(
            currentGenerationID: "generation-old",
            generationIDs: ["generation-old", "generation-new"],
            partialGenerationID: "generation-new"
        )

        _ = try await CloudBackupPublisher(store: store).publish(fixture.package)

        let currentGeneration = await store.current()
        let events = await store.events()
        let isComplete = await store.isGenerationComplete("generation-new")
        XCTAssertEqual(currentGeneration, "generation-new")
        XCTAssertTrue(events.contains("delete:generation-new"))
        XCTAssertTrue(isComplete)
    }

    func testAlreadyCurrentGenerationVerifiesWithoutUploadingAgain() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.remove() }
        let plan = try CloudBackupGenerationPlan.make(package: fixture.package)
        let store = FakeCloudBackupStore(
            currentGenerationID: "generation-new",
            completePlan: plan,
            generationIDs: ["generation-new", "generation-old"]
        )

        let result = try await CloudBackupPublisher(store: store).publish(fixture.package)

        XCTAssertTrue(result.wasAlreadyCurrent)
        let events = await store.events()
        let generationIDs = await store.allGenerationIDs()
        XCTAssertFalse(events.contains(where: { $0.hasPrefix("upload:") }))
        XCTAssertEqual(generationIDs, ["generation-new"])
    }

    func testEveryPrepublicationFailurePreservesPreviousPointer() async throws {
        let failurePoints: [FakeCloudBackupStore.FailurePoint] = [
            .readPointer,
            .deleteGeneration("generation-new"),
            .prepare,
            .upload,
            .verify,
            .publish
        ]

        for failurePoint in failurePoints {
            let fixture = try PublicationFixture()
            defer { fixture.remove() }
            let store = FakeCloudBackupStore(
                currentGenerationID: "generation-old",
                generationIDs: ["generation-old", "generation-new"],
                partialGenerationID: "generation-new",
                failurePoint: failurePoint
            )

            do {
                _ = try await CloudBackupPublisher(store: store).publish(fixture.package)
                XCTFail("Expected failure at \(failurePoint)")
            } catch {
                let currentGeneration = await store.current()
                XCTAssertEqual(
                    currentGeneration,
                    "generation-old",
                    "Pointer changed after failure at \(failurePoint)"
                )
            }
        }
    }

    func testPublicationGateClosingAfterVerificationPreservesPreviousPointer() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.remove() }
        let store = FakeCloudBackupStore(
            currentGenerationID: "generation-old",
            generationIDs: ["generation-old"]
        )

        do {
            _ = try await CloudBackupPublisher(store: store).publish(
                fixture.package,
                transferPolicy: .wifiOnly,
                publicationGate: {
                    let events = await store.events()
                    return !events.contains("verify:generation-new")
                }
            )
            XCTFail("Expected publication authorization to close before pointer replacement")
        } catch let error as CloudBackupPublicationError {
            XCTAssertEqual(error, .publicationNotAuthorized)
        }

        let currentGeneration = await store.current()
        let events = await store.events()
        XCTAssertEqual(currentGeneration, "generation-old")
        XCTAssertFalse(events.contains("publish:generation-new"))
    }

    func testAbandonedGenerationEnumerationFailureDoesNotBlockPublication() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.remove() }
        let store = FakeCloudBackupStore(
            currentGenerationID: "generation-old",
            generationIDs: ["generation-old"],
            failurePoint: .listGenerations
        )

        let result = try await CloudBackupPublisher(store: store).publish(fixture.package)

        XCTAssertEqual(result.generationID, "generation-new")
        XCTAssertTrue(result.cleanupPending)
        let currentGeneration = await store.current()
        XCTAssertEqual(currentGeneration, "generation-new")
    }

    func testPointerConflictCannotOverwriteConcurrentPublication() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.remove() }
        let store = FakeCloudBackupStore(
            currentGenerationID: "generation-old",
            generationIDs: ["generation-old"],
            replacePointerBeforePublishWith: "generation-concurrent"
        )

        do {
            _ = try await CloudBackupPublisher(store: store).publish(fixture.package)
            XCTFail("Expected pointer precondition conflict")
        } catch let error as CloudBackupStoreError {
            XCTAssertEqual(error.category, .conflict)
        }
        let currentGeneration = await store.current()
        XCTAssertEqual(currentGeneration, "generation-concurrent")
    }

    func testCleanupFailureAfterPublicationReportsPendingWithoutLosingNewPointer() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.remove() }
        let store = FakeCloudBackupStore(
            currentGenerationID: "generation-old",
            generationIDs: ["generation-old"],
            failurePoint: .deleteGeneration("generation-old")
        )

        let result = try await CloudBackupPublisher(store: store).publish(fixture.package)

        XCTAssertTrue(result.cleanupPending)
        let currentGeneration = await store.current()
        let generationIDs = await store.allGenerationIDs()
        XCTAssertEqual(currentGeneration, "generation-new")
        XCTAssertEqual(generationIDs, ["generation-new", "generation-old"])
    }

    func testCancellationLeavesPointerUntouchedAndRetryReplacesPartialGeneration() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.remove() }
        let store = FakeCloudBackupStore(
            currentGenerationID: "generation-old",
            generationIDs: ["generation-old"],
            suspendUpload: true
        )
        let publisher = CloudBackupPublisher(store: store)
        let publication = Task {
            try await publisher.publish(fixture.package)
        }
        try await waitForUpload(in: store)

        publication.cancel()
        do {
            _ = try await publication.value
            XCTFail("Expected publication cancellation")
        } catch is CancellationError {
            // Expected.
        }
        let currentAfterCancellation = await store.current()
        XCTAssertEqual(currentAfterCancellation, "generation-old")

        await store.allowUploads()
        let retryResult = try await publisher.publish(fixture.package)

        XCTAssertEqual(retryResult.generationID, "generation-new")
        let currentAfterRetry = await store.current()
        let events = await store.events()
        XCTAssertEqual(currentAfterRetry, "generation-new")
        XCTAssertTrue(events.contains("delete:generation-new"))
    }

    private func waitForUpload(in store: FakeCloudBackupStore) async throws {
        for _ in 0..<100 {
            if await store.events().contains(where: { $0.hasPrefix("upload:") }) {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Publication did not reach upload phase")
    }
}

private final class PublicationFixture: @unchecked Sendable {
    let root: URL
    let package: AppSnapshotPackage

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let databaseURL = root.appendingPathComponent("database.sqlite")
        let assetRelativePath = "Assets/opaque.asset"
        let assetURL = root.appendingPathComponent(assetRelativePath)
        try FileManager.default.createDirectory(
            at: assetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let databaseData = Data("database".utf8)
        let assetData = Data("asset!".utf8)
        try databaseData.write(to: databaseURL)
        try assetData.write(to: assetURL)
        let manifest = BackupManifest(
            databaseSchemaVersion: "0027_add_order_ingredient_costs",
            minimumCompatibleAppVersion: "1.0",
            generationID: "generation-new",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            database: BackupFileDescriptor(
                relativePath: "database.sqlite",
                byteCount: Int64(databaseData.count),
                sha256: BackupChecksum.sha256(of: databaseData)
            ),
            assets: [
                BackupAssetDescriptor(
                    originalRelativePath: "RecoveredPhotos/opaque.jpg",
                    file: BackupFileDescriptor(
                        relativePath: assetRelativePath,
                        byteCount: Int64(assetData.count),
                        sha256: BackupChecksum.sha256(of: assetData)
                    )
                )
            ]
        )
        let manifestURL = root.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL)
        package = AppSnapshotPackage(
            generationID: manifest.generationID,
            directoryURL: root,
            manifestURL: manifestURL,
            databaseURL: databaseURL,
            manifest: manifest
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private actor FakeCloudBackupStore: CloudBackupStoring {
    enum FailurePoint: Equatable {
        case readPointer
        case listGenerations
        case deleteGeneration(String)
        case prepare
        case upload
        case verify
        case publish

    }

    private struct Generation {
        var plan: CloudBackupGenerationPlan?
        var uploadedRecordNames: Set<String>
    }

    private var pointer: String?
    private var generations: [String: Generation]
    private let failurePoint: FailurePoint?
    private let replacePointerBeforePublishWith: String?
    private var shouldSuspendUpload: Bool
    private var eventLog: [String] = []
    private var transferPolicy = CloudBackupTransferPolicy.wifiOnly

    init(
        currentGenerationID: String?,
        completePlan: CloudBackupGenerationPlan? = nil,
        generationIDs: Set<String>,
        partialGenerationID: String? = nil,
        failurePoint: FailurePoint? = nil,
        replacePointerBeforePublishWith: String? = nil,
        suspendUpload: Bool = false
    ) {
        pointer = currentGenerationID
        self.failurePoint = failurePoint
        self.replacePointerBeforePublishWith = replacePointerBeforePublishWith
        shouldSuspendUpload = suspendUpload
        generations = Dictionary(uniqueKeysWithValues: generationIDs.map {
            ($0, Generation(plan: nil, uploadedRecordNames: []))
        })
        if let completePlan {
            generations[completePlan.generationID] = Generation(
                plan: completePlan,
                uploadedRecordNames: Set(completePlan.files.map(\.recordName))
            )
        }
        if let partialGenerationID {
            generations[partialGenerationID] = Generation(
                plan: nil,
                uploadedRecordNames: ["partial"]
            )
        }
    }

    func configureTransferPolicy(_ policy: CloudBackupTransferPolicy) {
        transferPolicy = policy
    }

    func configuredTransferPolicy() -> CloudBackupTransferPolicy {
        transferPolicy
    }

    func currentGenerationID() async throws -> String? {
        try failIfNeeded(.readPointer)
        eventLog.append("pointer:read")
        return pointer
    }

    func generationIDs() async throws -> Set<String> {
        try failIfNeeded(.listGenerations)
        eventLog.append("generations:list")
        return Set(generations.keys)
    }

    func prepareGeneration(_ plan: CloudBackupGenerationPlan) async throws {
        try failIfNeeded(.prepare)
        eventLog.append("prepare:\(plan.generationID)")
        generations[plan.generationID] = Generation(plan: plan, uploadedRecordNames: [])
    }

    func uploadFile(_ file: CloudBackupFileUpload, generationID: String) async throws {
        try failIfNeeded(.upload)
        eventLog.append("upload:\(file.recordName)")
        if shouldSuspendUpload {
            try await Task.sleep(nanoseconds: 30_000_000_000)
        }
        generations[generationID]?.uploadedRecordNames.insert(file.recordName)
    }

    func verifyGeneration(_ plan: CloudBackupGenerationPlan) async throws {
        try failIfNeeded(.verify)
        eventLog.append("verify:\(plan.generationID)")
        guard let generation = generations[plan.generationID],
              generation.plan == plan,
              generation.uploadedRecordNames == Set(plan.files.map(\.recordName)) else {
            throw CloudBackupStoreError(category: .corruptRemoteData, operationID: "verify")
        }
    }

    func publishCurrentGeneration(
        _ generationID: String,
        replacing expectedGenerationID: String?
    ) async throws {
        try failIfNeeded(.publish)
        if let replacePointerBeforePublishWith {
            pointer = replacePointerBeforePublishWith
        }
        guard pointer == expectedGenerationID else {
            throw CloudBackupStoreError(category: .conflict, operationID: "publish")
        }
        eventLog.append("publish:\(generationID)")
        pointer = generationID
    }

    func deleteGenerationIfNotCurrent(_ generationID: String) async throws -> Bool {
        try failIfNeeded(.deleteGeneration(generationID))
        guard pointer != generationID else { return false }
        eventLog.append("delete:\(generationID)")
        generations[generationID] = nil
        return true
    }

    func current() -> String? { pointer }
    func allGenerationIDs() -> Set<String> { Set(generations.keys) }
    func events() -> [String] { eventLog }

    func allowUploads() {
        shouldSuspendUpload = false
    }

    func isGenerationComplete(_ generationID: String) -> Bool {
        guard let generation = generations[generationID], let plan = generation.plan else {
            return false
        }
        return generation.uploadedRecordNames == Set(plan.files.map(\.recordName))
    }

    private func failIfNeeded(_ point: FailurePoint) throws {
        guard failurePoint == point else { return }
        throw CloudBackupStoreError(category: .temporarilyUnavailable, operationID: "injected")
    }
}
