import XCTest
@testable import CloudBakeOwner

final class InventoryAliasesTests: XCTestCase {
    func testAliasesAreSplitTrimmedAndDeduplicated() {
        XCTAssertEqual(
            InventoryAliases.aliases(from: "Maida, Aashirvaad Maida\n maida \nPlain Flour"),
            ["Maida", "Aashirvaad Maida", "Plain Flour"]
        )
    }
}
