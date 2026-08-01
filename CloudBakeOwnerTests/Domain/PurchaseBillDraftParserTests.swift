import XCTest

@testable import CloudBakeOwner

final class PurchaseBillDraftParserTests: XCTestCase {
    func testDraftItemsIncludeMeasuredProductsOutsideCatalog() {
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
                    unit: .kilogram,
                    receiptName: "Cake Flour",
                    amount: 4.50
                ),
                PurchaseBillDraftInventoryItem(
                    name: "Laundry Detergent",
                    sourceLine: "Laundry Detergent 1 L 8.00",
                    quantity: 1,
                    unit: .liter,
                    receiptName: "Laundry Detergent",
                    amount: 8
                ),
                PurchaseBillDraftInventoryItem(
                    name: "Butter",
                    sourceLine: "Unsalted Butter 500 g 6.20",
                    quantity: 500,
                    unit: .gram,
                    receiptName: "Unsalted Butter",
                    amount: 6.20
                ),
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
                    unit: .kilogram,
                    receiptName: "Aashirvaad Maida"
                ),
                PurchaseBillDraftInventoryItem(
                    name: "Cream",
                    sourceLine: "Fresh Cream 250ml",
                    quantity: 250,
                    unit: .milliliter,
                    receiptName: "Fresh Cream"
                ),
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
                    unit: nil,
                    receiptName: "Cake Board Round Large"
                )
            ]
        )
    }

    func testDraftItemsTreatInactiveCatalogEntriesAsUnknownProducts() {
        let text = "Sprinkles 100 g"
        let inactiveCatalog = [
            BakingCatalogItem(
                name: "Sprinkles",
                aliases: ["rainbow sprinkles"],
                category: "Decoration",
                active: false
            )
        ]

        XCTAssertEqual(
            PurchaseBillDraftParser.draftItems(from: text, catalog: inactiveCatalog),
            [
                PurchaseBillDraftInventoryItem(
                    name: "Sprinkles",
                    sourceLine: "Sprinkles 100 g",
                    quantity: 100,
                    unit: .gram,
                    receiptName: "Sprinkles"
                )
            ]
        )
    }

    func testDraftItemsParseExactOwnerOCRReceiptOutput() {
        let text = """
            GIANT SIMEI MRT (G381)
            30 Simei Street 3 #01-01 Simei MRT Station
            S (529888)
            GST M200010132 TAX Invoice BIZ 52909043B
            CHIPSMORE DOUBLE CHOCO 135G
            2 4.00
            OREO S COOKIES VANILLA 105G
            1.85
            WHITE GARLIC CHINA 500G 3. 15
            DORITOS SPICY NACHO 190G 5.35
            RUSSET POTATO USA 800G 3.95
            PLASTIC BAG CHARGE 0.05
            MEIJI FRESH MILK 2L. 6.90
            PRICE OFF 0. 20-
            Total saving 0. 20-
            Total (SGD) INCL. GST 25. 05
            GST AMT 2. 06
            Price payable includes GST
            yuu Points 15.39
            MASTER 9.66
            TERMINAL 57071180 APPR CODE: 816998
            BATCH: 000244 CARD NO:0275
            REF. NO: 621211224699
            yuu ID:***7969
            Previous Points Balance: 3, 078. 20
            yuu Points Redeemed: 3, 078. 00
            Check the yuu App for your updated
            Points balance and discover exciting
            Rewards
            Giant is now on foodpanda!
            Shop now, savour sooner.
            Delivered in Thr to your doorstep
            T&C apply
            3107265517090513968
            Receipt required for Refund or Exchange
            PO$51 TR3968 ID65381200 19:20 31/07/2026
            """
        let catalog = [
            BakingCatalogItem(
                name: "Oreo",
                aliases: ["oreo s cookies vanilla"],
                category: "Ingredient",
                active: true
            )
        ]

        let drafts = PurchaseBillDraftParser.draftItems(from: text, catalog: catalog)

        XCTAssertEqual(
            drafts.map(\.name),
            [
                "Chipsmore Double Choco",
                "Oreo",
                "White Garlic China",
                "Doritos Spicy Nacho",
                "Russet Potato Usa",
                "Plastic Bag Charge",
                "Meiji Fresh Milk",
            ]
        )
        XCTAssertEqual(drafts.map(\.quantity), [270, 105, 500, 190, 800, 1, 2])
        XCTAssertEqual(drafts.map(\.unit), [.gram, .gram, .gram, .gram, .gram, .each, .liter])
        XCTAssertEqual(drafts.map(\.amount), [4, 1.85, 3.15, 5.35, 3.95, 0.05, 6.90])
        XCTAssertEqual(drafts.map(\.shouldDefaultToIgnore), [false, false, false, false, false, true, false])
        XCTAssertEqual(drafts[0].sourceLine, "CHIPSMORE DOUBLE CHOCO 135G\n2 4.00")
        XCTAssertEqual(drafts[2].receiptName, "WHITE GARLIC CHINA")
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
            ),
        ]
    }
}
