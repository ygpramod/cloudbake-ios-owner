import XCTest
import GRDB
@testable import CloudBakeOwner

final class AppDatabaseTests: XCTestCase {
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
