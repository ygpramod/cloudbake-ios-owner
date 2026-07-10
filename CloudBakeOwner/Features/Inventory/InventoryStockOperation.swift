import Foundation

struct InventoryStockAdjustmentPlan {
    let updatedItem: InventoryItem
    let batch: InventoryStockBatch
    let transaction: InventoryTransaction
}

struct InventoryStockConsumptionPlan {
    let updatedItem: InventoryItem
    let transaction: InventoryTransaction
    let quantity: Double
}

enum InventoryStockOperationError: Error, Equatable {
    case missingItem
    case invalidQuantity(String)
    case invalidUnitCost
    case incompatibleUnit(String)
    case insufficientStock

    var message: String {
        switch self {
        case .missingItem:
            return "Inventory item could not be found."
        case .invalidQuantity(let label):
            return "\(label) quantity must be greater than zero."
        case .invalidUnitCost:
            return "Amount must be zero or greater."
        case .incompatibleUnit(let label):
            return "\(label) unit must be compatible with the inventory item unit."
        case .insufficientStock:
            return "Consumption quantity cannot be greater than current stock."
        }
    }
}

enum InventoryStockOperation {
    static func adjustmentPlan(
        item: InventoryItem?,
        quantityText: String,
        unit: InventoryUnit,
        expiresAt: Date,
        amountText: String,
        note: String,
        now: Date,
        itemIdProvider: () -> String
    ) -> Result<InventoryStockAdjustmentPlan, InventoryStockOperationError> {
        guard let item else {
            return .failure(.missingItem)
        }
        guard let quantity = positiveQuantity(from: quantityText) else {
            return .failure(.invalidQuantity("Adjustment"))
        }
        guard let itemQuantity = unit.convertedQuantity(quantity, to: item.unit) else {
            return .failure(.incompatibleUnit("Adjustment"))
        }
        guard let amount = optionalMoneyAmount(from: amountText) else {
            return .failure(.invalidUnitCost)
        }

        let updatedItem = copy(item, currentQuantity: item.currentQuantity + itemQuantity, updatedAt: now)
        let batch = InventoryStockBatch(
            id: itemIdProvider(),
            inventoryItemId: item.id,
            remainingQuantity: itemQuantity,
            expiresAt: expiresAt,
            amount: amount,
            createdAt: now,
            updatedAt: now
        )
        let transaction = InventoryTransaction(
            id: itemIdProvider(),
            inventoryItemId: item.id,
            kind: .adjustment,
            quantity: itemQuantity,
            occurredAt: now,
            note: TextInputFormatting.optionalText(note),
            createdAt: now,
            updatedAt: now
        )

        return .success(InventoryStockAdjustmentPlan(updatedItem: updatedItem, batch: batch, transaction: transaction))
    }

    static func consumptionPlan(
        item: InventoryItem?,
        quantityText: String,
        unit: InventoryUnit,
        note: String,
        now: Date,
        itemIdProvider: () -> String
    ) -> Result<InventoryStockConsumptionPlan, InventoryStockOperationError> {
        guard let item else {
            return .failure(.missingItem)
        }
        guard let quantity = positiveQuantity(from: quantityText) else {
            return .failure(.invalidQuantity("Consumption"))
        }
        guard let itemQuantity = unit.convertedQuantity(quantity, to: item.unit) else {
            return .failure(.incompatibleUnit("Consumption"))
        }
        guard item.currentQuantity - itemQuantity >= 0 else {
            return .failure(.insufficientStock)
        }

        let updatedItem = copy(item, currentQuantity: item.currentQuantity - itemQuantity, updatedAt: now)
        let transaction = InventoryTransaction(
            id: itemIdProvider(),
            inventoryItemId: item.id,
            kind: .consumption,
            quantity: itemQuantity,
            occurredAt: now,
            note: TextInputFormatting.optionalText(note),
            createdAt: now,
            updatedAt: now
        )

        return .success(
            InventoryStockConsumptionPlan(
                updatedItem: updatedItem,
                transaction: transaction,
                quantity: itemQuantity
            )
        )
    }

    private static func positiveQuantity(from text: String) -> Double? {
        let trimmed = TextInputFormatting.trimmed(text)
        guard let quantity = Double(trimmed), quantity > 0 else {
            return nil
        }

        return quantity
    }

    static func optionalMoneyAmount(from text: String) -> Decimal?? {
        let trimmed = TextInputFormatting.trimmed(text)
        guard !trimmed.isEmpty else {
            return .some(nil)
        }

        guard let amount = Decimal(string: trimmed), amount >= 0 else {
            return nil
        }

        return .some(amount)
    }

    private static func copy(
        _ item: InventoryItem,
        currentQuantity: Double,
        updatedAt: Date
    ) -> InventoryItem {
        InventoryItem(
            id: item.id,
            name: item.name,
            aliases: item.aliases,
            unit: item.unit,
            currentQuantity: currentQuantity,
            minimumQuantity: item.minimumQuantity,
            earliestExpiryAt: item.earliestExpiryAt,
            hasExpiredStock: item.hasExpiredStock,
            hasExpiringSoonStock: item.hasExpiringSoonStock,
            createdAt: item.createdAt,
            updatedAt: updatedAt
        )
    }
}
