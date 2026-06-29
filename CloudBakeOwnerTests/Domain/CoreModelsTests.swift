import XCTest
@testable import CloudBakeOwner

final class CoreModelsTests: XCTestCase {
    func testInventoryUnitsCoverOwnerRecipeMeasurements() {
        XCTAssertEqual(InventoryUnit.kilogram.rawValue, "kilogram")
        XCTAssertEqual(InventoryUnit.gram.rawValue, "gram")
        XCTAssertEqual(InventoryUnit.milliliter.rawValue, "milliliter")
        XCTAssertEqual(InventoryUnit.teaspoon.rawValue, "teaspoon")
        XCTAssertEqual(InventoryUnit.tablespoon.rawValue, "tablespoon")
        XCTAssertEqual(InventoryUnit.cup.rawValue, "cup")
    }

    func testOrderStatusStartsWithDraftAndConfirmedStates() {
        XCTAssertEqual(OrderStatus.draft.rawValue, "draft")
        XCTAssertEqual(OrderStatus.confirmed.rawValue, "confirmed")
    }

    func testInventoryItemIsLowStockWhenCurrentQuantityIsBelowMinimumQuantity() {
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_040_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_040_000)
        )

        XCTAssertTrue(item.isLowStock)
    }

    func testInventoryItemIsNotLowStockWhenCurrentQuantityMeetsMinimumQuantity() {
        let item = InventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_040_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_040_000)
        )

        XCTAssertFalse(item.isLowStock)
    }
}
