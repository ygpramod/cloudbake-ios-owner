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
        planningSnapshot: OrderInventoryReservationPlanningSnapshot,
        stockBatches: (String) throws -> [InventoryStockBatch],
        recipeComponents: (String) throws -> [RecipeComponent],
        recipeIngredients: (String) throws -> [RecipeIngredient],
        orderExtraIngredients: (String) throws -> [OrderExtraIngredient]
    ) throws -> [ProjectedIngredientShortage] {
        let itemsById = Dictionary(uniqueKeysWithValues: inventoryItems.map { ($0.id, $0) })
        var demandByItemId: [String: Demand] = [:]

        for order in orders where order.hasActiveReminderState {
            guard !planningSnapshot.consumedOrderIds.contains(order.id) else { continue }
            if order.status == .confirmed || order.status == .inProgress {
                let reservations = planningSnapshot.reservationsByOrderId[order.id] ?? []
                let repair = planningSnapshot.repairsByOrderId[order.id]
                let shouldUseReservations =
                    !planningSnapshot.invalidOrderIds.contains(order.id)
                    && (
                        repair?.state == .complete
                            || (repair == nil && !reservations.isEmpty)
                    )
                if shouldUseReservations,
                   let committedDemand = committedDemand(
                       reservations: reservations,
                       itemsById: itemsById
                   ) {
                    for (item, quantity) in committedDemand {
                        var demand = demandByItemId[item.id] ?? Demand()
                        demand.quantity += quantity
                        demand.orderIds.insert(order.id)
                        demandByItemId[item.id] = demand
                    }
                    continue
                }
            }
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

    private static func committedDemand(
        reservations: [OrderInventoryReservation],
        itemsById: [String: InventoryItem]
    ) -> [(item: InventoryItem, quantity: Double)]? {
        var quantitiesByItemId: [String: Double] = [:]

        for reservation in reservations {
            guard reservation.requiredQuantity.isFinite,
                  reservation.requiredQuantity > 0,
                  let item = itemsById[reservation.inventoryItemId],
                  let quantity = reservation.unit.convertedQuantity(
                      reservation.requiredQuantity,
                      to: item.unit
                  ),
                  quantity.isFinite,
                  quantity > 0 else {
                return nil
            }
            let aggregate = quantitiesByItemId[item.id, default: 0] + quantity
            guard aggregate.isFinite else {
                return nil
            }
            quantitiesByItemId[item.id] = aggregate
        }

        return quantitiesByItemId.compactMap { itemId, quantity in
            itemsById[itemId].map { ($0, quantity) }
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
