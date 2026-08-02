import XCTest
@testable import CloudBakeOwner

final class OrderCakeSpecificationTests: XCTestCase {
    func testSuggestionsUseFourteenServingsPerKilogram() {
        XCTAssertEqual(OrderCakeSpecification.suggestedWeight(forServings: 20), Decimal(string: "1.4"))
        XCTAssertEqual(OrderCakeSpecification.suggestedWeight(forServings: 21), Decimal(string: "1.5"))
        XCTAssertEqual(OrderCakeSpecification.suggestedServings(forWeightKilograms: 1.5), 21)
    }

    func testSuggestionsRejectNonPositiveValues() {
        XCTAssertNil(OrderCakeSpecification.suggestedWeight(forServings: 0))
        XCTAssertNil(OrderCakeSpecification.suggestedServings(forWeightKilograms: 0))
    }

    func testSummaryOmitsEmptyAndNoneValues() {
        let specification = OrderCakeSpecification(
            occasion: "Birthday",
            servings: 28,
            weightKilograms: 2,
            shape: "Circle",
            tiers: "2",
            spongeFlavour: "Chocolate",
            filling: "Chocolate Ganache",
            frosting: "Fondant",
            colourPalette: "Pink and gold",
            theme: "Floral",
            topperRequirements: "Name topper",
            candlesAndAccessories: "None",
            packaging: "Standard Box"
        )

        XCTAssertEqual(
            specification.summary,
            "Birthday cake for 28 servings (2 kg); circle, 2 tiers; with chocolate sponge, chocolate ganache filling, and fondant frosting; Pink and gold palette and Floral theme; Name topper; packed in standard box."
        )
        XCTAssertFalse(specification.summary?.contains("None") == true)
    }

    func testSummaryIsNilWhenNoMeaningfulDetailsExist() {
        XCTAssertNil(OrderCakeSpecification.empty.summary)
        XCTAssertEqual(
            OrderCakeSpecification(
                topperRequirements: "None",
                candlesAndAccessories: " none "
            ).summary,
            nil
        )
    }

    func testChoicesAreTrimmedAndCaseInsensitiveUnique() {
        XCTAssertEqual(
            OrderCakeSpecification.mergedChoices(
                defaults: ["Vanilla", "Chocolate"],
                saved: [" vanilla ", "Red Velvet", "red velvet"],
                current: "Matcha"
            ),
            ["Vanilla", "Chocolate", "Red Velvet", "Matcha"]
        )
    }

    func testOnlyCustomAndFreeFormValuesBecomeReusableChoices() {
        let specification = OrderCakeSpecification(
            occasion: "Birthday",
            shape: "Hexagon",
            spongeFlavour: "Pandan",
            colourPalette: "Sage and ivory",
            theme: "Botanical",
            topperRequirements: "None",
            packaging: "Standard Box"
        )

        XCTAssertEqual(
            specification.reusableChoiceValues.map(\.field),
            [.shape, .spongeFlavour, .colourPalette, .theme]
        )
        XCTAssertEqual(
            specification.reusableChoiceValues.map(\.value),
            ["Hexagon", "Pandan", "Sage and ivory", "Botanical"]
        )
    }

    func testInvalidNumericValuesAreNotRetained() {
        let specification = OrderCakeSpecification(servings: -1, weightKilograms: -2)

        XCTAssertNil(specification.servings)
        XCTAssertNil(specification.weightKilograms)
    }
}
