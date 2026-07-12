import Foundation
import GRDB

enum CakeDesignPersistenceError: Error, Equatable {
    case invalidSourceKind(String)
}

final class GRDBCoreDataRepository: InventoryItemRepository,
    RecipeRepository,
    RecipeComponentRepository,
    RecipeIngredientRepository,
    RecipeCSVImportRepository,
    CakeDesignRepository,
    CustomerRepository,
    CustomerImportantDateRepository,
    OrderRepository,
    OrderStatusChangeRepository,
    OrderRecipeUsageRepository,
    OrderIngredientCostRepository,
    OrderExtraIngredientRepository,
    OrderChecklistRepository,
    OrderPhotoRepository,
    InventoryTransactionRepository,
    InventoryStockBatchRepository,
    ExpiredStockDisposalRepository,
    PricingRuleRepository {
    let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    func arguments(_ values: [(any DatabaseValueConvertible)?]) -> StatementArguments {
        StatementArguments(values)
    }

    func inventoryItem(from row: Row, unit: InventoryUnit, db: Database) throws -> InventoryItem {
        let expiryState = try inventoryExpiryState(in: db, inventoryItemId: row["id"])
        return InventoryItem(
            id: row["id"],
            name: row["name"],
            aliases: inventoryAliases(from: row["aliases_json"]),
            type: InventoryItemType(rawValue: row["inventory_type"]) ?? .standard,
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

    func inventoryAliases(from json: String?) -> [String] {
        guard let json,
              let data = json.data(using: .utf8),
              let aliases = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return InventoryAliases.aliases(from: aliases.joined(separator: "\n"))
    }

    func inventoryAliasesJSON(_ aliases: [String]) -> String {
        guard let data = try? JSONEncoder().encode(InventoryAliases.aliases(from: aliases.joined(separator: "\n"))),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return json
    }

    func designTags(from json: String?) -> [String] {
        guard let json,
              let data = json.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return DesignTags.normalized(tags)
    }

    func designTagsJSON(_ tags: [String]) -> String {
        guard let data = try? JSONEncoder().encode(DesignTags.normalized(tags)),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
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

    func cakeDesign(from row: Row) throws -> CakeDesign {
        let sourceKindValue: String = row["source_kind"]
        guard let sourceKind = CakeDesignSourceKind(rawValue: sourceKindValue) else {
            throw CakeDesignPersistenceError.invalidSourceKind(sourceKindValue)
        }

        return CakeDesign(
            id: row["id"],
            name: row["name"],
            notes: row["notes"],
            photoReference: row["photo_reference"],
            sourceKind: sourceKind,
            originatingOrderPhotoId: row["originating_order_photo_id"],
            originatingOrderId: row["originating_order_id"],
            sourceName: row["source_name"],
            sourceURL: row["source_url"],
            tags: designTags(from: row["tags_json"]),
            isFavorite: row["is_favorite"],
            isPortfolioPublished: row["is_portfolio_published"],
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
            customerReferencePhotoId: row["customer_reference_photo_id"],
            recipeId: row["recipe_id"],
            recipeScaleMultiplier: optionalDecimal(row["recipe_scale_multiplier_decimal"]) ?? 1,
            title: row["title"],
            customerName: row["customer_name"],
            status: status,
            dueAt: date(row["due_at_unix_time"]),
            fulfillmentType: fulfillmentType,
            deliveryAddress: row["delivery_address"],
            cakeNotes: row["cake_notes"],
            cakeMessage: row["cake_message"],
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

    func orderExtraIngredient(from row: Row, unit: InventoryUnit) -> OrderExtraIngredient {
        OrderExtraIngredient(
            id: row["id"],
            orderId: row["order_id"],
            inventoryItemId: row["inventory_item_id"],
            quantity: row["quantity"],
            unit: unit,
            note: row["note"],
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
            tags: designTags(from: row["tags_json"]),
            isFavorite: row["is_favorite"],
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
            amount: optionalDecimal(row["amount_decimal"]),
            unitCost: optionalDecimal(row["unit_cost_decimal"]),
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
