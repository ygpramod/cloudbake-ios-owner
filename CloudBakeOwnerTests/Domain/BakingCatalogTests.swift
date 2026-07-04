import XCTest
@testable import CloudBakeOwner

final class BakingCatalogTests: XCTestCase {
    func testLoadDecodesCatalogItemsFromJSON() throws {
        let json = """
        [
          {
            "name": "Cake Flour",
            "aliases": ["maida"],
            "category": "Ingredient",
            "active": true
          }
        ]
        """

        let catalog = try BakingCatalog.load(from: Data(json.utf8))

        XCTAssertEqual(
            catalog,
            [
                BakingCatalogItem(
                    name: "Cake Flour",
                    aliases: ["maida"],
                    category: "Ingredient",
                    active: true
                )
            ]
        )
    }

    func testMatchesCatalogItemByNameAndAlias() {
        let catalog = [
            BakingCatalogItem(
                name: "Cake Flour",
                aliases: ["maida", "plain flour"],
                category: "Ingredient",
                active: true
            ),
            BakingCatalogItem(
                name: "Butter",
                aliases: ["unsalted butter"],
                category: "Ingredient",
                active: true
            )
        ]

        XCTAssertEqual(
            BakingCatalog.matches(in: "AASHIRVAAD Maida 1 kg", catalog: catalog),
            [catalog[0]]
        )
        XCTAssertEqual(
            BakingCatalog.matches(in: "Unsalted Butter 500 g", catalog: catalog),
            [catalog[1]]
        )
    }

    func testMatchesWholeTokensOnly() {
        let catalog = [
            BakingCatalogItem(
                name: "Eggs",
                aliases: ["egg"],
                category: "Ingredient",
                active: true
            )
        ]

        XCTAssertEqual(BakingCatalog.matches(in: "egg 12 pcs", catalog: catalog), catalog)
        XCTAssertEqual(BakingCatalog.matches(in: "eggplant 1 kg", catalog: catalog), [])
    }

    func testMatchesPluralizedTerms() {
        let catalog = [
            BakingCatalogItem(
                name: "Cake Box",
                aliases: ["cake boxes"],
                category: "Packaging",
                active: true
            )
        ]

        XCTAssertEqual(BakingCatalog.matches(in: "cake boxes large", catalog: catalog), catalog)
        XCTAssertEqual(BakingCatalog.matches(in: "cake box large", catalog: catalog), catalog)
    }

    func testInactiveItemsAreIgnored() {
        let catalog = [
            BakingCatalogItem(
                name: "Sprinkles",
                aliases: ["rainbow sprinkles"],
                category: "Decoration",
                active: false
            )
        ]

        XCTAssertEqual(BakingCatalog.matches(in: "rainbow sprinkles", catalog: catalog), [])
    }

    func testBundledCatalogContainsExpectedBakingItems() throws {
        let catalog = try BakingCatalog.loadBundledCatalog()

        XCTAssertTrue(catalog.contains { $0.name == "Cake Flour" })
        XCTAssertTrue(catalog.contains { $0.aliases.contains("maida") })
        XCTAssertTrue(catalog.contains { $0.name == "Butter" })
        XCTAssertTrue(catalog.allSatisfy { !$0.name.isEmpty && !$0.category.isEmpty })
    }
}
