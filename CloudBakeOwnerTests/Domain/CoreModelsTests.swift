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
}
