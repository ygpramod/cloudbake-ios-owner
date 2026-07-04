import XCTest
@testable import CloudBakeOwner

final class CoreModelsTests: XCTestCase {
    func testInventoryUnitsCoverOwnerRecipeMeasurements() {
        XCTAssertEqual(InventoryUnit.kilogram.rawValue, "kilogram")
        XCTAssertEqual(InventoryUnit.gram.rawValue, "gram")
        XCTAssertEqual(InventoryUnit.liter.rawValue, "liter")
        XCTAssertEqual(InventoryUnit.milliliter.rawValue, "milliliter")
        XCTAssertEqual(InventoryUnit.teaspoon.rawValue, "teaspoon")
        XCTAssertEqual(InventoryUnit.tablespoon.rawValue, "tablespoon")
        XCTAssertEqual(InventoryUnit.cup.rawValue, "cup")
    }

    func testInventoryUnitsConvertWithinWeightFamily() {
        XCTAssertEqual(InventoryUnit.kilogram.convertedQuantity(1.5, to: .gram), 1_500)
        XCTAssertEqual(InventoryUnit.gram.convertedQuantity(750, to: .kilogram), 0.75)
    }

    func testInventoryUnitsConvertWithinVolumeFamily() {
        XCTAssertEqual(InventoryUnit.liter.convertedQuantity(2, to: .milliliter), 2_000)
        XCTAssertEqual(InventoryUnit.tablespoon.convertedQuantity(2, to: .milliliter), 30)
        XCTAssertEqual(InventoryUnit.cup.convertedQuantity(1, to: .milliliter), 240)
    }

    func testInventoryUnitsDoNotConvertAcrossFamilies() {
        XCTAssertNil(InventoryUnit.gram.convertedQuantity(100, to: .milliliter))
        XCTAssertNil(InventoryUnit.each.convertedQuantity(1, to: .gram))
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

    func testInventoryItemIsLowStockWhenStockIsExpiringSoon() {
        let item = InventoryItem(
            id: "inventory-butter",
            name: "Butter",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 500,
            hasExpiringSoonStock: true,
            createdAt: Date(timeIntervalSince1970: 1_800_040_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_040_000)
        )

        XCTAssertTrue(item.isLowStock)
    }

    func testInventoryItemIsArchivedWhenArchivedAtIsPresent() {
        let item = InventoryItem(
            id: "inventory-old-flour",
            name: "Old flour",
            unit: .gram,
            currentQuantity: 0,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_040_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_040_100),
            archivedAt: Date(timeIntervalSince1970: 1_800_040_200)
        )

        XCTAssertTrue(item.isArchived)
    }
}
