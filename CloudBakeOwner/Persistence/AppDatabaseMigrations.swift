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

        migrator.registerMigration("0006_expand_customers") { db in
            try db.alter(table: "customers") { table in
                table.rename(column: "display_name", to: "name")
                table.add(column: "phone", .text).notNull().defaults(to: "")
                table.add(column: "email", .text)
                table.add(column: "address", .text)
                table.add(column: "dietary_restrictions", .text)
            }

            try db.create(table: "customer_important_dates") { table in
                table.column("id", .text).primaryKey()
                table.column("customer_id", .text)
                    .notNull()
                    .references("customers", onDelete: .cascade)
                table.column("label", .text).notNull()
                table.column("date_unix_time", .double).notNull()
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }
        }

        migrator.registerMigration("0007_expand_orders") { db in
            try db.alter(table: "orders") { table in
                table.add(column: "customer_name", .text).notNull().defaults(to: "")
                table.add(column: "fulfillment_type", .text).notNull().defaults(to: OrderFulfillmentType.pickup.rawValue)
                table.add(column: "delivery_address", .text)
                table.add(column: "cake_notes", .text)
            }
        }

        migrator.registerMigration("0008_add_order_recipe_link") { db in
            try db.alter(table: "orders") { table in
                table.add(column: "recipe_id", .text)
                    .references("recipes", onDelete: .setNull)
            }
        }

        migrator.registerMigration("0009_create_order_recipe_usages") { db in
            try db.create(table: "order_recipe_usages") { table in
                table.column("id", .text).primaryKey()
                table.column("order_id", .text)
                    .notNull()
                    .unique()
                    .references("orders", onDelete: .cascade)
                table.column("recipe_id", .text)
                    .notNull()
                    .references("recipes", onDelete: .restrict)
                table.column("used_at_unix_time", .double).notNull()
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }
        }

        migrator.registerMigration("0010_create_order_checklist_items") { db in
            try db.create(table: "order_checklist_items") { table in
                table.column("id", .text).primaryKey()
                table.column("order_id", .text)
                    .notNull()
                    .references("orders", onDelete: .cascade)
                table.column("title", .text).notNull()
                table.column("is_completed", .boolean).notNull().defaults(to: false)
                table.column("sort_order", .integer).notNull()
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }
        }

        migrator.registerMigration("0011_add_order_pricing_summary") { db in
            try db.alter(table: "orders") { table in
                table.add(column: "quoted_price_decimal", .text)
                table.add(column: "deposit_paid_decimal", .text)
                table.add(column: "payment_notes", .text)
            }
        }

        migrator.registerMigration("0012_create_order_photos") { db in
            try db.create(table: "order_photos") { table in
                table.column("id", .text).primaryKey()
                table.column("order_id", .text)
                    .notNull()
                    .references("orders", onDelete: .cascade)
                table.column("kind", .text).notNull()
                table.column("local_photo_path", .text).notNull()
                table.column("caption", .text)
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }
        }

        migrator.registerMigration("0013_add_order_recipe_scaling") { db in
            try db.alter(table: "orders") { table in
                table.add(column: "recipe_scale_multiplier_decimal", .text)
                    .notNull()
                    .defaults(to: "1")
            }

            try db.alter(table: "order_recipe_usages") { table in
                table.add(column: "recipe_scale_multiplier_decimal", .text)
                    .notNull()
                    .defaults(to: "1")
            }
        }

        migrator.registerMigration("0014_add_order_cake_message") { db in
            try db.alter(table: "orders") { table in
                table.add(column: "cake_message", .text)
            }
        }

        migrator.registerMigration("0015_add_inventory_batch_unit_cost") { db in
            try db.alter(table: "inventory_stock_batches") { table in
                table.add(column: "unit_cost_decimal", .text)
            }
        }

        migrator.registerMigration("0016_add_inventory_batch_amount") { db in
            try db.alter(table: "inventory_stock_batches") { table in
                table.add(column: "amount_decimal", .text)
            }

            try db.execute(
                sql: """
                    UPDATE inventory_stock_batches
                    SET amount_decimal = unit_cost_decimal
                    WHERE amount_decimal IS NULL
                    AND unit_cost_decimal IS NOT NULL
                    """
            )
        }

        migrator.registerMigration("0017_create_order_extra_ingredients") { db in
            try db.create(table: "order_extra_ingredients") { table in
                table.column("id", .text).primaryKey()
                table.column("order_id", .text)
                    .notNull()
                    .references("orders", onDelete: .cascade)
                table.column("inventory_item_id", .text)
                    .notNull()
                    .references("inventory_items", onDelete: .restrict)
                table.column("quantity", .double).notNull()
                table.column("unit", .text).notNull()
                table.column("note", .text)
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }
        }

        migrator.registerMigration("0018_add_inventory_aliases") { db in
            try db.alter(table: "inventory_items") { table in
                table.add(column: "aliases_json", .text).notNull().defaults(to: "[]")
            }
        }

        migrator.registerMigration("0019_add_inventory_type") { db in
            try db.alter(table: "inventory_items") { table in
                table.add(column: "inventory_type", .text).notNull().defaults(to: InventoryItemType.standard.rawValue)
            }
        }

        migrator.registerMigration("0020_add_cake_design_provenance") { db in
            try db.alter(table: "cake_designs") { table in
                table.add(column: "source_kind", .text)
                    .notNull()
                    .defaults(to: CakeDesignSourceKind.ownerMade.rawValue)
                table.add(column: "originating_order_photo_id", .text)
                    .references("order_photos", onDelete: .setNull)
                table.add(column: "originating_order_id", .text)
                    .references("orders", onDelete: .setNull)
            }

            try db.create(
                index: "cake_designs_on_source_kind",
                on: "cake_designs",
                columns: ["source_kind"]
            )
        }

        migrator.registerMigration("0021_create_design_photo_cleanups") { db in
            try db.create(table: "design_photo_cleanups") { table in
                table.column("relative_path", .text).primaryKey()
                table.column("created_at_unix_time", .double).notNull()
            }
        }

        return migrator
    }
}
