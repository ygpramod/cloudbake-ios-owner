import Foundation

enum InventoryLowInventoryAlertRules {
    static func itemsForAlerts(
        inventoryItems: [InventoryItem],
        activeOrders: [Order],
        recipeComponents: (String) throws -> [RecipeComponent],
        recipeIngredients: (String) throws -> [RecipeIngredient],
        orderExtraIngredients: (String) throws -> [OrderExtraIngredient]
    ) throws -> [InventoryItem] {
        let neededInventoryItemIds = try neededInventoryItemIds(
            activeOrders: activeOrders,
            recipeComponents: recipeComponents,
            recipeIngredients: recipeIngredients,
            orderExtraIngredients: orderExtraIngredients
        )

        return inventoryItems.filter {
            $0.showsLowInventoryAlert(neededInventoryItemIds: neededInventoryItemIds)
        }
    }

    private static func neededInventoryItemIds(
        activeOrders: [Order],
        recipeComponents: (String) throws -> [RecipeComponent],
        recipeIngredients: (String) throws -> [RecipeIngredient],
        orderExtraIngredients: (String) throws -> [OrderExtraIngredient]
    ) throws -> Set<String> {
        var inventoryItemIds = Set<String>()

        for order in activeOrders where order.hasActiveReminderState {
            if let recipeId = order.recipeId {
                let components = try recipeComponents(recipeId)
                for component in components {
                    let ingredients = try recipeIngredients(component.id)
                    inventoryItemIds.formUnion(ingredients.map(\.inventoryItemId))
                }
            }

            let extras = try orderExtraIngredients(order.id)
            inventoryItemIds.formUnion(extras.map(\.inventoryItemId))
        }

        return inventoryItemIds
    }
}
