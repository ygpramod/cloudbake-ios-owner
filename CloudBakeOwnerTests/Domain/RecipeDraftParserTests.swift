import XCTest
@testable import CloudBakeOwner

final class RecipeDraftParserTests: XCTestCase {
    func testDraftParsesChocolateCakeIngredientRowsAndNotes() {
        let text = """
        chocolate cake
        600g sponge for 1kg cake
        APF - 130 g
        BP - 1/2 tsp
        BSoda - 1 tsp
        Cocoa powder - 30 g
        Sugar - 150 g
        oil - 75 g
        Milk - 100 g
        curd - 100 g
        Vanilla ext - 1 tsp
        Coffee decoction - 50 g
        320g batter in each tin
        """

        XCTAssertEqual(
            RecipeDraftParser.draft(from: text),
            RecipeDraft(
                name: "chocolate cake",
                notes: "600g sponge for 1kg cake\n320g batter in each tin",
                ingredients: [
                    RecipeIngredientDraft(name: "APF", quantity: 130, unit: .gram, note: nil),
                    RecipeIngredientDraft(name: "BP", quantity: 0.5, unit: .teaspoon, note: nil),
                    RecipeIngredientDraft(name: "BSoda", quantity: 1, unit: .teaspoon, note: nil),
                    RecipeIngredientDraft(name: "Cocoa powder", quantity: 30, unit: .gram, note: nil),
                    RecipeIngredientDraft(name: "Sugar", quantity: 150, unit: .gram, note: nil),
                    RecipeIngredientDraft(name: "oil", quantity: 75, unit: .gram, note: nil),
                    RecipeIngredientDraft(name: "Milk", quantity: 100, unit: .gram, note: nil),
                    RecipeIngredientDraft(name: "curd", quantity: 100, unit: .gram, note: nil),
                    RecipeIngredientDraft(name: "Vanilla ext", quantity: 1, unit: .teaspoon, note: nil),
                    RecipeIngredientDraft(name: "Coffee decoction", quantity: 50, unit: .gram, note: nil)
                ]
            )
        )
    }

    func testDraftReturnsNilForBlankText() {
        XCTAssertNil(RecipeDraftParser.draft(from: " \n "))
    }
}
