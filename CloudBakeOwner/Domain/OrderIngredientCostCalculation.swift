import Foundation

struct OrderIngredientCostLine: Equatable, Identifiable {
    let inventoryItemId: String
    let inventoryItemName: String
    let quantity: Double
    let unit: InventoryUnit
    let knownCost: Decimal
    let missingPriceQuantity: Double
    let shortfallQuantity: Double

    var id: String { inventoryItemId }
    var hasMissingPrice: Bool { missingPriceQuantity > 0 }
    var hasShortfall: Bool { shortfallQuantity > 0 }

    init(
        inventoryItemId: String,
        inventoryItemName: String,
        quantity: Double,
        unit: InventoryUnit,
        knownCost: Decimal,
        missingPriceQuantity: Double,
        shortfallQuantity: Double = 0
    ) {
        self.inventoryItemId = inventoryItemId
        self.inventoryItemName = inventoryItemName
        self.quantity = quantity
        self.unit = unit
        self.knownCost = knownCost
        self.missingPriceQuantity = missingPriceQuantity
        self.shortfallQuantity = shortfallQuantity
    }
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
            let itemBatches = try batches(requirement.item.id)
            let usableQuantity = itemBatches
                .filter { $0.isUsable(at: date) }
                .reduce(0) { $0 + $1.remainingQuantity }
            let availableQuantity = itemBatches.isEmpty
                ? min(requirement.quantity, max(0, requirement.item.currentQuantity))
                : min(requirement.quantity, max(0, requirement.item.currentQuantity), usableQuantity)
            let shortfallQuantity = max(0, requirement.quantity - availableQuantity)
            let latestKnownUnitCost = itemBatches
                .filter { $0.unitCost != nil }
                .max {
                    if $0.createdAt == $1.createdAt {
                        return $0.id < $1.id
                    }
                    return $0.createdAt < $1.createdAt
                }?
                .unitCost

            var quantityRemainingToAllocate = availableQuantity
            var knownCost: Decimal = 0
            var missingPriceQuantity = 0.0

            for batch in itemBatches where quantityRemainingToAllocate > 0 && batch.isUsable(at: date) {
                let allocatedQuantity = min(quantityRemainingToAllocate, batch.remainingQuantity)
                if let unitCost = batch.unitCost {
                    knownCost += unitCost * Decimal(allocatedQuantity)
                } else {
                    missingPriceQuantity += allocatedQuantity
                }
                quantityRemainingToAllocate -= allocatedQuantity
            }
            missingPriceQuantity += quantityRemainingToAllocate

            if let latestKnownUnitCost {
                knownCost += latestKnownUnitCost * Decimal(shortfallQuantity)
            } else {
                missingPriceQuantity += shortfallQuantity
            }

            return OrderIngredientCostLine(
                inventoryItemId: requirement.item.id,
                inventoryItemName: requirement.item.name,
                quantity: requirement.quantity,
                unit: requirement.item.unit,
                knownCost: knownCost,
                missingPriceQuantity: missingPriceQuantity,
                shortfallQuantity: shortfallQuantity
            )
        }

        return OrderIngredientCostSummary(
            lines: lines.sorted {
                $0.inventoryItemName.localizedCaseInsensitiveCompare($1.inventoryItemName) == .orderedAscending
            }
        )
    }
}
