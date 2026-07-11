import Foundation
import GRDB

extension GRDBCoreDataRepository {
    func save(_ order: Order) throws {
        try writer.write { db in
            try save(order, in: db)
        }
    }

    func fetchOrder(id: String) throws -> Order? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM orders WHERE id = ?", arguments: [id]) else {
                return nil
            }

            return order(from: row)
        }
    }

    func fetchOrders() throws -> [Order] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM orders
                    ORDER BY due_at_unix_time ASC, lower(title), title
                    """
            ).map(order)
        }
    }

    func changeOrderStatus(
        order: Order,
        status: OrderStatus,
        updatedAt: Date,
        usageId: String,
        extraIngredients: [OrderExtraIngredient]? = nil,
        transactionIdProvider: () -> String
    ) throws -> Order {
        let updatedOrder = Order(
            id: order.id,
            customerId: order.customerId,
            cakeDesignId: order.cakeDesignId,
            recipeId: order.recipeId,
            recipeScaleMultiplier: order.recipeScaleMultiplier,
            title: order.title,
            customerName: order.customerName,
            status: status,
            dueAt: order.dueAt,
            fulfillmentType: order.fulfillmentType,
            deliveryAddress: order.deliveryAddress,
            cakeNotes: order.cakeNotes,
            cakeMessage: order.cakeMessage,
            quotedPrice: order.quotedPrice,
            depositPaid: order.depositPaid,
            paymentNotes: order.paymentNotes,
            createdAt: order.createdAt,
            updatedAt: updatedAt
        )

        try writer.write { db in
            if let extraIngredients {
                try replaceOrderExtraIngredients(orderId: order.id, with: extraIngredients, in: db)
            }

            if shouldRecordRecipeUsage(from: order.status, to: status), let recipeId = order.recipeId {
                try recordRecipeUsageIfNeeded(
                    order: order,
                    recipeId: recipeId,
                    usageId: usageId,
                    usedAt: updatedAt,
                    transactionIdProvider: transactionIdProvider,
                    in: db
                )
            }

            try save(updatedOrder, in: db)
        }

        return updatedOrder
    }

    func fetchOrderRecipeUsage(orderId: String) throws -> OrderRecipeUsage? {
        try writer.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM order_recipe_usages WHERE order_id = ?",
                arguments: [orderId]
            ) else {
                return nil
            }

            return orderRecipeUsage(from: row)
        }
    }

    func save(_ ingredient: OrderExtraIngredient) throws {
        try writer.write { db in
            try save(ingredient, in: db)
        }
    }

    func fetchOrderExtraIngredients(orderId: String) throws -> [OrderExtraIngredient] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM order_extra_ingredients
                    WHERE order_id = ?
                    ORDER BY created_at_unix_time ASC, id
                    """,
                arguments: [orderId]
            ).compactMap { row in
                guard let unit = InventoryUnit(rawValue: row["unit"] as String) else {
                    return nil
                }

                return orderExtraIngredient(from: row, unit: unit)
            }
        }
    }

    func deleteOrderExtraIngredient(id: String) throws {
        try writer.write { db in
            try db.execute(
                sql: "DELETE FROM order_extra_ingredients WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func recordRecipeUsage(
        for order: Order,
        usageId: String,
        usedAt: Date,
        transactionIdProvider: () -> String
    ) throws {
        guard let recipeId = order.recipeId else {
            throw OrderRecipeUsageError.orderHasNoLinkedRecipe
        }

        try writer.write { db in
            try recordRecipeUsage(
                order: order,
                recipeId: recipeId,
                usageId: usageId,
                usedAt: usedAt,
                transactionIdProvider: transactionIdProvider,
                in: db
            )
        }
    }

    func save(_ item: OrderChecklistItem) throws {
        try writer.write { db in
            try save(item, in: db)
        }
    }

    func fetchOrderChecklistItems(orderId: String) throws -> [OrderChecklistItem] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM order_checklist_items
                    WHERE order_id = ?
                    ORDER BY sort_order ASC, created_at_unix_time ASC, id
                    """,
                arguments: [orderId]
            ).map(orderChecklistItem)
        }
    }

    func deleteOrderChecklistItem(id: String) throws {
        try writer.write { db in
            try db.execute(
                sql: "DELETE FROM order_checklist_items WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func save(_ photo: OrderPhoto) throws {
        try writer.write { db in
            try save(photo, in: db)
        }
    }

    func save(_ photo: OrderPhoto, in db: Database) throws {
        try db.execute(
                sql: """
                    INSERT INTO order_photos
                    (id, order_id, kind, local_photo_path, caption, tags_json, is_favorite,
                     created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                    order_id = excluded.order_id,
                    kind = excluded.kind,
                    local_photo_path = excluded.local_photo_path,
                    caption = excluded.caption,
                    tags_json = excluded.tags_json,
                    is_favorite = excluded.is_favorite,
                    created_at_unix_time = excluded.created_at_unix_time,
                    updated_at_unix_time = excluded.updated_at_unix_time
                    """,
                arguments: arguments([
                    photo.id,
                    photo.orderId,
                    photo.kind.rawValue,
                    photo.localPhotoPath,
                    photo.caption,
                    designTagsJSON(photo.tags),
                    photo.isFavorite,
                    photo.createdAt.timeIntervalSince1970,
                    photo.updatedAt.timeIntervalSince1970
                ])
        )
    }

    func fetchOrderPhotos(orderId: String) throws -> [OrderPhoto] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM order_photos
                    WHERE order_id = ?
                    ORDER BY kind ASC, created_at_unix_time ASC, id
                    """,
                arguments: [orderId]
            ).compactMap(orderPhoto)
        }
    }

    func fetchOrderPhotos(kind: OrderPhotoKind) throws -> [OrderPhoto] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM order_photos
                    WHERE kind = ?
                    ORDER BY created_at_unix_time DESC, id
                    """,
                arguments: [kind.rawValue]
            ).compactMap(orderPhoto)
        }
    }

    func deleteOrderPhoto(id: String) throws {
        try deleteOrderPhoto(id: id, cleanupRelativePath: nil)
    }

    func deleteOrderPhoto(id: String, cleanupRelativePath: String?) throws {
        try writer.write { db in
            try db.execute(
                sql: "DELETE FROM order_photos WHERE id = ?",
                arguments: [id]
            )
            if let cleanupRelativePath {
                try db.execute(
                    sql: """
                        INSERT OR IGNORE INTO design_photo_cleanups
                        (relative_path, created_at_unix_time)
                        VALUES (?, ?)
                        """,
                    arguments: [cleanupRelativePath, Date().timeIntervalSince1970]
                )
            }
        }
    }

    func savePromotedDesign(
        _ design: CakeDesign,
        linking order: Order,
        photo: OrderPhoto,
        cleanupRelativePath: String?
    ) throws {
        try writer.write { db in
            if let originatingPhotoId = design.originatingOrderPhotoId {
                let existingCount = try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*) FROM cake_designs
                        WHERE originating_order_photo_id = ? AND id != ?
                        """,
                    arguments: [originatingPhotoId, design.id]
                ) ?? 0
                if existingCount > 0 {
                    throw CakeDesignPromotionError.originatingPhotoAlreadyPromoted
                }
            }
            try save(design, in: db)
            try save(order, in: db)
            try save(photo, in: db)
            if let cleanupRelativePath {
                try db.execute(
                    sql: """
                        INSERT OR IGNORE INTO design_photo_cleanups
                        (relative_path, created_at_unix_time)
                        VALUES (?, ?)
                        """,
                    arguments: [cleanupRelativePath, design.updatedAt.timeIntervalSince1970]
                )
            }
        }
    }

    func fetchPendingDesignPhotoCleanupPaths() throws -> [String] {
        try writer.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT relative_path FROM design_photo_cleanups ORDER BY created_at_unix_time, relative_path"
            )
        }
    }

    func deletePendingDesignPhotoCleanupPath(_ relativePath: String) throws {
        try writer.write { db in
            try db.execute(
                sql: "DELETE FROM design_photo_cleanups WHERE relative_path = ?",
                arguments: [relativePath]
            )
        }
    }
}

private extension GRDBCoreDataRepository {
    struct PendingInventoryUsage {
        let item: InventoryItem
        var quantity: Double
    }

    func ensureOrderRecipeUsageIsNotRecorded(orderId: String, in db: Database) throws {
        let existingUsageCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM order_recipe_usages WHERE order_id = ?",
            arguments: [orderId]
        ) ?? 0
        guard existingUsageCount == 0 else {
            throw OrderRecipeUsageError.alreadyRecorded
        }
    }

    func hasOrderRecipeUsage(orderId: String, in db: Database) throws -> Bool {
        let existingUsageCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM order_recipe_usages WHERE order_id = ?",
            arguments: [orderId]
        ) ?? 0
        return existingUsageCount > 0
    }

    func recordRecipeUsageIfNeeded(
        order: Order,
        recipeId: String,
        usageId: String,
        usedAt: Date,
        transactionIdProvider: () -> String,
        in db: Database
    ) throws {
        guard try !hasOrderRecipeUsage(orderId: order.id, in: db) else {
            return
        }

        try recordRecipeUsage(
            order: order,
            recipeId: recipeId,
            usageId: usageId,
            usedAt: usedAt,
            transactionIdProvider: transactionIdProvider,
            in: db
        )
    }

    func shouldRecordRecipeUsage(from currentStatus: OrderStatus, to newStatus: OrderStatus) -> Bool {
        currentStatus == .confirmed && (newStatus == .ready || newStatus == .completed)
    }

    func recordRecipeUsage(
        order: Order,
        recipeId: String,
        usageId: String,
        usedAt: Date,
        transactionIdProvider: () -> String,
        in db: Database
    ) throws {
        try ensureOrderRecipeUsageIsNotRecorded(orderId: order.id, in: db)
        let pendingUsages = try pendingInventoryUsages(
            recipeId: recipeId,
            orderId: order.id,
            scaleMultiplier: order.recipeScaleMultiplier,
            in: db
        )
        try validateStock(for: pendingUsages, in: db)
        try applyRecipeUsage(
            pendingUsages,
            order: order,
            usedAt: usedAt,
            transactionIdProvider: transactionIdProvider,
            in: db
        )
        try save(
            OrderRecipeUsage(
                id: usageId,
                orderId: order.id,
                recipeId: recipeId,
                recipeScaleMultiplier: order.recipeScaleMultiplier,
                usedAt: usedAt,
                createdAt: usedAt,
                updatedAt: usedAt
            ),
            in: db
        )
    }

    func save(_ order: Order, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO orders
                (
                    id,
                    customer_id,
                    cake_design_id,
                    recipe_id,
                    recipe_scale_multiplier_decimal,
                    title,
                    customer_name,
                    status,
                    due_at_unix_time,
                    fulfillment_type,
                    delivery_address,
                    cake_notes,
                    cake_message,
                    quoted_price_decimal,
                    deposit_paid_decimal,
                    payment_notes,
                    created_at_unix_time,
                    updated_at_unix_time
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                customer_id = excluded.customer_id,
                cake_design_id = excluded.cake_design_id,
                recipe_id = excluded.recipe_id,
                recipe_scale_multiplier_decimal = excluded.recipe_scale_multiplier_decimal,
                title = excluded.title,
                customer_name = excluded.customer_name,
                status = excluded.status,
                due_at_unix_time = excluded.due_at_unix_time,
                fulfillment_type = excluded.fulfillment_type,
                delivery_address = excluded.delivery_address,
                cake_notes = excluded.cake_notes,
                cake_message = excluded.cake_message,
                quoted_price_decimal = excluded.quoted_price_decimal,
                deposit_paid_decimal = excluded.deposit_paid_decimal,
                payment_notes = excluded.payment_notes,
                created_at_unix_time = excluded.created_at_unix_time,
                updated_at_unix_time = excluded.updated_at_unix_time
                """,
            arguments: arguments([
                order.id,
                order.customerId,
                order.cakeDesignId,
                order.recipeId,
                decimalString(order.recipeScaleMultiplier),
                order.title,
                order.customerName,
                order.status.rawValue,
                order.dueAt.timeIntervalSince1970,
                order.fulfillmentType.rawValue,
                order.deliveryAddress,
                order.cakeNotes,
                order.cakeMessage,
                decimalString(order.quotedPrice),
                decimalString(order.depositPaid),
                order.paymentNotes,
                order.createdAt.timeIntervalSince1970,
                order.updatedAt.timeIntervalSince1970
            ])
        )
    }

    func save(_ item: OrderChecklistItem, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO order_checklist_items
                (id, order_id, title, is_completed, sort_order, created_at_unix_time, updated_at_unix_time)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                order_id = excluded.order_id,
                title = excluded.title,
                is_completed = excluded.is_completed,
                sort_order = excluded.sort_order,
                created_at_unix_time = excluded.created_at_unix_time,
                updated_at_unix_time = excluded.updated_at_unix_time
                """,
            arguments: arguments([
                item.id,
                item.orderId,
                item.title,
                item.isCompleted,
                item.sortOrder,
                item.createdAt.timeIntervalSince1970,
                item.updatedAt.timeIntervalSince1970
            ])
        )
    }

    func save(_ ingredient: OrderExtraIngredient, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO order_extra_ingredients
                (id, order_id, inventory_item_id, quantity, unit, note, created_at_unix_time, updated_at_unix_time)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                order_id = excluded.order_id,
                inventory_item_id = excluded.inventory_item_id,
                quantity = excluded.quantity,
                unit = excluded.unit,
                note = excluded.note,
                created_at_unix_time = excluded.created_at_unix_time,
                updated_at_unix_time = excluded.updated_at_unix_time
                """,
            arguments: arguments([
                ingredient.id,
                ingredient.orderId,
                ingredient.inventoryItemId,
                ingredient.quantity,
                ingredient.unit.rawValue,
                ingredient.note,
                ingredient.createdAt.timeIntervalSince1970,
                ingredient.updatedAt.timeIntervalSince1970
            ])
        )
    }

    func replaceOrderExtraIngredients(
        orderId: String,
        with ingredients: [OrderExtraIngredient],
        in db: Database
    ) throws {
        try db.execute(
            sql: "DELETE FROM order_extra_ingredients WHERE order_id = ?",
            arguments: [orderId]
        )

        for ingredient in ingredients {
            try save(ingredient, in: db)
        }
    }

    func pendingInventoryUsages(recipeId: String, orderId: String, scaleMultiplier: Decimal = 1, in db: Database) throws -> [PendingInventoryUsage] {
        let ingredients = try recipeIngredients(recipeId: recipeId, in: db)
        let extraIngredients = try orderExtraIngredients(orderId: orderId, in: db)
        guard !ingredients.isEmpty || !extraIngredients.isEmpty else {
            throw OrderRecipeUsageError.recipeHasNoIngredients
        }

        var pendingUsagesByItemId: [String: PendingInventoryUsage] = [:]
        for ingredient in ingredients {
            guard let item = try inventoryItem(id: ingredient.inventoryItemId, in: db) else {
                throw OrderRecipeUsageError.missingInventoryItem(ingredient.inventoryItemId)
            }
            guard let convertedQuantity = ingredient.unit.convertedQuantity(ingredient.quantity, to: item.unit) else {
                throw OrderRecipeUsageError.incompatibleIngredientUnit(itemName: item.name)
            }
            let requiredQuantity = convertedQuantity * NSDecimalNumber(decimal: scaleMultiplier).doubleValue
            guard requiredQuantity > 0 else {
                continue
            }

            if var pendingUsage = pendingUsagesByItemId[item.id] {
                pendingUsage.quantity += requiredQuantity
                pendingUsagesByItemId[item.id] = pendingUsage
            } else {
                pendingUsagesByItemId[item.id] = PendingInventoryUsage(item: item, quantity: requiredQuantity)
            }
        }
        for ingredient in extraIngredients {
            guard let item = try inventoryItem(id: ingredient.inventoryItemId, in: db) else {
                throw OrderRecipeUsageError.missingInventoryItem(ingredient.inventoryItemId)
            }
            guard let requiredQuantity = ingredient.unit.convertedQuantity(ingredient.quantity, to: item.unit) else {
                throw OrderRecipeUsageError.incompatibleIngredientUnit(itemName: item.name)
            }
            guard requiredQuantity > 0 else {
                continue
            }

            if var pendingUsage = pendingUsagesByItemId[item.id] {
                pendingUsage.quantity += requiredQuantity
                pendingUsagesByItemId[item.id] = pendingUsage
            } else {
                pendingUsagesByItemId[item.id] = PendingInventoryUsage(item: item, quantity: requiredQuantity)
            }
        }

        let pendingUsages = pendingUsagesByItemId.values.sorted { lhs, rhs in
            lhs.item.name.localizedCaseInsensitiveCompare(rhs.item.name) == .orderedAscending
        }
        guard !pendingUsages.isEmpty else {
            throw OrderRecipeUsageError.recipeHasNoIngredients
        }

        return pendingUsages
    }

    func orderExtraIngredients(orderId: String, in db: Database) throws -> [OrderExtraIngredient] {
        try Row.fetchAll(
            db,
            sql: """
                SELECT * FROM order_extra_ingredients
                WHERE order_id = ?
                ORDER BY created_at_unix_time ASC, id
                """,
            arguments: [orderId]
        ).compactMap { row in
            guard let unit = InventoryUnit(rawValue: row["unit"] as String) else {
                return nil
            }

            return orderExtraIngredient(from: row, unit: unit)
        }
    }

    func validateStock(for pendingUsages: [PendingInventoryUsage], in db: Database) throws {
        for pendingUsage in pendingUsages {
            guard pendingUsage.item.currentQuantity - pendingUsage.quantity >= 0 else {
                throw OrderRecipeUsageError.insufficientStock(itemName: pendingUsage.item.name)
            }

            let batches = try inventoryStockBatches(inventoryItemId: pendingUsage.item.id, in: db)
            if !batches.isEmpty {
                let availableBatchQuantity = batches.reduce(0) { $0 + $1.remainingQuantity }
                guard availableBatchQuantity - pendingUsage.quantity >= 0 else {
                    throw OrderRecipeUsageError.insufficientStock(itemName: pendingUsage.item.name)
                }
            }
        }
    }

    func applyRecipeUsage(
        _ pendingUsages: [PendingInventoryUsage],
        order: Order,
        usedAt: Date,
        transactionIdProvider: () -> String,
        in db: Database
    ) throws {
        for pendingUsage in pendingUsages {
            let item = pendingUsage.item
            let updatedItem = InventoryItem(
                id: item.id,
                name: item.name,
                aliases: item.aliases,
                type: item.type,
                unit: item.unit,
                currentQuantity: item.currentQuantity - pendingUsage.quantity,
                minimumQuantity: item.minimumQuantity,
                earliestExpiryAt: item.earliestExpiryAt,
                hasExpiredStock: item.hasExpiredStock,
                hasExpiringSoonStock: item.hasExpiringSoonStock,
                createdAt: item.createdAt,
                updatedAt: usedAt,
                archivedAt: item.archivedAt
            )
            let batches = try inventoryStockBatches(inventoryItemId: item.id, in: db)
            try consume(quantity: pendingUsage.quantity, from: batches, updatedAt: usedAt, in: db)
            try save(updatedItem, in: db)
            try save(
                InventoryTransaction(
                    id: transactionIdProvider(),
                    inventoryItemId: item.id,
                    kind: .consumption,
                    quantity: pendingUsage.quantity,
                    occurredAt: usedAt,
                    note: "Order recipe usage: \(order.title)",
                    createdAt: usedAt,
                    updatedAt: usedAt
                ),
                in: db
            )
        }
    }

    func save(_ usage: OrderRecipeUsage, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO order_recipe_usages
                (id, order_id, recipe_id, recipe_scale_multiplier_decimal, used_at_unix_time, created_at_unix_time, updated_at_unix_time)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: arguments([
                usage.id,
                usage.orderId,
                usage.recipeId,
                decimalString(usage.recipeScaleMultiplier),
                usage.usedAt.timeIntervalSince1970,
                usage.createdAt.timeIntervalSince1970,
                usage.updatedAt.timeIntervalSince1970
            ])
        )
    }
}
