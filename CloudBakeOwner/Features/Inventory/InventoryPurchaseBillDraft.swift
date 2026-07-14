import Foundation

struct PurchaseBillInventoryDraft: Identifiable, Equatable {
    let id: String
    let sourceLine: String
    var name: String
    var quantityText: String
    var unit: InventoryUnit
    var minimumQuantityText: String
    var expiryDate: Date
    var isSelected: Bool
    var matchedInventoryItemId: String? = nil
    var matchedInventoryItemName: String? = nil
    var hasExpiryDate: Bool = true
    var expiryUsesDefault: Bool = true
}

enum InventoryPurchaseBillDraftBuilder {
    static func drafts(
        from parsedDrafts: [PurchaseBillDraftInventoryItem],
        inventoryItems: [InventoryItem],
        defaultExpiryDate: (InventoryItem?) -> Date,
        idProvider: () -> String
    ) -> [PurchaseBillInventoryDraft] {
        parsedDrafts.map { draft in
            let matchedItem = InventoryDuplicateMatcher.matchingItem(
                named: draft.name,
                in: inventoryItems,
                excludingItemId: nil
            )
            return PurchaseBillInventoryDraft(
                id: idProvider(),
                sourceLine: draft.sourceLine,
                name: draft.name,
                quantityText: draft.quantity?.formatted() ?? "",
                unit: draft.unit ?? .gram,
                minimumQuantityText: "0",
                expiryDate: defaultExpiryDate(matchedItem),
                isSelected: true,
                matchedInventoryItemId: matchedItem?.id,
                matchedInventoryItemName: matchedItem?.name
            )
        }
    }

    static func matchedInventoryItem(
        for draft: PurchaseBillInventoryDraft,
        inventoryItems: [InventoryItem]
    ) -> InventoryItem? {
        InventoryDuplicateMatcher.matchingItem(
            named: draft.name,
            in: inventoryItems,
            excludingItemId: nil
        )
    }
}
