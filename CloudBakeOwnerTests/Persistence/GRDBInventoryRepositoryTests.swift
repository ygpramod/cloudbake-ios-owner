import GRDB
import XCTest
@testable import CloudBakeOwner

final class GRDBInventoryRepositoryTests: XCTestCase {
    func testInventoryItemSaveUpdatesExistingItemWithSameId() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_020_000)
        let original = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            aliases: ["Maida"],
            type: .perishable,
            defaultExpiryDays: 4,
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: Date(timeIntervalSince1970: 1_800_020_100)
        )
        let edited = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour fine",
            aliases: ["Aashirvaad Maida", "Plain flour"],
            type: .perishable,
            defaultExpiryDays: 7,
            unit: .kilogram,
            currentQuantity: 1.25,
            minimumQuantity: 2,
            createdAt: createdAt,
            updatedAt: Date(timeIntervalSince1970: 1_800_020_200)
        )

        try repository.save(original)
        try repository.save(edited)

        XCTAssertEqual(try repository.fetchInventoryItem(id: "inventory-flour"), edited)
        XCTAssertEqual(try repository.fetchInventoryItems(), [edited])
    }

    func testInventoryItemsFetchExcludesArchivedItemsButDirectFetchStillFindsThem() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let active = InventoryItem(
            id: "inventory-active-flour",
            name: "Active flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let archived = InventoryItem(
            id: "inventory-archived-flour",
            name: "Archived flour",
            unit: .gram,
            currentQuantity: 0,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp,
            archivedAt: Date(timeIntervalSince1970: 1_800_020_100)
        )

        try repository.save(active)
        try repository.save(archived)

        XCTAssertEqual(try repository.fetchInventoryItems(), [active])
        XCTAssertEqual(try repository.fetchInventoryItem(id: archived.id), archived)
        XCTAssertEqual(try repository.fetchArchivedInventoryItems(), [archived])
    }

    func testRestoredInventoryItemMovesBackToActiveFetch() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_020_000)
        let archivedAt = Date(timeIntervalSince1970: 1_800_020_100)
        let restoredAt = Date(timeIntervalSince1970: 1_800_020_200)
        let archived = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: archivedAt,
            archivedAt: archivedAt
        )
        let restored = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: restoredAt
        )

        try repository.save(archived)
        try repository.save(restored)

        XCTAssertEqual(try repository.fetchInventoryItems(), [restored])
        XCTAssertEqual(try repository.fetchArchivedInventoryItems(), [])
    }

    func testInventoryAdjustmentStoresUpdatedQuantityAndTransaction() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_020_000)
        let adjustedAt = Date(timeIntervalSince1970: 1_800_020_100)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let adjustedItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 350,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: adjustedAt
        )
        let transaction = InventoryTransaction(
            id: "transaction-flour-adjustment",
            inventoryItemId: item.id,
            kind: .adjustment,
            quantity: 100,
            occurredAt: adjustedAt,
            note: "Restocked",
            createdAt: adjustedAt,
            updatedAt: adjustedAt
        )

        try repository.save(item)
        try repository.save(adjustedItem)
        try repository.save(transaction)

        XCTAssertEqual(try repository.fetchInventoryItem(id: item.id), adjustedItem)
        XCTAssertEqual(try repository.fetchInventoryTransaction(id: transaction.id), transaction)
    }

    func testInventoryStockBatchesFetchOldestExpiryFirstWithNoExpiryLast() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 350,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let newer = InventoryStockBatch(
            id: "batch-newer",
            inventoryItemId: item.id,
            remainingQuantity: 100,
            expiresAt: Date(timeIntervalSince1970: 1_800_202_800),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let older = InventoryStockBatch(
            id: "batch-older",
            inventoryItemId: item.id,
            remainingQuantity: 100,
            expiresAt: Date(timeIntervalSince1970: 1_800_116_400),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let noExpiry = InventoryStockBatch(
            id: "batch-no-expiry",
            inventoryItemId: item.id,
            remainingQuantity: 150,
            expiresAt: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(item)
        try repository.save(newer)
        try repository.save(noExpiry)
        try repository.save(older)

        XCTAssertEqual(
            try repository.fetchInventoryStockBatches(inventoryItemId: item.id),
            [older, newer, noExpiry]
        )
        XCTAssertEqual(try repository.fetchInventoryItem(id: item.id)?.earliestExpiryAt, older.expiresAt)
    }

    func testVoiceInventoryImportRollsBackItemsWhenABatchFails() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 800,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let invalidBatch = InventoryStockBatch(
            id: "batch-invalid",
            inventoryItemId: "missing-inventory",
            remainingQuantity: 800,
            expiresAt: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        XCTAssertThrowsError(
            try repository.saveVoiceInventoryImport(items: [item], batches: [invalidBatch])
        )
        XCTAssertNil(try repository.fetchInventoryItem(id: item.id))
        XCTAssertEqual(try repository.fetchInventoryStockBatches(inventoryItemId: item.id), [])
    }

    func testVoiceInventoryImportAtomicallyCombinesEquivalentBatches() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let expiry = Date(timeIntervalSince1970: 1_800_279_200)
        let originalItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let updatedItem = InventoryItem(
            id: originalItem.id,
            name: originalItem.name,
            unit: originalItem.unit,
            currentQuantity: 300,
            minimumQuantity: originalItem.minimumQuantity,
            createdAt: originalItem.createdAt,
            updatedAt: timestamp.addingTimeInterval(100)
        )
        let existingBatch = InventoryStockBatch(
            id: "batch-existing",
            inventoryItemId: originalItem.id,
            remainingQuantity: 100,
            expiresAt: expiry,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let firstVoiceBatch = InventoryStockBatch(
            id: "batch-voice-one",
            inventoryItemId: originalItem.id,
            remainingQuantity: 100,
            expiresAt: expiry,
            createdAt: timestamp.addingTimeInterval(100),
            updatedAt: timestamp.addingTimeInterval(100)
        )
        let secondVoiceBatch = InventoryStockBatch(
            id: "batch-voice-two",
            inventoryItemId: originalItem.id,
            remainingQuantity: 100,
            expiresAt: expiry,
            createdAt: timestamp.addingTimeInterval(100),
            updatedAt: timestamp.addingTimeInterval(100)
        )
        try repository.save(originalItem)
        try repository.save(existingBatch)

        try repository.saveVoiceInventoryImport(
            items: [updatedItem],
            batches: [firstVoiceBatch, secondVoiceBatch]
        )

        XCTAssertEqual(try repository.fetchInventoryItem(id: originalItem.id)?.currentQuantity, 300)
        let batches = try repository.fetchInventoryStockBatches(inventoryItemId: originalItem.id)
        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches[0].id, existingBatch.id)
        XCTAssertEqual(batches[0].remainingQuantity, 300)
    }

    func testExpiredRemainingBatchMarksInventoryItemAsLowStock() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 900,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let expiredBatch = InventoryStockBatch(
            id: "batch-expired",
            inventoryItemId: item.id,
            remainingQuantity: 100,
            expiresAt: Date(timeIntervalSince1970: 1),
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(item)
        try repository.save(expiredBatch)

        let fetchedItem = try XCTUnwrap(repository.fetchInventoryItem(id: item.id))
        XCTAssertTrue(fetchedItem.hasExpiredStock)
        XCTAssertTrue(fetchedItem.isLowStock)
    }

    func testRemainingBatchExpiringWithinOneMonthMarksInventoryItemAsLowStock() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let item = InventoryItem(
            id: "inventory-butter",
            name: "Butter",
            unit: .gram,
            currentQuantity: 900,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let expiringSoonBatch = InventoryStockBatch(
            id: "batch-expiring-soon",
            inventoryItemId: item.id,
            remainingQuantity: 100,
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(item)
        try repository.save(expiringSoonBatch)

        let fetchedItem = try XCTUnwrap(repository.fetchInventoryItem(id: item.id))
        XCTAssertFalse(fetchedItem.hasExpiredStock)
        XCTAssertTrue(fetchedItem.hasExpiringSoonStock)
        XCTAssertTrue(fetchedItem.isLowStock)
    }

    func testRemainingBatchExpiringAfterOneMonthDoesNotMarkInventoryItemAsLowStock() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let item = InventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram,
            currentQuantity: 900,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let laterBatch = InventoryStockBatch(
            id: "batch-later",
            inventoryItemId: item.id,
            remainingQuantity: 100,
            expiresAt: Calendar.current.date(byAdding: .day, value: 45, to: Date()),
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(item)
        try repository.save(laterBatch)

        let fetchedItem = try XCTUnwrap(repository.fetchInventoryItem(id: item.id))
        XCTAssertFalse(fetchedItem.hasExpiredStock)
        XCTAssertFalse(fetchedItem.hasExpiringSoonStock)
        XCTAssertFalse(fetchedItem.isLowStock)
    }

    func testInventoryItemWithTransactionCanBeArchived() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_020_000)
        let adjustedAt = Date(timeIntervalSince1970: 1_800_020_100)
        let archivedAt = Date(timeIntervalSince1970: 1_800_020_200)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 350,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: adjustedAt
        )
        let transaction = InventoryTransaction(
            id: "transaction-flour-adjustment",
            inventoryItemId: item.id,
            kind: .adjustment,
            quantity: 100,
            occurredAt: adjustedAt,
            note: nil,
            createdAt: adjustedAt,
            updatedAt: adjustedAt
        )
        let archivedItem = InventoryItem(
            id: item.id,
            name: item.name,
            unit: item.unit,
            currentQuantity: item.currentQuantity,
            minimumQuantity: item.minimumQuantity,
            createdAt: item.createdAt,
            updatedAt: archivedAt,
            archivedAt: archivedAt
        )

        try repository.save(item)
        try repository.save(transaction)
        try repository.save(archivedItem)

        XCTAssertEqual(try repository.fetchInventoryItems(), [])
        XCTAssertEqual(try repository.fetchArchivedInventoryItems(), [archivedItem])
        XCTAssertEqual(try repository.fetchInventoryTransaction(id: transaction.id), transaction)
    }

    func testInventoryConsumptionStoresUpdatedQuantityAndTransaction() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_020_000)
        let consumedAt = Date(timeIntervalSince1970: 1_800_020_100)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 350,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let consumedItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: consumedAt
        )
        let transaction = InventoryTransaction(
            id: "transaction-flour-consumption",
            inventoryItemId: item.id,
            kind: .consumption,
            quantity: 100,
            occurredAt: consumedAt,
            note: "Vanilla sponge",
            createdAt: consumedAt,
            updatedAt: consumedAt
        )

        try repository.save(item)
        try repository.save(consumedItem)
        try repository.save(transaction)

        XCTAssertEqual(try repository.fetchInventoryItem(id: item.id), consumedItem)
        XCTAssertEqual(try repository.fetchInventoryTransaction(id: transaction.id), transaction)
    }

    func testInventoryTransactionsFetchForItemNewestFirst() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let flour = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let sugar = InventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let olderFlourTransaction = InventoryTransaction(
            id: "transaction-flour-adjustment",
            inventoryItemId: flour.id,
            kind: .adjustment,
            quantity: 100,
            occurredAt: Date(timeIntervalSince1970: 1_800_020_100),
            note: "Restocked",
            createdAt: Date(timeIntervalSince1970: 1_800_020_100),
            updatedAt: Date(timeIntervalSince1970: 1_800_020_100)
        )
        let sugarTransaction = InventoryTransaction(
            id: "transaction-sugar-adjustment",
            inventoryItemId: sugar.id,
            kind: .adjustment,
            quantity: 100,
            occurredAt: Date(timeIntervalSince1970: 1_800_020_300),
            note: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_020_300),
            updatedAt: Date(timeIntervalSince1970: 1_800_020_300)
        )
        let newerFlourTransaction = InventoryTransaction(
            id: "transaction-flour-consumption",
            inventoryItemId: flour.id,
            kind: .consumption,
            quantity: 50,
            occurredAt: Date(timeIntervalSince1970: 1_800_020_200),
            note: "Vanilla sponge",
            createdAt: Date(timeIntervalSince1970: 1_800_020_200),
            updatedAt: Date(timeIntervalSince1970: 1_800_020_200)
        )

        try repository.save(flour)
        try repository.save(sugar)
        try repository.save(olderFlourTransaction)
        try repository.save(sugarTransaction)
        try repository.save(newerFlourTransaction)

        XCTAssertEqual(
            try repository.fetchInventoryTransactions(inventoryItemId: flour.id),
            [newerFlourTransaction, olderFlourTransaction]
        )
    }

    func testDeletingUnusedInventoryItemRemovesItPermanently() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let item = InventoryItem(
            id: "inventory-unused",
            name: "Unused decoration",
            unit: .each,
            currentQuantity: 0,
            minimumQuantity: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(item)

        try repository.deleteInventoryItem(id: item.id)

        XCTAssertNil(try repository.fetchInventoryItem(id: item.id))
    }

    func testDeletingInventoryItemWithHistoryIsRejected() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let item = InventoryItem(
            id: "inventory-used",
            name: "Used flour",
            unit: .gram,
            currentQuantity: 0,
            minimumQuantity: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(item)
        try repository.save(
            InventoryTransaction(
                id: "transaction-used",
                inventoryItemId: item.id,
                kind: .consumption,
                quantity: 10,
                occurredAt: timestamp,
                note: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )

        XCTAssertThrowsError(try repository.deleteInventoryItem(id: item.id)) { error in
            XCTAssertEqual(error as? InventoryItemDeletionError, .inUse)
        }
        XCTAssertEqual(try repository.fetchInventoryItem(id: item.id), item)
    }

    func testDeletingInventoryItemWithOperationalDependenciesIsRejected() throws {
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let cases: [(String, (GRDBCoreDataRepository, InventoryItem) throws -> Void)] = [
            (
                "stock batch",
                { repository, item in
                    try repository.save(
                        InventoryStockBatch(
                            id: "batch-dependent",
                            inventoryItemId: item.id,
                            remainingQuantity: 0,
                            expiresAt: nil,
                            createdAt: timestamp,
                            updatedAt: timestamp
                        )
                    )
                }
            ),
            (
                "recipe ingredient",
                { repository, item in
                    let recipe = Recipe(
                        id: "recipe-dependent",
                        name: "Dependent recipe",
                        notes: nil,
                        createdAt: timestamp,
                        updatedAt: timestamp
                    )
                    let component = RecipeComponent(
                        id: "component-dependent",
                        recipeId: recipe.id,
                        name: "Cake",
                        sortOrder: 0,
                        createdAt: timestamp,
                        updatedAt: timestamp
                    )
                    try repository.save(recipe)
                    try repository.save(component)
                    try repository.save(
                        RecipeIngredient(
                            id: "ingredient-dependent",
                            componentId: component.id,
                            inventoryItemId: item.id,
                            quantity: 10,
                            unit: .gram,
                            note: nil,
                            createdAt: timestamp,
                            updatedAt: timestamp
                        )
                    )
                }
            ),
            (
                "order extra ingredient",
                { repository, item in
                    let order = Order(
                        id: "order-dependent",
                        customerId: nil,
                        cakeDesignId: nil,
                        title: "Dependent order",
                        customerName: "Amy",
                        status: .draft,
                        dueAt: timestamp,
                        fulfillmentType: .pickup,
                        deliveryAddress: nil,
                        cakeNotes: nil,
                        createdAt: timestamp,
                        updatedAt: timestamp
                    )
                    try repository.save(order)
                    try repository.save(
                        OrderExtraIngredient(
                            id: "extra-dependent",
                            orderId: order.id,
                            inventoryItemId: item.id,
                            quantity: 10,
                            unit: .gram,
                            note: nil,
                            createdAt: timestamp,
                            updatedAt: timestamp
                        )
                    )
                }
            )
        ]

        for (dependencyName, setUpDependency) in cases {
            let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
            let item = InventoryItem(
                id: "inventory-\(dependencyName)",
                name: "Dependent inventory",
                unit: .gram,
                currentQuantity: 0,
                minimumQuantity: 0,
                createdAt: timestamp,
                updatedAt: timestamp
            )
            try repository.save(item)
            try setUpDependency(repository, item)

            XCTAssertThrowsError(
                try repository.deleteInventoryItem(id: item.id),
                "Expected \(dependencyName) to prevent deletion"
            ) { error in
                XCTAssertEqual(error as? InventoryItemDeletionError, .inUse)
            }
            XCTAssertEqual(try repository.fetchInventoryItem(id: item.id), item)
        }
    }

    func testDeletingInventoryItemWithRecordedOrderCostIsRejected() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let item = InventoryItem(
            id: "inventory-costed",
            name: "Costed flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-costed",
            name: "Costed cake",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-costed",
            recipeId: recipe.id,
            name: "Cake",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-costed",
            componentId: component.id,
            inventoryItemId: item.id,
            quantity: 100,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = Order(
            id: "order-costed",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipe.id,
            title: "Costed cake",
            customerName: "Amy",
            status: .confirmed,
            dueAt: timestamp.addingTimeInterval(86_400),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(item)
        try repository.save(
            InventoryStockBatch(
                id: "batch-costed",
                inventoryItemId: item.id,
                remainingQuantity: 500,
                expiresAt: nil,
                amount: 25,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.save(order)
        _ = try repository.changeOrderStatus(
            order: order,
            status: .ready,
            updatedAt: timestamp.addingTimeInterval(100),
            usageId: "usage-costed",
            extraIngredients: nil,
            transactionIdProvider: { "transaction-costed" }
        )
        let recordedCosts = try repository.fetchOrderIngredientCosts(orderId: order.id)
        XCTAssertEqual(recordedCosts.count, 1)
        try repository.writer.write { db in
            try db.execute(
                sql: "DELETE FROM recipe_ingredients WHERE inventory_item_id = ?",
                arguments: [item.id]
            )
            try db.execute(
                sql: "DELETE FROM inventory_transactions WHERE inventory_item_id = ?",
                arguments: [item.id]
            )
            try db.execute(
                sql: "DELETE FROM inventory_stock_batches WHERE inventory_item_id = ?",
                arguments: [item.id]
            )
        }
        let referenceCounts = try repository.writer.read { db in
            (
                recipeIngredients: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM recipe_ingredients WHERE inventory_item_id = ?",
                    arguments: [item.id]
                ) ?? 0,
                transactions: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM inventory_transactions WHERE inventory_item_id = ?",
                    arguments: [item.id]
                ) ?? 0,
                batches: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM inventory_stock_batches WHERE inventory_item_id = ?",
                    arguments: [item.id]
                ) ?? 0,
                costs: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM order_ingredient_costs WHERE inventory_item_id = ?",
                    arguments: [item.id]
                ) ?? 0
            )
        }
        XCTAssertEqual(referenceCounts.recipeIngredients, 0)
        XCTAssertEqual(referenceCounts.transactions, 0)
        XCTAssertEqual(referenceCounts.batches, 0)
        XCTAssertEqual(referenceCounts.costs, 1)

        XCTAssertThrowsError(try repository.deleteInventoryItem(id: item.id)) { error in
            XCTAssertEqual(error as? InventoryItemDeletionError, .inUse)
        }
        XCTAssertNotNil(try repository.fetchInventoryItem(id: item.id))
        XCTAssertEqual(try repository.fetchOrderIngredientCosts(orderId: order.id), recordedCosts)
    }
}
