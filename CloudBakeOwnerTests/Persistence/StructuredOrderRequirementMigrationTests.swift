import GRDB
import XCTest

@testable import CloudBakeOwner

final class StructuredOrderRequirementMigrationTests: XCTestCase {
    func testMigrationKeepsExistingOrderAndTemplateRequirementsEmpty() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue, upTo: "0040_add_order_templates")
        let timestamp = 1_800_001_000.0

        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO orders (
                        id, title, status, due_at_unix_time,
                        created_at_unix_time, updated_at_unix_time
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "legacy-structured-order",
                    "Legacy cake",
                    OrderStatus.draft.rawValue,
                    timestamp,
                    timestamp,
                    timestamp,
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO order_templates (
                        id, name, cake_title, recipe_scale_multiplier_decimal,
                        fulfillment_type, reminder_mode, reminder_day_offsets_json,
                        reminder_includes_due_time, created_at_unix_time, updated_at_unix_time
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "legacy-structured-template",
                    "Legacy template",
                    "Legacy cake",
                    "1",
                    OrderFulfillmentType.pickup.rawValue,
                    OrderReminderConfigurationMode.defaultSnapshot.rawValue,
                    "[3,2,1]",
                    true,
                    timestamp,
                    timestamp,
                ]
            )
        }

        try migrator.migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)

        XCTAssertEqual(
            try repository.fetchOrder(id: "legacy-structured-order")?.cakeSpecification,
            .empty
        )
        XCTAssertEqual(
            try repository.fetchOrderTemplates().first?.cakeSpecification,
            .empty
        )
        XCTAssertTrue(
            try queue.read { db in
                try db.tableExists("order_cake_requirement_choices")
            }
        )
    }
}
