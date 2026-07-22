import GRDB
import XCTest
@testable import CloudBakeOwner

final class GRDBOrderLifecycleRepositoryTests: XCTestCase {
    func testChangingOrderStatusToReadyRecordsRecipeUsageAndDeductsInventory() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let readyAt = Date(timeIntervalSince1970: 1_800_020_000)
        let inventoryItem = InventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-buttercream",
            name: "Buttercream",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-frosting",
            recipeId: recipe.id,
            name: "Frosting",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-sugar",
            componentId: component.id,
            inventoryItemId: inventoryItem.id,
            quantity: 100,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = Order(
            id: "order-buttercream",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipe.id,
            title: "Buttercream cake",
            customerName: "Amy",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_050_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(inventoryItem)
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.save(order)

        let updatedOrder = try repository.changeOrderStatus(
            order: order,
            status: .ready,
            updatedAt: readyAt,
            usageId: "usage-order-buttercream",
            extraIngredients: nil,
            transactionIdProvider: { "transaction-order-buttercream-sugar" }
        )

        XCTAssertEqual(updatedOrder.status, .ready)
        XCTAssertEqual(try repository.fetchOrder(id: order.id)?.status, .ready)
        XCTAssertEqual(try repository.fetchInventoryItem(id: inventoryItem.id)?.currentQuantity, 400)
        XCTAssertEqual(try repository.fetchOrderRecipeUsage(orderId: order.id)?.recipeId, recipe.id)
        XCTAssertEqual(try repository.fetchInventoryTransactions(inventoryItemId: inventoryItem.id).count, 1)
    }

    func testChangingDraftOrderToReadyCannotBypassRecipeUsageValidation() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let recipe = Recipe(
            id: "recipe-unfinished",
            name: "Unfinished recipe",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = Order(
            id: "order-draft-recipe",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipe.id,
            title: "Draft cake",
            customerName: "Amy",
            status: .draft,
            dueAt: Date(timeIntervalSince1970: 1_800_050_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(recipe)
        try repository.save(order)

        XCTAssertThrowsError(
            try repository.changeOrderStatus(
                order: order,
                status: .ready,
                updatedAt: timestamp.addingTimeInterval(60),
                usageId: "usage-draft-recipe",
                transactionIdProvider: { "transaction-draft-recipe" }
            )
        ) { error in
            XCTAssertEqual(error as? OrderRecipeUsageError, .recipeHasNoIngredients)
        }
        XCTAssertEqual(try repository.fetchOrder(id: order.id)?.status, .draft)
        XCTAssertNil(try repository.fetchOrderRecipeUsage(orderId: order.id))
    }

    func testChangingConfirmedOrderStatusToCompletedRecordsRecipeUsageAndDeductsInventory() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let completedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let inventoryItem = InventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-buttercream",
            name: "Buttercream",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-frosting",
            recipeId: recipe.id,
            name: "Frosting",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-sugar",
            componentId: component.id,
            inventoryItemId: inventoryItem.id,
            quantity: 100,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = Order(
            id: "order-buttercream",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipe.id,
            title: "Buttercream cake",
            customerName: "Amy",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_050_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(inventoryItem)
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.save(order)

        let updatedOrder = try repository.changeOrderStatus(
            order: order,
            status: .completed,
            updatedAt: completedAt,
            usageId: "usage-order-buttercream",
            extraIngredients: nil,
            transactionIdProvider: { "transaction-order-buttercream-sugar" }
        )

        XCTAssertEqual(updatedOrder.status, .completed)
        XCTAssertEqual(try repository.fetchOrder(id: order.id)?.status, .completed)
        XCTAssertEqual(try repository.fetchInventoryItem(id: inventoryItem.id)?.currentQuantity, 400)
        XCTAssertEqual(try repository.fetchOrderRecipeUsage(orderId: order.id)?.recipeId, recipe.id)
        XCTAssertEqual(try repository.fetchInventoryTransactions(inventoryItemId: inventoryItem.id).count, 1)
    }

    func testShortageOverrideConsumesUsableStockAndRecordsFallbackCost() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let completedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let inventoryItem = InventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram,
            currentQuantity: 150,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-buttercream",
            name: "Buttercream",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-frosting",
            recipeId: recipe.id,
            name: "Frosting",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-sugar",
            componentId: component.id,
            inventoryItemId: inventoryItem.id,
            quantity: 100,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = Order(
            id: "order-buttercream",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipe.id,
            title: "Buttercream cake",
            customerName: "Amy",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_050_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let expiredBatch = InventoryStockBatch(
            id: "batch-expired",
            inventoryItemId: inventoryItem.id,
            remainingQuantity: 100,
            expiresAt: completedAt.addingTimeInterval(-1),
            amount: 80,
            createdAt: timestamp.addingTimeInterval(20),
            updatedAt: timestamp.addingTimeInterval(20)
        )
        let usableBatch = InventoryStockBatch(
            id: "batch-usable",
            inventoryItemId: inventoryItem.id,
            remainingQuantity: 50,
            expiresAt: completedAt.addingTimeInterval(86_400),
            amount: 25,
            createdAt: timestamp.addingTimeInterval(10),
            updatedAt: timestamp.addingTimeInterval(10)
        )

        try repository.save(inventoryItem)
        try repository.save(expiredBatch)
        try repository.save(usableBatch)
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.save(order)

        let expectedShortage = OrderInventoryShortage(
            inventoryItemId: inventoryItem.id,
            inventoryItemName: inventoryItem.name,
            requiredQuantity: 100,
            availableQuantity: 50,
            unit: .gram
        )
        XCTAssertThrowsError(
            try repository.changeOrderStatus(
                order: order,
                status: .completed,
                updatedAt: completedAt,
                usageId: "strict-usage",
                extraIngredients: nil,
                transactionIdProvider: { "strict-transaction" }
            )
        ) { error in
            XCTAssertEqual(error as? OrderRecipeUsageError, .insufficientStock([expectedShortage]))
        }
        XCTAssertEqual(try repository.fetchOrder(id: order.id)?.status, .confirmed)

        let updatedOrder = try repository.changeOrderStatus(
            order: order,
            status: .completed,
            updatedAt: completedAt,
            usageId: "override-usage",
            extraIngredients: nil,
            allowInventoryShortage: true,
            transactionIdProvider: { "override-transaction" }
        )

        XCTAssertEqual(updatedOrder.status, .completed)
        XCTAssertEqual(try repository.fetchInventoryItem(id: inventoryItem.id)?.currentQuantity, 100)
        let batches = try repository.fetchInventoryStockBatches(inventoryItemId: inventoryItem.id)
        XCTAssertEqual(batches.first(where: { $0.id == usableBatch.id })?.remainingQuantity, 0)
        XCTAssertEqual(batches.first(where: { $0.id == expiredBatch.id })?.remainingQuantity, 100)
        XCTAssertEqual(try repository.fetchInventoryTransactions(inventoryItemId: inventoryItem.id).map(\.quantity), [50])
        XCTAssertEqual(
            try repository.fetchOrderIngredientCosts(orderId: order.id),
            [
                OrderIngredientCost(
                    id: "\(order.id):\(inventoryItem.id)",
                    orderId: order.id,
                    inventoryItemId: inventoryItem.id,
                    quantity: 100,
                    unit: .gram,
                    knownCost: 65,
                    missingPriceQuantity: 0,
                    shortfallQuantity: 50,
                    recordedAt: completedAt
                )
            ]
        )
    }

}
