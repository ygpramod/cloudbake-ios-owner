import XCTest
import GRDB
@testable import CloudBakeOwner

final class AppDatabaseTests: XCTestCase {
    @MainActor
    func testPersistedDesignLibrarySearchCompletesWithinBudget() throws {
        let database = try AppDatabase.makeInMemory()
        let repository = database.makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_050_000)
        for index in 0..<600 {
            try repository.save(
                CakeDesign(
                    id: "design-performance-\(index)",
                    name: "Birthday design \(index)",
                    notes: index.isMultiple(of: 2)
                        ? "Blue floral buttercream"
                        : "Pink minimal cake",
                    photoReference: nil,
                    tags: [index.isMultiple(of: 3) ? "Wedding" : "Birthday"],
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            )
        }
        let viewModel = CakeDesignListViewModel(repository: repository)

        let startedAt = ProcessInfo.processInfo.systemUptime
        viewModel.load()
        viewModel.searchText = "blue floral"
        let results = viewModel.visibleDesigns
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt

        XCTAssertEqual(results.count, 300)
        XCTAssertLessThan(elapsed, 1, "Persisted 600-item design search exceeded one second")
    }

    func testInMemoryDatabaseRunsMigrationsFromScratch() throws {
        let database = try AppDatabase.makeInMemory()
        let repository = database.makeHealthCheckRepository()
        let entry = HealthCheckEntry(
            id: "migration-smoke-test",
            note: "Database is usable after migrations",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        try repository.save(entry)

        XCTAssertEqual(try repository.fetch(id: entry.id), entry)
    }

    func testFileDatabaseRunsMigrationsFromScratch() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let databaseURL = temporaryDirectory.appendingPathComponent("cloudbake-owner.sqlite")
        let database = try AppDatabase.open(at: databaseURL)
        let repository = database.makeHealthCheckRepository()
        let entry = HealthCheckEntry(
            id: "file-database-smoke-test",
            note: "File database is usable after migrations",
            createdAt: Date(timeIntervalSince1970: 1_800_000_100)
        )

        try repository.save(entry)

        XCTAssertEqual(try repository.fetch(id: entry.id), entry)
        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
    }

    func testInventoryStockBatchMigrationPreservesExistingCurrentQuantity() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue, upTo: "0004_add_inventory_archive_timestamp")

        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO inventory_items
                    (id, name, unit, minimum_quantity, created_at_unix_time, updated_at_unix_time, current_quantity, archived_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "inventory-flour",
                    "Cake flour",
                    InventoryUnit.gram.rawValue,
                    500,
                    1_800_020_000,
                    1_800_020_100,
                    750,
                    nil
                ]
            )
        }

        try migrator.migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)

        XCTAssertEqual(
            try repository.fetchInventoryStockBatches(inventoryItemId: "inventory-flour"),
            [
                InventoryStockBatch(
                    id: "legacy-batch-inventory-flour",
                    inventoryItemId: "inventory-flour",
                    remainingQuantity: 750,
                    expiresAt: nil,
                    createdAt: Date(timeIntervalSince1970: 1_800_020_000),
                    updatedAt: Date(timeIntervalSince1970: 1_800_020_100)
                )
            ]
        )
    }

    func testCakeDesignProvenanceMigrationClassifiesExistingDesignsAsOwnerMade() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue, upTo: "0019_add_inventory_type")

        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO cake_designs
                    (id, name, notes, photo_reference, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "design-legacy",
                    "Legacy floral cake",
                    "Promoted before provenance",
                    "photos/legacy-floral.jpg",
                    1_800_030_000,
                    1_800_030_100
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO orders
                    (id, cake_design_id, title, status, due_at_unix_time,
                     created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "order-legacy-design",
                    "design-legacy",
                    "Legacy linked order",
                    OrderStatus.confirmed.rawValue,
                    1_800_040_000,
                    1_800_030_000,
                    1_800_030_100
                ]
            )
        }

        try migrator.migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let design = try XCTUnwrap(repository.fetchCakeDesign(id: "design-legacy"))

        XCTAssertEqual(design.sourceKind, .ownerMade)
        XCTAssertEqual(design.photoReference, "photos/legacy-floral.jpg")
        XCTAssertNil(design.originatingOrderPhotoId)
        XCTAssertNil(design.originatingOrderId)
        XCTAssertTrue(design.tags.isEmpty)
        XCTAssertFalse(design.isFavorite)
        XCTAssertEqual(
            try repository.fetchOrder(id: "order-legacy-design")?.cakeDesignId,
            design.id
        )
    }

    func testUniqueDesignOriginMigrationRepairsDuplicatesBeforeCreatingIndex() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue, upTo: "0023_add_design_tags_and_favorites")
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_050_000)
        let order = Order(
            id: "order-duplicate-origin",
            customerId: nil,
            cakeDesignId: nil,
            title: "Duplicate origin",
            customerName: "Amy",
            status: .confirmed,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let photo = OrderPhoto(
            id: "photo-duplicate-origin",
            orderId: order.id,
            kind: .finalCake,
            localPhotoPath: "photos://duplicate-origin",
            caption: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        func design(id: String) -> CakeDesign {
            CakeDesign(
                id: id,
                name: id,
                notes: nil,
                photoReference: photo.localPhotoPath,
                sourceKind: .ownerMade,
                originatingOrderPhotoId: photo.id,
                originatingOrderId: order.id,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        }
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO orders
                    (id, title, status, due_at_unix_time, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    order.id,
                    order.title,
                    order.status.rawValue,
                    order.dueAt.timeIntervalSince1970,
                    order.createdAt.timeIntervalSince1970,
                    order.updatedAt.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO order_photos
                    (id, order_id, kind, local_photo_path, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    photo.id,
                    photo.orderId,
                    photo.kind.rawValue,
                    photo.localPhotoPath,
                    photo.createdAt.timeIntervalSince1970,
                    photo.updatedAt.timeIntervalSince1970
                ]
            )
            for designId in ["design-b", "design-a"] {
                try db.execute(
                    sql: """
                        INSERT INTO cake_designs
                        (id, name, photo_reference, source_kind, originating_order_photo_id,
                         originating_order_id, created_at_unix_time, updated_at_unix_time)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        designId,
                        designId,
                        photo.localPhotoPath,
                        CakeDesignSourceKind.ownerMade.rawValue,
                        photo.id,
                        order.id,
                        timestamp.timeIntervalSince1970,
                        timestamp.timeIntervalSince1970
                    ]
                )
            }
        }

        try migrator.migrate(queue)

        XCTAssertEqual(
            try repository.fetchCakeDesign(id: "design-a")?.originatingOrderPhotoId,
            photo.id
        )
        XCTAssertNil(
            try repository.fetchCakeDesign(id: "design-b")?.originatingOrderPhotoId
        )
        XCTAssertEqual(try repository.fetchCakeDesigns().count, 2)
        XCTAssertThrowsError(try repository.save(design(id: "design-c")))
        XCTAssertNil(try repository.fetchCakeDesign(id: "design-c"))
    }

    func testCakeDesignFetchRejectsUnknownPersistedSourceKind() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let design = CakeDesign(
            id: "design-invalid-source",
            name: "Invalid source",
            notes: nil,
            photoReference: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(design)
        try queue.write { db in
            try db.execute(
                sql: "UPDATE cake_designs SET source_kind = ? WHERE id = ?",
                arguments: ["unexpected-source", design.id]
            )
        }

        XCTAssertThrowsError(try repository.fetchCakeDesign(id: design.id)) { error in
            XCTAssertEqual(
                error as? CakeDesignPersistenceError,
                .invalidSourceKind("unexpected-source")
            )
        }
    }
}
