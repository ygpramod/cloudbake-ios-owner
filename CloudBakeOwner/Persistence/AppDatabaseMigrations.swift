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

        migrator.registerMigration("0022_add_design_source_metadata") { db in
            try db.alter(table: "cake_designs") { table in
                table.add(column: "source_name", .text)
                table.add(column: "source_url", .text)
            }
        }

        migrator.registerMigration("0023_add_design_tags_and_favorites") { db in
            try db.alter(table: "cake_designs") { table in
                table.add(column: "tags_json", .text).notNull().defaults(to: "[]")
                table.add(column: "is_favorite", .boolean).notNull().defaults(to: false)
            }
            try db.alter(table: "order_photos") { table in
                table.add(column: "tags_json", .text).notNull().defaults(to: "[]")
                table.add(column: "is_favorite", .boolean).notNull().defaults(to: false)
            }
        }

        migrator.registerMigration("0024_unique_design_origin_photo") { db in
            try db.execute(
                sql: """
                    UPDATE cake_designs AS duplicate
                    SET originating_order_photo_id = NULL
                    WHERE originating_order_photo_id IS NOT NULL
                      AND EXISTS (
                        SELECT 1
                        FROM cake_designs AS keeper
                        WHERE keeper.originating_order_photo_id = duplicate.originating_order_photo_id
                          AND (
                            keeper.created_at_unix_time < duplicate.created_at_unix_time
                            OR (
                              keeper.created_at_unix_time = duplicate.created_at_unix_time
                              AND keeper.id < duplicate.id
                            )
                          )
                      )
                    """
            )
            try db.execute(
                sql: """
                    CREATE UNIQUE INDEX cake_designs_on_originating_order_photo_id
                    ON cake_designs(originating_order_photo_id)
                    WHERE originating_order_photo_id IS NOT NULL
                    """
            )
        }

        migrator.registerMigration("0025_add_order_customer_reference") { db in
            try db.alter(table: "orders") { table in
                table.add(column: "customer_reference_photo_id", .text)
                    .references("order_photos", onDelete: .setNull)
            }
            try db.create(
                index: "orders_on_customer_reference_photo_id",
                on: "orders",
                columns: ["customer_reference_photo_id"]
            )
        }

        migrator.registerMigration("0026_add_design_portfolio_publication") { db in
            try db.alter(table: "cake_designs") { table in
                table.add(column: "is_portfolio_published", .boolean)
                    .notNull()
                    .defaults(to: false)
            }
        }

        migrator.registerMigration("0027_add_order_ingredient_costs") { db in
            try db.execute(
                sql: """
                    UPDATE inventory_stock_batches
                    SET unit_cost_decimal = NULL
                    WHERE amount_decimal IS NOT NULL
                    """
            )

            try db.create(table: "order_ingredient_costs") { table in
                table.column("id", .text).primaryKey()
                table.column("order_id", .text)
                    .notNull()
                    .references("orders", onDelete: .cascade)
                table.column("inventory_item_id", .text)
                    .notNull()
                    .references("inventory_items", onDelete: .restrict)
                table.column("quantity", .double).notNull()
                table.column("unit", .text).notNull()
                table.column("known_cost_decimal", .text).notNull()
                table.column("missing_price_quantity", .double).notNull()
                table.column("recorded_at_unix_time", .double).notNull()
                table.uniqueKey(["order_id", "inventory_item_id"])
            }
        }

        migrator.registerMigration("0028_add_inventory_default_expiry_days") { db in
            try db.alter(table: "inventory_items") { table in
                table.add(column: "default_expiry_days", .integer)
            }
        }

        migrator.registerMigration("0029_add_order_ingredient_shortfall") { db in
            try db.alter(table: "order_ingredient_costs") { table in
                table.add(column: "shortfall_quantity", .double)
                    .notNull()
                    .defaults(to: 0)
            }
        }

        migrator.registerMigration("0030_create_order_inventory_reservations") { db in
            try db.create(table: "order_inventory_reservations") { table in
                table.column("id", .text).primaryKey()
                table.column("order_id", .text)
                    .notNull()
                    .references("orders", onDelete: .cascade)
                table.column("inventory_item_id", .text)
                    .notNull()
                    .references("inventory_items", onDelete: .restrict)
                table.column("required_quantity", .double)
                    .notNull()
                    .check { $0 > 0 }
                table.column("unit", .text)
                    .notNull()
                    .check(
                        sql: """
                            unit IN (
                                'kilogram', 'gram', 'liter', 'milliliter',
                                'teaspoon', 'tablespoon', 'cup', 'each'
                            )
                            """
                    )
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
                table.uniqueKey(["order_id", "inventory_item_id"])
            }
            try db.create(
                index: "order_inventory_reservations_on_inventory_item_id",
                on: "order_inventory_reservations",
                columns: ["inventory_item_id"]
            )

            try db.create(table: "order_inventory_reservation_events") { table in
                table.column("id", .text).primaryKey()
                table.column("order_id", .text)
                    .notNull()
                    .references("orders", onDelete: .restrict)
                table.column("inventory_item_id", .text)
                    .notNull()
                    .references("inventory_items", onDelete: .restrict)
                table.column("event_kind", .text)
                    .notNull()
                    .check(sql: "event_kind IN ('created', 'quantityChanged', 'released', 'repairFailed')")
                table.column("reason", .text)
                    .notNull()
                    .check(
                        sql: """
                            reason IN (
                                'orderConfirmed',
                                'orderEdited',
                                'orderReopened',
                                'orderCancelled',
                                'inventoryConsumed',
                                'recipeEdited',
                                'migrationRepair'
                            )
                            """
                    )
                table.column("previous_quantity", .double)
                    .notNull()
                    .check { $0 >= 0 }
                table.column("new_quantity", .double)
                    .notNull()
                    .check { $0 >= 0 }
                table.column("unit", .text)
                    .notNull()
                    .check(
                        sql: """
                            unit IN (
                                'kilogram', 'gram', 'liter', 'milliliter',
                                'teaspoon', 'tablespoon', 'cup', 'each'
                            )
                            """
                    )
                table.column("occurred_at_unix_time", .double).notNull()
            }
            try db.create(
                index: "order_inventory_reservation_events_on_order_occurred_at",
                on: "order_inventory_reservation_events",
                columns: ["order_id", "occurred_at_unix_time"]
            )

            try db.create(table: "order_inventory_reservation_repairs") { table in
                table.column("order_id", .text)
                    .primaryKey()
                    .references("orders", onDelete: .cascade)
                table.column("state", .text)
                    .notNull()
                    .check(sql: "state IN ('pending', 'complete', 'failed')")
                table.column("attempt_count", .integer)
                    .notNull()
                    .defaults(to: 0)
                    .check { $0 >= 0 }
                table.column("last_attempted_at_unix_time", .double)
                table.column("failure_code", .text)
                    .check(
                        sql: """
                            failure_code IS NULL OR failure_code IN (
                                'missingInventoryItem',
                                'incompatibleUnit',
                                'invalidRequirements'
                            )
                            """
                    )
                table.column("updated_at_unix_time", .double).notNull()
                table.check(
                    sql: """
                        (state = 'failed' AND failure_code IS NOT NULL)
                        OR (state != 'failed' AND failure_code IS NULL)
                        """
                )
            }
            try db.create(
                index: "order_inventory_reservation_repairs_on_state",
                on: "order_inventory_reservation_repairs",
                columns: ["state"]
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_repairs
                    (order_id, state, attempt_count, updated_at_unix_time)
                    SELECT orders.id, 'pending', 0, orders.updated_at_unix_time
                    FROM orders
                    WHERE orders.status IN (?, ?)
                      AND NOT EXISTS (
                        SELECT 1
                        FROM order_recipe_usages
                        WHERE order_recipe_usages.order_id = orders.id
                      )
                    """,
                arguments: [
                    OrderStatus.confirmed.rawValue,
                    OrderStatus.inProgress.rawValue,
                ]
            )
        }

        migrator.registerMigration("0031_allow_incomplete_reservation_repair_events") { db in
            try db.drop(index: "order_inventory_reservation_events_on_order_occurred_at")
            try db.rename(
                table: "order_inventory_reservation_events",
                to: "order_inventory_reservation_events_legacy"
            )
            try db.create(table: "order_inventory_reservation_events") { table in
                table.column("id", .text).primaryKey()
                table.column("order_id", .text)
                    .notNull()
                    .references("orders", onDelete: .restrict)
                table.column("inventory_item_id", .text)
                table.column("event_kind", .text)
                    .notNull()
                    .check(sql: "event_kind IN ('created', 'quantityChanged', 'released', 'repairFailed')")
                table.column("reason", .text)
                    .notNull()
                    .check(
                        sql: """
                            reason IN (
                                'orderConfirmed',
                                'orderEdited',
                                'orderReopened',
                                'orderCancelled',
                                'inventoryConsumed',
                                'recipeEdited',
                                'migrationRepair'
                            )
                            """
                    )
                table.column("previous_quantity", .double)
                    .notNull()
                    .check { $0 >= 0 }
                table.column("new_quantity", .double)
                    .notNull()
                    .check { $0 >= 0 }
                table.column("unit", .text)
                    .check(
                        sql: """
                            unit IS NULL OR unit IN (
                                'kilogram', 'gram', 'liter', 'milliliter',
                                'teaspoon', 'tablespoon', 'cup', 'each'
                            )
                            """
                    )
                table.column("occurred_at_unix_time", .double).notNull()
                table.check(
                    sql: """
                        event_kind = 'repairFailed'
                        OR (inventory_item_id IS NOT NULL AND unit IS NOT NULL)
                        """
                )
            }
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_events
                    (id, order_id, inventory_item_id, event_kind, reason,
                     previous_quantity, new_quantity, unit, occurred_at_unix_time)
                    SELECT id, order_id, inventory_item_id, event_kind, reason,
                           previous_quantity, new_quantity, unit, occurred_at_unix_time
                    FROM order_inventory_reservation_events_legacy
                    """
            )
            try db.drop(table: "order_inventory_reservation_events_legacy")
            try db.create(
                index: "order_inventory_reservation_events_on_order_occurred_at",
                on: "order_inventory_reservation_events",
                columns: ["order_id", "occurred_at_unix_time"]
            )
        }

        migrator.registerMigration("0032_track_reservation_repair_activation") { db in
            try db.alter(table: "order_inventory_reservation_repairs") { table in
                table.add(column: "last_activation_id", .text)
            }
        }

        migrator.registerMigration("0033_add_order_reminder_configurations") { db in
            try db.create(table: "order_reminder_defaults") { table in
                table.column("id", .integer)
                    .primaryKey()
                    .check { $0 == 1 }
                table.column("day_offsets_json", .text).notNull()
                table.column("includes_due_time", .boolean).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }
            try db.execute(
                sql: """
                    INSERT INTO order_reminder_defaults
                    (id, day_offsets_json, includes_due_time, updated_at_unix_time)
                    VALUES (1, '[3,2,1]', 1, 0)
                    """
            )

            try db.create(table: "order_reminder_configurations") { table in
                table.column("order_id", .text)
                    .primaryKey()
                    .references("orders", onDelete: .cascade)
                table.column("mode", .text)
                    .notNull()
                    .check(sql: "mode IN ('defaultSnapshot', 'custom', 'disabled')")
                table.column("day_offsets_json", .text).notNull()
                table.column("includes_due_time", .boolean).notNull()
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }
            try db.execute(
                sql: """
                    INSERT INTO order_reminder_configurations
                    (
                        order_id,
                        mode,
                        day_offsets_json,
                        includes_due_time,
                        created_at_unix_time,
                        updated_at_unix_time
                    )
                    SELECT
                        id,
                        'defaultSnapshot',
                        '[3,2,1]',
                        1,
                        created_at_unix_time,
                        updated_at_unix_time
                    FROM orders
                    """
            )
        }

        migrator.registerMigration("0034_add_order_completed_at") { db in
            try db.alter(table: "orders") { table in
                table.add(column: "completed_at_unix_time", .double)
            }
        }

        migrator.registerMigration("0035_add_payment_reminder_configuration") { db in
            try db.create(table: "payment_reminder_configuration") { table in
                table.column("id", .integer)
                    .primaryKey()
                    .check { $0 == 1 }
                table.column("hour", .integer)
                    .notNull()
                    .check { (0...23).contains($0) }
                table.column("minute", .integer)
                    .notNull()
                    .check { (0...59).contains($0) }
                table.column("updated_at_unix_time", .double).notNull()
            }
            try db.execute(
                sql: """
                    INSERT INTO payment_reminder_configuration
                    (id, hour, minute, updated_at_unix_time)
                    VALUES (1, 9, 0, 0)
                    """
            )
        }

        migrator.registerMigration("0036_add_order_query_indexes") { db in
            try db.create(
                index: "orders_on_status_due_id",
                on: "orders",
                columns: ["status", "due_at_unix_time", "id"]
            )
            try db.create(
                index: "orders_on_customer_due_id",
                on: "orders",
                columns: ["customer_id", "due_at_unix_time", "id"]
            )
            try db.create(
                index: "orders_on_status_completed_at_id",
                on: "orders",
                columns: ["status", "completed_at_unix_time", "id"]
            )
        }

        migrator.registerMigration("0037_add_design_usage_query_index") { db in
            try db.create(
                index: "orders_on_design_due_id",
                on: "orders",
                columns: ["cake_design_id", "due_at_unix_time", "id"]
            )
        }

        migrator.registerMigration("0038_add_inventory_expiry_query_index") { db in
            try db.create(
                index: "inventory_batches_on_expiry_remaining_id",
                on: "inventory_stock_batches",
                columns: [
                    "expires_at_unix_time",
                    "remaining_quantity",
                    "id",
                ]
            )
        }

        migrator.registerMigration("0039_add_payment_receipt_ledger") { db in
            try db.alter(table: "orders") { table in
                table.add(column: "legacy_paid_amount_decimal", .text)
                    .notNull()
                    .defaults(to: "0")
            }
            try db.execute(
                sql: """
                    UPDATE orders
                    SET legacy_paid_amount_decimal = COALESCE(deposit_paid_decimal, '0')
                    """
            )

            try db.create(table: "payment_receipts") { table in
                table.column("id", .text).primaryKey()
                table.column("order_id", .text)
                    .notNull()
                    .references("orders", onDelete: .cascade)
                table.column("amount_decimal", .text)
                    .notNull()
                    .check(sql: "CAST(amount_decimal AS REAL) > 0")
                table.column("received_at_unix_time", .double).notNull()
                table.column("note", .text)
                table.column("created_at_unix_time", .double).notNull()
            }
            try db.create(
                index: "payment_receipts_on_received_at_id",
                on: "payment_receipts",
                columns: ["received_at_unix_time", "id"]
            )
            try db.create(
                index: "payment_receipts_on_order_received_at_id",
                on: "payment_receipts",
                columns: ["order_id", "received_at_unix_time", "id"]
            )

            try db.create(table: "payment_receipt_voids") { table in
                table.column("id", .text).primaryKey()
                table.column("receipt_id", .text)
                    .notNull()
                    .unique()
                    .references("payment_receipts", onDelete: .cascade)
                table.column("reason", .text)
                table.column("voided_at_unix_time", .double).notNull()
                table.column("created_at_unix_time", .double).notNull()
            }
        }

        migrator.registerMigration("0040_add_order_templates") { db in
            try db.create(table: "order_templates") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("cake_title", .text).notNull()
                table.column("cake_design_id", .text)
                    .references("cake_designs", onDelete: .setNull)
                table.column("recipe_id", .text)
                    .references("recipes", onDelete: .setNull)
                table.column("recipe_scale_multiplier_decimal", .text).notNull()
                table.column("fulfillment_type", .text).notNull()
                table.column("cake_notes", .text)
                table.column("cake_message", .text)
                table.column("reminder_mode", .text).notNull()
                table.column("reminder_day_offsets_json", .text).notNull()
                table.column("reminder_includes_due_time", .boolean).notNull()
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
            }
            try db.create(
                index: "order_templates_on_name_id",
                on: "order_templates",
                columns: ["name", "id"]
            )

            try db.create(table: "order_template_extra_ingredients") { table in
                table.column("id", .text).primaryKey()
                table.column("template_id", .text)
                    .notNull()
                    .references("order_templates", onDelete: .cascade)
                table.column("inventory_item_id", .text)
                    .notNull()
                    .references("inventory_items", onDelete: .restrict)
                table.column("quantity", .double).notNull()
                table.column("unit", .text).notNull()
                table.column("note", .text)
                table.column("sort_order", .integer).notNull()
            }
            try db.create(
                index: "order_template_extra_ingredients_on_template_order",
                on: "order_template_extra_ingredients",
                columns: ["template_id", "sort_order", "id"]
            )

            try db.create(table: "order_template_checklist_items") { table in
                table.column("id", .text).primaryKey()
                table.column("template_id", .text)
                    .notNull()
                    .references("order_templates", onDelete: .cascade)
                table.column("title", .text).notNull()
                table.column("sort_order", .integer).notNull()
            }
            try db.create(
                index: "order_template_checklist_items_on_template_order",
                on: "order_template_checklist_items",
                columns: ["template_id", "sort_order", "id"]
            )
        }

        migrator.registerMigration("0041_add_structured_order_requirements") { db in
            for tableName in ["orders", "order_templates"] {
                try db.alter(table: tableName) { table in
                    table.add(column: "cake_occasion", .text)
                    table.add(column: "cake_servings", .integer)
                    table.add(column: "cake_size", .text)
                    table.add(column: "cake_weight_kilograms_decimal", .text)
                    table.add(column: "cake_shape", .text)
                    table.add(column: "cake_tiers", .text)
                    table.add(column: "cake_sponge_flavour", .text)
                    table.add(column: "cake_filling", .text)
                    table.add(column: "cake_frosting", .text)
                    table.add(column: "cake_colour_palette", .text)
                    table.add(column: "cake_theme", .text)
                    table.add(column: "cake_topper_requirements", .text)
                    table.add(column: "cake_candles_accessories", .text)
                    table.add(column: "cake_packaging", .text)
                }
            }

            try db.create(table: "order_cake_requirement_choices") { table in
                table.column("id", .text).primaryKey()
                table.column("field", .text).notNull()
                table.column("value", .text).notNull()
                table.column("normalized_value", .text).notNull()
                table.column("created_at_unix_time", .double).notNull()
                table.column("updated_at_unix_time", .double).notNull()
                table.uniqueKey(["field", "normalized_value"])
            }
            try db.create(
                index: "order_cake_requirement_choices_on_field_value",
                on: "order_cake_requirement_choices",
                columns: ["field", "value", "id"]
            )
        }

        migrator.registerMigration("0042_seed_starter_order_templates") { db in
            let timestamp = 0.0
            let reminderDefaults = try Row.fetchOne(
                db,
                sql: "SELECT day_offsets_json, includes_due_time FROM order_reminder_defaults WHERE id = 1"
            )
            let reminderDayOffsetsJSON: String = reminderDefaults?["day_offsets_json"] ?? "[3,2,1]"
            let reminderIncludesDueTime: Bool = reminderDefaults?["includes_due_time"] ?? true

            func insertStarterTemplate(
                id: String,
                name: String,
                occasion: String,
                tiers: String,
                theme: String?,
                packaging: String
            ) throws {
                try db.execute(
                    sql: """
                        INSERT INTO order_templates (
                            id, name, cake_title, recipe_scale_multiplier_decimal,
                            fulfillment_type, reminder_mode, reminder_day_offsets_json,
                            reminder_includes_due_time, cake_occasion, cake_shape, cake_tiers,
                            cake_sponge_flavour, cake_filling, cake_frosting, cake_theme,
                            cake_topper_requirements, cake_candles_accessories, cake_packaging,
                            created_at_unix_time, updated_at_unix_time
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO NOTHING
                        """,
                    arguments: [
                        id,
                        name,
                        name,
                        "1",
                        "pickup",
                        "defaultSnapshot",
                        reminderDayOffsetsJSON,
                        reminderIncludesDueTime,
                        occasion,
                        "Circle",
                        tiers,
                        nil,
                        nil,
                        nil,
                        theme,
                        "None",
                        "None",
                        packaging,
                        timestamp,
                        timestamp,
                    ]
                )
            }

            try insertStarterTemplate(
                id: "starter-template-classic-birthday",
                name: "Classic Birthday Cake",
                occasion: "Birthday",
                tiers: "1",
                theme: nil,
                packaging: "Standard Box"
            )
            try insertStarterTemplate(
                id: "starter-template-chocolate-birthday",
                name: "Chocolate Birthday Cake",
                occasion: "Birthday",
                tiers: "1",
                theme: nil,
                packaging: "Standard Box"
            )
            try insertStarterTemplate(
                id: "starter-template-anniversary",
                name: "Anniversary Cake",
                occasion: "Anniversary",
                tiers: "1",
                theme: "Elegant",
                packaging: "Standard Box"
            )
            try insertStarterTemplate(
                id: "starter-template-baby-shower",
                name: "Baby Shower Cake",
                occasion: "Baby Shower",
                tiers: "1",
                theme: "Baby Shower",
                packaging: "Standard Box"
            )
            try insertStarterTemplate(
                id: "starter-template-floral-celebration",
                name: "Floral Celebration Cake",
                occasion: "Celebration",
                tiers: "1",
                theme: "Floral",
                packaging: "Tall Box"
            )
            try insertStarterTemplate(
                id: "starter-template-two-tier-wedding",
                name: "Two-Tier Wedding Cake",
                occasion: "Wedding",
                tiers: "2",
                theme: "Elegant",
                packaging: "Tall Box"
            )
        }

        return migrator
    }
}
