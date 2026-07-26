import Foundation

struct InventoryImportWorkflowError: Error, Equatable {
    let ownerMessage: String
}

struct InventoryImportWorkflow {
    private let repository: any InventoryItemRepository & InventoryStockBatchRepository & VoiceInventoryImportRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date
    private let calendar: Calendar

    init(
        repository: any InventoryItemRepository & InventoryStockBatchRepository & VoiceInventoryImportRepository,
        idGenerator: @escaping () -> String,
        dateProvider: @escaping () -> Date,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func savePurchaseBillDrafts(
        _ drafts: [PurchaseBillInventoryDraft],
        inventoryItems: [InventoryItem]
    ) -> Result<Void, InventoryImportWorkflowError> {
        let selectedDrafts = drafts.filter(\.isSelected)
        guard !selectedDrafts.isEmpty else {
            return .failure(error("Select at least one draft item to save."))
        }

        let now = dateProvider()
        var itemsToSave: [InventoryItem] = []
        var batchesToSave: [InventoryStockBatch] = []
        var plannedExistingItems: [String: InventoryItem] = [:]

        for draft in selectedDrafts {
            let name = TextInputFormatting.trimmed(draft.name)
            guard !name.isEmpty else {
                return .failure(error("Draft item name is required."))
            }
            guard let currentQuantity = quantity(from: draft.quantityText),
                  currentQuantity >= 0 else {
                return .failure(error("Draft quantity must be zero or greater."))
            }
            guard let minimumQuantity = quantity(from: draft.minimumQuantityText),
                  minimumQuantity >= 0 else {
                return .failure(error("Draft minimum quantity must be zero or greater."))
            }

            if let existingItem = InventoryDuplicateMatcher.matchingItem(
                named: name,
                in: inventoryItems,
                excludingItemId: nil
            ) {
                let itemToUpdate = plannedExistingItems[existingItem.id] ?? existingItem
                guard let itemQuantity = draft.unit.convertedQuantity(
                    currentQuantity,
                    to: existingItem.unit
                ) else {
                    return .failure(
                        error("Draft unit must be compatible with \(existingItem.name).")
                    )
                }

                plannedExistingItems[existingItem.id] = copy(
                    itemToUpdate,
                    aliases: itemToUpdate.aliases,
                    currentQuantity: itemToUpdate.currentQuantity + itemQuantity,
                    updatedAt: now
                )
                if itemQuantity > 0 {
                    batchesToSave.append(
                        batch(
                            inventoryItemId: existingItem.id,
                            quantity: itemQuantity,
                            expiresAt: draft.hasExpiryDate ? draft.expiryDate : nil,
                            now: now
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
                    type: .standard,
                    unit: draft.unit,
                    currentQuantity: currentQuantity,
                    minimumQuantity: minimumQuantity,
                    createdAt: now,
                    updatedAt: now
                )
            )
            if currentQuantity > 0 {
                batchesToSave.append(
                    batch(
                        inventoryItemId: itemId,
                        quantity: currentQuantity,
                        expiresAt: draft.hasExpiryDate ? draft.expiryDate : nil,
                        now: now
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
                try saveOrCombine(batch, updatedAt: now)
            }
            return .success(())
        } catch {
            return .failure(self.error("Purchase bill drafts could not be saved."))
        }
    }

    func saveVoiceDrafts(
        _ drafts: [VoiceInventoryDraft],
        inventoryItems: [InventoryItem]
    ) -> Result<Void, InventoryImportWorkflowError> {
        guard !drafts.isEmpty else {
            return .failure(error("Create at least one voice inventory draft."))
        }
        guard !drafts.contains(where: { $0.destination == .unresolved }) else {
            return .failure(
                error("Choose whether each new item should be mapped or created.")
            )
        }

        let now = dateProvider()
        var itemsToSave: [InventoryItem] = []
        var batchesToSave: [InventoryStockBatch] = []
        var plannedExistingItems: [String: InventoryItem] = [:]

        for draft in drafts {
            let name = TextInputFormatting.trimmed(draft.name)
            guard !name.isEmpty,
                  let draftQuantity = quantity(from: draft.quantityText),
                  draftQuantity > 0 else {
                return .failure(
                    error("Each voice draft needs a name and positive quantity.")
                )
            }

            switch draft.destination {
            case .unresolved:
                return .failure(
                    error("Choose whether each new item should be mapped or created.")
                )
            case .existingItem(let itemId):
                guard let existingItem = inventoryItems.first(where: { $0.id == itemId }),
                      let itemQuantity = draft.unit.convertedQuantity(
                          draftQuantity,
                          to: existingItem.unit
                      ) else {
                    return .failure(
                        error("Draft unit must be compatible with the mapped inventory item.")
                    )
                }
                let currentItem = plannedExistingItems[itemId] ?? existingItem
                plannedExistingItems[itemId] = copy(
                    currentItem,
                    aliases: aliasesAddingVoiceName(name, to: currentItem),
                    currentQuantity: currentItem.currentQuantity + itemQuantity,
                    updatedAt: now
                )
                batchesToSave.append(
                    batch(
                        inventoryItemId: itemId,
                        quantity: itemQuantity,
                        expiresAt: draft.hasExpiryDate ? draft.expiryDate : nil,
                        now: now
                    )
                )
            case .newItem:
                guard let minimumQuantity = quantity(from: draft.minimumQuantityText),
                      minimumQuantity >= 0 else {
                    return .failure(
                        error("Each new inventory draft needs a valid minimum quantity.")
                    )
                }
                let itemId = idGenerator()
                itemsToSave.append(
                    InventoryItem(
                        id: itemId,
                        name: name,
                        unit: draft.unit,
                        currentQuantity: draftQuantity,
                        minimumQuantity: minimumQuantity,
                        createdAt: now,
                        updatedAt: now
                    )
                )
                batchesToSave.append(
                    batch(
                        inventoryItemId: itemId,
                        quantity: draftQuantity,
                        expiresAt: draft.hasExpiryDate ? draft.expiryDate : nil,
                        now: now
                    )
                )
            }
        }

        do {
            itemsToSave.append(contentsOf: plannedExistingItems.values)
            try repository.saveVoiceInventoryImport(
                items: itemsToSave,
                batches: batchesToSave
            )
            return .success(())
        } catch {
            return .failure(self.error("Voice inventory drafts could not be saved."))
        }
    }

    private func saveOrCombine(
        _ batch: InventoryStockBatch,
        updatedAt: Date
    ) throws {
        let batches = try repository.fetchInventoryStockBatches(
            inventoryItemId: batch.inventoryItemId
        )
        if let existingBatch = batches.first(where: { canCombine($0, with: batch) }) {
            try repository.save(
                InventoryStockBatch(
                    id: existingBatch.id,
                    inventoryItemId: existingBatch.inventoryItemId,
                    remainingQuantity: existingBatch.remainingQuantity + batch.remainingQuantity,
                    expiresAt: existingBatch.expiresAt,
                    amount: existingBatch.amount,
                    createdAt: existingBatch.createdAt,
                    updatedAt: updatedAt
                )
            )
        } else {
            try repository.save(batch)
        }
    }

    private func canCombine(
        _ left: InventoryStockBatch,
        with right: InventoryStockBatch
    ) -> Bool {
        left.inventoryItemId == right.inventoryItemId
            && sameExpiryDate(left.expiresAt, right.expiresAt)
            && left.amount == nil
            && right.amount == nil
    }

    private func sameExpiryDate(_ left: Date?, _ right: Date?) -> Bool {
        switch (left, right) {
        case (.none, .none):
            return true
        case (.some(let left), .some(let right)):
            return calendar.isDate(left, inSameDayAs: right)
        case (.none, .some), (.some, .none):
            return false
        }
    }

    private func aliasesAddingVoiceName(
        _ voiceName: String,
        to item: InventoryItem
    ) -> [String] {
        let voiceKey = TextInputFormatting.normalizedSearchKey(voiceName)
        let existingKeys = Set(
            ([item.name] + item.aliases).map(TextInputFormatting.normalizedSearchKey)
        )
        guard !voiceKey.isEmpty, !existingKeys.contains(voiceKey) else {
            return item.aliases
        }
        return InventoryAliases.aliases(
            from: (item.aliases + [voiceName]).joined(separator: "\n")
        )
    }

    private func copy(
        _ item: InventoryItem,
        aliases: [String],
        currentQuantity: Double,
        updatedAt: Date
    ) -> InventoryItem {
        InventoryItem(
            id: item.id,
            name: item.name,
            aliases: aliases,
            type: item.type,
            defaultExpiryDays: item.defaultExpiryDays,
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

    private func batch(
        inventoryItemId: String,
        quantity: Double,
        expiresAt: Date?,
        now: Date
    ) -> InventoryStockBatch {
        InventoryStockBatch(
            id: idGenerator(),
            inventoryItemId: inventoryItemId,
            remainingQuantity: quantity,
            expiresAt: expiresAt,
            amount: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    private func quantity(from text: String) -> Double? {
        Double(TextInputFormatting.trimmed(text))
    }

    private func error(_ message: String) -> InventoryImportWorkflowError {
        InventoryImportWorkflowError(ownerMessage: message)
    }
}
