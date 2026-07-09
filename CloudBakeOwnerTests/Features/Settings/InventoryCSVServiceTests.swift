import XCTest
@testable import CloudBakeOwner

final class InventoryCSVServiceTests: XCTestCase {
    func testExportWritesActiveInventoryWithBatchExpiry() throws {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let expiry = try XCTUnwrap(Self.dateFormatter.date(from: "2026-08-15"))
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.items = [item]
        repository.batches = [
            InventoryStockBatch(
                id: "batch-flour",
                inventoryItemId: item.id,
                remainingQuantity: 250,
                expiresAt: expiry,
                unitCost: Decimal(string: "2.50"),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        let service = InventoryCSVService()

        let csv = try service.exportCSV(repository: repository)

        XCTAssertTrue(csv.contains("name,unit,current_quantity,minimum_quantity,batch_quantity,unit_cost,expiry_date"))
        XCTAssertTrue(csv.contains("Cake flour,g,250,500,250,2.5,2026-08-15"))
    }

    func testImportCreatesInventoryAndBatchesFromCSV() throws {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let service = InventoryCSVService(
            idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
            dateProvider: { now }
        )

        let summary = try service.importCSV(
            """
            name,unit,current_quantity,minimum_quantity,batch_quantity,unit_cost,expiry_date
            Cake flour,g,250,500,250,2.50,2026-08-15
            Butter,kg,2,1,2,,
            """,
            repository: repository
        )

        XCTAssertEqual(summary, InventoryCSVImportSummary(importedItemCount: 2, importedBatchCount: 2))
        XCTAssertEqual(repository.items.map(\.name).sorted(), ["Butter", "Cake flour"])
        XCTAssertEqual(repository.items.first { $0.name == "Cake flour" }?.currentQuantity, 250)
        XCTAssertEqual(repository.items.first { $0.name == "Butter" }?.unit, .kilogram)
        XCTAssertEqual(repository.batches.count, 2)
        XCTAssertEqual(repository.batches.first { $0.remainingQuantity == 250 }?.unitCost, Decimal(string: "2.50"))
    }

    func testImportUpdatesExistingInventoryByNameAndUnit() throws {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let existing = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 50,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.items = [existing]
        repository.batches = [
            InventoryStockBatch(
                id: "old-batch",
                inventoryItemId: existing.id,
                remainingQuantity: 100,
                expiresAt: nil,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        let service = InventoryCSVService(
            idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
            dateProvider: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        let summary = try service.importCSV(
            """
            name,unit,current_quantity,minimum_quantity,batch_quantity,expiry_date
            cake flour,g,300,500,125,2026-08-15
            Cake Flour,g,300,500,175,2026-09-30
            """,
            repository: repository
        )

        XCTAssertEqual(summary, InventoryCSVImportSummary(importedItemCount: 1, importedBatchCount: 2))
        XCTAssertEqual(repository.items.count, 1)
        XCTAssertEqual(repository.items[0].id, existing.id)
        XCTAssertEqual(repository.items[0].currentQuantity, 300)
        XCTAssertEqual(repository.items[0].minimumQuantity, 500)
        XCTAssertEqual(repository.batches.map(\.remainingQuantity).sorted(), [125, 175])
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
