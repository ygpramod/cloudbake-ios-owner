import XCTest
@testable import CloudBakeOwner

@MainActor
final class InAppExpiryReminderViewModelTests: XCTestCase {
    func testRefreshShowsEarliestExpiredOrExpiringWithinAWeekBatch() {
        let repository = FakeInAppExpiryReminderRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 10))!
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 500,
                minimumQuantity: 250,
                createdAt: now,
                updatedAt: now
            ),
            InventoryItem(
                id: "inventory-butter",
                name: "Butter",
                unit: .gram,
                currentQuantity: 250,
                minimumQuantity: 100,
                createdAt: now,
                updatedAt: now
            )
        ]
        repository.batches = [
            InventoryStockBatch(
                id: "batch-flour",
                inventoryItemId: "inventory-flour",
                remainingQuantity: 500,
                expiresAt: calendar.date(byAdding: .day, value: 4, to: now),
                createdAt: now,
                updatedAt: now
            ),
            InventoryStockBatch(
                id: "batch-butter",
                inventoryItemId: "inventory-butter",
                remainingQuantity: 250,
                expiresAt: calendar.date(byAdding: .day, value: -1, to: now),
                createdAt: now,
                updatedAt: now
            )
        ]
        let viewModel = InAppExpiryReminderViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.refresh()

        XCTAssertEqual(
            viewModel.currentReminder,
            InAppExpiryReminder(
                id: "batch-butter",
                stockBatchId: "batch-butter",
                itemName: "Butter",
                quantityText: "250 g",
                expiresAt: calendar.date(byAdding: .day, value: -1, to: now)!,
                isExpired: true
            )
        )
        XCTAssertEqual(viewModel.selectedSnoozeDays, 1)
    }

    func testRefreshIgnoresSnoozedReminderUntilSnoozeExpires() {
        let repository = FakeInAppExpiryReminderRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 10))!
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 500,
                minimumQuantity: 250,
                createdAt: now,
                updatedAt: now
            )
        ]
        repository.batches = [
            InventoryStockBatch(
                id: "batch-flour",
                inventoryItemId: "inventory-flour",
                remainingQuantity: 500,
                expiresAt: calendar.date(byAdding: .day, value: 3, to: now),
                createdAt: now,
                updatedAt: now
            )
        ]
        repository.snoozes = [
            "batch-flour": calendar.date(byAdding: .day, value: 1, to: now)!
        ]
        let viewModel = InAppExpiryReminderViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )

        viewModel.refresh()

        XCTAssertNil(viewModel.currentReminder)
    }

    func testSnoozeCurrentReminderPersistsSelectedNumberOfDays() {
        let repository = FakeInAppExpiryReminderRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 10))!
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 500,
                minimumQuantity: 250,
                createdAt: now,
                updatedAt: now
            )
        ]
        repository.batches = [
            InventoryStockBatch(
                id: "batch-flour",
                inventoryItemId: "inventory-flour",
                remainingQuantity: 500,
                expiresAt: calendar.date(byAdding: .day, value: 3, to: now),
                createdAt: now,
                updatedAt: now
            )
        ]
        let viewModel = InAppExpiryReminderViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar
        )
        viewModel.refresh()
        viewModel.selectedSnoozeDays = 7

        viewModel.snoozeCurrentReminder()

        XCTAssertNil(viewModel.currentReminder)
        XCTAssertEqual(
            repository.snoozes["batch-flour"],
            calendar.date(byAdding: .day, value: 7, to: now)
        )
        XCTAssertEqual(repository.updatedAtByBatchId["batch-flour"], now)
    }
}

private final class FakeInAppExpiryReminderRepository: InventoryItemRepository, InventoryStockBatchRepository, InventoryExpirySnoozeRepository {
    var items: [InventoryItem] = []
    var batches: [InventoryStockBatch] = []
    var snoozes: [String: Date] = [:]
    var updatedAtByBatchId: [String: Date] = [:]

    func save(_ item: InventoryItem) throws {}

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        items.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        items
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        []
    }

    func save(_ batch: InventoryStockBatch) throws {}

    func saveBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {}

    func deleteBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {}

    func fetchInventoryStockBatches(inventoryItemId: String) throws -> [InventoryStockBatch] {
        batches.filter { $0.inventoryItemId == inventoryItemId }
    }

    func fetchInventoryExpirySnoozes() throws -> [String: Date] {
        snoozes
    }

    func snoozeInventoryExpiryReminder(stockBatchId: String, until snoozedUntil: Date, updatedAt: Date) throws {
        snoozes[stockBatchId] = snoozedUntil
        updatedAtByBatchId[stockBatchId] = updatedAt
    }
}
