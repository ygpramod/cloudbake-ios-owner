import CloudKit
import XCTest
@testable import CloudBakeOwner

final class CloudKitBackupStoreTests: XCTestCase {
    func testOperationPolicyDisablesCellularUnlessExplicitlyApproved() {
        XCTAssertFalse(
            CloudKitBackupOperationPolicy.configuration(for: .wifiOnly).allowsCellularAccess
        )
        XCTAssertTrue(
            CloudKitBackupOperationPolicy.configuration(for: .cellularAllowed).allowsCellularAccess
        )
    }

    func testDevelopmentContainerPublishesAndRetriesAnonymousSnapshot() async throws {
        #if CLOUDBAKE_CLOUDKIT_SMOKE
        #if targetEnvironment(simulator)
        throw XCTSkip("The CloudKit smoke test requires a physical iPhone.")
        #else
        let fixture = try CloudKitSmokeFixture()
        defer { fixture.remove() }
        let store = CloudKitBackupStore()
        let publisher = CloudBackupPublisher(store: store)

        let firstResult = try await publisher.publish(fixture.package)
        XCTAssertEqual(firstResult.generationID, fixture.package.generationID)
        XCTAssertFalse(firstResult.wasAlreadyCurrent)
        let firstCurrentGenerationID = try await store.currentGenerationID()
        XCTAssertEqual(firstCurrentGenerationID, fixture.package.generationID)

        let retryResult = try await publisher.publish(fixture.package)
        XCTAssertEqual(retryResult.generationID, fixture.package.generationID)
        XCTAssertTrue(retryResult.wasAlreadyCurrent)
        let retryCurrentGenerationID = try await store.currentGenerationID()
        XCTAssertEqual(retryCurrentGenerationID, fixture.package.generationID)

        let inspection = try XCTUnwrap(
            try await store.inspectCurrentSnapshot(currentAppVersion: "1.0")
        )
        XCTAssertEqual(inspection.generationID, fixture.package.generationID)
        XCTAssertEqual(inspection.integrity, .verified)
        let restoreURL = fixture.root.appendingPathComponent("Restore", isDirectory: true)
        let restored = try await store.downloadCurrentSnapshot(
            inspection,
            to: restoreURL,
            transferPolicy: .wifiOnly
        )
        XCTAssertEqual(restored.manifest, fixture.package.manifest)
        XCTAssertTrue(restored.brokenAssets.isEmpty)
        XCTAssertEqual(
            try Data(contentsOf: restoreURL.appendingPathComponent("database.sqlite")),
            try Data(contentsOf: fixture.package.databaseURL)
        )
        #endif
        #else
        throw XCTSkip("Pass -DCLOUDBAKE_CLOUDKIT_SMOKE explicitly to run the device smoke test.")
        #endif
    }

    func testCloudKitErrorsMapToOwnerSafeCategories() {
        let cases: [(CKError.Code, CloudBackupErrorCategory)] = [
            (.notAuthenticated, .authenticationRequired),
            (.accountTemporarilyUnavailable, .iCloudUnavailable),
            (.networkUnavailable, .networkUnavailable),
            (.networkFailure, .networkUnavailable),
            (.quotaExceeded, .quotaExceeded),
            (.permissionFailure, .permissionDenied),
            (.managedAccountRestricted, .permissionDenied),
            (.serverRecordChanged, .conflict),
            (.assetFileModified, .conflict),
            (.operationCancelled, .cancelled),
            (.serviceUnavailable, .temporarilyUnavailable),
            (.requestRateLimited, .temporarilyUnavailable),
            (.zoneBusy, .temporarilyUnavailable),
            (.unknownItem, .corruptRemoteData)
        ]

        for (code, expectedCategory) in cases {
            XCTAssertEqual(
                CloudKitBackupErrorMapper.category(for: CKError(code)),
                expectedCategory,
                "Unexpected mapping for \(code)"
            )
        }
    }

    func testPartialFailureSelectsDeterministicActionableCategory() {
        let partialFailure = NSError(
            domain: CKErrorDomain,
            code: CKError.partialFailure.rawValue,
            userInfo: [
                CKPartialErrorsByItemIDKey: [
                    "network": CKError(.networkFailure),
                    "account": CKError(.notAuthenticated)
                ]
            ]
        )

        XCTAssertEqual(
            CloudKitBackupErrorMapper.category(for: partialFailure),
            .authenticationRequired
        )
    }

    func testMappedErrorNeverExposesUnsafeOperationIdentifier() {
        let error = CloudKitBackupErrorMapper.storeError(
            CKError(.networkFailure),
            operationID: "customer@example.com"
        )

        XCTAssertEqual(error.category, .networkUnavailable)
        XCTAssertEqual(error.operationID, "operation")
    }

    func testCancellationMapsWithoutCloudKitError() {
        XCTAssertEqual(
            CloudKitBackupErrorMapper.category(for: CancellationError()),
            .cancelled
        )
    }

    func testLargeBackupIsSplitWithinCloudKitOperationLimits() {
        let fileCount = 2_002
        let values = Array(0..<fileCount)

        let fetchChunks = CloudKitBackupBatching.chunks(
            values,
            maximumCount: CloudKitBackupStore.recordFetchLimit
        )
        XCTAssertEqual(fetchChunks.flatMap(Array.init), values)
        XCTAssertTrue(fetchChunks.allSatisfy { $0.count <= 400 })
        XCTAssertEqual(fetchChunks.count, 6)
    }

    func testRestorePlanDerivesDeterministicRecordNamesWithoutLocalPaths() throws {
        let manifest = BackupManifest(
            databaseSchemaVersion: "0027_add_order_ingredient_costs",
            minimumCompatibleAppVersion: "1.0",
            generationID: "generation-1",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            database: BackupFileDescriptor(
                relativePath: "database.sqlite",
                byteCount: 20,
                sha256: "database-checksum"
            ),
            assets: [
                BackupAssetDescriptor(
                    originalRelativePath: "OrderPhotos/cake.jpg",
                    file: BackupFileDescriptor(
                        relativePath: "Assets/opaque.asset",
                        byteCount: 30,
                        sha256: "asset-checksum"
                    )
                )
            ]
        )
        let manifestFile = CloudRestoreFilePlan(
            recordName: "generation-1-manifest",
            role: .manifest,
            relativePath: "manifest.json",
            byteCount: 10,
            sha256: "manifest-checksum",
            originalAssetPath: nil
        )

        let files = try CloudRestoreFilePlan.make(
            manifest: manifest,
            manifestFile: manifestFile
        )

        XCTAssertEqual(
            files.map(\.recordName),
            ["generation-1-manifest", "generation-1-database", "generation-1-asset-000000"]
        )
        XCTAssertEqual(files.last?.originalAssetPath, "OrderPhotos/cake.jpg")
        XCTAssertEqual(CloudRestoreFilePlan.totalByteCount(files), 60)
    }
}

#if CLOUDBAKE_CLOUDKIT_SMOKE
private final class CloudKitSmokeFixture: @unchecked Sendable {
    let root: URL
    let package: AppSnapshotPackage

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let databaseURL = root.appendingPathComponent(AppSnapshotService.databaseFilename)
        let assetRelativePath = "Assets/anonymous-smoke.asset"
        let assetURL = root.appendingPathComponent(assetRelativePath)
        try FileManager.default.createDirectory(
            at: assetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let databaseData = Data("anonymous-cloudkit-smoke-database".utf8)
        let assetData = Data("anonymous-cloudkit-smoke-asset".utf8)
        try databaseData.write(to: databaseURL)
        try assetData.write(to: assetURL)

        let generationID = "smoke-\(UUID().uuidString.lowercased())"
        let manifest = BackupManifest(
            databaseSchemaVersion: "cloudkit-smoke",
            minimumCompatibleAppVersion: "1.0",
            generationID: generationID,
            createdAt: Date(
                timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down)
            ),
            database: BackupFileDescriptor(
                relativePath: AppSnapshotService.databaseFilename,
                byteCount: Int64(databaseData.count),
                sha256: BackupChecksum.sha256(of: databaseData)
            ),
            assets: [
                BackupAssetDescriptor(
                    originalRelativePath: "RecoveredPhotos/anonymous-smoke.asset",
                    file: BackupFileDescriptor(
                        relativePath: assetRelativePath,
                        byteCount: Int64(assetData.count),
                        sha256: BackupChecksum.sha256(of: assetData)
                    )
                )
            ]
        )
        let manifestURL = root.appendingPathComponent(AppSnapshotService.manifestFilename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL)
        package = AppSnapshotPackage(
            generationID: generationID,
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
#endif
