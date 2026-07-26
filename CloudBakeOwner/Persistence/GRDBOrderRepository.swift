import Foundation
import GRDB

extension GRDBCoreDataRepository {
    func saveRecipeIngredient(
        _ ingredient: RecipeIngredient,
        component: RecipeComponent,
        allowInventoryShortage: Bool
    ) throws {
        try writer.write { db in
            try saveRecipeIngredient(
                ingredient,
                component: component,
                allowInventoryShortage: allowInventoryShortage,
                in: db
            )
        }
    }

    func save(_ ingredient: RecipeIngredient) throws {
        try writer.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM recipe_components WHERE id = ?",
                arguments: [ingredient.componentId]
            ) else {
                throw RecipeIngredientReservationMutationError.componentNotFound
            }
            try saveRecipeIngredient(
                ingredient,
                component: recipeComponent(from: row),
                allowInventoryShortage: false,
                in: db
            )
        }
    }

    func deleteRecipeIngredient(
        id: String,
        updatedAt: Date,
        allowInventoryShortage: Bool
    ) throws {
        try writer.write { db in
            guard let recipeId = try String.fetchOne(
                db,
                sql: """
                    SELECT recipe_components.recipe_id
                    FROM recipe_ingredients
                    JOIN recipe_components
                      ON recipe_components.id = recipe_ingredients.component_id
                    WHERE recipe_ingredients.id = ?
                    """,
                arguments: [id]
            ) else {
                return
            }
            try db.execute(
                sql: "DELETE FROM recipe_ingredients WHERE id = ?",
                arguments: [id]
            )
            try synchronizeReservationsAfterRecipeIngredientMutation(
                recipeId: recipeId,
                at: updatedAt,
                allowInventoryShortage: allowInventoryShortage,
                in: db
            )
        }
    }

    func save(_ order: Order) throws {
        try writer.write { db in
            try save(order, in: db)
        }
    }

    func saveOrder(
        _ order: Order,
        replacingExtraIngredients extraIngredients: [OrderExtraIngredient],
        allowInventoryShortage: Bool
    ) throws {
        try writer.write { db in
            let persistedOrder = try self.order(id: order.id, in: db)
            let previousStatus = persistedOrder?.status
            let isEnteringConsumedStatus = previousStatus != order.status &&
                (order.status == .ready || order.status == .completed)
            if isEnteringConsumedStatus,
               (order.recipeId != nil || persistedOrder?.recipeId != nil),
               try !hasOrderRecipeUsage(orderId: order.id, in: db) {
                throw OrderRecipeUsageError.inventoryConsumptionRequired
            }
            try save(order, in: db)
            try replaceOrderExtraIngredients(
                orderId: order.id,
                with: extraIngredients,
                in: db
            )
            let reason = previousStatus.map {
                $0 == order.status
                    ? OrderInventoryReservationEventReason.orderEdited
                    : reservationEventReason(from: $0, to: order.status)
            } ?? (
                order.status == .confirmed || order.status == .inProgress
                    ? .orderConfirmed
                    : .orderEdited
            )
            try synchronizeOrderInventoryReservation(
                for: order,
                at: order.updatedAt,
                reason: reason,
                allowInventoryShortage: allowInventoryShortage,
                in: db
            )
        }
    }

    func repairOrderInventoryReservations(
        limit: Int,
        at timestamp: Date,
        activationId: String
    ) throws -> OrderInventoryReservationRepairSummary {
        guard (1...50).contains(limit),
              !activationId.isEmpty else {
            throw OrderInventoryReservationQueryError.invalidLimit
        }
        let orderIds = try writer.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT order_id
                    FROM order_inventory_reservation_repairs
                    WHERE state IN (?, ?)
                      AND (
                          last_activation_id IS NULL
                          OR last_activation_id != ?
                      )
                    ORDER BY
                        CASE state WHEN ? THEN 0 ELSE 1 END,
                        updated_at_unix_time,
                        order_id
                    LIMIT ?
                    """,
                arguments: [
                    OrderInventoryReservationRepairState.pending.rawValue,
                    OrderInventoryReservationRepairState.failed.rawValue,
                    activationId,
                    OrderInventoryReservationRepairState.pending.rawValue,
                    limit
                ]
            )
        }
        var completedCount = 0
        var failedCount = 0
        for orderId in orderIds {
            do {
                let didRepair = try writer.write { db -> Bool in
                    guard let order = try order(id: orderId, in: db) else {
                        return false
                    }
                    try synchronizeOrderInventoryReservation(
                        for: order,
                        at: timestamp,
                        reason: .migrationRepair,
                        allowInventoryShortage: true,
                        in: db
                    )
                    try db.execute(
                        sql: """
                            UPDATE order_inventory_reservation_repairs
                            SET state = ?,
                                attempt_count = attempt_count + 1,
                                last_attempted_at_unix_time = ?,
                                failure_code = NULL,
                                last_activation_id = ?,
                                updated_at_unix_time = ?
                            WHERE order_id = ?
                              AND state IN (?, ?)
                            """,
                        arguments: [
                            OrderInventoryReservationRepairState.complete.rawValue,
                            timestamp.timeIntervalSince1970,
                            activationId,
                            timestamp.timeIntervalSince1970,
                            orderId,
                            OrderInventoryReservationRepairState.pending.rawValue,
                            OrderInventoryReservationRepairState.failed.rawValue
                        ]
                    )
                    return db.changesCount > 0
                }
                if didRepair {
                    completedCount += 1
                }
            } catch {
                guard let failure = reservationRepairFailure(for: error) else {
                    throw error
                }
                if try recordReservationRepairFailure(
                    orderId: orderId,
                    failure: failure,
                    at: timestamp,
                    activationId: activationId
                ) {
                    failedCount += 1
                }
            }
        }
        let hasMore = try hasEligibleInventoryReservationRepairs(
            excludingActivationId: activationId
        )
        return OrderInventoryReservationRepairSummary(
            completedCount: completedCount,
            failedCount: failedCount,
            hasMore: hasMore
        )
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
        allowInventoryShortage: Bool = false,
        transactionIdProvider: () -> String
    ) throws -> Order {
        let updatedOrder = Order(
            id: order.id,
            customerId: order.customerId,
            cakeDesignId: order.cakeDesignId,
            customerReferencePhotoId: order.customerReferencePhotoId,
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
            guard let persistedOrder = try self.order(id: order.id, in: db) else {
                throw OrderRecipeUsageError.orderNotFound
            }
            if let extraIngredients {
                try replaceOrderExtraIngredients(orderId: order.id, with: extraIngredients, in: db)
            }

            if shouldRecordRecipeUsage(from: persistedOrder.status, to: status) {
                guard let recipeId = order.recipeId else {
                    throw OrderRecipeUsageError.orderHasNoLinkedRecipe
                }
                try recordRecipeUsageIfNeeded(
                    order: order,
                    recipeId: recipeId,
                    usageId: usageId,
                    usedAt: updatedAt,
                    allowInventoryShortage: allowInventoryShortage,
                    transactionIdProvider: transactionIdProvider,
                    in: db
                )
            }

            try save(updatedOrder, in: db)
            try synchronizeOrderInventoryReservation(
                for: updatedOrder,
                at: updatedAt,
                reason: reservationEventReason(from: persistedOrder.status, to: status),
                allowInventoryShortage: allowInventoryShortage,
                in: db
            )
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

    func fetchOrderIngredientCosts(orderId: String) throws -> [OrderIngredientCost] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM order_ingredient_costs
                    WHERE order_id = ?
                    ORDER BY inventory_item_id
                    """,
                arguments: [orderId]
            ).compactMap { row in
                guard let unit = InventoryUnit(rawValue: row["unit"]),
                      let knownCost = optionalDecimal(row["known_cost_decimal"]) else {
                    return nil
                }
                return OrderIngredientCost(
                    id: row["id"],
                    orderId: row["order_id"],
                    inventoryItemId: row["inventory_item_id"],
                    quantity: row["quantity"],
                    unit: unit,
                    knownCost: knownCost,
                    missingPriceQuantity: row["missing_price_quantity"],
                    shortfallQuantity: row["shortfall_quantity"],
                    recordedAt: date(row["recorded_at_unix_time"])
                )
            }
        }
    }

    func save(_ ingredient: OrderExtraIngredient) throws {
        try writer.write { db in
            let existingOrderId = try String.fetchOne(
                db,
                sql: "SELECT order_id FROM order_extra_ingredients WHERE id = ?",
                arguments: [ingredient.id]
            )
            guard existingOrderId == nil || existingOrderId == ingredient.orderId else {
                throw OrderExtraIngredientError.orderReassignmentNotAllowed
            }
            try save(ingredient, in: db)
            if let order = try order(id: ingredient.orderId, in: db) {
                try synchronizeOrderInventoryReservation(
                    for: order,
                    at: ingredient.updatedAt,
                    reason: .orderEdited,
                    allowInventoryShortage: false,
                    in: db
                )
            }
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
            ).map { row in
                let unitValue: String = row["unit"]
                guard let unit = InventoryUnit(rawValue: unitValue) else {
                    throw OrderInventoryReservationPersistenceError.invalidUnit(unitValue)
                }

                return orderExtraIngredient(from: row, unit: unit)
            }
        }
    }

    func fetchOrderInventoryReservations(orderId: String) throws -> [OrderInventoryReservation] {
        try writer.read { db in
            try reservationRows(
                sql: """
                    SELECT *
                    FROM order_inventory_reservations
                    WHERE order_id = ?
                    ORDER BY inventory_item_id
                    """,
                arguments: [orderId],
                in: db
            )
        }
    }

    func fetchInventoryReservationTotal(
        inventoryItemId: String,
        excludingOrderId: String?
    ) throws -> Double {
        try writer.read { db in
            if let excludingOrderId {
                return try Double.fetchOne(
                    db,
                    sql: """
                        SELECT COALESCE(SUM(required_quantity), 0)
                        FROM order_inventory_reservations
                        WHERE inventory_item_id = ?
                          AND order_id != ?
                        """,
                    arguments: [inventoryItemId, excludingOrderId]
                ) ?? 0
            }
            return try Double.fetchOne(
                db,
                sql: """
                    SELECT COALESCE(SUM(required_quantity), 0)
                    FROM order_inventory_reservations
                    WHERE inventory_item_id = ?
                    """,
                arguments: [inventoryItemId]
            ) ?? 0
        }
    }

    func fetchOrderInventoryReservationEvents(
        orderId: String,
        limit: Int
    ) throws -> [OrderInventoryReservationEvent] {
        guard (1...50).contains(limit) else {
            throw OrderInventoryReservationQueryError.invalidLimit
        }
        return try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT *
                    FROM order_inventory_reservation_events
                    WHERE order_id = ?
                    ORDER BY occurred_at_unix_time DESC, id DESC
                    LIMIT ?
                    """,
                arguments: [orderId, limit]
            ).map { row in
                let kindValue: String = row["event_kind"]
                guard let kind = OrderInventoryReservationEventKind(rawValue: kindValue) else {
                    throw OrderInventoryReservationPersistenceError.invalidEventKind(kindValue)
                }
                let reasonValue: String = row["reason"]
                guard let reason = OrderInventoryReservationEventReason(rawValue: reasonValue) else {
                    throw OrderInventoryReservationPersistenceError.invalidEventReason(reasonValue)
                }
                let unitValue: String? = row["unit"]
                let unit: InventoryUnit?
                if let unitValue {
                    guard let parsedUnit = InventoryUnit(rawValue: unitValue) else {
                        throw OrderInventoryReservationPersistenceError.invalidUnit(unitValue)
                    }
                    unit = parsedUnit
                } else {
                    unit = nil
                }
                return orderInventoryReservationEvent(
                    from: row,
                    kind: kind,
                    reason: reason,
                    unit: unit
                )
            }
        }
    }

    func fetchOrderInventoryReservationRepair(
        orderId: String
    ) throws -> OrderInventoryReservationRepair? {
        try writer.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT *
                    FROM order_inventory_reservation_repairs
                    WHERE order_id = ?
                    """,
                arguments: [orderId]
            ) else {
                return nil
            }
            let stateValue: String = row["state"]
            guard let state = OrderInventoryReservationRepairState(rawValue: stateValue) else {
                throw OrderInventoryReservationPersistenceError.invalidRepairState(stateValue)
            }
            let failureCodeValue: String? = row["failure_code"]
            let failureCode: OrderInventoryReservationRepairFailureCode?
            if let failureCodeValue {
                guard let parsedFailureCode = OrderInventoryReservationRepairFailureCode(
                    rawValue: failureCodeValue
                ) else {
                    throw OrderInventoryReservationPersistenceError.invalidRepairFailureCode(
                        failureCodeValue
                    )
                }
                failureCode = parsedFailureCode
            } else {
                failureCode = nil
            }
            return orderInventoryReservationRepair(
                from: row,
                state: state,
                failureCode: failureCode
            )
        }
    }

    func fetchOrderInventoryReservationPlanningSnapshot(
        orderIds: [String]
    ) throws -> OrderInventoryReservationPlanningSnapshot {
        let uniqueOrderIds = Array(Set(orderIds)).sorted()
        guard !uniqueOrderIds.isEmpty else {
            return .empty
        }

        return try writer.read { db in
            var consumedOrderIds = Set<String>()
            var reservationsByOrderId: [String: [OrderInventoryReservation]] = [:]
            var repairsByOrderId: [String: OrderInventoryReservationRepair] = [:]
            var invalidOrderIds = Set<String>()
            var invalidLiveRequirementOrderIds = Set<String>()
            var liveRequirementsByOrderId: [String: [OrderInventoryRequirement]] = [:]
            var requiredInventoryItemIds = Set<String>()

            for chunkStart in stride(from: 0, to: uniqueOrderIds.count, by: 400) {
                let chunkEnd = min(chunkStart + 400, uniqueOrderIds.count)
                let chunk = Array(uniqueOrderIds[chunkStart..<chunkEnd])
                let placeholders = chunk.map { _ in "?" }.joined(separator: ", ")
                let arguments = StatementArguments(chunk)

                consumedOrderIds.formUnion(
                    try String.fetchAll(
                        db,
                        sql: """
                            SELECT order_id
                            FROM order_recipe_usages
                            WHERE order_id IN (\(placeholders))
                            """,
                        arguments: arguments
                    )
                )
                let reservationRows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT *
                        FROM order_inventory_reservations
                        WHERE order_id IN (\(placeholders))
                        ORDER BY order_id, inventory_item_id
                        """,
                    arguments: arguments
                )
                for row in reservationRows {
                    let orderId: String = row["order_id"]
                    let unitValue: String = row["unit"]
                    let requiredQuantity: Double = row["required_quantity"]
                    guard let unit = InventoryUnit(rawValue: unitValue),
                          requiredQuantity.isFinite,
                          requiredQuantity > 0 else {
                        invalidOrderIds.insert(orderId)
                        continue
                    }
                    reservationsByOrderId[orderId, default: []].append(
                        orderInventoryReservation(from: row, unit: unit)
                    )
                    requiredInventoryItemIds.insert(row["inventory_item_id"])
                }
                let repairRows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT *
                        FROM order_inventory_reservation_repairs
                        WHERE order_id IN (\(placeholders))
                        """,
                    arguments: arguments
                )
                for row in repairRows {
                    let orderId: String = row["order_id"]
                    let stateValue: String = row["state"]
                    guard let state = OrderInventoryReservationRepairState(rawValue: stateValue) else {
                        invalidOrderIds.insert(orderId)
                        continue
                    }
                    let failureCodeValue: String? = row["failure_code"]
                    let failureCode: OrderInventoryReservationRepairFailureCode?
                    if let failureCodeValue {
                        guard let parsedFailureCode = OrderInventoryReservationRepairFailureCode(
                            rawValue: failureCodeValue
                        ) else {
                            invalidOrderIds.insert(orderId)
                            continue
                        }
                        failureCode = parsedFailureCode
                    } else {
                        failureCode = nil
                    }
                    let repair = orderInventoryReservationRepair(
                        from: row,
                        state: state,
                        failureCode: failureCode
                    )
                    repairsByOrderId[repair.orderId] = repair
                }

                let recipeRequirementRows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT orders.id AS order_id,
                               orders.recipe_scale_multiplier_decimal,
                               recipe_ingredients.inventory_item_id,
                               recipe_ingredients.quantity,
                               recipe_ingredients.unit
                        FROM orders
                        JOIN recipe_components
                          ON recipe_components.recipe_id = orders.recipe_id
                        JOIN recipe_ingredients
                          ON recipe_ingredients.component_id = recipe_components.id
                        WHERE orders.id IN (\(placeholders))
                        """,
                    arguments: arguments
                )
                for row in recipeRequirementRows {
                    let orderId: String = row["order_id"]
                    let scaleValue: String = row["recipe_scale_multiplier_decimal"]
                    guard let scale = Decimal(string: scaleValue) else {
                        invalidLiveRequirementOrderIds.insert(orderId)
                        continue
                    }
                    let scaleDouble = NSDecimalNumber(decimal: scale).doubleValue
                    let quantity: Double = row["quantity"]
                    let unitValue: String = row["unit"]
                    guard let unit = InventoryUnit(rawValue: unitValue),
                          scaleDouble.isFinite,
                          scaleDouble > 0,
                          quantity.isFinite,
                          quantity > 0,
                          (quantity * scaleDouble).isFinite else {
                        invalidLiveRequirementOrderIds.insert(orderId)
                        continue
                    }
                    let inventoryItemId: String = row["inventory_item_id"]
                    liveRequirementsByOrderId[orderId, default: []].append(
                        OrderInventoryRequirement(
                            inventoryItemId: inventoryItemId,
                            quantity: quantity * scaleDouble,
                            unit: unit
                        )
                    )
                    requiredInventoryItemIds.insert(inventoryItemId)
                }

                let extraRequirementRows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT order_id, inventory_item_id, quantity, unit
                        FROM order_extra_ingredients
                        WHERE order_id IN (\(placeholders))
                        """,
                    arguments: arguments
                )
                for row in extraRequirementRows {
                    let orderId: String = row["order_id"]
                    let quantity: Double = row["quantity"]
                    let unitValue: String = row["unit"]
                    guard let unit = InventoryUnit(rawValue: unitValue),
                          quantity.isFinite,
                          quantity > 0 else {
                        invalidLiveRequirementOrderIds.insert(orderId)
                        continue
                    }
                    let inventoryItemId: String = row["inventory_item_id"]
                    liveRequirementsByOrderId[orderId, default: []].append(
                        OrderInventoryRequirement(
                            inventoryItemId: inventoryItemId,
                            quantity: quantity,
                            unit: unit
                        )
                    )
                    requiredInventoryItemIds.insert(inventoryItemId)
                }
            }

            var stockBatchesByInventoryItemId: [String: [InventoryStockBatch]] = [:]
            let sortedInventoryItemIds = requiredInventoryItemIds.sorted()
            for chunkStart in stride(from: 0, to: sortedInventoryItemIds.count, by: 400) {
                let chunkEnd = min(chunkStart + 400, sortedInventoryItemIds.count)
                let chunk = Array(sortedInventoryItemIds[chunkStart..<chunkEnd])
                let placeholders = chunk.map { _ in "?" }.joined(separator: ", ")
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT *
                        FROM inventory_stock_batches
                        WHERE inventory_item_id IN (\(placeholders))
                        ORDER BY inventory_item_id, created_at_unix_time, id
                        """,
                    arguments: StatementArguments(chunk)
                )
                for row in rows {
                    let batch = inventoryStockBatch(from: row)
                    stockBatchesByInventoryItemId[
                        batch.inventoryItemId,
                        default: []
                    ].append(batch)
                }
            }

            return OrderInventoryReservationPlanningSnapshot(
                consumedOrderIds: consumedOrderIds,
                reservationsByOrderId: reservationsByOrderId,
                repairsByOrderId: repairsByOrderId,
                invalidOrderIds: invalidOrderIds,
                invalidLiveRequirementOrderIds: invalidLiveRequirementOrderIds,
                liveRequirementsByOrderId: liveRequirementsByOrderId,
                stockBatchesByInventoryItemId: stockBatchesByInventoryItemId
            )
        }
    }

    func deleteOrderExtraIngredient(id: String) throws {
        try deleteOrderExtraIngredient(id: id, updatedAt: Date())
    }

    func deleteOrderExtraIngredient(id: String, updatedAt: Date) throws {
        try writer.write { db in
            let orderId = try String.fetchOne(
                db,
                sql: "SELECT order_id FROM order_extra_ingredients WHERE id = ?",
                arguments: [id]
            )
            try db.execute(
                sql: "DELETE FROM order_extra_ingredients WHERE id = ?",
                arguments: [id]
            )
            if let orderId, let order = try order(id: orderId, in: db) {
                try synchronizeOrderInventoryReservation(
                    for: order,
                    at: updatedAt,
                    reason: .orderEdited,
                    allowInventoryShortage: true,
                    in: db
                )
            }
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

    func fetchOrderPhoto(id: String) throws -> OrderPhoto? {
        try writer.read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT * FROM order_photos WHERE id = ?",
                arguments: [id]
            ).flatMap(orderPhoto)
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

    func saveRecipeIngredient(
        _ ingredient: RecipeIngredient,
        component: RecipeComponent,
        allowInventoryShortage: Bool,
        in db: Database
    ) throws {
        let persistedComponentRecipeId = try String.fetchOne(
            db,
            sql: "SELECT recipe_id FROM recipe_components WHERE id = ?",
            arguments: [component.id]
        )
        guard persistedComponentRecipeId == nil
                || persistedComponentRecipeId == component.recipeId else {
            throw RecipeIngredientReservationMutationError.recipeReassignmentNotAllowed
        }
        guard ingredient.componentId == component.id else {
            throw RecipeIngredientReservationMutationError.componentNotFound
        }
        let existingRecipeId = try String.fetchOne(
            db,
            sql: """
                SELECT recipe_components.recipe_id
                FROM recipe_ingredients
                JOIN recipe_components
                  ON recipe_components.id = recipe_ingredients.component_id
                WHERE recipe_ingredients.id = ?
                """,
            arguments: [ingredient.id]
        )
        guard existingRecipeId == nil || existingRecipeId == component.recipeId else {
            throw RecipeIngredientReservationMutationError.recipeReassignmentNotAllowed
        }

        try persistRecipeComponent(component, in: db)
        try persistRecipeIngredient(ingredient, in: db)
        try synchronizeReservationsAfterRecipeIngredientMutation(
            recipeId: component.recipeId,
            at: ingredient.updatedAt,
            allowInventoryShortage: allowInventoryShortage,
            in: db
        )
    }

    func reservationRows(
        sql: String,
        arguments: StatementArguments,
        in db: Database
    ) throws -> [OrderInventoryReservation] {
        try Row.fetchAll(db, sql: sql, arguments: arguments).map { row in
            let unitValue: String = row["unit"]
            guard let unit = InventoryUnit(rawValue: unitValue) else {
                throw OrderInventoryReservationPersistenceError.invalidUnit(unitValue)
            }
            return orderInventoryReservation(from: row, unit: unit)
        }
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

    func order(id: String, in db: Database) throws -> Order? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM orders WHERE id = ?",
            arguments: [id]
        ) else {
            return nil
        }
        return order(from: row)
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
        allowInventoryShortage: Bool,
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
            allowInventoryShortage: allowInventoryShortage,
            transactionIdProvider: transactionIdProvider,
            in: db
        )
    }

    func shouldRecordRecipeUsage(from currentStatus: OrderStatus, to newStatus: OrderStatus) -> Bool {
        currentStatus.recordsRecipeUsage(whenChangingTo: newStatus)
    }

    func reservationEventReason(
        from currentStatus: OrderStatus,
        to newStatus: OrderStatus
    ) -> OrderInventoryReservationEventReason {
        if newStatus == .confirmed || newStatus == .inProgress {
            return currentStatus == .ready || currentStatus == .completed
                ? .orderReopened
                : .orderConfirmed
        }
        if newStatus == .cancelled {
            return .orderCancelled
        }
        if newStatus == .ready || newStatus == .completed {
            return .inventoryConsumed
        }
        return .orderEdited
    }

    func synchronizeOrderInventoryReservation(
        for order: Order,
        at timestamp: Date,
        reason: OrderInventoryReservationEventReason,
        allowInventoryShortage: Bool,
        in db: Database
    ) throws {
        let hasUsage = try hasOrderRecipeUsage(orderId: order.id, in: db)
        let isEligibleStatus = order.status == .confirmed || order.status == .inProgress
        let pendingUsages: [PendingInventoryUsage]
        if isEligibleStatus, !hasUsage {
            pendingUsages = try pendingInventoryUsages(
                recipeId: order.recipeId,
                orderId: order.id,
                scaleMultiplier: order.recipeScaleMultiplier,
                in: db
            )
            try validateReservationAvailability(
                pendingUsages,
                excludingOrderId: order.id,
                at: timestamp,
                allowInventoryShortage: allowInventoryShortage,
                in: db
            )
        } else {
            pendingUsages = []
        }

        try replaceOrderInventoryReservations(
            orderId: order.id,
            with: pendingUsages,
            at: timestamp,
            reason: reason,
            in: db
        )
        if reason != .migrationRepair {
            try completeInventoryReservationRepairIfNeeded(
                orderId: order.id,
                at: timestamp,
                in: db
            )
        }
    }

    func synchronizeReservationsAfterRecipeIngredientMutation(
        recipeId: String,
        at timestamp: Date,
        allowInventoryShortage: Bool,
        in db: Database
    ) throws {
        let affectedOrders = try Row.fetchAll(
            db,
            sql: """
                SELECT orders.*
                FROM orders
                WHERE orders.recipe_id = ?
                  AND orders.status IN (?, ?)
                  AND NOT EXISTS (
                      SELECT 1
                      FROM order_recipe_usages
                      WHERE order_recipe_usages.order_id = orders.id
                  )
                ORDER BY orders.id
                """,
            arguments: [
                recipeId,
                OrderStatus.confirmed.rawValue,
                OrderStatus.inProgress.rawValue
            ]
        ).map(order)
        guard !affectedOrders.isEmpty else { return }

        let proposedReservations = try affectedOrders.map { order in
            (
                order: order,
                usages: try pendingInventoryUsages(
                    recipeId: recipeId,
                    orderId: order.id,
                    scaleMultiplier: order.recipeScaleMultiplier,
                    in: db
                )
            )
        }
        try validateRecipeReservationAvailability(
            proposedReservations.flatMap { $0.usages },
            recipeId: recipeId,
            at: timestamp,
            allowInventoryShortage: allowInventoryShortage,
            in: db
        )
        for proposedReservation in proposedReservations {
            try replaceOrderInventoryReservations(
                orderId: proposedReservation.order.id,
                with: proposedReservation.usages,
                at: timestamp,
                reason: .recipeEdited,
                in: db
            )
            try completeInventoryReservationRepairIfNeeded(
                orderId: proposedReservation.order.id,
                at: timestamp,
                in: db
            )
        }
    }

    func validateRecipeReservationAvailability(
        _ pendingUsages: [PendingInventoryUsage],
        recipeId: String,
        at timestamp: Date,
        allowInventoryShortage: Bool,
        in db: Database
    ) throws {
        guard !allowInventoryShortage else { return }

        var proposedByItemId: [String: PendingInventoryUsage] = [:]
        for pendingUsage in pendingUsages {
            if var proposed = proposedByItemId[pendingUsage.item.id] {
                proposed.quantity += pendingUsage.quantity
                proposedByItemId[pendingUsage.item.id] = proposed
            } else {
                proposedByItemId[pendingUsage.item.id] = pendingUsage
            }
        }

        let shortages = try proposedByItemId.values.compactMap { proposed -> OrderInventoryShortage? in
            let batches = try inventoryStockBatches(
                inventoryItemId: proposed.item.id,
                in: db
            )
            let usableQuantity = availableInventoryQuantity(
                item: proposed.item,
                batches: batches,
                at: timestamp
            )
            let reservedQuantity = try Double.fetchOne(
                db,
                sql: """
                    SELECT COALESCE(SUM(required_quantity), 0)
                    FROM order_inventory_reservations
                    WHERE inventory_item_id = ?
                    """,
                arguments: [proposed.item.id]
            ) ?? 0
            let affectedExistingQuantity = try Double.fetchOne(
                db,
                sql: """
                    SELECT COALESCE(SUM(order_inventory_reservations.required_quantity), 0)
                    FROM order_inventory_reservations
                    JOIN orders
                      ON orders.id = order_inventory_reservations.order_id
                    WHERE order_inventory_reservations.inventory_item_id = ?
                      AND orders.recipe_id = ?
                      AND orders.status IN (?, ?)
                      AND NOT EXISTS (
                          SELECT 1
                          FROM order_recipe_usages
                          WHERE order_recipe_usages.order_id = orders.id
                      )
                    """,
                arguments: [
                    proposed.item.id,
                    recipeId,
                    OrderStatus.confirmed.rawValue,
                    OrderStatus.inProgress.rawValue
                ]
            ) ?? 0
            let reservedByUnaffectedOrders = max(
                reservedQuantity - affectedExistingQuantity,
                0
            )
            let availableToPromise = max(
                usableQuantity - reservedByUnaffectedOrders,
                0
            )
            guard proposed.quantity > availableToPromise else {
                return nil
            }
            return OrderInventoryShortage(
                inventoryItemId: proposed.item.id,
                inventoryItemName: proposed.item.name,
                requiredQuantity: proposed.quantity,
                availableQuantity: availableToPromise,
                unit: proposed.item.unit
            )
        }
        guard shortages.isEmpty else {
            throw OrderRecipeUsageError.insufficientStock(
                shortages.sorted {
                    $0.inventoryItemName.localizedCaseInsensitiveCompare(
                        $1.inventoryItemName
                    ) == .orderedAscending
                }
            )
        }
    }

    func validateReservationAvailability(
        _ pendingUsages: [PendingInventoryUsage],
        excludingOrderId: String,
        at timestamp: Date,
        allowInventoryShortage: Bool,
        in db: Database
    ) throws {
        guard !allowInventoryShortage else { return }
        let shortages = try pendingUsages.compactMap { pendingUsage -> OrderInventoryShortage? in
            let batches = try inventoryStockBatches(
                inventoryItemId: pendingUsage.item.id,
                in: db
            )
            let usableQuantity = availableInventoryQuantity(
                item: pendingUsage.item,
                batches: batches,
                at: timestamp
            )
            let otherReservedQuantity = try Double.fetchOne(
                db,
                sql: """
                    SELECT COALESCE(SUM(required_quantity), 0)
                    FROM order_inventory_reservations
                    WHERE inventory_item_id = ?
                      AND order_id != ?
                    """,
                arguments: [pendingUsage.item.id, excludingOrderId]
            ) ?? 0
            let availableToPromise = max(usableQuantity - otherReservedQuantity, 0)
            guard pendingUsage.quantity > availableToPromise else {
                return nil
            }
            return OrderInventoryShortage(
                inventoryItemId: pendingUsage.item.id,
                inventoryItemName: pendingUsage.item.name,
                requiredQuantity: pendingUsage.quantity,
                availableQuantity: availableToPromise,
                unit: pendingUsage.item.unit
            )
        }
        guard shortages.isEmpty else {
            throw OrderRecipeUsageError.insufficientStock(shortages)
        }
    }

    func hasEligibleInventoryReservationRepairs(
        excludingActivationId activationId: String
    ) throws -> Bool {
        try writer.read { db in
            try Bool.fetchOne(
                db,
                sql: """
                    SELECT EXISTS (
                        SELECT 1
                        FROM order_inventory_reservation_repairs
                        WHERE state IN (?, ?)
                          AND (
                              last_activation_id IS NULL
                              OR last_activation_id != ?
                          )
                    )
                    """,
                arguments: [
                    OrderInventoryReservationRepairState.pending.rawValue,
                    OrderInventoryReservationRepairState.failed.rawValue,
                    activationId
                ]
            ) ?? false
        }
    }

    func completeInventoryReservationRepairIfNeeded(
        orderId: String,
        at timestamp: Date,
        in db: Database
    ) throws {
        try db.execute(
            sql: """
                UPDATE order_inventory_reservation_repairs
                SET state = ?,
                    failure_code = NULL,
                    updated_at_unix_time = ?
                WHERE order_id = ?
                  AND state IN (?, ?)
                """,
            arguments: [
                OrderInventoryReservationRepairState.complete.rawValue,
                timestamp.timeIntervalSince1970,
                orderId,
                OrderInventoryReservationRepairState.pending.rawValue,
                OrderInventoryReservationRepairState.failed.rawValue
            ]
        )
    }

    func reservationRepairFailure(
        for error: Error
    ) -> (code: OrderInventoryReservationRepairFailureCode, inventoryItemId: String?)? {
        switch error as? OrderRecipeUsageError {
        case .missingInventoryItem(let itemId):
            return (.missingInventoryItem, itemId)
        case .incompatibleIngredientUnit:
            return (.incompatibleUnit, nil)
        case .recipeHasNoIngredients, .invalidIngredientQuantity:
            return (.invalidRequirements, nil)
        default:
            break
        }
        if case .invalidUnit = error as? OrderInventoryReservationPersistenceError {
            return (.invalidRequirements, nil)
        }
        return nil
    }

    func recordReservationRepairFailure(
        orderId: String,
        failure: (code: OrderInventoryReservationRepairFailureCode, inventoryItemId: String?),
        at timestamp: Date,
        activationId: String
    ) throws -> Bool {
        try writer.write { db in
            try db.execute(
                sql: """
                    UPDATE order_inventory_reservation_repairs
                    SET state = ?,
                        attempt_count = attempt_count + 1,
                        last_attempted_at_unix_time = ?,
                        failure_code = ?,
                        last_activation_id = ?,
                        updated_at_unix_time = ?
                    WHERE order_id = ?
                      AND state IN (?, ?)
                    """,
                arguments: [
                    OrderInventoryReservationRepairState.failed.rawValue,
                    timestamp.timeIntervalSince1970,
                    failure.code.rawValue,
                    activationId,
                    timestamp.timeIntervalSince1970,
                    orderId,
                    OrderInventoryReservationRepairState.pending.rawValue,
                    OrderInventoryReservationRepairState.failed.rawValue
                ]
            )
            guard db.changesCount > 0 else { return false }
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_events
                    (id, order_id, inventory_item_id, event_kind, reason,
                     previous_quantity, new_quantity, unit, occurred_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    idProvider(),
                    orderId,
                    failure.inventoryItemId,
                    OrderInventoryReservationEventKind.repairFailed.rawValue,
                    OrderInventoryReservationEventReason.migrationRepair.rawValue,
                    0,
                    0,
                    nil,
                    timestamp.timeIntervalSince1970
                ])
            )
            return true
        }
    }

    func replaceOrderInventoryReservations(
        orderId: String,
        with pendingUsages: [PendingInventoryUsage],
        at timestamp: Date,
        reason: OrderInventoryReservationEventReason,
        in db: Database
    ) throws {
        let existingReservations = try reservationRows(
            sql: """
                SELECT *
                FROM order_inventory_reservations
                WHERE order_id = ?
                ORDER BY inventory_item_id
                """,
            arguments: [orderId],
            in: db
        )
        let existingByItemId = Dictionary(
            uniqueKeysWithValues: existingReservations.map { ($0.inventoryItemId, $0) }
        )
        let pendingByItemId = Dictionary(
            uniqueKeysWithValues: pendingUsages.map { ($0.item.id, $0) }
        )
        let changedItemIds = Set(existingByItemId.keys)
            .union(pendingByItemId.keys)
            .filter { itemId in
                let existing = existingByItemId[itemId]
                let pending = pendingByItemId[itemId]
                guard let existing, let pending else {
                    return true
                }
                return existing.unit != pending.item.unit
                    || abs(existing.requiredQuantity - pending.quantity) > 0.000_000_1
            }
            .sorted()
        guard !changedItemIds.isEmpty else { return }

        try db.execute(
            sql: "DELETE FROM order_inventory_reservations WHERE order_id = ?",
            arguments: [orderId]
        )
        for pendingUsage in pendingUsages {
            let existing = existingByItemId[pendingUsage.item.id]
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservations
                    (id, order_id, inventory_item_id, required_quantity, unit,
                     created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    "\(orderId):\(pendingUsage.item.id)",
                    orderId,
                    pendingUsage.item.id,
                    pendingUsage.quantity,
                    pendingUsage.item.unit.rawValue,
                    (existing?.createdAt ?? timestamp).timeIntervalSince1970,
                    timestamp.timeIntervalSince1970
                ])
            )
        }
        for itemId in changedItemIds {
            let existing = existingByItemId[itemId]
            let pending = pendingByItemId[itemId]
            let previousQuantity = existing?.requiredQuantity ?? 0
            let newQuantity = pending?.quantity ?? 0
            let kind: OrderInventoryReservationEventKind
            if previousQuantity == 0 {
                kind = .created
            } else if newQuantity == 0 {
                kind = .released
            } else {
                kind = .quantityChanged
            }
            guard let unit = pending?.item.unit ?? existing?.unit else {
                continue
            }
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_events
                    (id, order_id, inventory_item_id, event_kind, reason,
                     previous_quantity, new_quantity, unit, occurred_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    idProvider(),
                    orderId,
                    itemId,
                    kind.rawValue,
                    reason.rawValue,
                    previousQuantity,
                    newQuantity,
                    unit.rawValue,
                    timestamp.timeIntervalSince1970
                ])
            )
        }
    }

    func recordRecipeUsage(
        order: Order,
        recipeId: String,
        usageId: String,
        usedAt: Date,
        allowInventoryShortage: Bool = false,
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
        try validateStock(
            for: pendingUsages,
            at: usedAt,
            allowInventoryShortage: allowInventoryShortage,
            in: db
        )
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
        guard order.cakeDesignId == nil || order.customerReferencePhotoId == nil else {
            throw OrderPersistenceError.multipleDesignReferences
        }
        if let photoId = order.customerReferencePhotoId {
            let kind = try String.fetchOne(
                db,
                sql: "SELECT kind FROM order_photos WHERE id = ?",
                arguments: [photoId]
            )
            guard kind == OrderPhotoKind.customerReference.rawValue else {
                throw OrderPersistenceError.invalidCustomerReferencePhoto
            }
        }
        try db.execute(
            sql: """
                INSERT INTO orders
                (
                    id,
                    customer_id,
                    cake_design_id,
                    customer_reference_photo_id,
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
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                customer_id = excluded.customer_id,
                cake_design_id = excluded.cake_design_id,
                customer_reference_photo_id = excluded.customer_reference_photo_id,
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
                order.customerReferencePhotoId,
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
        for ingredient in ingredients {
            guard ingredient.orderId == orderId else {
                throw OrderExtraIngredientError.orderReassignmentNotAllowed
            }
            let existingOrderId = try String.fetchOne(
                db,
                sql: "SELECT order_id FROM order_extra_ingredients WHERE id = ?",
                arguments: [ingredient.id]
            )
            guard existingOrderId == nil || existingOrderId == orderId else {
                throw OrderExtraIngredientError.orderReassignmentNotAllowed
            }
        }
        try db.execute(
            sql: "DELETE FROM order_extra_ingredients WHERE order_id = ?",
            arguments: [orderId]
        )

        for ingredient in ingredients {
            try save(ingredient, in: db)
        }
    }

    func pendingInventoryUsages(
        recipeId: String?,
        orderId: String,
        scaleMultiplier: Decimal = 1,
        in db: Database
    ) throws -> [PendingInventoryUsage] {
        let ingredients: [RecipeIngredient]
        if let recipeId {
            ingredients = try recipeIngredients(recipeId: recipeId, in: db)
        } else {
            ingredients = []
        }
        let extraIngredients = try orderExtraIngredients(orderId: orderId, in: db)

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
                throw OrderRecipeUsageError.invalidIngredientQuantity(itemName: item.name)
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
                throw OrderRecipeUsageError.invalidIngredientQuantity(itemName: item.name)
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
        if recipeId == nil, ingredients.isEmpty, extraIngredients.isEmpty {
            return []
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
        ).map { row in
            let unitValue: String = row["unit"]
            guard let unit = InventoryUnit(rawValue: unitValue) else {
                throw OrderInventoryReservationPersistenceError.invalidUnit(unitValue)
            }

            return orderExtraIngredient(from: row, unit: unit)
        }
    }

    func validateStock(
        for pendingUsages: [PendingInventoryUsage],
        at usedAt: Date,
        allowInventoryShortage: Bool,
        in db: Database
    ) throws {
        let shortages = try pendingUsages.compactMap { pendingUsage -> OrderInventoryShortage? in
            let batches = try inventoryStockBatches(inventoryItemId: pendingUsage.item.id, in: db)
            let availableQuantity = availableInventoryQuantity(
                item: pendingUsage.item,
                batches: batches,
                at: usedAt
            )
            guard availableQuantity < pendingUsage.quantity else {
                return nil
            }

            return OrderInventoryShortage(
                inventoryItemId: pendingUsage.item.id,
                inventoryItemName: pendingUsage.item.name,
                requiredQuantity: pendingUsage.quantity,
                availableQuantity: availableQuantity,
                unit: pendingUsage.item.unit
            )
        }

        if !allowInventoryShortage && !shortages.isEmpty {
            throw OrderRecipeUsageError.insufficientStock(shortages)
        }
    }

    func availableInventoryQuantity(
        item: InventoryItem,
        batches: [InventoryStockBatch],
        at date: Date
    ) -> Double {
        let currentQuantity = max(0, item.currentQuantity)
        guard !batches.isEmpty else { return currentQuantity }
        let usableBatchQuantity = batches
            .filter { $0.isUsable(at: date) }
            .reduce(0) { $0 + $1.remainingQuantity }
        return min(currentQuantity, usableBatchQuantity)
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
            let batches = try inventoryStockBatches(inventoryItemId: item.id, in: db)
            let consumedQuantity = min(
                pendingUsage.quantity,
                availableInventoryQuantity(item: item, batches: batches, at: usedAt)
            )
            let updatedItem = InventoryItem(
                id: item.id,
                name: item.name,
                aliases: item.aliases,
                type: item.type,
                defaultExpiryDays: item.defaultExpiryDays,
                unit: item.unit,
                currentQuantity: max(0, item.currentQuantity - consumedQuantity),
                minimumQuantity: item.minimumQuantity,
                earliestExpiryAt: item.earliestExpiryAt,
                hasExpiredStock: item.hasExpiredStock,
                hasExpiringSoonStock: item.hasExpiringSoonStock,
                createdAt: item.createdAt,
                updatedAt: usedAt,
                archivedAt: item.archivedAt
            )
            let costSummary = try OrderIngredientCostCalculation.summary(
                requirements: [(item, pendingUsage.quantity)],
                batches: { _ in batches },
                at: usedAt
            )
            if let costLine = costSummary.lines.first {
                try save(
                    OrderIngredientCost(
                        id: "\(order.id):\(item.id)",
                        orderId: order.id,
                        inventoryItemId: item.id,
                        quantity: pendingUsage.quantity,
                        unit: item.unit,
                        knownCost: costLine.knownCost,
                        missingPriceQuantity: costLine.missingPriceQuantity,
                        shortfallQuantity: costLine.shortfallQuantity,
                        recordedAt: usedAt
                    ),
                    in: db
                )
            }
            if consumedQuantity > 0 {
                try consume(quantity: consumedQuantity, from: batches, updatedAt: usedAt, in: db)
                try save(updatedItem, in: db)
                try save(
                    InventoryTransaction(
                        id: transactionIdProvider(),
                        inventoryItemId: item.id,
                        kind: .consumption,
                        quantity: consumedQuantity,
                        occurredAt: usedAt,
                        note: "Order recipe usage: \(order.title)",
                        createdAt: usedAt,
                        updatedAt: usedAt
                    ),
                    in: db
                )
            }
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

    func save(_ cost: OrderIngredientCost, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO order_ingredient_costs
                (id, order_id, inventory_item_id, quantity, unit, known_cost_decimal, missing_price_quantity, shortfall_quantity, recorded_at_unix_time)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(order_id, inventory_item_id) DO UPDATE SET
                quantity = excluded.quantity,
                unit = excluded.unit,
                known_cost_decimal = excluded.known_cost_decimal,
                missing_price_quantity = excluded.missing_price_quantity,
                shortfall_quantity = excluded.shortfall_quantity,
                recorded_at_unix_time = excluded.recorded_at_unix_time
                """,
            arguments: arguments([
                cost.id,
                cost.orderId,
                cost.inventoryItemId,
                cost.quantity,
                cost.unit.rawValue,
                decimalString(cost.knownCost),
                cost.missingPriceQuantity,
                cost.shortfallQuantity,
                cost.recordedAt.timeIntervalSince1970
            ])
        )
    }
}
