import GRDB

enum AppDatabaseMigrations {
    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("0001_create_health_checks") { db in
            try db.create(table: "app_health_checks") { table in
                table.column("id", .text).primaryKey()
                table.column("note", .text).notNull()
                table.column("created_at_unix_time", .double).notNull()
            }
        }

        migrator.registerMigration("0002_create_core_tables") { db in
            try db.create(table: "inventory_items") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("unit", .text).notNull()
                table.column("minimum_quantity", .double).notNull()
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }

            try db.create(table: "recipes") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("notes", .text)
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }

            try db.create(table: "recipe_components") { table in
                table.column("id", .text).primaryKey()
                table.column("recipe_id", .text)
                    .notNull()
                    .references("recipes", onDelete: .cascade)
                table.column("name", .text).notNull()
                table.column("sort_order", .integer).notNull()
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }

            try db.create(table: "recipe_ingredients") { table in
                table.column("id", .text).primaryKey()
                table.column("component_id", .text)
                    .notNull()
                    .references("recipe_components", onDelete: .cascade)
                table.column("inventory_item_id", .text)
                    .notNull()
                    .references("inventory_items", onDelete: .restrict)
                table.column("quantity", .double).notNull()
                table.column("unit", .text).notNull()
                table.column("note", .text)
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }

            try db.create(table: "cake_designs") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("notes", .text)
                table.column("photo_reference", .text)
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }

            try db.create(table: "customers") { table in
                table.column("id", .text).primaryKey()
                table.column("display_name", .text).notNull()
                table.column("likes", .text)
                table.column("dislikes", .text)
                table.column("allergies", .text)
                table.column("notes", .text)
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }

            try db.create(table: "orders") { table in
                table.column("id", .text).primaryKey()
                table.column("customer_id", .text)
                    .references("customers", onDelete: .setNull)
                table.column("cake_design_id", .text)
                    .references("cake_designs", onDelete: .setNull)
                table.column("title", .text).notNull()
                table.column("status", .text).notNull()
                table.column("due_at_unix_time", .double).notNull()
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }

            try db.create(table: "inventory_transactions") { table in
                table.column("id", .text).primaryKey()
                table.column("inventory_item_id", .text)
                    .notNull()
                    .references("inventory_items", onDelete: .restrict)
                table.column("kind", .text).notNull()
                table.column("quantity", .double).notNull()
                table.column("occurred_at_unix_time", .double).notNull()
                table.column("note", .text)
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }

            try db.create(table: "pricing_rules") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("kind", .text).notNull()
                table.column("amount_decimal", .text).notNull()
                table.column("currency_code", .text).notNull()
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }
        }

        migrator.registerMigration("0003_add_inventory_current_quantity") { db in
            try db.alter(table: "inventory_items") { table in
                table.add(column: "current_quantity", .double).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("0004_add_inventory_archive_timestamp") { db in
            try db.alter(table: "inventory_items") { table in
                table.add(column: "archived_at_unix_time", .double)
            }
        }

        migrator.registerMigration("0005_create_inventory_stock_batches") { db in
            try db.create(table: "inventory_stock_batches") { table in
                table.column("id", .text).primaryKey()
                table.column("inventory_item_id", .text)
                    .notNull()
                    .references("inventory_items", onDelete: .restrict)
                table.column("remaining_quantity", .double).notNull()
                table.column("expires_at_unix_time", .double)
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }

            try db.execute(
                sql: """
                    INSERT INTO inventory_stock_batches
                    (id, inventory_item_id, remaining_quantity, expires_at_unix_time, created_at_unix_time, updated_at_unix_time)
                    SELECT
                    'legacy-batch-' || id,
                    id,
                    current_quantity,
                    NULL,
                    created_at_unix_time,
                    updated_at_unix_time
                    FROM inventory_items
                    WHERE current_quantity > 0
                    """
            )
        }

        migrator.registerMigration("0006_create_inventory_expiry_snoozes") { db in
            try db.create(table: "inventory_expiry_snoozes") { table in
                table.column("stock_batch_id", .text)
                    .primaryKey()
                    .references("inventory_stock_batches", onDelete: .cascade)
                table.column("snoozed_until_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }
        }

        return migrator
    }
}
