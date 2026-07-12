import Foundation

enum InventoryLowInventoryAlertRules {
    static func itemsForAlerts(
        inventoryItems: [InventoryItem],
        activeOrders: [Order],
        date: Date,
        inventoryStockBatches: (String) throws -> [InventoryStockBatch],
        orderRecipeUsage: (String) throws -> OrderRecipeUsage?,
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
        let projectedShortageIds = try Set(
            ProjectedIngredientDemand.shortages(
                inventoryItems: inventoryItems,
                orders: activeOrders,
                at: date,
                stockBatches: inventoryStockBatches,
                recipeUsage: orderRecipeUsage,
                recipeComponents: recipeComponents,
                recipeIngredients: recipeIngredients,
                orderExtraIngredients: orderExtraIngredients
            ).map(\.inventoryItemId)
        )

        return inventoryItems.filter {
            $0.showsLowInventoryAlert(neededInventoryItemIds: neededInventoryItemIds)
                || projectedShortageIds.contains($0.id)
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
