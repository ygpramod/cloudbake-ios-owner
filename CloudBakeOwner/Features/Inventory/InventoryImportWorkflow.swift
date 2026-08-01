import Foundation

struct InventoryImportWorkflowError: Error, Equatable {
    let ownerMessage: String
}

struct InventoryImportWorkflow {
    private let repository: any InventoryItemRepository & InventoryStockBatchRepository & VoiceInventoryImportRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date

    init(
        repository: any InventoryItemRepository & InventoryStockBatchRepository & VoiceInventoryImportRepository,
        idGenerator: @escaping () -> String,
        dateProvider: @escaping () -> Date
    ) {
        self.repository = repository
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    func savePurchaseBillDrafts(
        _ drafts: [PurchaseBillInventoryDraft],
        inventoryItems: [InventoryItem]
    ) -> Result<Void, InventoryImportWorkflowError> {
        let includedDrafts = drafts.filter { $0.destination != .ignored }
        guard !includedDrafts.isEmpty else {
            return .failure(error("Select at least one draft item to save."))
        }
        let now = dateProvider()
        var itemsToSave: [InventoryItem] = []
        var batchesToSave: [InventoryStockBatch] = []
        var plannedExistingItems: [String: InventoryItem] = [:]

        for draft in includedDrafts {
            let name = TextInputFormatting.trimmed(draft.name)
            guard !name.isEmpty else {
                return .failure(error("Draft item name is required."))
            }
            guard let currentQuantity = quantity(from: draft.quantityText), currentQuantity > 0
            else {
                return .failure(error("Draft quantity must be greater than zero."))
            }
            guard let amount = InventoryStockOperation.optionalMoneyAmount(from: draft.amountPaidText)
            else {
                return .failure(error("Draft amount paid must be zero or greater."))
            }

            switch draft.destination {
            case .ignored:
                continue
            case .existingItem(let itemId):
                guard let existingItem = inventoryItems.first(where: { $0.id == itemId }) else {
                    return .failure(error("The mapped inventory item could not be found."))
                }
                guard
                    let itemQuantity = draft.unit.convertedQuantity(
                        currentQuantity,
                        to: existingItem.unit
                    )
                else {
                    return .failure(
                        error("Draft unit must be compatible with \(existingItem.name).")
                    )
                }

                let itemToUpdate = plannedExistingItems[existingItem.id] ?? existingItem
                plannedExistingItems[existingItem.id] = copy(
                    itemToUpdate,
                    aliases: aliasesAddingReceiptName(draft.receiptName, to: itemToUpdate),
                    currentQuantity: itemToUpdate.currentQuantity + itemQuantity,
                    updatedAt: now
                )
                batchesToSave.append(
                    batch(
                        inventoryItemId: existingItem.id,
                        quantity: itemQuantity,
                        expiresAt: draft.hasExpiryDate ? draft.expiryDate : nil,
                        amount: amount,
                        now: now
                    )
                )
            case .newItem:
                guard let minimumQuantity = quantity(from: draft.minimumQuantityText),
                    minimumQuantity >= 0
                else {
                    return .failure(error("Each new inventory draft needs a valid minimum quantity."))
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
                batchesToSave.append(
                    batch(
                        inventoryItemId: itemId,
                        quantity: currentQuantity,
                        expiresAt: draft.hasExpiryDate ? draft.expiryDate : nil,
                        amount: amount,
                        now: now
                    )
                )
            }
        }

        do {
            itemsToSave.append(contentsOf: plannedExistingItems.values)
            try repository.saveVoiceInventoryImport(items: itemsToSave, batches: batchesToSave)
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
                draftQuantity > 0
            else {
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
                    )
                else {
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
                    minimumQuantity >= 0
                else {
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

    private func aliasesAddingReceiptName(
        _ receiptName: String,
        to item: InventoryItem
    ) -> [String] {
        aliasesAddingVoiceName(receiptName, to: item)
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
        amount: Decimal? = nil,
        now: Date
    ) -> InventoryStockBatch {
        InventoryStockBatch(
            id: idGenerator(),
            inventoryItemId: inventoryItemId,
            remainingQuantity: quantity,
            expiresAt: expiresAt,
            amount: amount,
            createdAt: now,
            updatedAt: now
        )
    }

    private func quantity(from text: String) -> Double? {
        InventoryDraftValidation.quantity(from: text)
    }

    private func error(_ message: String) -> InventoryImportWorkflowError {
        InventoryImportWorkflowError(ownerMessage: message)
    }
}
