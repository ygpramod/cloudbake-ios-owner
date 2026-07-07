import Foundation
import GRDB

final class GRDBCoreDataRepository: InventoryItemRepository,
    RecipeRepository,
    RecipeComponentRepository,
    RecipeIngredientRepository,
    CakeDesignRepository,
    CustomerRepository,
    CustomerImportantDateRepository,
    OrderRepository,
    OrderStatusChangeRepository,
    OrderRecipeUsageRepository,
    OrderChecklistRepository,
    OrderPhotoRepository,
    InventoryTransactionRepository,
    InventoryStockBatchRepository,
    PricingRuleRepository {
    let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    func save(_ customer: Customer) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO customers
                    (id, name, phone, email, address, likes, dislikes, allergies, dietary_restrictions, notes, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    customer.id,
                    customer.name,
                    customer.phone,
                    customer.email,
                    customer.address,
                    customer.likes,
                    customer.dislikes,
                    customer.allergies,
                    customer.dietaryRestrictions,
                    customer.notes,
                    customer.createdAt.timeIntervalSince1970,
                    customer.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchCustomer(id: String) throws -> Customer? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM customers WHERE id = ?", arguments: [id]) else {
                return nil
            }

            return customer(from: row)
        }
    }

    func fetchCustomers() throws -> [Customer] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM customers ORDER BY lower(name), name"
            ).map(customer)
        }
    }

    func save(_ importantDate: CustomerImportantDate) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO customer_important_dates
                    (id, customer_id, label, date_unix_time, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    importantDate.id,
                    importantDate.customerId,
                    importantDate.label,
                    importantDate.date.timeIntervalSince1970,
                    importantDate.createdAt.timeIntervalSince1970,
                    importantDate.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchCustomerImportantDates(customerId: String) throws -> [CustomerImportantDate] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM customer_important_dates
                    WHERE customer_id = ?
                    ORDER BY date_unix_time ASC, lower(label), label
                    """,
                arguments: [customerId]
            ).map(customerImportantDate)
        }
    }

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
            quotedPrice: order.quotedPrice,
            depositPaid: order.depositPaid,
            paymentNotes: order.paymentNotes,
            createdAt: order.createdAt,
            updatedAt: updatedAt
        )

        try writer.write { db in
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
            try db.execute(
                sql: """
                    INSERT INTO order_photos
                    (id, order_id, kind, local_photo_path, caption, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                    order_id = excluded.order_id,
                    kind = excluded.kind,
                    local_photo_path = excluded.local_photo_path,
                    caption = excluded.caption,
                    created_at_unix_time = excluded.created_at_unix_time,
                    updated_at_unix_time = excluded.updated_at_unix_time
                    """,
                arguments: arguments([
                    photo.id,
                    photo.orderId,
                    photo.kind.rawValue,
                    photo.localPhotoPath,
                    photo.caption,
                    photo.createdAt.timeIntervalSince1970,
                    photo.updatedAt.timeIntervalSince1970
                ])
            )
        }
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

    func deleteOrderPhoto(id: String) throws {
        try writer.write { db in
            try db.execute(
                sql: "DELETE FROM order_photos WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func save(_ rule: PricingRule) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO pricing_rules
                    (id, name, kind, amount_decimal, currency_code, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    rule.id,
                    rule.name,
                    rule.kind.rawValue,
                    NSDecimalNumber(decimal: rule.amount).stringValue,
                    rule.currencyCode,
                    rule.createdAt.timeIntervalSince1970,
                    rule.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchPricingRule(id: String) throws -> PricingRule? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM pricing_rules WHERE id = ?", arguments: [id]),
                  let kind = PricingRuleKind(rawValue: row["kind"]),
                  let amount = Decimal(string: row["amount_decimal"]) else {
                return nil
            }

            return PricingRule(
                id: row["id"],
                name: row["name"],
                kind: kind,
                amount: amount,
                currencyCode: row["currency_code"],
                createdAt: date(row["created_at_unix_time"]),
                updatedAt: date(row["updated_at_unix_time"])
            )
        }
    }

    func arguments(_ values: [(any DatabaseValueConvertible)?]) -> StatementArguments {
        StatementArguments(values)
    }

    func inventoryItem(from row: Row, unit: InventoryUnit, db: Database) throws -> InventoryItem {
        let expiryState = try inventoryExpiryState(in: db, inventoryItemId: row["id"])
        return InventoryItem(
            id: row["id"],
            name: row["name"],
            unit: unit,
            currentQuantity: row["current_quantity"],
            minimumQuantity: row["minimum_quantity"],
            earliestExpiryAt: expiryState.earliestExpiryAt,
            hasExpiredStock: expiryState.hasExpiredStock,
            hasExpiringSoonStock: expiryState.hasExpiringSoonStock,
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"]),
            archivedAt: optionalDate(row["archived_at_unix_time"])
        )
    }

    func recipe(from row: Row) -> Recipe {
        Recipe(
            id: row["id"],
            name: row["name"],
            notes: row["notes"],
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func recipeComponent(from row: Row) -> RecipeComponent {
        RecipeComponent(
            id: row["id"],
            recipeId: row["recipe_id"],
            name: row["name"],
            sortOrder: row["sort_order"],
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func recipeIngredient(from row: Row, unit: InventoryUnit) -> RecipeIngredient {
        RecipeIngredient(
            id: row["id"],
            componentId: row["component_id"],
            inventoryItemId: row["inventory_item_id"],
            quantity: row["quantity"],
            unit: unit,
            note: row["note"],
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func customer(from row: Row) -> Customer {
        Customer(
            id: row["id"],
            name: row["name"],
            phone: row["phone"],
            email: row["email"],
            address: row["address"],
            likes: row["likes"],
            dislikes: row["dislikes"],
            allergies: row["allergies"],
            dietaryRestrictions: row["dietary_restrictions"],
            notes: row["notes"],
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func cakeDesign(from row: Row) -> CakeDesign {
        CakeDesign(
            id: row["id"],
            name: row["name"],
            notes: row["notes"],
            photoReference: row["photo_reference"],
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func customerImportantDate(from row: Row) -> CustomerImportantDate {
        CustomerImportantDate(
            id: row["id"],
            customerId: row["customer_id"],
            label: row["label"],
            date: date(row["date_unix_time"]),
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func order(from row: Row) -> Order {
        let status = OrderStatus(rawValue: row["status"] as String) ?? .draft
        let fulfillmentType = OrderFulfillmentType(rawValue: row["fulfillment_type"] as String) ?? .pickup

        return Order(
            id: row["id"],
            customerId: row["customer_id"],
            cakeDesignId: row["cake_design_id"],
            recipeId: row["recipe_id"],
            recipeScaleMultiplier: optionalDecimal(row["recipe_scale_multiplier_decimal"]) ?? 1,
            title: row["title"],
            customerName: row["customer_name"],
            status: status,
            dueAt: date(row["due_at_unix_time"]),
            fulfillmentType: fulfillmentType,
            deliveryAddress: row["delivery_address"],
            cakeNotes: row["cake_notes"],
            quotedPrice: optionalDecimal(row["quoted_price_decimal"]),
            depositPaid: optionalDecimal(row["deposit_paid_decimal"]),
            paymentNotes: row["payment_notes"],
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func orderRecipeUsage(from row: Row) -> OrderRecipeUsage {
        OrderRecipeUsage(
            id: row["id"],
            orderId: row["order_id"],
            recipeId: row["recipe_id"],
            recipeScaleMultiplier: optionalDecimal(row["recipe_scale_multiplier_decimal"]) ?? 1,
            usedAt: date(row["used_at_unix_time"]),
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func orderChecklistItem(from row: Row) -> OrderChecklistItem {
        OrderChecklistItem(
            id: row["id"],
            orderId: row["order_id"],
            title: row["title"],
            isCompleted: row["is_completed"],
            sortOrder: row["sort_order"],
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func orderPhoto(from row: Row) -> OrderPhoto? {
        guard let kind = OrderPhotoKind(rawValue: row["kind"]) else {
            return nil
        }

        return OrderPhoto(
            id: row["id"],
            orderId: row["order_id"],
            kind: kind,
            localPhotoPath: row["local_photo_path"],
            caption: row["caption"],
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func inventoryExpiryState(
        in db: Database,
        inventoryItemId: String
    ) throws -> (earliestExpiryAt: Date?, hasExpiredStock: Bool, hasExpiringSoonStock: Bool) {
        let now = Date()
        let nowUnixTime = now.timeIntervalSince1970
        let expiringSoonThreshold = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now.addingTimeInterval(30 * 24 * 60 * 60)
        let earliestExpiryUnixTime = try Double.fetchOne(
            db,
            sql: """
                SELECT MIN(expires_at_unix_time)
                FROM inventory_stock_batches
                WHERE inventory_item_id = ?
                AND remaining_quantity > 0
                AND expires_at_unix_time IS NOT NULL
                """,
            arguments: [inventoryItemId]
        )
        let expiredBatchCount = try Int.fetchOne(
            db,
            sql: """
                SELECT COUNT(*)
                FROM inventory_stock_batches
                WHERE inventory_item_id = ?
                AND remaining_quantity > 0
                AND expires_at_unix_time IS NOT NULL
                AND expires_at_unix_time < ?
                """,
            arguments: [inventoryItemId, nowUnixTime]
        ) ?? 0
        let expiringSoonBatchCount = try Int.fetchOne(
            db,
            sql: """
                SELECT COUNT(*)
                FROM inventory_stock_batches
                WHERE inventory_item_id = ?
                AND remaining_quantity > 0
                AND expires_at_unix_time IS NOT NULL
                AND expires_at_unix_time >= ?
                AND expires_at_unix_time <= ?
                """,
            arguments: [inventoryItemId, nowUnixTime, expiringSoonThreshold.timeIntervalSince1970]
        ) ?? 0

        return (
            earliestExpiryAt: earliestExpiryUnixTime.map(Date.init(timeIntervalSince1970:)),
            hasExpiredStock: expiredBatchCount > 0,
            hasExpiringSoonStock: expiringSoonBatchCount > 0
        )
    }

    func inventoryTransaction(from row: Row, kind: InventoryTransactionKind) -> InventoryTransaction {
        InventoryTransaction(
            id: row["id"],
            inventoryItemId: row["inventory_item_id"],
            kind: kind,
            quantity: row["quantity"],
            occurredAt: date(row["occurred_at_unix_time"]),
            note: row["note"],
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func inventoryStockBatch(from row: Row) -> InventoryStockBatch {
        InventoryStockBatch(
            id: row["id"],
            inventoryItemId: row["inventory_item_id"],
            remainingQuantity: row["remaining_quantity"],
            expiresAt: optionalDate(row["expires_at_unix_time"]),
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    func date(_ timeInterval: Double) -> Date {
        Date(timeIntervalSince1970: timeInterval)
    }

    func optionalDate(_ timeInterval: Double?) -> Date? {
        timeInterval.map(Date.init(timeIntervalSince1970:))
    }

    func optionalDecimal(_ value: String?) -> Decimal? {
        guard let value else {
            return nil
        }

        return Decimal(string: value)
    }

    func decimalString(_ value: Decimal?) -> String? {
        guard let value else {
            return nil
        }

        return NSDecimalNumber(decimal: value).stringValue
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
                    quoted_price_decimal,
                    deposit_paid_decimal,
                    payment_notes,
                    created_at_unix_time,
                    updated_at_unix_time
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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

    func pendingInventoryUsages(recipeId: String, scaleMultiplier: Decimal = 1, in db: Database) throws -> [PendingInventoryUsage] {
        let ingredients = try recipeIngredients(recipeId: recipeId, in: db)
        guard !ingredients.isEmpty else {
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

        let pendingUsages = pendingUsagesByItemId.values.sorted { lhs, rhs in
            lhs.item.name.localizedCaseInsensitiveCompare(rhs.item.name) == .orderedAscending
        }
        guard !pendingUsages.isEmpty else {
            throw OrderRecipeUsageError.recipeHasNoIngredients
        }

        return pendingUsages
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
