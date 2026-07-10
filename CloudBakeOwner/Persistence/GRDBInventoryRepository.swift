import Foundation
import GRDB

extension GRDBCoreDataRepository {
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

    func save(_ transaction: InventoryTransaction) throws {
        try writer.write { db in
            try save(transaction, in: db)
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

    func replaceInventoryStock(item: InventoryItem, batches: [InventoryStockBatch]) throws {
        try writer.write { db in
            try save(item, in: db)
            try db.execute(
                sql: "DELETE FROM inventory_stock_batches WHERE inventory_item_id = ?",
                arguments: [item.id]
            )
            for batch in batches {
                try save(batch, in: db)
            }
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

    func save(_ item: InventoryItem, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO inventory_items
                (id, name, aliases_json, unit, current_quantity, minimum_quantity, created_at_unix_time, updated_at_unix_time, archived_at_unix_time)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                aliases_json = excluded.aliases_json,
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
                inventoryAliasesJSON(item.aliases),
                item.unit.rawValue,
                item.currentQuantity,
                item.minimumQuantity,
                item.createdAt.timeIntervalSince1970,
                item.updatedAt.timeIntervalSince1970,
                item.archivedAt?.timeIntervalSince1970
            ])
        )
    }

    func save(_ transaction: InventoryTransaction, in db: Database) throws {
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

    func save(_ batch: InventoryStockBatch, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO inventory_stock_batches
                (id, inventory_item_id, remaining_quantity, expires_at_unix_time, amount_decimal, created_at_unix_time, updated_at_unix_time)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                inventory_item_id = excluded.inventory_item_id,
                remaining_quantity = excluded.remaining_quantity,
                expires_at_unix_time = excluded.expires_at_unix_time,
                amount_decimal = excluded.amount_decimal,
                created_at_unix_time = excluded.created_at_unix_time,
                updated_at_unix_time = excluded.updated_at_unix_time
                """,
            arguments: arguments([
                batch.id,
                batch.inventoryItemId,
                batch.remainingQuantity,
                batch.expiresAt?.timeIntervalSince1970,
                decimalString(batch.amount),
                batch.createdAt.timeIntervalSince1970,
                batch.updatedAt.timeIntervalSince1970
            ])
        )
    }

    func inventoryItem(id: String, in db: Database) throws -> InventoryItem? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM inventory_items WHERE id = ?", arguments: [id]),
              let unit = InventoryUnit(rawValue: row["unit"]) else {
            return nil
        }

        return try inventoryItem(from: row, unit: unit, db: db)
    }

    func inventoryStockBatches(inventoryItemId: String, in db: Database) throws -> [InventoryStockBatch] {
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

    func consume(
        quantity: Double,
        from batches: [InventoryStockBatch],
        updatedAt: Date,
        in db: Database
    ) throws {
        var remainingQuantityToUse = quantity
        for batch in batches where remainingQuantityToUse > 0 && batch.remainingQuantity > 0 {
            let quantityFromBatch = min(batch.remainingQuantity, remainingQuantityToUse)
            try save(
                InventoryStockBatch(
                    id: batch.id,
                    inventoryItemId: batch.inventoryItemId,
                    remainingQuantity: batch.remainingQuantity - quantityFromBatch,
                    expiresAt: batch.expiresAt,
                    amount: batch.amount,
                    createdAt: batch.createdAt,
                    updatedAt: updatedAt
                ),
                in: db
            )
            remainingQuantityToUse -= quantityFromBatch
        }
    }
}
