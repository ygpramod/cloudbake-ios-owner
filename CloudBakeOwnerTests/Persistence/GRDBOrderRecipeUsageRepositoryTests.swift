import GRDB
import XCTest
@testable import CloudBakeOwner

final class GRDBOrderRecipeUsageRepositoryTests: XCTestCase {
    func testOrderRecipeUsageDeductsInventoryFromOldestExpiringBatches() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let usedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let expiredAt = usedAt.addingTimeInterval(-1)
        let olderExpiry = Date(timeIntervalSince1970: 1_805_000_000)
        let newerExpiry = Date(timeIntervalSince1970: 1_806_000_000)
        let inventoryItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 575,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla sponge",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-sponge",
            recipeId: recipe.id,
            name: "Sponge",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: inventoryItem.id,
            quantity: 0.15,
            unit: .kilogram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = Order(
            id: "order-vanilla",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipe.id,
            title: "Vanilla birthday cake",
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
        try repository.save(
            InventoryStockBatch(
                id: "batch-expired-flour",
                inventoryItemId: inventoryItem.id,
                remainingQuantity: 75,
                expiresAt: expiredAt,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
        try repository.save(
            InventoryStockBatch(
                id: "batch-newer-flour",
                inventoryItemId: inventoryItem.id,
                remainingQuantity: 400,
                expiresAt: newerExpiry,
                amount: 200,
                createdAt: timestamp.addingTimeInterval(20),
                updatedAt: timestamp.addingTimeInterval(20)
            )
        )
        try repository.save(
            InventoryStockBatch(
                id: "batch-older-flour",
                inventoryItemId: inventoryItem.id,
                remainingQuantity: 100,
                expiresAt: olderExpiry,
                amount: 20,
                createdAt: timestamp.addingTimeInterval(10),
                updatedAt: timestamp.addingTimeInterval(10)
            )
        )
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.save(order)

        try repository.recordRecipeUsage(
            for: order,
            usageId: "usage-order-vanilla",
            usedAt: usedAt,
            transactionIdProvider: { "transaction-order-vanilla-flour" }
        )

        XCTAssertEqual(try repository.fetchInventoryItem(id: inventoryItem.id)?.currentQuantity, 425)
        XCTAssertEqual(
            try repository.fetchInventoryStockBatches(inventoryItemId: inventoryItem.id),
            [
                InventoryStockBatch(
                    id: "batch-expired-flour",
                    inventoryItemId: inventoryItem.id,
                    remainingQuantity: 75,
                    expiresAt: expiredAt,
                    createdAt: timestamp,
                    updatedAt: timestamp
                ),
                InventoryStockBatch(
                    id: "batch-older-flour",
                    inventoryItemId: inventoryItem.id,
                    remainingQuantity: 0,
                    expiresAt: olderExpiry,
                    amount: 20,
                    unitCost: decimal("0.2"),
                    createdAt: timestamp.addingTimeInterval(10),
                    updatedAt: usedAt
                ),
                InventoryStockBatch(
                    id: "batch-newer-flour",
                    inventoryItemId: inventoryItem.id,
                    remainingQuantity: 350,
                    expiresAt: newerExpiry,
                    amount: 200,
                    unitCost: decimal("0.5"),
                    createdAt: timestamp.addingTimeInterval(20),
                    updatedAt: usedAt
                )
            ]
        )
        XCTAssertEqual(
            try repository.fetchOrderRecipeUsage(orderId: order.id),
            OrderRecipeUsage(
                id: "usage-order-vanilla",
                orderId: order.id,
                recipeId: recipe.id,
                usedAt: usedAt,
                createdAt: usedAt,
                updatedAt: usedAt
            )
        )
        XCTAssertEqual(
            try repository.fetchOrderIngredientCosts(orderId: order.id),
            [
                OrderIngredientCost(
                    id: "\(order.id):\(inventoryItem.id)",
                    orderId: order.id,
                    inventoryItemId: inventoryItem.id,
                    quantity: 150,
                    unit: .gram,
                    knownCost: 45,
                    missingPriceQuantity: 0,
                    recordedAt: usedAt
                )
            ]
        )
        XCTAssertEqual(
            try repository.fetchInventoryTransactions(inventoryItemId: inventoryItem.id),
            [
                InventoryTransaction(
                    id: "transaction-order-vanilla-flour",
                    inventoryItemId: inventoryItem.id,
                    kind: .consumption,
                    quantity: 150,
                    occurredAt: usedAt,
                    note: "Order recipe usage: Vanilla birthday cake",
                    createdAt: usedAt,
                    updatedAt: usedAt
                )
            ]
        )
    }

    func testOrderRecipeUsageRejectsDuplicateWithoutDeductingAgain() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let usedAt = Date(timeIntervalSince1970: 1_800_020_000)
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
        try repository.recordRecipeUsage(
            for: order,
            usageId: "usage-order-buttercream",
            usedAt: usedAt,
            transactionIdProvider: { "transaction-order-buttercream-sugar" }
        )

        XCTAssertThrowsError(
            try repository.recordRecipeUsage(
                for: order,
                usageId: "usage-order-buttercream-again",
                usedAt: usedAt.addingTimeInterval(60),
                transactionIdProvider: { "transaction-order-buttercream-sugar-again" }
            )
        ) { error in
            XCTAssertEqual(error as? OrderRecipeUsageError, .alreadyRecorded)
        }
        XCTAssertEqual(try repository.fetchInventoryItem(id: inventoryItem.id)?.currentQuantity, 400)
        XCTAssertEqual(try repository.fetchInventoryTransactions(inventoryItemId: inventoryItem.id).count, 1)
    }

    func testOrderRecipeUsageAppliesOrderRecipeScaleMultiplier() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let usedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let inventoryItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla sponge",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-sponge",
            recipeId: recipe.id,
            name: "Sponge",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: inventoryItem.id,
            quantity: 100,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = Order(
            id: "order-vanilla",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipe.id,
            recipeScaleMultiplier: Decimal(string: "2.5")!,
            title: "Large vanilla birthday cake",
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

        try repository.recordRecipeUsage(
            for: order,
            usageId: "usage-order-vanilla",
            usedAt: usedAt,
            transactionIdProvider: { "transaction-order-vanilla-flour" }
        )

        XCTAssertEqual(try repository.fetchInventoryItem(id: inventoryItem.id)?.currentQuantity, 250)
        XCTAssertEqual(
            try repository.fetchOrderRecipeUsage(orderId: order.id),
            OrderRecipeUsage(
                id: "usage-order-vanilla",
                orderId: order.id,
                recipeId: recipe.id,
                recipeScaleMultiplier: Decimal(string: "2.5")!,
                usedAt: usedAt,
                createdAt: usedAt,
                updatedAt: usedAt
            )
        )
        XCTAssertEqual(
            try repository.fetchInventoryTransactions(inventoryItemId: inventoryItem.id),
            [
                InventoryTransaction(
                    id: "transaction-order-vanilla-flour",
                    inventoryItemId: inventoryItem.id,
                    kind: .consumption,
                    quantity: 250,
                    occurredAt: usedAt,
                    note: "Order recipe usage: Large vanilla birthday cake",
                    createdAt: usedAt,
                    updatedAt: usedAt
                )
            ]
        )
    }

    func testOrderRecipeUsageDeductsOrderExtraIngredients() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let usedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let flour = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let almonds = InventoryItem(
            id: "inventory-almonds",
            name: "Almonds",
            unit: .gram,
            currentQuantity: 200,
            minimumQuantity: 50,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-vanilla",
            name: "Vanilla cake",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-cake",
            recipeId: recipe.id,
            name: "Cake",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: flour.id,
            quantity: 100,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = Order(
            id: "order-vanilla",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipe.id,
            title: "Vanilla almond cake",
            customerName: "Amy",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_050_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let extraIngredient = OrderExtraIngredient(
            id: "extra-almonds",
            orderId: order.id,
            inventoryItemId: almonds.id,
            quantity: 0.05,
            unit: .kilogram,
            note: "Customer requested almond crunch",
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(flour)
        try repository.save(almonds)
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.save(order)
        try repository.save(extraIngredient)

        XCTAssertEqual(try repository.fetchOrderExtraIngredients(orderId: order.id), [extraIngredient])

        try repository.recordRecipeUsage(
            for: order,
            usageId: "usage-order-vanilla",
            usedAt: usedAt,
            transactionIdProvider: makeSequentialIdProvider(["transaction-almonds", "transaction-flour"])
        )

        XCTAssertEqual(try repository.fetchInventoryItem(id: flour.id)?.currentQuantity, 400)
        XCTAssertEqual(try repository.fetchInventoryItem(id: almonds.id)?.currentQuantity, 150)
        XCTAssertEqual(
            try repository.fetchInventoryTransactions(inventoryItemId: almonds.id),
            [
                InventoryTransaction(
                    id: "transaction-almonds",
                    inventoryItemId: almonds.id,
                    kind: .consumption,
                    quantity: 50,
                    occurredAt: usedAt,
                    note: "Order recipe usage: Vanilla almond cake",
                    createdAt: usedAt,
                    updatedAt: usedAt
                )
            ]
        )
    }

    func testOrderExtraIngredientCanBeDeleted() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let item = InventoryItem(
            id: "inventory-sprinkles",
            name: "Sprinkles",
            unit: .gram,
            currentQuantity: 200,
            minimumQuantity: 50,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = Order(
            id: "order-sprinkles",
            customerId: nil,
            cakeDesignId: nil,
            title: "Sprinkle cake",
            customerName: "Amy",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_050_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let extraIngredient = OrderExtraIngredient(
            id: "extra-sprinkles",
            orderId: order.id,
            inventoryItemId: item.id,
            quantity: 20,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(item)
        try repository.save(order)
        try repository.save(extraIngredient)
        try repository.deleteOrderExtraIngredient(id: extraIngredient.id)

        XCTAssertEqual(try repository.fetchOrderExtraIngredients(orderId: order.id), [])
    }

}
