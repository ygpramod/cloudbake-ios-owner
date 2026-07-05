import Foundation

struct InAppExpiryReminder: Equatable, Identifiable {
    let id: String
    let stockBatchId: String
    let itemName: String
    let quantityText: String
    let expiresAt: Date
    let isExpired: Bool
}

@MainActor
final class InAppExpiryReminderViewModel: ObservableObject {
    @Published private(set) var currentReminder: InAppExpiryReminder?
    @Published var selectedSnoozeDays = 1
    @Published var errorMessage: String?

    let snoozeDayOptions = Array(1...7)

    private let repository: any InventoryItemRepository & InventoryStockBatchRepository & InventoryExpirySnoozeRepository
    private let dateProvider: () -> Date
    private let calendar: Calendar

    init(
        repository: any InventoryItemRepository & InventoryStockBatchRepository & InventoryExpirySnoozeRepository,
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func refresh() {
        do {
            currentReminder = try nextReminder()
            selectedSnoozeDays = 1
            errorMessage = nil
        } catch {
            errorMessage = "Expiry reminders could not be loaded."
        }
    }

    func snoozeCurrentReminder() {
        guard let currentReminder else {
            return
        }

        let now = dateProvider()
        let snoozedUntil = calendar.date(byAdding: .day, value: selectedSnoozeDays, to: now)
            ?? now.addingTimeInterval(TimeInterval(selectedSnoozeDays * 24 * 60 * 60))

        do {
            try repository.snoozeInventoryExpiryReminder(
                stockBatchId: currentReminder.stockBatchId,
                until: snoozedUntil,
                updatedAt: now
            )
            self.currentReminder = nil
            errorMessage = nil
        } catch {
            errorMessage = "Expiry reminder could not be snoozed."
        }
    }

    func dismissCurrentReminder() {
        currentReminder = nil
    }

    private func nextReminder() throws -> InAppExpiryReminder? {
        let now = dateProvider()
        let expiringThreshold = calendar.date(byAdding: .day, value: 7, to: now)
            ?? now.addingTimeInterval(7 * 24 * 60 * 60)
        let snoozes = try repository.fetchInventoryExpirySnoozes()
        let items = try repository.fetchInventoryItems()
        var reminders: [InAppExpiryReminder] = []

        for item in items {
            let batches = try repository.fetchInventoryStockBatches(inventoryItemId: item.id)
            for batch in batches where batch.remainingQuantity > 0 {
                guard let expiresAt = batch.expiresAt,
                      expiresAt <= expiringThreshold else {
                    continue
                }

                if let snoozedUntil = snoozes[batch.id], snoozedUntil > now {
                    continue
                }

                reminders.append(
                    InAppExpiryReminder(
                        id: batch.id,
                        stockBatchId: batch.id,
                        itemName: item.name,
                        quantityText: "\(batch.remainingQuantity.formatted()) \(item.unit.displayName)",
                        expiresAt: expiresAt,
                        isExpired: expiresAt < now
                    )
                )
            }
        }

        return reminders.sorted {
            if $0.expiresAt == $1.expiresAt {
                return $0.itemName.localizedCaseInsensitiveCompare($1.itemName) == .orderedAscending
            }

            return $0.expiresAt < $1.expiresAt
        }.first
    }
}
