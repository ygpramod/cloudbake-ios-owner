import XCTest
@testable import CloudBakeOwner

final class CoreDataRepositoryTests: XCTestCase {
    func testCoreEntitiesRoundTripThroughFreshDatabase() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamps = TestTimestamps(
            createdAt: Date(timeIntervalSince1970: 1_800_001_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_001_100)
        )

        let inventoryItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 500,
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(inventoryItem)
        XCTAssertEqual(try repository.fetchInventoryItem(id: inventoryItem.id), inventoryItem)

        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla sponge",
            notes: "Owner recipe book import target",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(recipe)
        XCTAssertEqual(try repository.fetchRecipe(id: recipe.id), recipe)

        let component = RecipeComponent(
            id: "component-sponge",
            recipeId: recipe.id,
            name: "Sponge",
            sortOrder: 1,
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(component)
        XCTAssertEqual(try repository.fetchRecipeComponent(id: component.id), component)
        XCTAssertEqual(try repository.fetchRecipeComponents(recipeId: recipe.id), [component])

        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: inventoryItem.id,
            quantity: 250,
            unit: .gram,
            note: "Sift before mixing",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(ingredient)
        XCTAssertEqual(try repository.fetchRecipeIngredient(id: ingredient.id), ingredient)
        XCTAssertEqual(try repository.fetchRecipeIngredients(componentId: component.id), [ingredient])

        let design = CakeDesign(
            id: "design-rose-garden",
            name: "Rose garden",
            notes: "Hand-piped flowers",
            photoReference: "photos/rose-garden.jpg",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(design)
        XCTAssertEqual(try repository.fetchCakeDesign(id: design.id), design)

        let customer = Customer(
            id: "customer-amy",
            name: "Amy",
            phone: "5550101",
            email: "amy@example.com",
            address: "10 Cake Street",
            likes: "Vanilla, pink flowers",
            dislikes: "Too much fondant",
            allergies: "Nuts",
            dietaryRestrictions: "Eggless",
            notes: "Prefers less sweet frosting",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(customer)
        XCTAssertEqual(try repository.fetchCustomer(id: customer.id), customer)

        let importantDate = CustomerImportantDate(
            id: "customer-date-birthday",
            customerId: customer.id,
            label: "Birthday",
            date: Date(timeIntervalSince1970: 1_800_030_000),
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(importantDate)
        XCTAssertEqual(try repository.fetchCustomerImportantDates(customerId: customer.id), [importantDate])

        let order = Order(
            id: "order-rose-garden",
            customerId: customer.id,
            cakeDesignId: design.id,
            recipeId: recipe.id,
            title: "Rose garden birthday cake",
            customerName: customer.name,
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_050_000),
            fulfillmentType: .delivery,
            deliveryAddress: "10 Cake Street",
            cakeNotes: "Vanilla sponge with pink flowers",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(order)
        XCTAssertEqual(try repository.fetchOrder(id: order.id), order)
        XCTAssertEqual(try repository.fetchOrders(), [order])

        let checklistItem = OrderChecklistItem(
            id: "checklist-crumb-coat",
            orderId: order.id,
            title: "Crumb coat",
            isCompleted: false,
            sortOrder: 0,
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(checklistItem)
        XCTAssertEqual(try repository.fetchOrderChecklistItems(orderId: order.id), [checklistItem])

        let transaction = InventoryTransaction(
            id: "transaction-flour-purchase",
            inventoryItemId: inventoryItem.id,
            kind: .purchase,
            quantity: 2_000,
            occurredAt: Date(timeIntervalSince1970: 1_800_002_000),
            note: "Restocked flour",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(transaction)
        XCTAssertEqual(try repository.fetchInventoryTransaction(id: transaction.id), transaction)

        let stockBatch = InventoryStockBatch(
            id: "batch-flour-purchase",
            inventoryItemId: inventoryItem.id,
            remainingQuantity: 750,
            expiresAt: Date(timeIntervalSince1970: 1_800_086_400),
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(stockBatch)
        XCTAssertEqual(try repository.fetchInventoryStockBatches(inventoryItemId: inventoryItem.id), [stockBatch])

        let pricingRule = PricingRule(
            id: "pricing-base-cake",
            name: "Base cake",
            kind: .basePrice,
            amount: Decimal(7_550) / Decimal(100),
            currencyCode: "USD",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(pricingRule)
        XCTAssertEqual(try repository.fetchPricingRule(id: pricingRule.id), pricingRule)
    }

    func testOrderChecklistItemsFetchIncompleteBeforeCompletedForOneOrder() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let order = Order(
            id: "order-vanilla",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: nil,
            title: "Vanilla birthday",
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
            id: "order-chocolate",
            customerId: nil,
            cakeDesignId: nil,
            recipeId: nil,
            title: "Chocolate birthday",
            customerName: "Zoe",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_060_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let completedItem = OrderChecklistItem(
            id: "checklist-bake",
            orderId: order.id,
            title: "Bake sponge",
            isCompleted: true,
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let nextItem = OrderChecklistItem(
            id: "checklist-frost",
            orderId: order.id,
            title: "Frost cake",
            isCompleted: false,
            sortOrder: 1,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let firstItem = OrderChecklistItem(
            id: "checklist-crumb",
            orderId: order.id,
            title: "Crumb coat",
            isCompleted: false,
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let otherOrderItem = OrderChecklistItem(
            id: "checklist-other",
            orderId: otherOrder.id,
            title: "Box cake",
            isCompleted: false,
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(order)
        try repository.save(otherOrder)
        try repository.save(completedItem)
        try repository.save(nextItem)
        try repository.save(firstItem)
        try repository.save(otherOrderItem)

        XCTAssertEqual(try repository.fetchOrderChecklistItems(orderId: order.id), [firstItem, nextItem, completedItem])
    }

    func testRecipeIngredientDeleteRemovesIngredient() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let inventoryItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 500,
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
            id: "component-ingredients",
            recipeId: recipe.id,
            name: "Ingredients",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: inventoryItem.id,
            quantity: 250,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(inventoryItem)
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.deleteRecipeIngredient(id: ingredient.id)

        XCTAssertNil(try repository.fetchRecipeIngredient(id: ingredient.id))
        XCTAssertEqual(try repository.fetchRecipeIngredients(componentId: component.id), [])
    }

    func testOrderRecipeUsageDeductsInventoryFromOldestExpiringBatches() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let usedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let olderExpiry = Date(timeIntervalSince1970: 1_805_000_000)
        let newerExpiry = Date(timeIntervalSince1970: 1_806_000_000)
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
                id: "batch-newer-flour",
                inventoryItemId: inventoryItem.id,
                remainingQuantity: 400,
                expiresAt: newerExpiry,
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

        XCTAssertEqual(try repository.fetchInventoryItem(id: inventoryItem.id)?.currentQuantity, 350)
        XCTAssertEqual(
            try repository.fetchInventoryStockBatches(inventoryItemId: inventoryItem.id),
            [
                InventoryStockBatch(
                    id: "batch-older-flour",
                    inventoryItemId: inventoryItem.id,
                    remainingQuantity: 0,
                    expiresAt: olderExpiry,
                    createdAt: timestamp.addingTimeInterval(10),
                    updatedAt: usedAt
                ),
                InventoryStockBatch(
                    id: "batch-newer-flour",
                    inventoryItemId: inventoryItem.id,
                    remainingQuantity: 350,
                    expiresAt: newerExpiry,
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
            transactionIdProvider: { "transaction-order-buttercream-sugar" }
        )

        XCTAssertEqual(updatedOrder.status, .ready)
        XCTAssertEqual(try repository.fetchOrder(id: order.id)?.status, .ready)
        XCTAssertEqual(try repository.fetchInventoryItem(id: inventoryItem.id)?.currentQuantity, 400)
        XCTAssertEqual(try repository.fetchOrderRecipeUsage(orderId: order.id)?.recipeId, recipe.id)
        XCTAssertEqual(try repository.fetchInventoryTransactions(inventoryItemId: inventoryItem.id).count, 1)
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
            transactionIdProvider: { "transaction-order-buttercream-sugar" }
        )

        XCTAssertEqual(updatedOrder.status, .completed)
        XCTAssertEqual(try repository.fetchOrder(id: order.id)?.status, .completed)
        XCTAssertEqual(try repository.fetchInventoryItem(id: inventoryItem.id)?.currentQuantity, 400)
        XCTAssertEqual(try repository.fetchOrderRecipeUsage(orderId: order.id)?.recipeId, recipe.id)
        XCTAssertEqual(try repository.fetchInventoryTransactions(inventoryItemId: inventoryItem.id).count, 1)
    }

    func testInventoryItemsFetchInNameOrder() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let sugar = InventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 250,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let butter = InventoryItem(
            id: "inventory-butter",
            name: "Butter",
            unit: .gram,
            currentQuantity: 600,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(sugar)
        try repository.save(butter)

        XCTAssertEqual(try repository.fetchInventoryItems(), [butter, sugar])
    }

    func testRecipesFetchInNameOrder() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let vanilla = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let chocolate = Recipe(
            id: "recipe-chocolate-truffle",
            name: "Chocolate Truffle",
            notes: "Book page 18",
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(vanilla)
        try repository.save(chocolate)

        XCTAssertEqual(try repository.fetchRecipes(), [chocolate, vanilla])
    }

    func testCustomersFetchInNameOrder() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let zoe = Customer(
            id: "customer-zoe",
            name: "Zoe",
            phone: "5550102",
            email: nil,
            address: nil,
            likes: nil,
            dislikes: nil,
            allergies: nil,
            dietaryRestrictions: nil,
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let amy = Customer(
            id: "customer-amy",
            name: "Amy",
            phone: "5550101",
            email: nil,
            address: nil,
            likes: nil,
            dislikes: nil,
            allergies: nil,
            dietaryRestrictions: nil,
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(zoe)
        try repository.save(amy)

        XCTAssertEqual(try repository.fetchCustomers(), [amy, zoe])
    }

    func testInventoryItemSaveUpdatesExistingItemWithSameId() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_020_000)
        let original = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: Date(timeIntervalSince1970: 1_800_020_100)
        )
        let edited = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour fine",
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
}

private struct TestTimestamps {
    let createdAt: Date
    let updatedAt: Date
}
