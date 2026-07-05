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
    InventoryTransactionRepository,
    InventoryStockBatchRepository,
    PricingRuleRepository {
    private let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    func save(_ item: InventoryItem) throws {
        try writer.write { db in
            try save(item, in: db)
        }
    }

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM inventory_items WHERE id = ?", arguments: [id]),
                  let unit = InventoryUnit(rawValue: row["unit"]) else {
                return nil
            }

            return try inventoryItem(from: row, unit: unit, db: db)
        }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM inventory_items WHERE archived_at_unix_time IS NULL ORDER BY lower(name), name"
            ).compactMap { row in
                guard let unit = InventoryUnit(rawValue: row["unit"]) else {
                    return nil
                }

                return try inventoryItem(from: row, unit: unit, db: db)
            }
        }
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM inventory_items WHERE archived_at_unix_time IS NOT NULL ORDER BY archived_at_unix_time DESC, lower(name), name"
            ).compactMap { row in
                guard let unit = InventoryUnit(rawValue: row["unit"]) else {
                    return nil
                }

                return try inventoryItem(from: row, unit: unit, db: db)
            }
        }
    }

    func save(_ recipe: Recipe) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO recipes
                    (id, name, notes, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    recipe.id,
                    recipe.name,
                    recipe.notes,
                    recipe.createdAt.timeIntervalSince1970,
                    recipe.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchRecipe(id: String) throws -> Recipe? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM recipes WHERE id = ?", arguments: [id]) else {
                return nil
            }

            return recipe(from: row)
        }
    }

    func fetchRecipes() throws -> [Recipe] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM recipes ORDER BY lower(name), name"
            ).map(recipe)
        }
    }

    func save(_ component: RecipeComponent) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO recipe_components
                    (id, recipe_id, name, sort_order, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    component.id,
                    component.recipeId,
                    component.name,
                    component.sortOrder,
                    component.createdAt.timeIntervalSince1970,
                    component.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchRecipeComponent(id: String) throws -> RecipeComponent? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM recipe_components WHERE id = ?", arguments: [id]) else {
                return nil
            }

            return recipeComponent(from: row)
        }
    }

    func fetchRecipeComponents(recipeId: String) throws -> [RecipeComponent] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM recipe_components
                    WHERE recipe_id = ?
                    ORDER BY sort_order ASC, lower(name), name
                    """,
                arguments: [recipeId]
            ).map(recipeComponent)
        }
    }

    func fetchRecipeIngredients(componentId: String) throws -> [RecipeIngredient] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM recipe_ingredients
                    WHERE component_id = ?
                    ORDER BY created_at_unix_time ASC, id
                    """,
                arguments: [componentId]
            ).compactMap { row in
                guard let unit = InventoryUnit(rawValue: row["unit"]) else {
                    return nil
                }

                return recipeIngredient(from: row, unit: unit)
            }
        }
    }

    func deleteRecipeIngredient(id: String) throws {
        try writer.write { db in
            try db.execute(
                sql: "DELETE FROM recipe_ingredients WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func save(_ ingredient: RecipeIngredient) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO recipe_ingredients
                    (id, component_id, inventory_item_id, quantity, unit, note, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    ingredient.id,
                    ingredient.componentId,
                    ingredient.inventoryItemId,
                    ingredient.quantity,
                    ingredient.unit.rawValue,
                    ingredient.note,
                    ingredient.createdAt.timeIntervalSince1970,
                    ingredient.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchRecipeIngredient(id: String) throws -> RecipeIngredient? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM recipe_ingredients WHERE id = ?", arguments: [id]),
                  let unit = InventoryUnit(rawValue: row["unit"]) else {
                return nil
            }

            return recipeIngredient(from: row, unit: unit)
        }
    }

    func save(_ design: CakeDesign) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO cake_designs
                    (id, name, notes, photo_reference, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    design.id,
                    design.name,
                    design.notes,
                    design.photoReference,
                    design.createdAt.timeIntervalSince1970,
                    design.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchCakeDesign(id: String) throws -> CakeDesign? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM cake_designs WHERE id = ?", arguments: [id]) else {
                return nil
            }

            return CakeDesign(
                id: row["id"],
                name: row["name"],
                notes: row["notes"],
                photoReference: row["photo_reference"],
                createdAt: date(row["created_at_unix_time"]),
                updatedAt: date(row["updated_at_unix_time"])
            )
        }
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
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO orders
                    (id, customer_id, cake_design_id, title, status, due_at_unix_time, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    order.id,
                    order.customerId,
                    order.cakeDesignId,
                    order.title,
                    order.status.rawValue,
                    order.dueAt.timeIntervalSince1970,
                    order.createdAt.timeIntervalSince1970,
                    order.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchOrder(id: String) throws -> Order? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM orders WHERE id = ?", arguments: [id]),
                  let status = OrderStatus(rawValue: row["status"]) else {
                return nil
            }

            return Order(
                id: row["id"],
                customerId: row["customer_id"],
                cakeDesignId: row["cake_design_id"],
                title: row["title"],
                status: status,
                dueAt: date(row["due_at_unix_time"]),
                createdAt: date(row["created_at_unix_time"]),
                updatedAt: date(row["updated_at_unix_time"])
            )
        }
    }

    func save(_ transaction: InventoryTransaction) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO inventory_transactions
                    (id, inventory_item_id, kind, quantity, occurred_at_unix_time, note, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    transaction.id,
                    transaction.inventoryItemId,
                    transaction.kind.rawValue,
                    transaction.quantity,
                    transaction.occurredAt.timeIntervalSince1970,
                    transaction.note,
                    transaction.createdAt.timeIntervalSince1970,
                    transaction.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchInventoryTransaction(id: String) throws -> InventoryTransaction? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM inventory_transactions WHERE id = ?", arguments: [id]),
                  let kind = InventoryTransactionKind(rawValue: row["kind"]) else {
                return nil
            }

            return inventoryTransaction(from: row, kind: kind)
        }
    }

    func fetchInventoryTransactions(inventoryItemId: String) throws -> [InventoryTransaction] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM inventory_transactions
                    WHERE inventory_item_id = ?
                    ORDER BY occurred_at_unix_time DESC, created_at_unix_time DESC, id
                    """,
                arguments: [inventoryItemId]
            ).compactMap { row in
                guard let kind = InventoryTransactionKind(rawValue: row["kind"]) else {
                    return nil
                }

                return inventoryTransaction(from: row, kind: kind)
            }
        }
    }

    func save(_ batch: InventoryStockBatch) throws {
        try writer.write { db in
            try save(batch, in: db)
        }
    }

    func saveBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {
        try writer.write { db in
            try save(item, in: db)
            try save(batch, in: db)
        }
    }

    func deleteBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {
        try writer.write { db in
            try save(item, in: db)
            try db.execute(
                sql: "DELETE FROM inventory_stock_batches WHERE id = ?",
                arguments: [batch.id]
            )
        }
    }

    func fetchInventoryStockBatches(inventoryItemId: String) throws -> [InventoryStockBatch] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM inventory_stock_batches
                    WHERE inventory_item_id = ?
                    ORDER BY expires_at_unix_time IS NULL, expires_at_unix_time ASC, created_at_unix_time ASC, id
                    """,
                arguments: [inventoryItemId]
            ).map(inventoryStockBatch(from:))
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

    private func arguments(_ values: [(any DatabaseValueConvertible)?]) -> StatementArguments {
        StatementArguments(values)
    }

    private func inventoryItem(from row: Row, unit: InventoryUnit, db: Database) throws -> InventoryItem {
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

    private func recipe(from row: Row) -> Recipe {
        Recipe(
            id: row["id"],
            name: row["name"],
            notes: row["notes"],
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    private func recipeComponent(from row: Row) -> RecipeComponent {
        RecipeComponent(
            id: row["id"],
            recipeId: row["recipe_id"],
            name: row["name"],
            sortOrder: row["sort_order"],
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    private func recipeIngredient(from row: Row, unit: InventoryUnit) -> RecipeIngredient {
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

    private func customer(from row: Row) -> Customer {
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

    private func customerImportantDate(from row: Row) -> CustomerImportantDate {
        CustomerImportantDate(
            id: row["id"],
            customerId: row["customer_id"],
            label: row["label"],
            date: date(row["date_unix_time"]),
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    private func inventoryExpiryState(
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

    private func inventoryTransaction(from row: Row, kind: InventoryTransactionKind) -> InventoryTransaction {
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

    private func inventoryStockBatch(from row: Row) -> InventoryStockBatch {
        InventoryStockBatch(
            id: row["id"],
            inventoryItemId: row["inventory_item_id"],
            remainingQuantity: row["remaining_quantity"],
            expiresAt: optionalDate(row["expires_at_unix_time"]),
            createdAt: date(row["created_at_unix_time"]),
            updatedAt: date(row["updated_at_unix_time"])
        )
    }

    private func date(_ timeInterval: Double) -> Date {
        Date(timeIntervalSince1970: timeInterval)
    }

    private func optionalDate(_ timeInterval: Double?) -> Date? {
        timeInterval.map(Date.init(timeIntervalSince1970:))
    }
}

private extension GRDBCoreDataRepository {
    func save(_ item: InventoryItem, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO inventory_items
                (id, name, unit, current_quantity, minimum_quantity, created_at_unix_time, updated_at_unix_time, archived_at_unix_time)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                unit = excluded.unit,
                current_quantity = excluded.current_quantity,
                minimum_quantity = excluded.minimum_quantity,
                created_at_unix_time = excluded.created_at_unix_time,
                updated_at_unix_time = excluded.updated_at_unix_time,
                archived_at_unix_time = excluded.archived_at_unix_time
                """,
            arguments: arguments([
                item.id,
                item.name,
                item.unit.rawValue,
                item.currentQuantity,
                item.minimumQuantity,
                item.createdAt.timeIntervalSince1970,
                item.updatedAt.timeIntervalSince1970,
                item.archivedAt?.timeIntervalSince1970
            ])
        )
    }

    func save(_ batch: InventoryStockBatch, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO inventory_stock_batches
                (id, inventory_item_id, remaining_quantity, expires_at_unix_time, created_at_unix_time, updated_at_unix_time)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                inventory_item_id = excluded.inventory_item_id,
                remaining_quantity = excluded.remaining_quantity,
                expires_at_unix_time = excluded.expires_at_unix_time,
                created_at_unix_time = excluded.created_at_unix_time,
                updated_at_unix_time = excluded.updated_at_unix_time
                """,
            arguments: arguments([
                batch.id,
                batch.inventoryItemId,
                batch.remainingQuantity,
                batch.expiresAt?.timeIntervalSince1970,
                batch.createdAt.timeIntervalSince1970,
                batch.updatedAt.timeIntervalSince1970
            ])
        )
    }
}
