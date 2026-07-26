import GRDB
import XCTest
@testable import CloudBakeOwner

final class GRDBOrderRecipeUsageRepositoryTests: XCTestCase {
    func testOrderAndCustomReminderConfigurationSaveTogether() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_004_000)
        let order = Order(
            id: "order-atomic-reminder",
            customerId: nil,
            cakeDesignId: nil,
            title: "Atomic reminder cake",
            customerName: "Amy",
            status: .draft,
            dueAt: timestamp.addingTimeInterval(100_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let configuration = try OrderReminderConfiguration(
            mode: .custom,
            dayOffsets: [8, 1],
            includesDueTime: false
        )

        try repository.saveOrder(
            order,
            replacingExtraIngredients: [],
            reminderConfiguration: configuration,
            allowInventoryShortage: false
        )

        XCTAssertEqual(try repository.fetchOrder(id: order.id), order)
        XCTAssertEqual(
            try repository.fetchOrderReminderConfiguration(orderId: order.id),
            configuration
        )
    }

    func testOrderReminderConfigurationsSnapshotDefaultsAndPersistOverrides() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_005_000)
        let firstOrder = Order(
            id: "order-reminder-original-default",
            customerId: nil,
            cakeDesignId: nil,
            title: "Original reminder cake",
            customerName: "Amy",
            status: .draft,
            dueAt: timestamp.addingTimeInterval(100_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(firstOrder)

        XCTAssertEqual(
            try repository.fetchDefaultOrderReminderConfiguration(),
            .initialDefault
        )
        XCTAssertEqual(
            try repository.fetchOrderReminderConfiguration(orderId: firstOrder.id),
            .initialDefault
        )

        let changedDefault = try OrderReminderConfiguration(
            mode: .custom,
            dayOffsets: [7, 1],
            includesDueTime: false
        )
        try repository.saveDefaultOrderReminderConfiguration(
            changedDefault,
            updatedAt: timestamp.addingTimeInterval(10)
        )
        XCTAssertEqual(
            try repository.fetchDefaultOrderReminderConfiguration(),
            try changedDefault.snapshotAsDefault()
        )
        XCTAssertEqual(
            try repository.fetchOrderReminderConfiguration(orderId: firstOrder.id),
            .initialDefault
        )

        let secondOrder = Order(
            id: "order-reminder-new-default",
            customerId: nil,
            cakeDesignId: nil,
            title: "New reminder cake",
            customerName: "Amy",
            status: .draft,
            dueAt: timestamp.addingTimeInterval(200_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp.addingTimeInterval(20),
            updatedAt: timestamp.addingTimeInterval(20)
        )
        try repository.save(secondOrder)
        XCTAssertEqual(
            try repository.fetchOrderReminderConfiguration(orderId: secondOrder.id),
            try changedDefault.snapshotAsDefault()
        )

        let customConfiguration = try OrderReminderConfiguration(
            mode: .custom,
            dayOffsets: [14, 2],
            includesDueTime: true
        )
        try repository.saveOrderReminderConfiguration(
            customConfiguration,
            orderId: firstOrder.id,
            updatedAt: timestamp.addingTimeInterval(30)
        )
        try repository.saveOrderReminderConfiguration(
            .disabled,
            orderId: secondOrder.id,
            updatedAt: timestamp.addingTimeInterval(30)
        )

        let configurations = try repository.fetchOrderReminderConfigurations(
            orderIds: [firstOrder.id, secondOrder.id]
                + (0..<1_001).map { "unknown-order-\($0)" }
        )
        XCTAssertEqual(configurations[firstOrder.id], customConfiguration)
        XCTAssertEqual(configurations[secondOrder.id], .disabled)
        XCTAssertEqual(configurations.count, 2)

        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE order_reminder_configurations
                    SET day_offsets_json = ?
                    WHERE order_id = ?
                    """,
                arguments: ["invalid-json", firstOrder.id]
            )
        }
        XCTAssertThrowsError(
            try repository.fetchOrderReminderConfiguration(orderId: firstOrder.id)
        ) { error in
            XCTAssertEqual(
                error as? OrderReminderConfigurationPersistenceError,
                .invalidDayOffsets
            )
        }
    }

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
        let otherOrder = Order(
            id: "order-other-sprinkles",
            customerId: nil,
            cakeDesignId: nil,
            title: "Other sprinkle cake",
            customerName: "Bea",
            status: .draft,
            dueAt: order.dueAt,
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
        try repository.save(otherOrder)
        try repository.save(extraIngredient)
        XCTAssertThrowsError(
            try repository.save(
                OrderExtraIngredient(
                    id: extraIngredient.id,
                    orderId: otherOrder.id,
                    inventoryItemId: extraIngredient.inventoryItemId,
                    quantity: extraIngredient.quantity,
                    unit: extraIngredient.unit,
                    note: extraIngredient.note,
                    createdAt: extraIngredient.createdAt,
                    updatedAt: timestamp.addingTimeInterval(10)
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? OrderExtraIngredientError,
                .orderReassignmentNotAllowed
            )
        }
        XCTAssertEqual(
            try repository.fetchOrderExtraIngredients(orderId: order.id),
            [extraIngredient]
        )
        XCTAssertThrowsError(
            try repository.saveOrder(
                otherOrder,
                replacingExtraIngredients: [
                    OrderExtraIngredient(
                        id: extraIngredient.id,
                        orderId: otherOrder.id,
                        inventoryItemId: extraIngredient.inventoryItemId,
                        quantity: extraIngredient.quantity,
                        unit: extraIngredient.unit,
                        note: extraIngredient.note,
                        createdAt: extraIngredient.createdAt,
                        updatedAt: timestamp.addingTimeInterval(20)
                    )
                ],
                allowInventoryShortage: false
            )
        ) { error in
            XCTAssertEqual(
                error as? OrderExtraIngredientError,
                .orderReassignmentNotAllowed
            )
        }
        XCTAssertEqual(
            try repository.fetchOrderExtraIngredients(orderId: order.id),
            [extraIngredient]
        )
        XCTAssertEqual(
            try repository.fetchOrderExtraIngredients(orderId: otherOrder.id),
            []
        )
        try repository.deleteOrderExtraIngredient(id: extraIngredient.id)

        XCTAssertEqual(try repository.fetchOrderExtraIngredients(orderId: order.id), [])
    }

    func testConfirmedOrderRejectsLinkedRecipeWithoutRequirements() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let recipe = Recipe(
            id: "recipe-empty-reservation",
            name: "Empty recipe",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let draftOrder = Order(
            id: "order-empty-reservation",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipe.id,
            title: "Empty recipe cake",
            customerName: "Amy",
            status: .draft,
            dueAt: timestamp.addingTimeInterval(10_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let confirmedOrder = Order(
            id: draftOrder.id,
            customerId: draftOrder.customerId,
            cakeDesignId: draftOrder.cakeDesignId,
            customerReferencePhotoId: draftOrder.customerReferencePhotoId,
            recipeId: draftOrder.recipeId,
            recipeScaleMultiplier: draftOrder.recipeScaleMultiplier,
            title: draftOrder.title,
            customerName: draftOrder.customerName,
            status: .confirmed,
            dueAt: draftOrder.dueAt,
            fulfillmentType: draftOrder.fulfillmentType,
            deliveryAddress: draftOrder.deliveryAddress,
            cakeNotes: draftOrder.cakeNotes,
            cakeMessage: draftOrder.cakeMessage,
            quotedPrice: draftOrder.quotedPrice,
            depositPaid: draftOrder.depositPaid,
            paymentNotes: draftOrder.paymentNotes,
            createdAt: draftOrder.createdAt,
            updatedAt: timestamp.addingTimeInterval(10)
        )
        try repository.save(recipe)
        try repository.save(draftOrder)

        XCTAssertThrowsError(
            try repository.saveOrder(
                confirmedOrder,
                replacingExtraIngredients: [],
                allowInventoryShortage: false
            )
        ) { error in
            XCTAssertEqual(error as? OrderRecipeUsageError, .recipeHasNoIngredients)
        }
        XCTAssertEqual(try repository.fetchOrder(id: draftOrder.id), draftOrder)
    }

    func testReservationPlanningSnapshotLoadsLiveRequirementsAndStockBatches() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_025_000)
        let item = InventoryItem(
            id: "inventory-planning-flour",
            name: "Planning flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let batch = InventoryStockBatch(
            id: "batch-planning-flour",
            inventoryItemId: item.id,
            remainingQuantity: 350,
            expiresAt: timestamp.addingTimeInterval(100_000),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-planning-cake",
            name: "Planning cake",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-planning-cake",
            recipeId: recipe.id,
            name: "Cake",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-planning-flour",
            componentId: component.id,
            inventoryItemId: item.id,
            quantity: 100,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = Order(
            id: "order-planning-cake",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipe.id,
            recipeScaleMultiplier: 2,
            title: "Planning cake",
            customerName: "Amy",
            status: .draft,
            dueAt: timestamp.addingTimeInterval(10_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let extra = OrderExtraIngredient(
            id: "extra-planning-flour",
            orderId: order.id,
            inventoryItemId: item.id,
            quantity: 50,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(item)
        try repository.save(batch)
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.save(order)
        try repository.save(extra)

        let snapshot = try repository.fetchOrderInventoryReservationPlanningSnapshot(
            orderIds: [order.id]
        )

        XCTAssertEqual(
            snapshot.liveRequirementsByOrderId[order.id],
            [
                OrderInventoryRequirement(
                    inventoryItemId: item.id,
                    quantity: 200,
                    unit: .gram
                ),
                OrderInventoryRequirement(
                    inventoryItemId: item.id,
                    quantity: 50,
                    unit: .gram
                )
            ]
        )
        XCTAssertEqual(snapshot.stockBatchesByInventoryItemId[item.id], [batch])
        XCTAssertTrue(snapshot.invalidOrderIds.isEmpty)
        XCTAssertTrue(snapshot.invalidLiveRequirementOrderIds.isEmpty)

        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE orders
                    SET recipe_scale_multiplier_decimal = ?
                    WHERE id = ?
                    """,
                arguments: ["invalid-scale", order.id]
            )
        }
        let corruptSnapshot = try repository.fetchOrderInventoryReservationPlanningSnapshot(
            orderIds: [order.id]
        )
        XCTAssertTrue(corruptSnapshot.invalidOrderIds.isEmpty)
        XCTAssertEqual(corruptSnapshot.invalidLiveRequirementOrderIds, [order.id])
        XCTAssertEqual(
            corruptSnapshot.liveRequirementsByOrderId[order.id],
            [
                OrderInventoryRequirement(
                    inventoryItemId: item.id,
                    quantity: 50,
                    unit: .gram
                )
            ]
        )
    }

    func testOrderInventoryReservationStateCanBeRead() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_030_000)
        let item = InventoryItem(
            id: "inventory-reserved-flour",
            name: "Reserved flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = Order(
            id: "order-reserved-flour",
            customerId: nil,
            cakeDesignId: nil,
            title: "Reserved flour cake",
            customerName: "Amy",
            status: .confirmed,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let pendingRepairOrder = Order(
            id: "order-reservation-repair-pending",
            customerId: nil,
            cakeDesignId: nil,
            title: "Pending reservation repair",
            customerName: "Amy",
            status: .confirmed,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let failedRepairOrder = Order(
            id: "order-reservation-repair-failed",
            customerId: nil,
            cakeDesignId: nil,
            title: "Failed reservation repair",
            customerName: "Amy",
            status: .confirmed,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(item)
        try repository.save(order)
        try repository.save(pendingRepairOrder)
        try repository.save(failedRepairOrder)

        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservations
                    (id, order_id, inventory_item_id, required_quantity, unit,
                     created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "\(order.id):\(item.id)",
                    order.id,
                    item.id,
                    125,
                    item.unit.rawValue,
                    timestamp.timeIntervalSince1970,
                    timestamp.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_events
                    (id, order_id, inventory_item_id, event_kind, reason, previous_quantity,
                     new_quantity, unit, occurred_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "reservation-event-changed",
                    order.id,
                    item.id,
                    OrderInventoryReservationEventKind.quantityChanged.rawValue,
                    OrderInventoryReservationEventReason.orderEdited.rawValue,
                    125,
                    150,
                    item.unit.rawValue,
                    timestamp.addingTimeInterval(10).timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_events
                    (id, order_id, inventory_item_id, event_kind, reason, previous_quantity,
                     new_quantity, unit, occurred_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "reservation-event-created",
                    order.id,
                    item.id,
                    OrderInventoryReservationEventKind.created.rawValue,
                    OrderInventoryReservationEventReason.orderConfirmed.rawValue,
                    0,
                    125,
                    item.unit.rawValue,
                    timestamp.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_repairs
                    (order_id, state, attempt_count, last_attempted_at_unix_time,
                     failure_code, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, NULL, ?)
                    """,
                arguments: [
                    order.id,
                    OrderInventoryReservationRepairState.complete.rawValue,
                    1,
                    timestamp.timeIntervalSince1970,
                    timestamp.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_repairs
                    (order_id, state, attempt_count, last_attempted_at_unix_time,
                     failure_code, updated_at_unix_time)
                    VALUES (?, ?, ?, NULL, NULL, ?)
                    """,
                arguments: [
                    pendingRepairOrder.id,
                    OrderInventoryReservationRepairState.pending.rawValue,
                    0,
                    timestamp.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_repairs
                    (order_id, state, attempt_count, last_attempted_at_unix_time,
                     failure_code, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    failedRepairOrder.id,
                    OrderInventoryReservationRepairState.failed.rawValue,
                    2,
                    timestamp.timeIntervalSince1970,
                    OrderInventoryReservationRepairFailureCode.incompatibleUnit.rawValue,
                    timestamp.timeIntervalSince1970
                ]
            )
        }

        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: order.id),
            [
                OrderInventoryReservation(
                    id: "\(order.id):\(item.id)",
                    orderId: order.id,
                    inventoryItemId: item.id,
                    requiredQuantity: 125,
                    unit: .gram,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            ]
        )
        XCTAssertEqual(
            try repository.fetchInventoryReservationTotal(
                inventoryItemId: item.id,
                excludingOrderId: nil
            ),
            125
        )
        XCTAssertEqual(
            try repository.fetchInventoryReservationTotal(
                inventoryItemId: item.id,
                excludingOrderId: order.id
            ),
            0
        )
        let events = try repository.fetchOrderInventoryReservationEvents(
            orderId: order.id,
            limit: 50
        )
        XCTAssertEqual(events.map(\.id), ["reservation-event-changed", "reservation-event-created"])
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationEvents(orderId: order.id, limit: 1).map(\.id),
            ["reservation-event-changed"]
        )
        XCTAssertThrowsError(
            try repository.fetchOrderInventoryReservationEvents(orderId: order.id, limit: 0)
        ) { error in
            XCTAssertEqual(error as? OrderInventoryReservationQueryError, .invalidLimit)
        }
        let event = events[1]
        XCTAssertEqual(event.id, "reservation-event-created")
        XCTAssertEqual(event.orderId, order.id)
        XCTAssertEqual(event.inventoryItemId, item.id)
        XCTAssertEqual(event.kind, .created)
        XCTAssertEqual(event.reason, .orderConfirmed)
        XCTAssertEqual(event.previousQuantity, 0)
        XCTAssertEqual(event.newQuantity, 125)
        XCTAssertEqual(event.unit, .gram)
        XCTAssertEqual(event.occurredAt, timestamp)
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: order.id),
            OrderInventoryReservationRepair(
                orderId: order.id,
                state: .complete,
                attemptCount: 1,
                lastAttemptedAt: timestamp,
                failureCode: nil,
                updatedAt: timestamp
            )
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: pendingRepairOrder.id),
            OrderInventoryReservationRepair(
                orderId: pendingRepairOrder.id,
                state: .pending,
                attemptCount: 0,
                lastAttemptedAt: nil,
                failureCode: nil,
                updatedAt: timestamp
            )
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: failedRepairOrder.id),
            OrderInventoryReservationRepair(
                orderId: failedRepairOrder.id,
                state: .failed,
                attemptCount: 2,
                lastAttemptedAt: timestamp,
                failureCode: .incompatibleUnit,
                updatedAt: timestamp
            )
        )
        let planningSnapshot = try repository.fetchOrderInventoryReservationPlanningSnapshot(
            orderIds: [
                order.id,
                pendingRepairOrder.id,
                failedRepairOrder.id,
                "unknown-order"
            ] + (0..<1_001).map { "unknown-order-\($0)" }
        )
        XCTAssertTrue(planningSnapshot.consumedOrderIds.isEmpty)
        XCTAssertEqual(
            planningSnapshot.reservationsByOrderId[order.id],
            try repository.fetchOrderInventoryReservations(orderId: order.id)
        )
        XCTAssertEqual(planningSnapshot.repairsByOrderId.count, 3)
        XCTAssertEqual(planningSnapshot.repairsByOrderId[order.id]?.state, .complete)
        XCTAssertEqual(
            planningSnapshot.repairsByOrderId[pendingRepairOrder.id]?.state,
            .pending
        )
        XCTAssertEqual(
            planningSnapshot.repairsByOrderId[failedRepairOrder.id]?.state,
            .failed
        )

        try queue.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            try db.execute(
                sql: "UPDATE order_inventory_reservations SET unit = ? WHERE id = ?",
                arguments: ["invalid-unit", "\(order.id):\(item.id)"]
            )
            try db.execute(sql: "PRAGMA ignore_check_constraints = OFF")
        }
        XCTAssertThrowsError(
            try repository.fetchOrderInventoryReservations(orderId: order.id)
        ) { error in
            XCTAssertEqual(
                error as? OrderInventoryReservationPersistenceError,
                .invalidUnit("invalid-unit")
            )
        }
        let corruptPlanningSnapshot =
            try repository.fetchOrderInventoryReservationPlanningSnapshot(
                orderIds: [order.id, pendingRepairOrder.id]
            )
        XCTAssertEqual(corruptPlanningSnapshot.invalidOrderIds, [order.id])
        XCTAssertEqual(
            corruptPlanningSnapshot.repairsByOrderId[pendingRepairOrder.id]?.state,
            .pending
        )

        try queue.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            try db.execute(
                sql: "UPDATE order_inventory_reservation_events SET event_kind = ? WHERE id = ?",
                arguments: ["invalid-event", "reservation-event-created"]
            )
            try db.execute(sql: "PRAGMA ignore_check_constraints = OFF")
        }
        XCTAssertThrowsError(
            try repository.fetchOrderInventoryReservationEvents(orderId: order.id, limit: 50)
        ) { error in
            XCTAssertEqual(
                error as? OrderInventoryReservationPersistenceError,
                .invalidEventKind("invalid-event")
            )
        }
        try queue.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            try db.execute(
                sql: """
                    UPDATE order_inventory_reservation_events
                    SET event_kind = ?, reason = ?
                    WHERE id = ?
                    """,
                arguments: [
                    OrderInventoryReservationEventKind.created.rawValue,
                    "invalid-reason",
                    "reservation-event-created"
                ]
            )
            try db.execute(sql: "PRAGMA ignore_check_constraints = OFF")
        }
        XCTAssertThrowsError(
            try repository.fetchOrderInventoryReservationEvents(orderId: order.id, limit: 50)
        ) { error in
            XCTAssertEqual(
                error as? OrderInventoryReservationPersistenceError,
                .invalidEventReason("invalid-reason")
            )
        }

        try queue.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            try db.execute(
                sql: "UPDATE order_inventory_reservation_repairs SET state = ? WHERE order_id = ?",
                arguments: ["invalid-state", pendingRepairOrder.id]
            )
            try db.execute(
                sql: "UPDATE order_inventory_reservation_repairs SET failure_code = ? WHERE order_id = ?",
                arguments: ["invalid-failure", failedRepairOrder.id]
            )
            try db.execute(sql: "PRAGMA ignore_check_constraints = OFF")
        }
        XCTAssertThrowsError(
            try repository.fetchOrderInventoryReservationRepair(orderId: pendingRepairOrder.id)
        ) { error in
            XCTAssertEqual(
                error as? OrderInventoryReservationPersistenceError,
                .invalidRepairState("invalid-state")
            )
        }
        XCTAssertThrowsError(
            try repository.fetchOrderInventoryReservationRepair(orderId: failedRepairOrder.id)
        ) { error in
            XCTAssertEqual(
                error as? OrderInventoryReservationPersistenceError,
                .invalidRepairFailureCode("invalid-failure")
            )
        }
    }

    func testOrderStatusLifecycleCreatesConsumesAndDoesNotRecreateReservation() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_040_000)
        let confirmedAt = timestamp.addingTimeInterval(100)
        let readyAt = timestamp.addingTimeInterval(200)
        let reopenedAt = timestamp.addingTimeInterval(300)
        let flour = InventoryItem(
            id: "inventory-reservation-flour",
            name: "Reservation flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-reservation-cake",
            name: "Reservation cake",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-reservation-cake",
            recipeId: recipe.id,
            name: "Cake",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-reservation-flour",
            componentId: component.id,
            inventoryItemId: flour.id,
            quantity: 100,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let draftOrder = Order(
            id: "order-reservation-cake",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipe.id,
            recipeScaleMultiplier: 2,
            title: "Reservation cake",
            customerName: "Amy",
            status: .draft,
            dueAt: timestamp.addingTimeInterval(10_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let extraIngredient = OrderExtraIngredient(
            id: "extra-reservation-flour",
            orderId: draftOrder.id,
            inventoryItemId: flour.id,
            quantity: 50,
            unit: .gram,
            note: "Extra flour",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(flour)
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.save(draftOrder)
        try repository.save(extraIngredient)

        let confirmedOrder = try repository.changeOrderStatus(
            order: draftOrder,
            status: .confirmed,
            updatedAt: confirmedAt,
            usageId: "unused-confirmation-usage",
            extraIngredients: nil,
            transactionIdProvider: { "unused-confirmation-transaction" }
        )

        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: draftOrder.id),
            [
                OrderInventoryReservation(
                    id: "\(draftOrder.id):\(flour.id)",
                    orderId: draftOrder.id,
                    inventoryItemId: flour.id,
                    requiredQuantity: 250,
                    unit: .gram,
                    createdAt: confirmedAt,
                    updatedAt: confirmedAt
                )
            ]
        )
        let createdEvent = try XCTUnwrap(
            repository.fetchOrderInventoryReservationEvents(
                orderId: draftOrder.id,
                limit: 50
            ).first
        )
        XCTAssertEqual(createdEvent.kind, .created)
        XCTAssertEqual(createdEvent.reason, .orderConfirmed)
        XCTAssertEqual(createdEvent.previousQuantity, 0)
        XCTAssertEqual(createdEvent.newQuantity, 250)
        XCTAssertEqual(try repository.fetchInventoryItem(id: flour.id)?.currentQuantity, 500)

        try repository.save(
            OrderExtraIngredient(
                id: extraIngredient.id,
                orderId: extraIngredient.orderId,
                inventoryItemId: extraIngredient.inventoryItemId,
                quantity: 100,
                unit: extraIngredient.unit,
                note: extraIngredient.note,
                createdAt: extraIngredient.createdAt,
                updatedAt: confirmedAt.addingTimeInterval(10)
            )
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: draftOrder.id)
                .first?
                .requiredQuantity,
            300
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationEvents(
                orderId: draftOrder.id,
                limit: 50
            ).first?.kind,
            .quantityChanged
        )

        let directReadyOrder = Order(
            id: confirmedOrder.id,
            customerId: confirmedOrder.customerId,
            cakeDesignId: confirmedOrder.cakeDesignId,
            customerReferencePhotoId: confirmedOrder.customerReferencePhotoId,
            recipeId: confirmedOrder.recipeId,
            recipeScaleMultiplier: confirmedOrder.recipeScaleMultiplier,
            title: confirmedOrder.title,
            customerName: confirmedOrder.customerName,
            status: .ready,
            dueAt: confirmedOrder.dueAt,
            fulfillmentType: confirmedOrder.fulfillmentType,
            deliveryAddress: confirmedOrder.deliveryAddress,
            cakeNotes: confirmedOrder.cakeNotes,
            cakeMessage: confirmedOrder.cakeMessage,
            quotedPrice: confirmedOrder.quotedPrice,
            depositPaid: confirmedOrder.depositPaid,
            paymentNotes: confirmedOrder.paymentNotes,
            createdAt: confirmedOrder.createdAt,
            updatedAt: readyAt
        )
        XCTAssertThrowsError(
            try repository.saveOrder(
                directReadyOrder,
                replacingExtraIngredients: try repository.fetchOrderExtraIngredients(
                    orderId: confirmedOrder.id
                ),
                allowInventoryShortage: false
            )
        ) { error in
            XCTAssertEqual(
                error as? OrderRecipeUsageError,
                .inventoryConsumptionRequired
            )
        }
        XCTAssertNil(try repository.fetchOrderRecipeUsage(orderId: confirmedOrder.id))
        XCTAssertEqual(try repository.fetchOrder(id: confirmedOrder.id)?.status, .confirmed)
        XCTAssertEqual(try repository.fetchInventoryItem(id: flour.id)?.currentQuantity, 500)
        let unlinkedDirectReadyOrder = Order(
            id: directReadyOrder.id,
            customerId: directReadyOrder.customerId,
            cakeDesignId: directReadyOrder.cakeDesignId,
            customerReferencePhotoId: directReadyOrder.customerReferencePhotoId,
            recipeId: nil,
            recipeScaleMultiplier: 1,
            title: directReadyOrder.title,
            customerName: directReadyOrder.customerName,
            status: directReadyOrder.status,
            dueAt: directReadyOrder.dueAt,
            fulfillmentType: directReadyOrder.fulfillmentType,
            deliveryAddress: directReadyOrder.deliveryAddress,
            cakeNotes: directReadyOrder.cakeNotes,
            cakeMessage: directReadyOrder.cakeMessage,
            quotedPrice: directReadyOrder.quotedPrice,
            depositPaid: directReadyOrder.depositPaid,
            paymentNotes: directReadyOrder.paymentNotes,
            createdAt: directReadyOrder.createdAt,
            updatedAt: directReadyOrder.updatedAt
        )
        XCTAssertThrowsError(
            try repository.saveOrder(
                unlinkedDirectReadyOrder,
                replacingExtraIngredients: try repository.fetchOrderExtraIngredients(
                    orderId: confirmedOrder.id
                ),
                allowInventoryShortage: false
            )
        ) { error in
            XCTAssertEqual(
                error as? OrderRecipeUsageError,
                .inventoryConsumptionRequired
            )
        }

        let readyOrder = try repository.changeOrderStatus(
            order: directReadyOrder,
            status: .ready,
            updatedAt: readyAt,
            usageId: "usage-reservation-cake",
            extraIngredients: nil,
            transactionIdProvider: { "transaction-reservation-cake" }
        )

        XCTAssertEqual(try repository.fetchOrderInventoryReservations(orderId: draftOrder.id), [])
        XCTAssertEqual(try repository.fetchInventoryItem(id: flour.id)?.currentQuantity, 200)
        let readyEvents = try repository.fetchOrderInventoryReservationEvents(
            orderId: draftOrder.id,
            limit: 50
        )
        XCTAssertEqual(readyEvents.map(\.kind), [.released, .quantityChanged, .created])
        XCTAssertEqual(readyEvents.first?.reason, .inventoryConsumed)
        XCTAssertEqual(readyEvents.first?.previousQuantity, 300)
        XCTAssertEqual(readyEvents.first?.newQuantity, 0)

        _ = try repository.changeOrderStatus(
            order: readyOrder,
            status: .confirmed,
            updatedAt: reopenedAt,
            usageId: "unused-reopened-usage",
            extraIngredients: nil,
            transactionIdProvider: { "unused-reopened-transaction" }
        )

        XCTAssertEqual(try repository.fetchOrderInventoryReservations(orderId: draftOrder.id), [])
        XCTAssertNotNil(try repository.fetchOrderRecipeUsage(orderId: draftOrder.id))
        XCTAssertEqual(try repository.fetchInventoryItem(id: flour.id)?.currentQuantity, 200)
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationEvents(
                orderId: draftOrder.id,
                limit: 50
            ).count,
            3
        )
    }

    func testOrderConfirmationUsesOtherReservationsAndSupportsShortageOverride() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_050_000)
        let flour = InventoryItem(
            id: "inventory-shared-reservation-flour",
            name: "Shared reservation flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-shared-reservation",
            name: "Shared reservation cake",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-shared-reservation",
            recipeId: recipe.id,
            name: "Cake",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-shared-reservation-flour",
            componentId: component.id,
            inventoryItemId: flour.id,
            quantity: 300,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        func makeOrder(id: String) -> Order {
            Order(
                id: id,
                customerId: nil,
                cakeDesignId: nil,
                recipeId: recipe.id,
                title: id,
                customerName: "Amy",
                status: .draft,
                dueAt: timestamp.addingTimeInterval(10_000),
                fulfillmentType: .pickup,
                deliveryAddress: nil,
                cakeNotes: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        }
        let firstOrder = makeOrder(id: "order-first-reservation")
        let secondOrder = makeOrder(id: "order-second-reservation")
        try repository.save(flour)
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.save(firstOrder)
        try repository.save(secondOrder)

        _ = try repository.changeOrderStatus(
            order: firstOrder,
            status: .confirmed,
            updatedAt: timestamp.addingTimeInterval(10),
            usageId: "unused-first-usage",
            extraIngredients: nil,
            transactionIdProvider: { "unused-first-transaction" }
        )
        let secondConfirmedOrder = Order(
            id: secondOrder.id,
            customerId: secondOrder.customerId,
            cakeDesignId: secondOrder.cakeDesignId,
            customerReferencePhotoId: secondOrder.customerReferencePhotoId,
            recipeId: secondOrder.recipeId,
            recipeScaleMultiplier: secondOrder.recipeScaleMultiplier,
            title: secondOrder.title,
            customerName: secondOrder.customerName,
            status: .confirmed,
            dueAt: secondOrder.dueAt,
            fulfillmentType: secondOrder.fulfillmentType,
            deliveryAddress: secondOrder.deliveryAddress,
            cakeNotes: secondOrder.cakeNotes,
            cakeMessage: secondOrder.cakeMessage,
            quotedPrice: secondOrder.quotedPrice,
            depositPaid: secondOrder.depositPaid,
            paymentNotes: secondOrder.paymentNotes,
            createdAt: secondOrder.createdAt,
            updatedAt: timestamp.addingTimeInterval(20)
        )

        XCTAssertThrowsError(
            try repository.saveOrder(
                secondConfirmedOrder,
                replacingExtraIngredients: [],
                allowInventoryShortage: false
            )
        ) { error in
            XCTAssertEqual(
                error as? OrderRecipeUsageError,
                .insufficientStock([
                    OrderInventoryShortage(
                        inventoryItemId: flour.id,
                        inventoryItemName: flour.name,
                        requiredQuantity: 300,
                        availableQuantity: 200,
                        unit: .gram
                    )
                ])
            )
        }
        XCTAssertEqual(try repository.fetchOrder(id: secondOrder.id)?.status, .draft)
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: secondOrder.id),
            []
        )

        try repository.saveOrder(
            secondConfirmedOrder,
            replacingExtraIngredients: [],
            allowInventoryShortage: true
        )

        XCTAssertEqual(
            try repository.fetchInventoryReservationTotal(
                inventoryItemId: flour.id,
                excludingOrderId: nil
            ),
            600
        )
        XCTAssertEqual(try repository.fetchInventoryItem(id: flour.id)?.currentQuantity, 500)

        let extraIngredient = OrderExtraIngredient(
            id: "extra-first-reservation",
            orderId: firstOrder.id,
            inventoryItemId: flour.id,
            quantity: 1,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp.addingTimeInterval(30)
        )
        XCTAssertThrowsError(try repository.save(extraIngredient)) { error in
            XCTAssertEqual(
                error as? OrderRecipeUsageError,
                .insufficientStock([
                    OrderInventoryShortage(
                        inventoryItemId: flour.id,
                        inventoryItemName: flour.name,
                        requiredQuantity: 301,
                        availableQuantity: 200,
                        unit: .gram
                    )
                ])
            )
        }
        XCTAssertEqual(
            try repository.fetchOrderExtraIngredients(orderId: firstOrder.id),
            []
        )
    }

    func testReservationRepairCompletesValidOrdersAndRetriesFailures() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        var eventSequence = 0
        let repository = GRDBCoreDataRepository(
            writer: queue,
            idProvider: {
                eventSequence += 1
                return "repair-event-\(eventSequence)"
            }
        )
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let repairedAt = timestamp.addingTimeInterval(100)
        let flour = InventoryItem(
            id: "inventory-repair-flour",
            name: "Repair flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let validComponent = RecipeComponent(
            id: "component-repair-valid",
            recipeId: "recipe-repair-valid",
            name: "Valid",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let invalidComponent = RecipeComponent(
            id: "component-repair-invalid",
            recipeId: "recipe-repair-invalid",
            name: "Invalid",
            sortOrder: 1,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let validIngredient = RecipeIngredient(
            id: "ingredient-repair-valid",
            componentId: validComponent.id,
            inventoryItemId: flour.id,
            quantity: 100,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let invalidIngredient = RecipeIngredient(
            id: "ingredient-repair-invalid",
            componentId: invalidComponent.id,
            inventoryItemId: flour.id,
            quantity: 1,
            unit: .each,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        func makeOrder(
            id: String,
            recipeId: String?,
            status: OrderStatus = .confirmed
        ) -> Order {
            Order(
                id: id,
                customerId: nil,
                cakeDesignId: nil,
                recipeId: recipeId,
                title: id,
                customerName: "Amy",
                status: status,
                dueAt: timestamp.addingTimeInterval(10_000),
                fulfillmentType: .pickup,
                deliveryAddress: nil,
                cakeNotes: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        }
        let validRecipe = Recipe(
            id: "recipe-repair-valid",
            name: "Valid repair recipe",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let invalidRecipe = Recipe(
            id: "recipe-repair-invalid",
            name: "Invalid repair recipe",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let validOrder = makeOrder(id: "order-repair-valid", recipeId: validRecipe.id)
        let invalidOrder = makeOrder(id: "order-repair-invalid", recipeId: invalidRecipe.id)
        let extraOnlyDraftOrder = makeOrder(
            id: "order-repair-extra-only",
            recipeId: nil,
            status: .draft
        )
        let extraOnlyOrder = makeOrder(
            id: extraOnlyDraftOrder.id,
            recipeId: nil
        )
        let extraOnlyIngredient = OrderExtraIngredient(
            id: "extra-repair-only",
            orderId: extraOnlyOrder.id,
            inventoryItemId: flour.id,
            quantity: 50,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(flour)
        try repository.save(validRecipe)
        try repository.save(invalidRecipe)
        try repository.save(validComponent)
        try repository.save(invalidComponent)
        try repository.save(validIngredient)
        try repository.save(invalidIngredient)
        try repository.save(validOrder)
        try repository.save(invalidOrder)
        try repository.save(extraOnlyDraftOrder)
        try repository.save(extraOnlyIngredient)
        try repository.save(extraOnlyOrder)
        try queue.write { db in
            for order in [validOrder, invalidOrder, extraOnlyOrder] {
                try db.execute(
                    sql: """
                        INSERT INTO order_inventory_reservation_repairs
                        (order_id, state, attempt_count, updated_at_unix_time)
                        VALUES (?, ?, 0, ?)
                        """,
                    arguments: [
                        order.id,
                        OrderInventoryReservationRepairState.pending.rawValue,
                        timestamp.timeIntervalSince1970
                    ]
                )
            }
        }

        XCTAssertEqual(
            try repository.repairOrderInventoryReservations(
                limit: 50,
                at: repairedAt,
                activationId: "activation-1"
            ),
            OrderInventoryReservationRepairSummary(completedCount: 2, failedCount: 1)
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: validOrder.id)
                .first?
                .requiredQuantity,
            100
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: validOrder.id)?.state,
            .complete
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: extraOnlyOrder.id)
                .first?
                .requiredQuantity,
            50
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: extraOnlyOrder.id)?.state,
            .complete
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: invalidOrder.id),
            OrderInventoryReservationRepair(
                orderId: invalidOrder.id,
                state: .failed,
                attemptCount: 1,
                lastAttemptedAt: repairedAt,
                failureCode: .incompatibleUnit,
                updatedAt: repairedAt
            )
        )
        let failureEvent = try XCTUnwrap(
            repository.fetchOrderInventoryReservationEvents(
                orderId: invalidOrder.id,
                limit: 50
            ).first
        )
        XCTAssertEqual(failureEvent.kind, .repairFailed)
        XCTAssertEqual(failureEvent.reason, .migrationRepair)
        XCTAssertNil(failureEvent.inventoryItemId)
        XCTAssertNil(failureEvent.unit)

        XCTAssertEqual(
            try repository.repairOrderInventoryReservations(
                limit: 50,
                at: repairedAt,
                activationId: "activation-1"
            ),
            OrderInventoryReservationRepairSummary(completedCount: 0, failedCount: 0)
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: invalidOrder.id)?.attemptCount,
            1
        )

        let retryAt = repairedAt.addingTimeInterval(-20)
        XCTAssertEqual(
            try repository.repairOrderInventoryReservations(
                limit: 50,
                at: retryAt,
                activationId: "activation-2"
            ),
            OrderInventoryReservationRepairSummary(completedCount: 0, failedCount: 1)
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: invalidOrder.id)?.attemptCount,
            2
        )

        try repository.save(
            RecipeIngredient(
                id: invalidIngredient.id,
                componentId: invalidIngredient.componentId,
                inventoryItemId: invalidIngredient.inventoryItemId,
                quantity: 100,
                unit: .gram,
                note: invalidIngredient.note,
                createdAt: invalidIngredient.createdAt,
                updatedAt: repairedAt.addingTimeInterval(10)
            )
        )

        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: invalidOrder.id)?.state,
            .complete
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: invalidOrder.id)?.attemptCount,
            2
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: invalidOrder.id)
                .first?
                .requiredQuantity,
            100
        )
        XCTAssertEqual(
            try repository.repairOrderInventoryReservations(
                limit: 50,
                at: retryAt,
                activationId: "activation-2"
            ),
            OrderInventoryReservationRepairSummary(completedCount: 0, failedCount: 0)
        )
    }

    func testReservationRepairReportsPendingRowsBeyondBatchLimit() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_085_000)

        for index in 1...2 {
            let order = Order(
                id: "order-repair-page-\(index)",
                customerId: nil,
                cakeDesignId: nil,
                title: "Repair page \(index)",
                customerName: "Amy",
                status: .draft,
                dueAt: timestamp.addingTimeInterval(10_000),
                fulfillmentType: .pickup,
                deliveryAddress: nil,
                cakeNotes: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
            try repository.save(order)
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO order_inventory_reservation_repairs
                        (order_id, state, attempt_count, updated_at_unix_time)
                        VALUES (?, ?, 0, ?)
                        """,
                    arguments: [
                        order.id,
                        OrderInventoryReservationRepairState.pending.rawValue,
                        timestamp.timeIntervalSince1970
                    ]
                )
            }
        }

        XCTAssertEqual(
            try repository.repairOrderInventoryReservations(
                limit: 1,
                at: timestamp.addingTimeInterval(10),
                activationId: "page-activation"
            ),
            OrderInventoryReservationRepairSummary(
                completedCount: 1,
                failedCount: 0,
                hasMore: true
            )
        )
        XCTAssertEqual(
            try repository.repairOrderInventoryReservations(
                limit: 1,
                at: timestamp.addingTimeInterval(10),
                activationId: "page-activation"
            ),
            OrderInventoryReservationRepairSummary(
                completedCount: 1,
                failedCount: 0
            )
        )
    }

    func testReservationRepairPropagatesInfrastructureFailureAndStaysPending() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(
            writer: queue,
            idProvider: { "duplicate-repair-event" }
        )
        let timestamp = Date(timeIntervalSince1970: 1_800_080_000)
        let flour = InventoryItem(
            id: "inventory-repair-infrastructure",
            name: "Infrastructure flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        func makeOrder(status: OrderStatus) -> Order {
            Order(
                id: "order-repair-infrastructure",
                customerId: nil,
                cakeDesignId: nil,
                title: "Infrastructure repair",
                customerName: "Amy",
                status: status,
                dueAt: timestamp.addingTimeInterval(10_000),
                fulfillmentType: .pickup,
                deliveryAddress: nil,
                cakeNotes: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        }
        let draftOrder = makeOrder(status: .draft)
        let confirmedOrder = makeOrder(status: .confirmed)
        let extraIngredient = OrderExtraIngredient(
            id: "extra-repair-infrastructure",
            orderId: draftOrder.id,
            inventoryItemId: flour.id,
            quantity: 50,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(flour)
        try repository.save(draftOrder)
        try repository.save(extraIngredient)
        try repository.save(confirmedOrder)
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_repairs
                    (order_id, state, attempt_count, updated_at_unix_time)
                    VALUES (?, ?, 0, ?)
                    """,
                arguments: [
                    confirmedOrder.id,
                    OrderInventoryReservationRepairState.pending.rawValue,
                    timestamp.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO order_inventory_reservation_events
                    (id, order_id, inventory_item_id, event_kind, reason,
                     previous_quantity, new_quantity, unit, occurred_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "duplicate-repair-event",
                    confirmedOrder.id,
                    flour.id,
                    OrderInventoryReservationEventKind.created.rawValue,
                    OrderInventoryReservationEventReason.orderConfirmed.rawValue,
                    0,
                    1,
                    InventoryUnit.gram.rawValue,
                    timestamp.timeIntervalSince1970
                ]
            )
        }

        XCTAssertThrowsError(
            try repository.repairOrderInventoryReservations(
                limit: 50,
                at: timestamp.addingTimeInterval(10),
                activationId: "infrastructure-activation"
            )
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: confirmedOrder.id)?.state,
            .pending
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationRepair(orderId: confirmedOrder.id)?.attemptCount,
            0
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: confirmedOrder.id),
            []
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationEvents(
                orderId: confirmedOrder.id,
                limit: 50
            ).count,
            1
        )
    }

}
