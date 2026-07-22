import XCTest
@testable import CloudBakeOwner

final class OrderIngredientCostCalculationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testCalculatesKnownCostAndReportsMissingBatchPrice() throws {
        let item = makeItem()
        let batches = [
            makeBatch(id: "priced", quantity: 100, amount: 50, expiresIn: 1),
            makeBatch(id: "missing", quantity: 50, amount: nil, expiresIn: 2)
        ]

        let summary = try OrderIngredientCostCalculation.summary(
            requirements: [(item, 120)],
            batches: { _ in batches },
            at: now
        )

        XCTAssertEqual(summary.knownCost, decimal("50"))
        XCTAssertEqual(summary.lines[0].missingPriceQuantity, 20, accuracy: 0.001)
        XCTAssertEqual(summary.lines[0].shortfallQuantity, 0, accuracy: 0.001)
        XCTAssertEqual(summary.itemsMissingPrice, ["Cake flour"])
    }

    func testExcludesExpiredBatchCost() throws {
        let item = makeItem()
        let batches = [
            makeBatch(id: "expired", quantity: 100, amount: 10, expiresIn: -1),
            makeBatch(id: "usable", quantity: 100, amount: 40, expiresIn: 1)
        ]

        let summary = try OrderIngredientCostCalculation.summary(
            requirements: [(item, 50)],
            batches: { _ in batches },
            at: now
        )

        XCTAssertEqual(summary.knownCost, decimal("20"))
        XCTAssertEqual(summary.lines[0].missingPriceQuantity, 0, accuracy: 0.001)
    }

    func testUsesLatestKnownPriceForRequiredQuantityBeyondUsableStock() throws {
        let item = makeItem()
        let batches = [makeBatch(id: "priced", quantity: 100, amount: 50, expiresIn: 1)]

        let summary = try OrderIngredientCostCalculation.summary(
            requirements: [(item, 300)],
            batches: { _ in batches },
            at: now
        )

        XCTAssertEqual(summary.knownCost, decimal("150"))
        XCTAssertEqual(summary.lines[0].missingPriceQuantity, 0, accuracy: 0.001)
        XCTAssertEqual(summary.lines[0].shortfallQuantity, 200, accuracy: 0.001)
        XCTAssertTrue(summary.itemsMissingPrice.isEmpty)
    }

    func testUsesNewestHistoricalPriceWithoutConsumingExpiredStock() throws {
        let item = makeItem(currentQuantity: 0)
        let older = makeBatch(id: "older", quantity: 0, amount: nil, expiresIn: -5, createdAt: now.addingTimeInterval(-20))
        let newer = InventoryStockBatch(
            id: "newer",
            inventoryItemId: item.id,
            remainingQuantity: 0,
            expiresAt: now.addingTimeInterval(-86_400),
            amount: 80,
            unitCost: decimal("0.8"),
            createdAt: now.addingTimeInterval(-10),
            updatedAt: now.addingTimeInterval(-10)
        )

        let summary = try OrderIngredientCostCalculation.summary(
            requirements: [(item, 100)],
            batches: { _ in [older, newer] },
            at: now
        )

        XCTAssertEqual(summary.knownCost, decimal("80"))
        XCTAssertEqual(summary.lines[0].shortfallQuantity, 100, accuracy: 0.001)
        XCTAssertTrue(summary.itemsMissingPrice.isEmpty)
    }

    func testKeepsMissingPriceWarningWhenNoHistoricalPriceExists() throws {
        let item = makeItem(currentQuantity: 0)

        let summary = try OrderIngredientCostCalculation.summary(
            requirements: [(item, 100)],
            batches: { _ in [] },
            at: now
        )

        XCTAssertEqual(summary.knownCost, 0)
        XCTAssertEqual(summary.lines[0].missingPriceQuantity, 100, accuracy: 0.001)
        XCTAssertEqual(summary.lines[0].shortfallQuantity, 100, accuracy: 0.001)
        XCTAssertEqual(summary.itemsMissingPrice, ["Cake flour"])
    }

    private func makeItem(currentQuantity: Double = 150) -> InventoryItem {
        InventoryItem(
            id: "flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: currentQuantity,
            minimumQuantity: 10,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeBatch(
        id: String,
        quantity: Double,
        amount: Decimal?,
        expiresIn days: Double,
        createdAt: Date? = nil
    ) -> InventoryStockBatch {
        InventoryStockBatch(
            id: id,
            inventoryItemId: "flour",
            remainingQuantity: quantity,
            expiresAt: now.addingTimeInterval(days * 86_400),
            amount: amount,
            createdAt: createdAt ?? now,
            updatedAt: createdAt ?? now
        )
    }
}
