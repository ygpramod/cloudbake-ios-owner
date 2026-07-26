import Foundation

enum InventoryLowInventoryAlertRules {
    static func itemsForAlerts(
        inventoryItems: [InventoryItem],
        neededInventoryItemIds: Set<String>,
        projectedShortageIds: Set<String>
    ) -> [InventoryItem] {
        return inventoryItems.filter {
            $0.showsLowInventoryAlert(neededInventoryItemIds: neededInventoryItemIds)
                || projectedShortageIds.contains($0.id)
        }
    }
}
