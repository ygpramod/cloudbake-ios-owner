import Foundation

struct OrderIngredientCostLine: Equatable, Identifiable {
    let inventoryItemId: String
    let inventoryItemName: String
    let quantity: Double
    let unit: InventoryUnit
    let knownCost: Decimal
    let missingPriceQuantity: Double

    var id: String { inventoryItemId }
    var hasMissingPrice: Bool { missingPriceQuantity > 0 }
}

struct OrderIngredientCostSummary: Equatable {
    let lines: [OrderIngredientCostLine]

    var knownCost: Decimal {
        lines.reduce(0) { $0 + $1.knownCost }
    }

    var itemsMissingPrice: [String] {
        lines.filter(\.hasMissingPrice).map(\.inventoryItemName)
    }
}

enum OrderIngredientCostCalculation {
    static func summary(
        requirements: [(item: InventoryItem, quantity: Double)],
        batches: (String) throws -> [InventoryStockBatch],
        at date: Date
    ) throws -> OrderIngredientCostSummary {
        let lines = try requirements.map { requirement in
            var quantityRemaining = requirement.quantity
            var knownCost: Decimal = 0
            var missingPriceQuantity = 0.0

            for batch in try batches(requirement.item.id) where quantityRemaining > 0 && batch.isUsable(at: date) {
                let allocatedQuantity = min(quantityRemaining, batch.remainingQuantity)
                if let unitCost = batch.unitCost {
                    knownCost += unitCost * Decimal(allocatedQuantity)
                } else {
                    missingPriceQuantity += allocatedQuantity
                }
                quantityRemaining -= allocatedQuantity
            }
            missingPriceQuantity += quantityRemaining

            return OrderIngredientCostLine(
                inventoryItemId: requirement.item.id,
                inventoryItemName: requirement.item.name,
                quantity: requirement.quantity,
                unit: requirement.item.unit,
                knownCost: knownCost,
                missingPriceQuantity: missingPriceQuantity
            )
        }

        return OrderIngredientCostSummary(
            lines: lines.sorted {
                $0.inventoryItemName.localizedCaseInsensitiveCompare($1.inventoryItemName) == .orderedAscending
            }
        )
    }
}
