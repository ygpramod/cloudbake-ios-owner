import XCTest
@testable import CloudBakeOwner

final class TextInputFormattingTests: XCTestCase {
    func testOptionalTextTrimsWhitespaceAndDropsEmptyValues() {
        XCTAssertEqual(TextInputFormatting.optionalText("  vanilla  "), "vanilla")
        XCTAssertNil(TextInputFormatting.optionalText(" \n\t "))
    }

    func testNormalizedSearchKeyKeepsOnlyLowercaseLettersAndNumbers() {
        XCTAssertEqual(TextInputFormatting.normalizedSearchKey("  Cake Flour #1  "), "cakeflour1")
    }

    func testDigitsOnlyRemovesFormattingCharacters() {
        XCTAssertEqual(TextInputFormatting.digitsOnly("+65 9123-4567"), "6591234567")
    }

    func testDecimalTextKeepsStoredDecimalPrecisionAndDefaultsNilToEmpty() {
        XCTAssertEqual(TextInputFormatting.decimalText(Decimal(string: "12.50")), "12.5")
        XCTAssertEqual(TextInputFormatting.decimalText(nil), "")
    }
}
