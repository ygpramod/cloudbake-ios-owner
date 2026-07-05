import XCTest
@testable import CloudBakeOwner

final class PurchaseBillDraftParserTests: XCTestCase {
    func testDraftItemsIncludesOnlyCatalogMatchedBillLines() {
        let text = """
        Cake Flour 1 kg 4.50
        Laundry Detergent 1 L 8.00
        Unsalted Butter 500 g 6.20
        """

        let drafts = PurchaseBillDraftParser.draftItems(from: text, catalog: catalog)

        XCTAssertEqual(
            drafts,
            [
                PurchaseBillDraftInventoryItem(
                    name: "Cake Flour",
                    sourceLine: "Cake Flour 1 kg 4.50",
                    quantity: 1,
                    unit: .kilogram
                ),
                PurchaseBillDraftInventoryItem(
                    name: "Butter",
                    sourceLine: "Unsalted Butter 500 g 6.20",
                    quantity: 500,
                    unit: .gram
                )
            ]
        )
    }

    func testDraftItemsMatchAliasesAndCombinedQuantityUnitTokens() {
        let text = """
        Aashirvaad Maida 2kg
        Fresh Cream 250ml
        """

        let drafts = PurchaseBillDraftParser.draftItems(from: text, catalog: catalog)

        XCTAssertEqual(
            drafts,
            [
                PurchaseBillDraftInventoryItem(
                    name: "Cake Flour",
                    sourceLine: "Aashirvaad Maida 2kg",
                    quantity: 2,
                    unit: .kilogram
                ),
                PurchaseBillDraftInventoryItem(
                    name: "Cream",
                    sourceLine: "Fresh Cream 250ml",
                    quantity: 250,
                    unit: .milliliter
                )
            ]
        )
    }

    func testDraftItemsSupportCommonReceiptUnits() {
        let text = """
        Eggs 12 pcs
        Vanilla Essence 2 tsp
        Cocoa Powder 1 cup
        """

        let drafts = PurchaseBillDraftParser.draftItems(from: text, catalog: catalog)

        XCTAssertEqual(drafts.map(\.unit), [.each, .teaspoon, .cup])
        XCTAssertEqual(drafts.map(\.quantity), [12, 2, 1])
    }

    func testDraftItemsCanBeCreatedWithoutRecognizedMeasurement() {
        let text = "Cake Board Round Large"

        let drafts = PurchaseBillDraftParser.draftItems(from: text, catalog: catalog)

        XCTAssertEqual(
            drafts,
            [
                PurchaseBillDraftInventoryItem(
                    name: "Cake Board",
                    sourceLine: "Cake Board Round Large",
                    quantity: nil,
                    unit: nil
                )
            ]
        )
    }

    func testDraftItemsIgnoreInactiveCatalogEntries() {
        let text = "Sprinkles 100 g"
        let inactiveCatalog = [
            BakingCatalogItem(
                name: "Sprinkles",
                aliases: ["rainbow sprinkles"],
                category: "Decoration",
                active: false
            )
        ]

        XCTAssertEqual(PurchaseBillDraftParser.draftItems(from: text, catalog: inactiveCatalog), [])
    }

    private var catalog: [BakingCatalogItem] {
        [
            BakingCatalogItem(
                name: "Cake Flour",
                aliases: ["flour", "maida"],
                category: "Ingredient",
                active: true
            ),
            BakingCatalogItem(
                name: "Butter",
                aliases: ["unsalted butter"],
                category: "Ingredient",
                active: true
            ),
            BakingCatalogItem(
                name: "Cream",
                aliases: ["fresh cream"],
                category: "Ingredient",
                active: true
            ),
            BakingCatalogItem(
                name: "Eggs",
                aliases: ["egg"],
                category: "Ingredient",
                active: true
            ),
            BakingCatalogItem(
                name: "Vanilla Extract",
                aliases: ["vanilla essence"],
                category: "Ingredient",
                active: true
            ),
            BakingCatalogItem(
                name: "Cocoa Powder",
                aliases: ["cocoa"],
                category: "Ingredient",
                active: true
            ),
            BakingCatalogItem(
                name: "Cake Board",
                aliases: ["cake boards"],
                category: "Packaging",
                active: true
            )
        ]
    }
}
