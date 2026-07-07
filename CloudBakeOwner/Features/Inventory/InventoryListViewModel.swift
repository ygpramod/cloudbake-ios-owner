import CoreGraphics
import Foundation

@MainActor
final class InventoryListViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    @Published private(set) var archivedItems: [InventoryItem] = []
    @Published var draftName = ""
    @Published var draftUnit: InventoryUnit = .gram
    @Published var draftCurrentQuantity = ""
    @Published var draftMinimumQuantity = ""
    @Published var draftExpiryDate = Date()
    @Published var errorMessage: String?
    @Published var duplicateWarningMessage: String?
    @Published private(set) var selectedItem: InventoryItem?
    @Published private(set) var selectedItemBatches: [InventoryStockBatch] = []
    @Published private(set) var editingItem: InventoryItem?
    @Published private(set) var editingBatch: InventoryStockBatch?
    @Published var draftBatchQuantity = ""
    @Published var draftBatchExpiryDate = Date()
    @Published private(set) var adjustingItem: InventoryItem?
    @Published var draftAdjustmentQuantity = ""
    @Published var draftAdjustmentUnit: InventoryUnit = .gram
    @Published var draftAdjustmentExpiryDate = Date()
    @Published var draftAdjustmentNote = ""
    @Published private(set) var consumingItem: InventoryItem?
    @Published var draftConsumptionQuantity = ""
    @Published var draftConsumptionUnit: InventoryUnit = .gram
    @Published var draftConsumptionNote = ""
    @Published var purchaseBillRecognizedText = ""
    @Published var purchaseBillDrafts: [PurchaseBillInventoryDraft] = []
    @Published private(set) var isRecognizingPurchaseBill = false
    @Published private(set) var historyItem: InventoryItem?
    @Published private(set) var historyTransactions: [InventoryTransaction] = []

    private let repository: any InventoryItemRepository & InventoryTransactionRepository & InventoryStockBatchRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date
    private var acknowledgedDuplicateNameKey: String?

    init(
        repository: any InventoryItemRepository & InventoryTransactionRepository & InventoryStockBatchRepository,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
        self.draftExpiryDate = defaultExpiryDate()
        self.draftAdjustmentExpiryDate = defaultExpiryDate()
    }

    func load() {
        do {
            items = try repository.fetchInventoryItems()
            errorMessage = nil
        } catch {
            errorMessage = "Inventory could not be loaded."
        }
    }

    func loadArchivedItems() {
        do {
            archivedItems = try repository.fetchArchivedInventoryItems()
            errorMessage = nil
        } catch {
            errorMessage = "Archived inventory could not be loaded."
        }
    }

    func addItem() -> Bool {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Inventory item name is required."
            duplicateWarningMessage = nil
            return false
        }

        if shouldWarnAboutDuplicate(
            named: name,
            excludingItemId: nil,
            warningMessage: { "Possible duplicate: \($0.name) already exists. Tap Save again to add a separate item." }
        ) {
            return false
        }

        guard let quantities = validatedDraftQuantities() else {
            return false
        }

        let now = dateProvider()
        let item = InventoryItem(
            id: idGenerator(),
            name: name,
            unit: draftUnit,
            currentQuantity: quantities.current,
            minimumQuantity: quantities.minimum,
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.save(item)
            if quantities.current > 0 {
                try repository.save(
                    InventoryStockBatch(
                        id: idGenerator(),
                        inventoryItemId: item.id,
                        remainingQuantity: quantities.current,
                        expiresAt: draftExpiryDate,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            }
            resetDraft()
            load()
            return true
        } catch {
            errorMessage = "Inventory item could not be saved."
            return false
        }
    }

    func beginEditing(_ item: InventoryItem) {
        editingItem = item
        draftName = item.name
        draftUnit = item.unit
        draftCurrentQuantity = item.currentQuantity.formatted()
        draftMinimumQuantity = item.minimumQuantity.formatted()
        draftExpiryDate = item.earliestExpiryAt ?? defaultExpiryDate()
        errorMessage = nil
        duplicateWarningMessage = nil
        acknowledgedDuplicateNameKey = nil
    }

    func saveEditedItem() -> Bool {
        guard let editingItem else {
            errorMessage = "Inventory item could not be found."
            duplicateWarningMessage = nil
            return false
        }

        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Inventory item name is required."
            duplicateWarningMessage = nil
            return false
        }

        if shouldWarnAboutDuplicate(
            named: name,
            excludingItemId: editingItem.id,
            warningMessage: { "Possible duplicate: \($0.name) already exists. Tap Save again to keep this item separate." }
        ) {
            return false
        }

        guard let minimumQuantity = validatedMinimumQuantity() else {
            return false
        }

        let item = InventoryItem(
            id: editingItem.id,
            name: name,
            unit: editingItem.unit,
            currentQuantity: editingItem.currentQuantity,
            minimumQuantity: minimumQuantity,
            earliestExpiryAt: editingItem.earliestExpiryAt,
            hasExpiredStock: editingItem.hasExpiredStock,
            hasExpiringSoonStock: editingItem.hasExpiringSoonStock,
            createdAt: editingItem.createdAt,
            updatedAt: dateProvider()
        )

        do {
            try repository.save(item)
            if selectedItem?.id == item.id {
                beginViewingItem(item)
            }
            resetDraft()
            load()
            return true
        } catch {
            errorMessage = "Inventory item could not be saved."
            return false
        }
    }

    func cancelEditing() {
        resetDraft()
    }

    func beginViewingItem(_ item: InventoryItem) {
        selectedItem = item
        loadSelectedItemBatches()
    }

    func loadSelectedItemBatches() {
        guard let selectedItem else {
            selectedItemBatches = []
            return
        }

        do {
            if let refreshedItem = try repository.fetchInventoryItem(id: selectedItem.id) {
                self.selectedItem = refreshedItem
            }
            selectedItemBatches = try repository.fetchInventoryStockBatches(inventoryItemId: selectedItem.id)
            errorMessage = nil
        } catch {
            selectedItemBatches = []
            errorMessage = "Inventory item details could not be loaded."
        }
    }

    func closeSelectedItem() {
        selectedItem = nil
        selectedItemBatches = []
        editingBatch = nil
        errorMessage = nil
    }

    func beginEditingBatch(_ batch: InventoryStockBatch) {
        editingBatch = batch
        draftBatchQuantity = batch.remainingQuantity.formatted()
        draftBatchExpiryDate = batch.expiresAt ?? defaultExpiryDate()
        errorMessage = nil
    }

    func saveEditedBatch() -> Bool {
        guard let editingBatch else {
            errorMessage = "Stock batch could not be found."
            return false
        }

        guard let selectedItem else {
            errorMessage = "Inventory item could not be found."
            return false
        }

        guard let remainingQuantity = parsedQuantity(from: draftBatchQuantity), remainingQuantity >= 0 else {
            errorMessage = "Batch quantity must be zero or greater."
            return false
        }

        let quantityDelta = remainingQuantity - editingBatch.remainingQuantity
        guard selectedItem.currentQuantity + quantityDelta >= 0 else {
            errorMessage = "Batch quantity cannot reduce current stock below zero."
            return false
        }

        let now = dateProvider()
        let updatedItem = InventoryItem(
            id: selectedItem.id,
            name: selectedItem.name,
            unit: selectedItem.unit,
            currentQuantity: selectedItem.currentQuantity + quantityDelta,
            minimumQuantity: selectedItem.minimumQuantity,
            earliestExpiryAt: selectedItem.earliestExpiryAt,
            hasExpiredStock: selectedItem.hasExpiredStock,
            hasExpiringSoonStock: selectedItem.hasExpiringSoonStock,
            createdAt: selectedItem.createdAt,
            updatedAt: now
        )
        let updatedBatch = InventoryStockBatch(
            id: editingBatch.id,
            inventoryItemId: editingBatch.inventoryItemId,
            remainingQuantity: remainingQuantity,
            expiresAt: draftBatchExpiryDate,
            createdAt: editingBatch.createdAt,
            updatedAt: now
        )

        do {
            try repository.saveBatchCorrection(item: updatedItem, batch: updatedBatch)
            resetBatchDraft()
            loadSelectedItemBatches()
            load()
            return true
        } catch {
            errorMessage = "Stock batch could not be saved."
            return false
        }
    }

    func cancelEditingBatch() {
        resetBatchDraft()
    }

    func deleteBatch(_ batch: InventoryStockBatch) {
        guard let selectedItem else {
            errorMessage = "Inventory item could not be found."
            return
        }

        let updatedQuantity = selectedItem.currentQuantity - batch.remainingQuantity
        guard updatedQuantity >= 0 else {
            errorMessage = "Stock batch cannot be deleted because it would reduce current stock below zero."
            return
        }

        let updatedItem = InventoryItem(
            id: selectedItem.id,
            name: selectedItem.name,
            unit: selectedItem.unit,
            currentQuantity: updatedQuantity,
            minimumQuantity: selectedItem.minimumQuantity,
            earliestExpiryAt: selectedItem.earliestExpiryAt,
            hasExpiredStock: selectedItem.hasExpiredStock,
            hasExpiringSoonStock: selectedItem.hasExpiringSoonStock,
            createdAt: selectedItem.createdAt,
            updatedAt: dateProvider()
        )

        do {
            try repository.deleteBatchCorrection(item: updatedItem, batch: batch)
            loadSelectedItemBatches()
            load()
        } catch {
            errorMessage = "Stock batch could not be deleted."
        }
    }

    func archiveItem(_ item: InventoryItem) {
        let now = dateProvider()
        let currentItem = (try? repository.fetchInventoryItem(id: item.id)) ?? item
        let archivedItem = InventoryItem(
            id: currentItem.id,
            name: currentItem.name,
            unit: currentItem.unit,
            currentQuantity: currentItem.currentQuantity,
            minimumQuantity: currentItem.minimumQuantity,
            earliestExpiryAt: currentItem.earliestExpiryAt,
            hasExpiredStock: currentItem.hasExpiredStock,
            hasExpiringSoonStock: currentItem.hasExpiringSoonStock,
            createdAt: currentItem.createdAt,
            updatedAt: now,
            archivedAt: now
        )

        do {
            try repository.save(archivedItem)
            load()
        } catch {
            errorMessage = "Inventory item could not be archived."
        }
    }

    func restoreItem(_ item: InventoryItem) {
        let restoredItem = InventoryItem(
            id: item.id,
            name: item.name,
            unit: item.unit,
            currentQuantity: item.currentQuantity,
            minimumQuantity: item.minimumQuantity,
            earliestExpiryAt: item.earliestExpiryAt,
            hasExpiredStock: item.hasExpiredStock,
            hasExpiringSoonStock: item.hasExpiringSoonStock,
            createdAt: item.createdAt,
            updatedAt: dateProvider()
        )

        do {
            try repository.save(restoredItem)
            load()
            loadArchivedItems()
        } catch {
            errorMessage = "Inventory item could not be restored."
        }
    }

    func beginAdjusting(_ item: InventoryItem) {
        adjustingItem = item
        draftAdjustmentQuantity = ""
        draftAdjustmentUnit = item.unit
        draftAdjustmentExpiryDate = defaultExpiryDate()
        draftAdjustmentNote = ""
        errorMessage = nil
    }

    func recordStockAdjustment() -> Bool {
        let now = dateProvider()
        let planResult = InventoryStockOperation.adjustmentPlan(
            item: adjustingItem,
            quantityText: draftAdjustmentQuantity,
            unit: draftAdjustmentUnit,
            expiresAt: draftAdjustmentExpiryDate,
            note: draftAdjustmentNote,
            now: now,
            itemIdProvider: idGenerator
        )

        let plan: InventoryStockAdjustmentPlan
        switch planResult {
        case .success(let adjustmentPlan):
            plan = adjustmentPlan
        case .failure(let error):
            errorMessage = error.message
            return false
        }

        do {
            try repository.save(plan.updatedItem)
            try repository.save(plan.batch)
            try repository.save(plan.transaction)
            resetAdjustmentDraft()
            load()
            refreshSelectedItemIfNeeded(plan.updatedItem)
            return true
        } catch {
            errorMessage = "Stock adjustment could not be saved."
            return false
        }
    }

    func cancelStockAdjustment() {
        resetAdjustmentDraft()
    }

    func beginConsuming(_ item: InventoryItem) {
        consumingItem = item
        draftConsumptionQuantity = ""
        draftConsumptionUnit = item.unit
        draftConsumptionNote = ""
        errorMessage = nil
    }

    func recordStockConsumption() -> Bool {
        let now = dateProvider()
        let planResult = InventoryStockOperation.consumptionPlan(
            item: consumingItem,
            quantityText: draftConsumptionQuantity,
            unit: draftConsumptionUnit,
            note: draftConsumptionNote,
            now: now,
            itemIdProvider: idGenerator
        )

        let plan: InventoryStockConsumptionPlan
        switch planResult {
        case .success(let consumptionPlan):
            plan = consumptionPlan
        case .failure(let error):
            errorMessage = error.message
            return false
        }

        do {
            let batches = try repository.fetchInventoryStockBatches(inventoryItemId: plan.updatedItem.id)
            if !batches.isEmpty {
                let availableBatchQuantity = batches.reduce(0) { $0 + $1.remainingQuantity }
                guard availableBatchQuantity - plan.quantity >= 0 else {
                    errorMessage = "Consumption quantity cannot be greater than current stock."
                    return false
                }

                try consume(quantity: plan.quantity, from: batches, updatedAt: now)
            }
            try repository.save(plan.updatedItem)
            try repository.save(plan.transaction)
            resetConsumptionDraft()
            load()
            refreshSelectedItemIfNeeded(plan.updatedItem)
            return true
        } catch {
            errorMessage = "Stock consumption could not be saved."
            return false
        }
    }

    func cancelStockConsumption() {
        resetConsumptionDraft()
    }

    func createPurchaseBillDrafts(catalog: [BakingCatalogItem]) -> Bool {
        let drafts = PurchaseBillDraftParser.draftItems(
            from: purchaseBillRecognizedText,
            catalog: catalog
        )

        guard !drafts.isEmpty else {
            errorMessage = "No baking inventory items were found in the bill text."
            purchaseBillDrafts = []
            return false
        }

        purchaseBillDrafts = drafts.map { draft in
            let matchedItem = InventoryDuplicateMatcher.matchingItem(
                named: draft.name,
                in: items,
                excludingItemId: nil
            )
            return PurchaseBillInventoryDraft(
                id: idGenerator(),
                sourceLine: draft.sourceLine,
                name: draft.name,
                quantityText: draft.quantity?.formatted() ?? "",
                unit: draft.unit ?? .gram,
                minimumQuantityText: "0",
                expiryDate: defaultExpiryDate(),
                isSelected: true,
                matchedInventoryItemId: matchedItem?.id,
                matchedInventoryItemName: matchedItem?.name
            )
        }
        errorMessage = nil
        return true
    }

    func recognizePurchaseBillImage(
        _ image: CGImage,
        recognizer: PurchaseBillTextRecognizing,
        catalog: [BakingCatalogItem]
    ) async -> Bool {
        isRecognizingPurchaseBill = true
        errorMessage = nil
        defer {
            isRecognizingPurchaseBill = false
        }

        do {
            purchaseBillRecognizedText = try await recognizer.recognizedText(from: image)
            return createPurchaseBillDrafts(catalog: catalog)
        } catch {
            purchaseBillDrafts = []
            errorMessage = "The bill photo could not be read. Try another photo or enter the bill text manually."
            return false
        }
    }

    func savePurchaseBillDrafts() -> Bool {
        let selectedDrafts = purchaseBillDrafts.filter(\.isSelected)
        guard !selectedDrafts.isEmpty else {
            errorMessage = "Select at least one draft item to save."
            return false
        }

        let now = dateProvider()
        var itemsToSave: [InventoryItem] = []
        var batchesToSave: [InventoryStockBatch] = []
        var plannedExistingItems: [String: InventoryItem] = [:]

        for draft in selectedDrafts {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                errorMessage = "Draft item name is required."
                return false
            }

            guard let currentQuantity = parsedQuantity(from: draft.quantityText), currentQuantity >= 0 else {
                errorMessage = "Draft quantity must be zero or greater."
                return false
            }

            guard let minimumQuantity = parsedQuantity(from: draft.minimumQuantityText), minimumQuantity >= 0 else {
                errorMessage = "Draft minimum quantity must be zero or greater."
                return false
            }

            if let existingItem = InventoryDuplicateMatcher.matchingItem(
                named: name,
                in: items,
                excludingItemId: nil
            ) {
                let itemToUpdate = plannedExistingItems[existingItem.id] ?? existingItem
                guard let itemQuantity = draft.unit.convertedQuantity(currentQuantity, to: existingItem.unit) else {
                    errorMessage = "Draft unit must be compatible with \(existingItem.name)."
                    return false
                }

                plannedExistingItems[existingItem.id] = InventoryItem(
                    id: itemToUpdate.id,
                    name: itemToUpdate.name,
                    unit: itemToUpdate.unit,
                    currentQuantity: itemToUpdate.currentQuantity + itemQuantity,
                    minimumQuantity: itemToUpdate.minimumQuantity,
                    earliestExpiryAt: itemToUpdate.earliestExpiryAt,
                    hasExpiredStock: itemToUpdate.hasExpiredStock,
                    hasExpiringSoonStock: itemToUpdate.hasExpiringSoonStock,
                    createdAt: itemToUpdate.createdAt,
                    updatedAt: now
                )

                if itemQuantity > 0 {
                    batchesToSave.append(
                        InventoryStockBatch(
                            id: idGenerator(),
                            inventoryItemId: existingItem.id,
                            remainingQuantity: itemQuantity,
                            expiresAt: draft.expiryDate,
                            createdAt: now,
                            updatedAt: now
                        )
                    )
                }
                continue
            }

            let itemId = idGenerator()
            itemsToSave.append(
                InventoryItem(
                    id: itemId,
                    name: name,
                    unit: draft.unit,
                    currentQuantity: currentQuantity,
                    minimumQuantity: minimumQuantity,
                    createdAt: now,
                    updatedAt: now
                )
            )

            if currentQuantity > 0 {
                batchesToSave.append(
                    InventoryStockBatch(
                        id: idGenerator(),
                        inventoryItemId: itemId,
                        remainingQuantity: currentQuantity,
                        expiresAt: draft.expiryDate,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            }
        }

        do {
            itemsToSave.append(contentsOf: plannedExistingItems.values)
            for item in itemsToSave {
                try repository.save(item)
            }
            for batch in batchesToSave {
                try repository.save(batch)
            }
            errorMessage = nil
            load()
            return true
        } catch {
            errorMessage = "Purchase bill drafts could not be saved."
            return false
        }
    }

    func cancelPurchaseBillImport() {
        resetPurchaseBillDrafts()
    }

    func refreshPurchaseBillDraftMatch(draftId: String) {
        guard let draftIndex = purchaseBillDrafts.firstIndex(where: { $0.id == draftId }) else {
            return
        }

        let matchedItem = InventoryDuplicateMatcher.matchingItem(
            named: purchaseBillDrafts[draftIndex].name,
            in: items,
            excludingItemId: nil
        )
        purchaseBillDrafts[draftIndex].matchedInventoryItemId = matchedItem?.id
        purchaseBillDrafts[draftIndex].matchedInventoryItemName = matchedItem?.name
    }

    func beginViewingHistory(_ item: InventoryItem) {
        historyItem = item
        loadHistory()
    }

    func loadHistory() {
        guard let historyItem else {
            historyTransactions = []
            errorMessage = "Inventory item could not be found."
            return
        }

        do {
            historyTransactions = try repository.fetchInventoryTransactions(inventoryItemId: historyItem.id)
            errorMessage = nil
        } catch {
            historyTransactions = []
            errorMessage = "Inventory history could not be loaded."
        }
    }

    func closeHistory() {
        historyItem = nil
        historyTransactions = []
        errorMessage = nil
    }

    private func refreshSelectedItemIfNeeded(_ item: InventoryItem) {
        guard selectedItem?.id == item.id else {
            return
        }

        beginViewingItem(item)
    }

    private func shouldWarnAboutDuplicate(
        named name: String,
        excludingItemId: String?,
        warningMessage: (InventoryItem) -> String
    ) -> Bool {
        let nameKey = InventoryDuplicateMatcher.duplicateKey(for: name)
        if acknowledgedDuplicateNameKey != nameKey,
           let matchingItem = InventoryDuplicateMatcher.matchingItem(
            named: name,
            in: items,
            excludingItemId: excludingItemId
           ) {
            duplicateWarningMessage = warningMessage(matchingItem)
            errorMessage = nil
            acknowledgedDuplicateNameKey = nameKey
            return true
        }

        return false
    }

    private func validatedDraftQuantities() -> (current: Double, minimum: Double)? {
        let currentQuantityText = draftCurrentQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let currentQuantity = parsedQuantity(from: currentQuantityText) else {
            errorMessage = "Current quantity is required."
            duplicateWarningMessage = nil
            return nil
        }

        guard currentQuantity >= 0 else {
            errorMessage = "Current quantity cannot be negative."
            duplicateWarningMessage = nil
            return nil
        }

        let minimumQuantityText = draftMinimumQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minimumQuantity = parsedQuantity(from: minimumQuantityText) else {
            errorMessage = "Minimum quantity is required."
            duplicateWarningMessage = nil
            return nil
        }

        guard minimumQuantity >= 0 else {
            errorMessage = "Minimum quantity cannot be negative."
            duplicateWarningMessage = nil
            return nil
        }

        return (current: currentQuantity, minimum: minimumQuantity)
    }

    private func validatedMinimumQuantity() -> Double? {
        let minimumQuantityText = draftMinimumQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minimumQuantity = parsedQuantity(from: minimumQuantityText) else {
            errorMessage = "Minimum quantity is required."
            duplicateWarningMessage = nil
            return nil
        }

        guard minimumQuantity >= 0 else {
            errorMessage = "Minimum quantity cannot be negative."
            duplicateWarningMessage = nil
            return nil
        }

        return minimumQuantity
    }

    private func parsedQuantity(from text: String) -> Double? {
        InventoryDraftValidation.quantity(from: text)
    }

    private func resetDraft() {
        draftName = ""
        draftUnit = .gram
        draftCurrentQuantity = ""
        draftMinimumQuantity = ""
        draftExpiryDate = defaultExpiryDate()
        errorMessage = nil
        duplicateWarningMessage = nil
        acknowledgedDuplicateNameKey = nil
        editingItem = nil
    }

    private func resetBatchDraft() {
        editingBatch = nil
        draftBatchQuantity = ""
        draftBatchExpiryDate = defaultExpiryDate()
        errorMessage = nil
    }

    private func resetAdjustmentDraft() {
        adjustingItem = nil
        draftAdjustmentQuantity = ""
        draftAdjustmentUnit = .gram
        draftAdjustmentExpiryDate = defaultExpiryDate()
        draftAdjustmentNote = ""
        errorMessage = nil
    }

    private func resetConsumptionDraft() {
        consumingItem = nil
        draftConsumptionQuantity = ""
        draftConsumptionUnit = .gram
        draftConsumptionNote = ""
        errorMessage = nil
    }

    private func resetPurchaseBillDrafts() {
        purchaseBillRecognizedText = ""
        purchaseBillDrafts = []
        errorMessage = nil
    }

    private func defaultExpiryDate() -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    }

    private func consume(
        quantity: Double,
        from batches: [InventoryStockBatch],
        updatedAt: Date
    ) throws {
        var remainingQuantityToUse = quantity
        for batch in batches where remainingQuantityToUse > 0 && batch.remainingQuantity > 0 {
            let quantityFromBatch = min(batch.remainingQuantity, remainingQuantityToUse)
            let updatedBatch = InventoryStockBatch(
                id: batch.id,
                inventoryItemId: batch.inventoryItemId,
                remainingQuantity: batch.remainingQuantity - quantityFromBatch,
                expiresAt: batch.expiresAt,
                createdAt: batch.createdAt,
                updatedAt: updatedAt
            )
            try repository.save(updatedBatch)
            remainingQuantityToUse -= quantityFromBatch
        }
    }
}

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
}
