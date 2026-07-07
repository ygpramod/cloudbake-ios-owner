import CoreGraphics
@testable import CloudBakeOwner

struct FakePurchaseBillTextRecognizer: PurchaseBillTextRecognizing {
    let result: Result<String, Error>

    func recognizedText(from image: CGImage) async throws -> String {
        try result.get()
    }
}

func makeTestCGImage() throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ),
    let image = context.makeImage() else {
        throw TestImageError.unavailable
    }

    return image
}

enum TestImageError: Error {
    case unavailable
}

enum FakeRepositoryError: Error {
    case requestedFailure
}

final class FakeInventoryItemRepository: InventoryItemRepository, InventoryTransactionRepository, InventoryStockBatchRepository {
    var items: [InventoryItem] = []
    var transactions: [InventoryTransaction] = []
    var batches: [InventoryStockBatch] = []
    var shouldFailBatchCorrectionSave = false
    var shouldFailBatchCorrectionDelete = false

    func save(_ item: InventoryItem) throws {
        if let existingIndex = items.firstIndex(where: { $0.id == item.id }) {
            items[existingIndex] = item
        } else {
            items.append(item)
        }
    }

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        items.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        items.filter { !$0.isArchived }
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        items.filter(\.isArchived)
    }

    func save(_ transaction: InventoryTransaction) throws {
        if let existingIndex = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[existingIndex] = transaction
        } else {
            transactions.append(transaction)
        }
    }

    func fetchInventoryTransaction(id: String) throws -> InventoryTransaction? {
        transactions.first { $0.id == id }
    }

    func fetchInventoryTransactions(inventoryItemId: String) throws -> [InventoryTransaction] {
        transactions
            .filter { $0.inventoryItemId == inventoryItemId }
            .sorted {
                if $0.occurredAt == $1.occurredAt {
                    return $0.createdAt > $1.createdAt
                }

                return $0.occurredAt > $1.occurredAt
            }
    }

    func save(_ batch: InventoryStockBatch) throws {
        if let existingIndex = batches.firstIndex(where: { $0.id == batch.id }) {
            batches[existingIndex] = batch
        } else {
            batches.append(batch)
        }
    }

    func saveBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {
        if shouldFailBatchCorrectionSave {
            throw FakeRepositoryError.requestedFailure
        }

        try save(item)
        try save(batch)
    }

    func deleteBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {
        if shouldFailBatchCorrectionDelete {
            throw FakeRepositoryError.requestedFailure
        }

        try save(item)
        batches.removeAll { $0.id == batch.id }
    }

    func fetchInventoryStockBatches(inventoryItemId: String) throws -> [InventoryStockBatch] {
        batches
            .filter { $0.inventoryItemId == inventoryItemId }
            .sorted {
                switch ($0.expiresAt, $1.expiresAt) {
                case let (.some(left), .some(right)):
                    if left == right {
                        return $0.createdAt < $1.createdAt
                    }

                    return left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return $0.createdAt < $1.createdAt
                }
            }
    }
}

let purchaseBillCatalog = [
    BakingCatalogItem(
        name: "Cake Flour",
        aliases: ["flour"],
        category: "Ingredient",
        active: true
    ),
    BakingCatalogItem(
        name: "Butter",
        aliases: ["unsalted butter"],
        category: "Ingredient",
        active: true
    )
]
