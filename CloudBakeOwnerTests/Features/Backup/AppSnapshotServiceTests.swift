import Foundation
import GRDB
import XCTest

@testable import CloudBakeOwner

final class AppSnapshotServiceTests: XCTestCase {
    func testSnapshotCapturesConsistentDatabaseAndManagedAssets() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let repository = fixture.database.makeCoreDataRepository()
        try fixture.write(Data("design".utf8), to: "OrderPhotos/design.jpg")
        try fixture.write(Data("logo".utf8), to: "Branding/custom-logo.jpg")
        try repository.save(fixture.design(id: "captured", photoReference: "OrderPhotos/design.jpg"))
        try repository.save(fixture.design(id: "external", photoReference: "photos://asset-id"))
        let completedAt = Date(timeIntervalSince1970: 1_800_000_100)
        let reminderOrder = fixture.order(
            id: "captured-reminder-order",
            status: .completed,
            completedAt: completedAt,
            cakeSpecification: OrderCakeSpecification(
                occasion: "Birthday",
                servings: 28,
                spongeFlavour: "Pandan",
                packaging: "Tall Box"
            )
        )
        let reminderConfiguration = try OrderReminderConfiguration(
            mode: .custom,
            dayOffsets: [9, 2],
            includesDueTime: false
        )
        let paymentReminderConfiguration = try PaymentReminderConfiguration(
            hour: 16,
            minute: 45
        )
        try repository.save(reminderOrder)
        try repository.saveOrderReminderConfiguration(
            reminderConfiguration,
            orderId: reminderOrder.id,
            updatedAt: reminderOrder.updatedAt
        )
        try repository.savePaymentReminderConfiguration(
            paymentReminderConfiguration,
            updatedAt: reminderOrder.updatedAt
        )
        let orderTemplate = OrderTemplate(
            id: "captured-order-template",
            name: "Birthday Standard",
            cakeTitle: "Vanilla Birthday",
            cakeDesignId: nil,
            recipeId: nil,
            recipeScaleMultiplier: 1,
            fulfillmentType: .delivery,
            cakeNotes: "Pink flowers",
            cakeMessage: "Happy Birthday",
            cakeSpecification: reminderOrder.cakeSpecification,
            reminderConfiguration: reminderConfiguration,
            extraIngredients: [],
            checklistItems: [
                OrderTemplateChecklistItem(
                    id: "captured-template-checklist",
                    title: "Add topper",
                    sortOrder: 0
                )
            ],
            createdAt: reminderOrder.createdAt,
            updatedAt: reminderOrder.updatedAt
        )
        try repository.save(orderTemplate)
        try repository.saveOrderCakeRequirementChoices(
            [(.spongeFlavour, "Pandan")],
            at: reminderOrder.updatedAt
        )

        let service = fixture.service(didCaptureDatabase: {
            try repository.save(fixture.design(id: "created-later", photoReference: nil))
        })
        let package = try await service.createSnapshot()

        let snapshotQueue = try DatabaseQueue(path: package.databaseURL.path)
        let designIDs = try await snapshotQueue.read { db in
            try String.fetchAll(db, sql: "SELECT id FROM cake_designs ORDER BY id")
        }
        XCTAssertEqual(designIDs, ["captured", "external"])
        let recoveredExternalReference = try await snapshotQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT photo_reference FROM cake_designs WHERE id = 'external'"
            )
        }
        XCTAssertNotNil(recoveredExternalReference)
        XCTAssertFalse(try XCTUnwrap(recoveredExternalReference).hasPrefix("photos://"))
        let snapshotRepository = GRDBCoreDataRepository(writer: snapshotQueue)
        XCTAssertEqual(
            try snapshotRepository.fetchOrderReminderConfiguration(
                orderId: reminderOrder.id
            ),
            reminderConfiguration
        )
        XCTAssertEqual(
            try snapshotRepository.fetchPaymentReminderConfiguration(),
            paymentReminderConfiguration
        )
        XCTAssertEqual(
            try snapshotRepository.fetchOrder(id: reminderOrder.id)?.completedAt,
            completedAt
        )
        XCTAssertEqual(
            try snapshotRepository.fetchOrder(id: reminderOrder.id)?.cakeSpecification,
            reminderOrder.cakeSpecification
        )
        XCTAssertEqual(
            try snapshotRepository.fetchOrderTemplates(),
            [orderTemplate]
        )
        XCTAssertEqual(
            try snapshotRepository.fetchOrderCakeRequirementChoices(field: .spongeFlavour),
            ["Pandan"]
        )

        let manifest = try fixture.decodeManifest(at: package.manifestURL)
        XCTAssertEqual(
            manifest.databaseSchemaVersion,
            "0041_add_structured_order_requirements"
        )
        XCTAssertEqual(
            manifest.assets.map(\.originalRelativePath),
            [
                "Branding/custom-logo.jpg",
                "OrderPhotos/design.jpg",
                try XCTUnwrap(recoveredExternalReference),
            ].sorted()
        )
        let designAsset = try XCTUnwrap(
            manifest.assets.first { $0.originalRelativePath == "OrderPhotos/design.jpg" }
        )
        XCTAssertFalse(designAsset.file.relativePath.contains("design"))
        XCTAssertEqual(
            try Data(contentsOf: package.directoryURL.appendingPathComponent(designAsset.file.relativePath)),
            Data("design".utf8)
        )
        try await service.validatePackage(at: package.directoryURL)
    }

    func testSnapshotWithFractionalTimestampBuildsPublicationPlan() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000.789)

        let package = try await fixture.service(now: { timestamp }).createSnapshot()
        let persistedManifest = try fixture.decodeManifest(at: package.manifestURL)

        XCTAssertEqual(package.manifest, persistedManifest)
        XCTAssertNoThrow(try CloudBackupGenerationPlan.make(package: package))
    }

    func testValidationDetectsPayloadCorruption() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let package = try await fixture.service().createSnapshot()
        try Data("corrupt".utf8).write(to: package.databaseURL)

        do {
            try await fixture.service().validatePackage(at: package.directoryURL)
            XCTFail("Expected package validation to fail")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .payloadSizeMismatch("database.sqlite"))
        }
    }

    func testValidationDetectsSameSizePayloadModification() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let package = try await fixture.service().createSnapshot()
        let manifest = try fixture.decodeManifest(at: package.manifestURL)
        try Data(repeating: 0xA5, count: Int(manifest.database.byteCount)).write(to: package.databaseURL)

        do {
            try await fixture.service().validatePackage(at: package.directoryURL)
            XCTFail("Expected package validation to fail")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .payloadChecksumMismatch("database.sqlite"))
        }
    }

    func testValidationRejectsOverflowingManifestSizesWithoutReadingPayloads() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let packageURL = fixture.root.appendingPathComponent("HostilePackage", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        let json = """
            {
              "formatVersion": 1,
              "databaseSchemaVersion": "0027_add_order_ingredient_costs",
              "minimumCompatibleAppVersion": "1.0",
              "generationID": "hostile",
              "createdAt": "2027-01-15T08:00:00Z",
              "database": {"relativePath":"database.sqlite","byteCount":9223372036854775807,"sha256":"db"},
              "assets": [{"originalRelativePath":"asset.jpg","file":{"relativePath":"Assets/a.asset","byteCount":1,"sha256":"asset"}}],
              "totalByteCount": 0
            }
            """
        try Data(json.utf8).write(
            to: packageURL.appendingPathComponent(AppSnapshotService.manifestFilename)
        )

        do {
            try await fixture.service().validatePackage(at: packageURL)
            XCTFail("Expected invalid sizes to fail validation")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .invalidPayloadSize("manifest.json"))
        }
    }

    func testValidationRejectsSymlinkPayload() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let package = try await fixture.service().createSnapshot()
        let externalFile = fixture.root.appendingPathComponent("external.sqlite")
        try FileManager.default.copyItem(at: package.databaseURL, to: externalFile)
        try FileManager.default.removeItem(at: package.databaseURL)
        try FileManager.default.createSymbolicLink(
            at: package.databaseURL,
            withDestinationURL: externalFile
        )

        do {
            try await fixture.service().validatePackage(at: package.directoryURL)
            XCTFail("Expected symlink payload to fail validation")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .missingPayload("database.sqlite"))
        }
    }

    func testValidationRejectsSymlinkManifest() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let package = try await fixture.service().createSnapshot()
        let externalManifest = fixture.root.appendingPathComponent("external-manifest.json")
        try FileManager.default.copyItem(at: package.manifestURL, to: externalManifest)
        try FileManager.default.removeItem(at: package.manifestURL)
        try FileManager.default.createSymbolicLink(
            at: package.manifestURL,
            withDestinationURL: externalManifest
        )

        do {
            try await fixture.service().validatePackage(at: package.directoryURL)
            XCTFail("Expected symlink manifest to fail validation")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .missingPayload("manifest.json"))
        }
    }

    func testUnavailableExternalPhotosAreReportedTogetherAndCleanStaging() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let repository = fixture.database.makeCoreDataRepository()
        try repository.save(fixture.design(id: "first", photoReference: "photos://first-missing"))
        try repository.save(fixture.design(id: "second", photoReference: "photos://second-missing"))

        do {
            _ = try await fixture.service(
                externalAssetResolver: UnavailableExternalAssetResolver()
            ).createSnapshot()
            XCTFail("Expected missing PhotoKit asset to fail snapshot creation")
        } catch let error as BackupUnavailableExternalAssetsError {
            XCTAssertEqual(
                Set(error.assets.map(\.sourceReference)),
                ["photos://first-missing", "photos://second-missing"]
            )
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.stagingRoot.path), [])
    }

    func testApprovedMissingDesignPhotoIsOmittedOnlyFromSnapshot() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let reference = "photos://missing-design"
        let repository = fixture.database.makeCoreDataRepository()
        try repository.save(fixture.design(id: "external", photoReference: reference))
        let approvedDigest = BackupChecksum.sha256(of: Data(reference.utf8))

        let package = try await fixture.service(
            externalAssetResolver: UnavailableExternalAssetResolver()
        ).createSnapshot(approvedOmissionDigests: [approvedDigest])

        let snapshotQueue = try DatabaseQueue(path: package.databaseURL.path)
        let snapshotReference = try await snapshotQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT photo_reference FROM cake_designs WHERE id = 'external'"
            )
        }
        XCTAssertNil(snapshotReference)
        XCTAssertEqual(package.manifest.omittedAssetCount, 1)
        XCTAssertTrue(package.manifest.assets.isEmpty)
        XCTAssertEqual(
            try repository.fetchCakeDesign(id: "external")?.photoReference,
            reference
        )
        try await fixture.service().validatePackage(at: package.directoryURL)
    }

    func testApprovedPhotoOmissionSurvivesFullLocalRestore() async throws {
        let source = try Fixture()
        defer { source.remove() }
        let missingReference = "photos://missing-design"
        let retainedReference = "OrderPhotos/retained.jpg"
        let sourceRepository = source.database.makeCoreDataRepository()
        try source.write(Data("retained-photo".utf8), to: retainedReference)
        try sourceRepository.save(
            source.design(id: "omitted-photo", photoReference: missingReference)
        )
        try sourceRepository.save(
            source.design(id: "retained-photo", photoReference: retainedReference)
        )

        let package = try await source.service(
            externalAssetResolver: UnavailableExternalAssetResolver()
        ).createSnapshot(
            approvedOmissionDigests: [
                BackupChecksum.sha256(of: Data(missingReference.utf8))
            ]
        )
        XCTAssertEqual(package.manifest.omittedAssetCount, 1)

        let targetRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: targetRoot) }
        let targetAppStorage = targetRoot.appendingPathComponent(
            "CloudBakeOwner",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: targetAppStorage,
            withIntermediateDirectories: true
        )
        let targetDatabase = try AppDatabase.open(
            at: targetAppStorage.appendingPathComponent("cloudbake-owner.sqlite")
        )
        defer { try? targetDatabase.close() }
        let restoreService = LocalRestoreService(
            database: targetDatabase,
            snapshotCreator: FixedAppSnapshotCreator(package: package),
            appStorageRoot: targetAppStorage,
            activationRoot: targetRoot.appendingPathComponent(
                "RestoreActivation",
                isDirectory: true
            )
        )
        let downloaded = DownloadedRestoreSnapshot(
            directoryURL: package.directoryURL,
            manifest: package.manifest,
            brokenAssets: []
        )

        let prepared = try await restoreService.prepare(downloaded)
        XCTAssertTrue(prepared.brokenAssets.isEmpty)
        try await restoreService.activate(prepared, rollbackSnapshot: nil)

        let restoredRepository = targetDatabase.makeCoreDataRepository()
        let restoredOmittedPhotoDesign = try XCTUnwrap(
            restoredRepository.fetchCakeDesign(id: "omitted-photo")
        )
        XCTAssertNil(restoredOmittedPhotoDesign.photoReference)
        XCTAssertEqual(
            try restoredRepository.fetchCakeDesign(id: "retained-photo")?.photoReference,
            retainedReference
        )
        XCTAssertEqual(
            try Data(
                contentsOf: targetAppStorage.appendingPathComponent(retainedReference)
            ),
            Data("retained-photo".utf8)
        )
    }

    func testApprovedMissingOrderPhotoClearsSnapshotLinksWithoutChangingLiveData() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let reference = "photos://missing-order-reference"
        let repository = fixture.database.makeCoreDataRepository()
        let sourceOrder = fixture.order(id: "source-order")
        let photo = fixture.orderPhoto(
            id: "missing-photo",
            orderId: sourceOrder.id,
            reference: reference
        )
        let linkedOrder = fixture.order(
            id: "linked-order",
            customerReferencePhotoId: photo.id
        )
        try repository.save(sourceOrder)
        try repository.save(photo)
        try repository.save(linkedOrder)

        let package = try await fixture.service(
            externalAssetResolver: UnavailableExternalAssetResolver()
        ).createSnapshot(
            approvedOmissionDigests: [BackupChecksum.sha256(of: Data(reference.utf8))]
        )

        let snapshotQueue = try DatabaseQueue(path: package.databaseURL.path)
        let snapshotPhotoCount = try await snapshotQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM order_photos")
        }
        let snapshotReferenceID = try await snapshotQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT customer_reference_photo_id FROM orders WHERE id = 'linked-order'"
            )
        }
        XCTAssertEqual(snapshotPhotoCount, 0)
        XCTAssertNil(snapshotReferenceID)
        XCTAssertEqual(package.manifest.omittedAssetCount, 1)
        XCTAssertEqual(try repository.fetchOrderPhoto(id: photo.id), photo)
        XCTAssertEqual(
            try repository.fetchOrder(id: linkedOrder.id)?.customerReferencePhotoId,
            photo.id
        )
    }

    func testExternalPhotoAccessDeniedRemainsAHardFailure() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.database.makeCoreDataRepository().save(
            fixture.design(id: "external", photoReference: "photos://denied")
        )

        do {
            _ = try await fixture.service(
                externalAssetResolver: AccessDeniedExternalAssetResolver()
            ).createSnapshot()
            XCTFail("Expected photo access denial to fail snapshot creation")
        } catch let error as BackupExternalAssetResolverError {
            XCTAssertEqual(error, .accessDenied)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.stagingRoot.path), [])
    }

    func testRemovingUnavailableReferencesChangesOnlyExactLiveRecords() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let repository = fixture.database.makeCoreDataRepository()
        let missingReference = "photos://missing"
        let retainedReference = "photos://retained"
        try repository.save(fixture.design(id: "missing", photoReference: missingReference))
        try repository.save(fixture.design(id: "retained", photoReference: retainedReference))
        let sourceOrder = fixture.order(id: "source-order")
        let missingPhoto = fixture.orderPhoto(
            id: "missing-photo",
            orderId: sourceOrder.id,
            reference: missingReference
        )
        let retainedPhoto = fixture.orderPhoto(
            id: "retained-photo",
            orderId: sourceOrder.id,
            reference: retainedReference
        )
        let linkedOrder = fixture.order(
            id: "linked-order",
            customerReferencePhotoId: missingPhoto.id
        )
        try repository.save(sourceOrder)
        try repository.save(missingPhoto)
        try repository.save(retainedPhoto)
        try repository.save(linkedOrder)

        try fixture.database.removeUnavailablePhotoReferences([missingReference])

        XCTAssertNil(try repository.fetchCakeDesign(id: "missing")?.photoReference)
        XCTAssertEqual(
            try repository.fetchCakeDesign(id: "retained")?.photoReference,
            retainedReference
        )
        XCTAssertNil(try repository.fetchOrderPhoto(id: missingPhoto.id))
        XCTAssertEqual(try repository.fetchOrderPhoto(id: retainedPhoto.id), retainedPhoto)
        XCTAssertNil(
            try repository.fetchOrder(id: linkedOrder.id)?.customerReferencePhotoId
        )
    }

    func testRemovingInvalidPhotoReferenceRollsBackAllChanges() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let repository = fixture.database.makeCoreDataRepository()
        let reference = "photos://missing"
        try repository.save(fixture.design(id: "missing", photoReference: reference))

        XCTAssertThrowsError(
            try fixture.database.removeUnavailablePhotoReferences(
                [reference, "OrderPhotos/not-external.jpg"]
            )
        )

        XCTAssertEqual(
            try repository.fetchCakeDesign(id: "missing")?.photoReference,
            reference
        )
    }

    func testExternalPhotoChangedAfterDatabaseCaptureFailsSnapshot() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let reference = "photos://asset-id"
        try fixture.database.makeCoreDataRepository().save(
            fixture.design(id: "external", photoReference: reference)
        )
        let recoveryPath = "RecoveredPhotos/\(BackupChecksum.sha256(of: Data(reference.utf8))).jpg"

        do {
            _ = try await fixture.service(
                externalAssetResolver: FutureDatedExternalAssetResolver()
            ).createSnapshot()
            XCTFail("Expected post-capture PhotoKit edit to fail snapshot creation")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .assetChanged(recoveryPath))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.stagingRoot.path), [])
    }

    func testCancellationDuringExternalPhotoReadCleansStaging() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.database.makeCoreDataRepository().save(
            fixture.design(id: "external", photoReference: "photos://slow")
        )
        let probe = ExternalResolverProbe()
        let service = fixture.service(
            externalAssetResolver: SlowExternalAssetResolver(probe: probe)
        )
        let snapshotTask = Task {
            try await service.createSnapshot()
        }
        try await probe.waitUntilStarted()

        snapshotTask.cancel()
        do {
            _ = try await snapshotTask.value
            XCTFail("Expected snapshot cancellation")
        } catch is CancellationError {
            // Expected.
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.stagingRoot.path), [])
    }

    func testMissingReferencedAssetFailsAndRemovesBuildingDirectory() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.database.makeCoreDataRepository().save(
            fixture.design(id: "missing", photoReference: "OrderPhotos/missing.jpg")
        )

        do {
            _ = try await fixture.service().createSnapshot()
            XCTFail("Expected missing asset to fail snapshot creation")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .assetMissing("OrderPhotos/missing.jpg"))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.stagingRoot.path), [])
    }

    func testAssetChangedDuringStagingFailsAndRemovesBuildingDirectory() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.write(Data("before".utf8), to: "OrderPhotos/design.jpg")
        try fixture.database.makeCoreDataRepository().save(
            fixture.design(id: "changing", photoReference: "OrderPhotos/design.jpg")
        )
        let service = fixture.service(didCopyAsset: { _ in
            try fixture.write(Data("after".utf8), to: "OrderPhotos/design.jpg")
        })

        do {
            _ = try await service.createSnapshot()
            XCTFail("Expected changing asset to fail snapshot creation")
        } catch let error as AppSnapshotError {
            XCTAssertEqual(error, .assetChanged("OrderPhotos/design.jpg"))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.stagingRoot.path), [])
    }

    func testCleanupOnlyRemovesAbandonedBuildingDirectories() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let abandoned = fixture.stagingRoot.appendingPathComponent("old.building")
        let finalized = fixture.stagingRoot.appendingPathComponent("published")
        try FileManager.default.createDirectory(at: abandoned, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: finalized, withIntermediateDirectories: true)

        try await fixture.service().cleanAbandonedStagingDirectories()

        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalized.path))
    }

}

private final class Fixture: @unchecked Sendable {
    let root: URL
    let appStorageRoot: URL
    let stagingRoot: URL
    let database: AppDatabase

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        appStorageRoot = root.appendingPathComponent("ApplicationSupport/CloudBakeOwner", isDirectory: true)
        stagingRoot = root.appendingPathComponent("BackupStaging", isDirectory: true)
        try FileManager.default.createDirectory(at: appStorageRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        database = try AppDatabase.makeInMemory()
    }

    func service(
        didCaptureDatabase: @escaping @Sendable () throws -> Void = {},
        didCopyAsset: @escaping @Sendable (String) throws -> Void = { _ in },
        externalAssetResolver: any BackupExternalAssetResolving = FakeExternalAssetResolver(),
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_800_000_000) }
    ) -> AppSnapshotService {
        AppSnapshotService(
            database: database,
            appStorageRoot: appStorageRoot,
            stagingRoot: stagingRoot,
            minimumCompatibleAppVersion: "1.0",
            currentAppVersion: "1.0",
            externalAssetResolver: externalAssetResolver,
            now: now,
            makeGenerationID: { "generation-1" },
            didCaptureDatabase: didCaptureDatabase,
            didCopyAsset: didCopyAsset
        )
    }

    func design(id: String, photoReference: String?) -> CakeDesign {
        CakeDesign(
            id: id,
            name: id,
            notes: nil,
            photoReference: photoReference,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    func order(
        id: String,
        customerReferencePhotoId: String? = nil,
        status: OrderStatus = .draft,
        completedAt: Date? = nil,
        cakeSpecification: OrderCakeSpecification = .empty
    ) -> Order {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        return Order(
            id: id,
            customerId: nil,
            cakeDesignId: nil,
            customerReferencePhotoId: customerReferencePhotoId,
            title: id,
            customerName: "Amy",
            status: status,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            cakeSpecification: cakeSpecification,
            completedAt: completedAt,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    func orderPhoto(
        id: String,
        orderId: String,
        reference: String
    ) -> OrderPhoto {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        return OrderPhoto(
            id: id,
            orderId: orderId,
            kind: .customerReference,
            localPhotoPath: reference,
            caption: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    func write(_ data: Data, to relativePath: String) throws {
        let url = appStorageRoot.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }

    func decodeManifest(at url: URL) throws -> BackupManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupManifest.self, from: Data(contentsOf: url))
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private struct FakeExternalAssetResolver: BackupExternalAssetResolving {
    func resolve(reference: String) async throws -> BackupResolvedExternalAsset {
        guard reference == "photos://asset-id" else {
            throw BackupExternalAssetResolverError.assetUnavailable
        }
        return BackupResolvedExternalAsset(
            data: Data("external-photo".utf8),
            modificationDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

private struct UnavailableExternalAssetResolver: BackupExternalAssetResolving {
    func resolve(reference: String) async throws -> BackupResolvedExternalAsset {
        throw BackupExternalAssetResolverError.assetUnavailable
    }
}

private struct AccessDeniedExternalAssetResolver: BackupExternalAssetResolving {
    func resolve(reference: String) async throws -> BackupResolvedExternalAsset {
        throw BackupExternalAssetResolverError.accessDenied
    }
}

private struct FutureDatedExternalAssetResolver: BackupExternalAssetResolving {
    func resolve(reference: String) async throws -> BackupResolvedExternalAsset {
        BackupResolvedExternalAsset(
            data: Data("edited-photo".utf8),
            modificationDate: .distantFuture
        )
    }
}

private struct FixedAppSnapshotCreator: AppSnapshotCreating {
    let package: AppSnapshotPackage

    func createSnapshot() async throws -> AppSnapshotPackage {
        package
    }
}

private struct SlowExternalAssetResolver: BackupExternalAssetResolving {
    let probe: ExternalResolverProbe

    func resolve(reference: String) async throws -> BackupResolvedExternalAsset {
        await probe.markStarted()
        try await Task.sleep(nanoseconds: 30_000_000_000)
        return BackupResolvedExternalAsset(data: Data(), modificationDate: .distantPast)
    }
}

private actor ExternalResolverProbe {
    private var isStarted = false

    func markStarted() {
        isStarted = true
    }

    func waitUntilStarted() async throws {
        for _ in 0..<100 where !isStarted {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        guard isStarted else {
            throw BackupExternalAssetResolverError.assetUnavailable
        }
    }
}
