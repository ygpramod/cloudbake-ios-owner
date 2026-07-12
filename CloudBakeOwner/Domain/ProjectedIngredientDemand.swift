import Foundation

struct ProjectedIngredientShortage: Equatable, Identifiable {
    let inventoryItemId: String
    let inventoryItemName: String
    let requiredQuantity: Double
    let availableQuantity: Double
    let unit: InventoryUnit
    let orderIds: Set<String>

    var id: String { inventoryItemId }

    var missingQuantity: Double {
        max(requiredQuantity - availableQuantity, 0)
    }
}

enum ProjectedIngredientDemand {
    static func shortages(
        inventoryItems: [InventoryItem],
        orders: [Order],
        at date: Date,
        stockBatches: (String) throws -> [InventoryStockBatch],
        recipeUsage: (String) throws -> OrderRecipeUsage?,
        recipeComponents: (String) throws -> [RecipeComponent],
        recipeIngredients: (String) throws -> [RecipeIngredient],
        orderExtraIngredients: (String) throws -> [OrderExtraIngredient]
    ) throws -> [ProjectedIngredientShortage] {
        let itemsById = Dictionary(uniqueKeysWithValues: inventoryItems.map { ($0.id, $0) })
        var demandByItemId: [String: Demand] = [:]

        for order in orders where order.hasActiveReminderState {
            guard try recipeUsage(order.id) == nil else { continue }
            let requirements = try OrderIngredientRequirements.requirements(
                for: order,
                inventoryItems: inventoryItems,
                recipeComponents: recipeComponents,
                recipeIngredients: recipeIngredients,
                orderExtraIngredients: orderExtraIngredients
            )
            for requirement in requirements {
                var demand = demandByItemId[requirement.item.id] ?? Demand()
                demand.quantity += requirement.quantity
                demand.orderIds.insert(order.id)
                demandByItemId[requirement.item.id] = demand
            }
        }

        return try demandByItemId.compactMap { inventoryItemId, demand in
            guard let item = itemsById[inventoryItemId] else { return nil }
            let batches = try stockBatches(inventoryItemId)
            let availableQuantity = batches.isEmpty
                ? item.currentQuantity
                : batches.filter { $0.isUsable(at: date) }.reduce(0) { $0 + $1.remainingQuantity }
            guard demand.quantity > availableQuantity else { return nil }

            return ProjectedIngredientShortage(
                inventoryItemId: item.id,
                inventoryItemName: item.name,
                requiredQuantity: demand.quantity,
                availableQuantity: availableQuantity,
                unit: item.unit,
                orderIds: demand.orderIds
            )
        }
        .sorted {
            $0.inventoryItemName.localizedCaseInsensitiveCompare($1.inventoryItemName) == .orderedAscending
        }
    }

    private struct Demand {
        var quantity = 0.0
        var orderIds = Set<String>()
    }
}

enum OrderIngredientRequirements {
    static func requirements(
        for order: Order,
        inventoryItems: [InventoryItem],
        recipeComponents: (String) throws -> [RecipeComponent],
        recipeIngredients: (String) throws -> [RecipeIngredient],
        orderExtraIngredients: (String) throws -> [OrderExtraIngredient]
    ) throws -> [(item: InventoryItem, quantity: Double)] {
        let itemsById = Dictionary(uniqueKeysWithValues: inventoryItems.map { ($0.id, $0) })
        var quantitiesByItemId: [String: Double] = [:]

        if let recipeId = order.recipeId {
            let scale = NSDecimalNumber(decimal: order.recipeScaleMultiplier).doubleValue
            for component in try recipeComponents(recipeId) {
                for ingredient in try recipeIngredients(component.id) {
                    add(
                        inventoryItemId: ingredient.inventoryItemId,
                        quantity: ingredient.quantity * scale,
                        unit: ingredient.unit,
                        itemsById: itemsById,
                        quantitiesByItemId: &quantitiesByItemId
                    )
                }
            }
        }

        for ingredient in try orderExtraIngredients(order.id) {
            add(
                inventoryItemId: ingredient.inventoryItemId,
                quantity: ingredient.quantity,
                unit: ingredient.unit,
                itemsById: itemsById,
                quantitiesByItemId: &quantitiesByItemId
            )
        }

        return quantitiesByItemId.compactMap { itemId, quantity in
            itemsById[itemId].map { ($0, quantity) }
        }
    }

    private static func add(
        inventoryItemId: String,
        quantity: Double,
        unit: InventoryUnit,
        itemsById: [String: InventoryItem],
        quantitiesByItemId: inout [String: Double]
    ) {
        guard quantity > 0,
              let item = itemsById[inventoryItemId],
              let convertedQuantity = unit.convertedQuantity(quantity, to: item.unit) else {
            return
        }
        quantitiesByItemId[inventoryItemId, default: 0] += convertedQuantity
    }
}
