import XCTest
import GRDB
@testable import CloudBakeOwner

final class AppDatabaseTests: XCTestCase {
    func testOrderQueryIndexesAreCreated() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let indexNames = try queue.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT name
                    FROM sqlite_master
                    WHERE type = 'index'
                      AND name LIKE 'orders_on_%'
                    ORDER BY name
                    """
            )
        }

        XCTAssertTrue(indexNames.contains("orders_on_status_due_id"))
        XCTAssertTrue(indexNames.contains("orders_on_customer_due_id"))
        XCTAssertTrue(indexNames.contains("orders_on_status_completed_at_id"))
    }

    func testPaymentReminderConfigurationDefaultsToNineAndPersistsChanges() throws {
        let database = try AppDatabase.makeInMemory()
        let repository = database.makeCoreDataRepository()
        let updatedAt = Date(timeIntervalSince1970: 1_800_001_000)

        XCTAssertEqual(
            try repository.fetchPaymentReminderConfiguration(),
            .initialDefault
        )

        let changed = try PaymentReminderConfiguration(hour: 14, minute: 30)
        try repository.savePaymentReminderConfiguration(changed, updatedAt: updatedAt)

        XCTAssertEqual(try repository.fetchPaymentReminderConfiguration(), changed)
    }

    func testOrderCompletedAtMigrationLeavesLegacyCompletionUnknown() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue, upTo: "0033_add_order_reminder_configurations")
        let timestamp = 1_800_001_000.0

        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO orders
                    (id, title, status, due_at_unix_time,
                     created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "legacy-completed-order",
                    "Legacy completed cake",
                    OrderStatus.completed.rawValue,
                    timestamp,
                    timestamp,
                    timestamp
                ]
            )
        }

        try migrator.migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)

        XCTAssertNil(try repository.fetchOrder(id: "legacy-completed-order")?.completedAt)
    }

    func testOrderCompletionTimestampIsRecordedOnceAndPreserved() throws {
        let database = try AppDatabase.makeInMemory()
        let repository = database.makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let firstCompletion = Date(timeIntervalSince1970: 1_800_001_000)
        let laterUpdate = Date(timeIntervalSince1970: 1_800_002_000)
        let order = Order(
            id: "completion-history",
            customerId: nil,
            cakeDesignId: nil,
            title: "Completion history",
            customerName: "Customer",
            status: .draft,
            dueAt: createdAt,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        try repository.save(order)

        let completed = Order(
            id: order.id,
            customerId: order.customerId,
            cakeDesignId: order.cakeDesignId,
            title: order.title,
            customerName: order.customerName,
            status: .completed,
            dueAt: order.dueAt,
            fulfillmentType: order.fulfillmentType,
            deliveryAddress: order.deliveryAddress,
            cakeNotes: order.cakeNotes,
            createdAt: order.createdAt,
            updatedAt: firstCompletion
        )
        try repository.save(completed)

        let reopened = Order(
            id: completed.id,
            customerId: completed.customerId,
            cakeDesignId: completed.cakeDesignId,
            title: completed.title,
            customerName: completed.customerName,
            status: .confirmed,
            dueAt: completed.dueAt,
            fulfillmentType: completed.fulfillmentType,
            deliveryAddress: completed.deliveryAddress,
            cakeNotes: completed.cakeNotes,
            completedAt: firstCompletion,
            createdAt: completed.createdAt,
            updatedAt: laterUpdate
        )
        try repository.save(reopened)

        XCTAssertEqual(try repository.fetchOrder(id: order.id)?.completedAt, firstCompletion)
    }

    func testOrderReminderConfigurationMigrationBackfillsExistingOrders() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue, upTo: "0032_track_reservation_repair_activation")
        let timestamp = 1_800_001_000.0

        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO orders
                    (id, title, status, due_at_unix_time,
                     created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "order-reminder-migration",
                    "Reminder migration cake",
                    OrderStatus.draft.rawValue,
                    timestamp,
                    timestamp,
                    timestamp
                ]
            )
        }

        try migrator.migrate(queue)

        try queue.read { db in
            XCTAssertTrue(try db.tableExists("order_reminder_defaults"))
            XCTAssertTrue(try db.tableExists("order_reminder_configurations"))
            let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT mode, day_offsets_json, includes_due_time
                    FROM order_reminder_configurations
                    WHERE order_id = ?
                    """,
                arguments: ["order-reminder-migration"]
            )
            XCTAssertEqual(row?["mode"] as String?, "defaultSnapshot")
            XCTAssertEqual(row?["day_offsets_json"] as String?, "[3,2,1]")
            XCTAssertEqual(row?["includes_due_time"] as Bool?, true)
        }
    }

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

    func testIngredientCostMigrationLeavesLegacyPartialBatchUnpriced() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue, upTo: "0026_add_design_portfolio_publication")

        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO inventory_items
                    (id, name, unit, minimum_quantity, current_quantity, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: ["legacy-flour", "Legacy flour", "gram", 10, 50, 1_800_000_000, 1_800_000_000]
            )
            try db.execute(
                sql: """
                    INSERT INTO inventory_stock_batches
                    (id, inventory_item_id, remaining_quantity, amount_decimal, unit_cost_decimal, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: ["legacy-batch", "legacy-flour", 50, "10", "10", 1_800_000_000, 1_800_000_000]
            )
        }

        try migrator.migrate(queue)

        try queue.read { db in
            let unitCost: String? = try String.fetchOne(
                db,
                sql: "SELECT unit_cost_decimal FROM inventory_stock_batches WHERE id = ?",
                arguments: ["legacy-batch"]
            )
            XCTAssertNil(unitCost)
            XCTAssertTrue(try db.tableExists("order_ingredient_costs"))
        }
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
        XCTAssertFalse(design.isPortfolioPublished)
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

    func testReservationMigrationQueuesOnlyEligibleUnconsumedOrders() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue, upTo: "0029_add_order_ingredient_shortfall")
        let timestamp = 1_800_060_000.0

        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO recipes
                    (id, name, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?)
                    """,
                arguments: ["recipe-consumed", "Consumed recipe", timestamp, timestamp]
            )
            for (id, status) in [
                ("order-confirmed", OrderStatus.confirmed),
                ("order-in-progress", OrderStatus.inProgress),
                ("order-draft", OrderStatus.draft),
                ("order-consumed", OrderStatus.confirmed)
            ] {
                try db.execute(
                    sql: """
                        INSERT INTO orders
                        (id, recipe_id, title, status, due_at_unix_time,
                         created_at_unix_time, updated_at_unix_time)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        id,
                        id == "order-consumed" ? "recipe-consumed" : nil,
                        id,
                        status.rawValue,
                        timestamp,
                        timestamp,
                        timestamp
                    ]
                )
            }
            try db.execute(
                sql: """
                    INSERT INTO order_recipe_usages
                    (id, order_id, recipe_id, used_at_unix_time,
                     created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "usage-consumed",
                    "order-consumed",
                    "recipe-consumed",
                    timestamp,
                    timestamp,
                    timestamp
                ]
            )
        }

        try migrator.migrate(queue)

        try queue.read { db in
            XCTAssertTrue(try db.tableExists("order_inventory_reservations"))
            XCTAssertTrue(try db.tableExists("order_inventory_reservation_events"))
            XCTAssertTrue(try db.tableExists("order_inventory_reservation_repairs"))
            XCTAssertTrue(
                try db.columns(in: "order_inventory_reservation_repairs")
                    .contains { $0.name == "last_activation_id" }
            )
            XCTAssertEqual(
                try String.fetchAll(
                    db,
                    sql: """
                        SELECT order_id
                        FROM order_inventory_reservation_repairs
                        ORDER BY order_id
                        """
                ),
                ["order-confirmed", "order-in-progress"]
            )
            XCTAssertEqual(
                try String.fetchAll(
                    db,
                    sql: """
                        SELECT DISTINCT state
                        FROM order_inventory_reservation_repairs
                        """
                ),
                ["pending"]
            )
            XCTAssertEqual(
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*)
                        FROM sqlite_master
                        WHERE type = 'index'
                          AND name IN (
                            'order_inventory_reservations_on_inventory_item_id',
                            'order_inventory_reservation_events_on_order_occurred_at',
                            'order_inventory_reservation_repairs_on_state'
                          )
                        """
                ),
                3
            )
        }

        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO inventory_items
                    (id, name, unit, minimum_quantity, current_quantity,
                     created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "inventory-reservation-constraint",
                    "Reservation constraint",
                    InventoryUnit.gram.rawValue,
                    10,
                    100,
                    timestamp,
                    timestamp
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservations
                    (id, order_id, inventory_item_id, required_quantity, unit,
                     created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "reservation-constraint",
                    "order-confirmed",
                    "inventory-reservation-constraint",
                    25,
                    InventoryUnit.gram.rawValue,
                    timestamp,
                    timestamp
                ]
            )
            XCTAssertThrowsError(
                try db.execute(
                    sql: """
                        INSERT INTO order_inventory_reservations
                        (id, order_id, inventory_item_id, required_quantity, unit,
                         created_at_unix_time, updated_at_unix_time)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        "reservation-duplicate",
                        "order-confirmed",
                        "inventory-reservation-constraint",
                        10,
                        InventoryUnit.gram.rawValue,
                        timestamp,
                        timestamp
                    ]
                )
            )
            XCTAssertThrowsError(
                try db.execute(
                    sql: """
                        INSERT INTO order_inventory_reservations
                        (id, order_id, inventory_item_id, required_quantity, unit,
                         created_at_unix_time, updated_at_unix_time)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        "reservation-zero",
                        "order-in-progress",
                        "inventory-reservation-constraint",
                        0,
                        InventoryUnit.gram.rawValue,
                        timestamp,
                        timestamp
                    ]
                )
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_events
                    (id, order_id, inventory_item_id, event_kind, reason,
                     previous_quantity, new_quantity, unit, occurred_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "stable-reservation-event-id",
                    "order-confirmed",
                    "inventory-reservation-constraint",
                    OrderInventoryReservationEventKind.created.rawValue,
                    OrderInventoryReservationEventReason.orderConfirmed.rawValue,
                    0,
                    25,
                    InventoryUnit.gram.rawValue,
                    timestamp
                ]
            )
            XCTAssertEqual(
                try String.fetchOne(
                    db,
                    sql: """
                        SELECT typeof(id)
                        FROM order_inventory_reservation_events
                        WHERE id = ?
                        """,
                    arguments: ["stable-reservation-event-id"]
                ),
                "text"
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_events
                    (id, order_id, inventory_item_id, event_kind, reason,
                     previous_quantity, new_quantity, unit, occurred_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "repair-failure-event-id",
                    "order-confirmed",
                    "missing-inventory-item",
                    OrderInventoryReservationEventKind.repairFailed.rawValue,
                    OrderInventoryReservationEventReason.migrationRepair.rawValue,
                    0,
                    0,
                    nil,
                    timestamp
                ]
            )
            XCTAssertThrowsError(
                try db.execute(
                    sql: """
                        INSERT INTO order_inventory_reservation_events
                        (id, order_id, inventory_item_id, event_kind, reason,
                         previous_quantity, new_quantity, unit, occurred_at_unix_time)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        "invalid-created-event-id",
                        "order-confirmed",
                        nil,
                        OrderInventoryReservationEventKind.created.rawValue,
                        OrderInventoryReservationEventReason.orderConfirmed.rawValue,
                        0,
                        25,
                        nil,
                        timestamp
                    ]
                )
            )
            XCTAssertThrowsError(
                try db.execute(
                    sql: "DELETE FROM orders WHERE id = ?",
                    arguments: ["order-confirmed"]
                )
            )
            XCTAssertThrowsError(
                try db.execute(
                    sql: """
                        INSERT INTO order_inventory_reservation_repairs
                        (order_id, state, updated_at_unix_time)
                        VALUES (?, ?, ?)
                        """,
                    arguments: ["order-draft", "unknown", timestamp]
                )
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_repairs
                    (order_id, state, updated_at_unix_time)
                    VALUES (?, ?, ?)
                    """,
                arguments: [
                    "order-draft",
                    OrderInventoryReservationRepairState.pending.rawValue,
                    timestamp
                ]
            )
            XCTAssertEqual(
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT attempt_count
                        FROM order_inventory_reservation_repairs
                        WHERE order_id = ?
                        """,
                    arguments: ["order-draft"]
                ),
                0
            )
            XCTAssertThrowsError(
                try db.execute(
                    sql: """
                        INSERT INTO order_inventory_reservation_repairs
                        (order_id, state, updated_at_unix_time)
                        VALUES (?, ?, ?)
                        """,
                    arguments: [
                        "order-consumed",
                        OrderInventoryReservationRepairState.failed.rawValue,
                        timestamp
                    ]
                )
            )
        }
    }

    func testReservationFailureEventSchemaUpgradesAfterMigration0030WasApplied() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue, upTo: "0030_create_order_inventory_reservations")
        let timestamp = 1_800_070_000.0

        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO inventory_items
                    (id, name, unit, minimum_quantity, current_quantity,
                     created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "inventory-upgrade-event",
                    "Upgrade event flour",
                    InventoryUnit.gram.rawValue,
                    0,
                    100,
                    timestamp,
                    timestamp
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO orders
                    (id, title, status, due_at_unix_time,
                     created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "order-upgrade-event",
                    "Upgrade event order",
                    OrderStatus.confirmed.rawValue,
                    timestamp,
                    timestamp,
                    timestamp
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_events
                    (id, order_id, inventory_item_id, event_kind, reason,
                     previous_quantity, new_quantity, unit, occurred_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "event-before-0031",
                    "order-upgrade-event",
                    "inventory-upgrade-event",
                    OrderInventoryReservationEventKind.created.rawValue,
                    OrderInventoryReservationEventReason.orderConfirmed.rawValue,
                    0,
                    25,
                    InventoryUnit.gram.rawValue,
                    timestamp
                ]
            )
            XCTAssertThrowsError(
                try db.execute(
                    sql: """
                        INSERT INTO order_inventory_reservation_events
                        (id, order_id, inventory_item_id, event_kind, reason,
                         previous_quantity, new_quantity, unit, occurred_at_unix_time)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        "repair-before-0031",
                        "order-upgrade-event",
                        nil,
                        OrderInventoryReservationEventKind.repairFailed.rawValue,
                        OrderInventoryReservationEventReason.migrationRepair.rawValue,
                        0,
                        0,
                        nil,
                        timestamp
                    ]
                )
            )
        }

        try migrator.migrate(queue)

        try queue.write { db in
            XCTAssertEqual(
                try String.fetchOne(
                    db,
                    sql: """
                        SELECT id
                        FROM order_inventory_reservation_events
                        WHERE id = ?
                        """,
                    arguments: ["event-before-0031"]
                ),
                "event-before-0031"
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_events
                    (id, order_id, inventory_item_id, event_kind, reason,
                     previous_quantity, new_quantity, unit, occurred_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "repair-after-0031",
                    "order-upgrade-event",
                    nil,
                    OrderInventoryReservationEventKind.repairFailed.rawValue,
                    OrderInventoryReservationEventReason.migrationRepair.rawValue,
                    0,
                    0,
                    nil,
                    timestamp
                ]
            )
        }
    }
}
