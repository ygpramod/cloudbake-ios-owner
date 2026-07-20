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

}
