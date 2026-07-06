import UserNotifications
import XCTest
@testable import CloudBakeOwner

final class ExpiryReminderSchedulerTests: XCTestCase {
    func testMakeReminderRequestsSchedulesExpiringBatchesWithinOneMonth() throws {
        let repository = FakeExpiryReminderRepository()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 8, minute: 0))!
        let expiresAt = calendar.date(byAdding: .day, value: 10, to: now)!
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
                expiresAt: expiresAt,
                createdAt: now,
                updatedAt: now
            )
        ]
        let scheduler = ExpiryReminderScheduler(
            repository: repository,
            notificationCenter: FakeExpiryReminderNotificationCenter(),
            dateProvider: { now }
        )

        let requests = try scheduler.makeReminderRequests()

        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].identifier, "inventory-expiry-batch-flour")
        XCTAssertEqual(requests[0].content.title, "Inventory expiring soon")
        XCTAssertEqual(
            requests[0].content.body,
            "Cake flour has 500 g expiring on \(expiresAt.formatted(date: .abbreviated, time: .omitted))."
        )
        let trigger = try XCTUnwrap(requests[0].trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
    }

    func testMakeReminderRequestsIgnoresBatchesThatDoNotNeedExpiryReminder() throws {
        let repository = FakeExpiryReminderRepository()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
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
                id: "batch-expired",
                inventoryItemId: "inventory-flour",
                remainingQuantity: 100,
                expiresAt: now.addingTimeInterval(-86_400),
                createdAt: now,
                updatedAt: now
            ),
            InventoryStockBatch(
                id: "batch-later",
                inventoryItemId: "inventory-flour",
                remainingQuantity: 100,
                expiresAt: Calendar(identifier: .gregorian).date(byAdding: .day, value: 45, to: now),
                createdAt: now,
                updatedAt: now
            ),
            InventoryStockBatch(
                id: "batch-empty",
                inventoryItemId: "inventory-flour",
                remainingQuantity: 0,
                expiresAt: Calendar(identifier: .gregorian).date(byAdding: .day, value: 10, to: now),
                createdAt: now,
                updatedAt: now
            ),
            InventoryStockBatch(
                id: "batch-no-expiry",
                inventoryItemId: "inventory-flour",
                remainingQuantity: 100,
                expiresAt: nil,
                createdAt: now,
                updatedAt: now
            )
        ]
        let scheduler = ExpiryReminderScheduler(
            repository: repository,
            notificationCenter: FakeExpiryReminderNotificationCenter(),
            dateProvider: { now }
        )

        XCTAssertEqual(try scheduler.makeReminderRequests(), [])
    }

    func testRefreshRemindersRequestsPermissionAndAddsRequests() async throws {
        let repository = FakeExpiryReminderRepository()
        let notificationCenter = FakeExpiryReminderNotificationCenter()
        notificationCenter.pendingRequests = [
            UNNotificationRequest(
                identifier: "inventory-expiry-stale-batch",
                content: UNNotificationContent(),
                trigger: nil
            ),
            UNNotificationRequest(
                identifier: "unrelated-reminder",
                content: UNNotificationContent(),
                trigger: nil
            )
        ]
        let now = Date(timeIntervalSince1970: 1_800_000_000)
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
                expiresAt: Calendar(identifier: .gregorian).date(byAdding: .day, value: 10, to: now),
                createdAt: now,
                updatedAt: now
            )
        ]
        let scheduler = ExpiryReminderScheduler(
            repository: repository,
            notificationCenter: notificationCenter,
            dateProvider: { now }
        )

        await scheduler.refreshReminders()

        XCTAssertEqual(notificationCenter.requestedAuthorizationOptions, [.alert, .sound, .badge])
        XCTAssertEqual(notificationCenter.removedIdentifiers, ["inventory-expiry-stale-batch"])
        XCTAssertEqual(notificationCenter.addedRequests.map(\.identifier), ["inventory-expiry-batch-flour"])
    }
}

private final class FakeExpiryReminderRepository: InventoryItemRepository, InventoryStockBatchRepository {
    var items: [InventoryItem] = []
    var batches: [InventoryStockBatch] = []

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
}

private final class FakeExpiryReminderNotificationCenter: LocalNotificationCenter {
    var requestedAuthorizationOptions: UNAuthorizationOptions?
    var pendingRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var addedRequests: [UNNotificationRequest] = []
    var allowsAuthorization = true

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedAuthorizationOptions = options
        return allowsAuthorization
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers = identifiers
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }
}
