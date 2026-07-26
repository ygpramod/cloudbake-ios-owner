import GRDB
import XCTest
@testable import CloudBakeOwner

final class GRDBRecipeRepositoryTests: XCTestCase {
    func testSavingEditedRecipePreservesComponentsAndIngredients() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_001_000)
        let updatedAt = Date(timeIntervalSince1970: 1_800_002_000)
        let inventoryItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla sponge",
            notes: "Original notes",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let component = RecipeComponent(
            id: "component-sponge",
            recipeId: recipe.id,
            name: "Sponge",
            sortOrder: 0,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: inventoryItem.id,
            quantity: 250,
            unit: .gram,
            note: "Sift",
            createdAt: createdAt,
            updatedAt: createdAt
        )

        try repository.save(inventoryItem)
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.save(
            Recipe(
                id: recipe.id,
                name: "Vanilla sponge cake",
                notes: "Edited notes",
                createdAt: recipe.createdAt,
                updatedAt: updatedAt
            )
        )

        XCTAssertEqual(try repository.fetchRecipeComponents(recipeId: recipe.id), [component])
        XCTAssertEqual(try repository.fetchRecipeIngredients(componentId: component.id), [ingredient])
    }

    func testOrderChecklistItemsFetchInEntryOrderForOneOrder() throws {
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
            sortOrder: 2,
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

    func testOrderChecklistItemDeleteRemovesChecklistItem() throws {
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
        let firstItem = OrderChecklistItem(
            id: "checklist-crumb",
            orderId: order.id,
            title: "Crumb coat",
            isCompleted: false,
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let secondItem = OrderChecklistItem(
            id: "checklist-frost",
            orderId: order.id,
            title: "Frost cake",
            isCompleted: false,
            sortOrder: 1,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(order)
        try repository.save(firstItem)
        try repository.save(secondItem)

        try repository.deleteOrderChecklistItem(id: firstItem.id)

        XCTAssertEqual(try repository.fetchOrderChecklistItems(orderId: order.id), [secondItem])
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

    func testRecipeIngredientFetchRejectsUnknownPersistedUnit() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let inventoryItem = InventoryItem(
            id: "inventory-invalid-unit",
            name: "Invalid unit flour",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-invalid-unit",
            name: "Invalid unit recipe",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-invalid-unit",
            recipeId: recipe.id,
            name: "Ingredients",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-invalid-unit",
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
        try queue.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            try db.execute(
                sql: "UPDATE recipe_ingredients SET unit = ? WHERE id = ?",
                arguments: ["unknown-unit", ingredient.id]
            )
            try db.execute(sql: "PRAGMA ignore_check_constraints = OFF")
        }

        XCTAssertThrowsError(
            try repository.fetchRecipeIngredients(componentId: component.id)
        ) { error in
            XCTAssertEqual(
                error as? OrderInventoryReservationPersistenceError,
                .invalidUnit("unknown-unit")
            )
        }
    }

    func testRecipeIngredientEditReplacesAllAffectedReservationsAsOneSet() throws {
        let database = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(database)
        let repository = GRDBCoreDataRepository(
            writer: database,
            idProvider: makeIncrementingIdGenerator(prefix: "event")
        )
        let createdAt = Date(timeIntervalSince1970: 1_800_010_000)
        let updatedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let flour = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 1_000,
            minimumQuantity: 100,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let recipe = Recipe(
            id: "recipe-reserved",
            name: "Reserved sponge",
            notes: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let component = RecipeComponent(
            id: "component-reserved",
            recipeId: recipe.id,
            name: "Ingredients",
            sortOrder: 0,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: flour.id,
            quantity: 200,
            unit: .gram,
            note: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let otherRecipe = Recipe(
            id: "recipe-other",
            name: "Other sponge",
            notes: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let otherComponent = RecipeComponent(
            id: "component-other",
            recipeId: otherRecipe.id,
            name: "Ingredients",
            sortOrder: 0,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let otherIngredient = RecipeIngredient(
            id: "ingredient-other-flour",
            componentId: otherComponent.id,
            inventoryItemId: flour.id,
            quantity: 200,
            unit: .gram,
            note: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let firstOrder = makeReservedOrder(
            id: "order-first",
            recipeId: recipe.id,
            multiplier: 1,
            at: createdAt
        )
        let secondOrder = makeReservedOrder(
            id: "order-second",
            recipeId: recipe.id,
            multiplier: 2,
            at: createdAt
        )
        let otherOrder = makeReservedOrder(
            id: "order-other",
            recipeId: otherRecipe.id,
            multiplier: 1,
            at: createdAt
        )

        try repository.save(flour)
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.save(otherRecipe)
        try repository.save(otherComponent)
        try repository.save(otherIngredient)
        try repository.saveOrder(
            firstOrder,
            replacingExtraIngredients: [],
            allowInventoryShortage: false
        )
        try repository.saveOrder(
            secondOrder,
            replacingExtraIngredients: [],
            allowInventoryShortage: false
        )
        try repository.saveOrder(
            otherOrder,
            replacingExtraIngredients: [],
            allowInventoryShortage: false
        )

        let editedIngredient = RecipeIngredient(
            id: ingredient.id,
            componentId: component.id,
            inventoryItemId: flour.id,
            quantity: 300,
            unit: .gram,
            note: nil,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        XCTAssertThrowsError(
            try repository.saveRecipeIngredient(
                editedIngredient,
                component: component,
                allowInventoryShortage: false
            )
        ) { error in
            XCTAssertEqual(
                error as? OrderRecipeUsageError,
                .insufficientStock([
                    OrderInventoryShortage(
                        inventoryItemId: flour.id,
                        inventoryItemName: flour.name,
                        requiredQuantity: 900,
                        availableQuantity: 800,
                        unit: .gram
                    )
                ])
            )
        }
        XCTAssertEqual(
            try repository.fetchRecipeIngredient(id: ingredient.id),
            ingredient
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: firstOrder.id)
                .map { $0.requiredQuantity },
            [200]
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: secondOrder.id)
                .map { $0.requiredQuantity },
            [400]
        )

        try repository.saveRecipeIngredient(
            editedIngredient,
            component: component,
            allowInventoryShortage: true
        )

        XCTAssertEqual(
            try repository.fetchRecipeIngredient(id: ingredient.id),
            editedIngredient
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: firstOrder.id)
                .map { $0.requiredQuantity },
            [300]
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: secondOrder.id)
                .map { $0.requiredQuantity },
            [600]
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: otherOrder.id)
                .map { $0.requiredQuantity },
            [200]
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservationEvents(
                orderId: firstOrder.id,
                limit: 50
            ).first?.reason,
            .recipeEdited
        )
    }

    func testDeletingLastIngredientRollsBackWhenReservedOrdersWouldBeInvalid() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let flour = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 1_000,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let recipe = Recipe(
            id: "recipe-reserved",
            name: "Reserved sponge",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-reserved",
            recipeId: recipe.id,
            name: "Ingredients",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: flour.id,
            quantity: 200,
            unit: .gram,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let order = makeReservedOrder(
            id: "order-reserved",
            recipeId: recipe.id,
            multiplier: 1,
            at: timestamp
        )

        try repository.save(flour)
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(ingredient)
        try repository.saveOrder(
            order,
            replacingExtraIngredients: [],
            allowInventoryShortage: false
        )

        XCTAssertThrowsError(
            try repository.deleteRecipeIngredient(
                id: ingredient.id,
                updatedAt: timestamp.addingTimeInterval(60),
                allowInventoryShortage: false
            )
        ) { error in
            XCTAssertEqual(
                error as? OrderRecipeUsageError,
                .recipeHasNoIngredients
            )
        }
        XCTAssertEqual(
            try repository.fetchRecipeIngredient(id: ingredient.id),
            ingredient
        )
        XCTAssertEqual(
            try repository.fetchOrderInventoryReservations(orderId: order.id)
                .map { $0.requiredQuantity },
            [200]
        )
    }

    private func makeReservedOrder(
        id: String,
        recipeId: String,
        multiplier: Decimal,
        at timestamp: Date
    ) -> Order {
        Order(
            id: id,
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipeId,
            recipeScaleMultiplier: multiplier,
            title: id,
            customerName: "Amy",
            status: .confirmed,
            dueAt: timestamp.addingTimeInterval(86_400),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}
