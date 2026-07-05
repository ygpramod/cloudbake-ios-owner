import XCTest
@testable import CloudBakeOwner

final class RecipeDraftParserTests: XCTestCase {
    func testDraftUsesFirstLineAsNameAndRemainingLinesAsNotes() {
        let text = """

        Vanilla Sponge
        Flour 250 g
        Sugar 200 g
        Bake until golden
        """

        XCTAssertEqual(
            RecipeDraftParser.draft(from: text),
            RecipeDraft(
                name: "Vanilla Sponge",
                notes: "Flour 250 g\nSugar 200 g\nBake until golden"
            )
        )
    }

    func testDraftReturnsNilForBlankText() {
        XCTAssertNil(RecipeDraftParser.draft(from: " \n "))
    }
}
