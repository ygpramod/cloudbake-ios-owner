import XCTest
@testable import CloudBakeOwner

final class RecipeDraftValidationTests: XCTestCase {
    func testValidateTrimsNameAndOptionalNotes() {
        let result = RecipeDraftValidation.validate(
            RecipeDraftValidationInput(
                name: " Vanilla Sponge ",
                notes: " Book page 12 "
            )
        )

        XCTAssertEqual(
            try? result.get(),
            ValidatedRecipeDraft(
                name: "Vanilla Sponge",
                notes: "Book page 12"
            )
        )
    }

    func testValidateConvertsBlankNotesToNil() {
        let result = RecipeDraftValidation.validate(
            RecipeDraftValidationInput(
                name: "Vanilla Sponge",
                notes: " "
            )
        )

        XCTAssertEqual(
            try? result.get(),
            ValidatedRecipeDraft(
                name: "Vanilla Sponge",
                notes: nil
            )
        )
    }

    func testValidateRejectsBlankName() {
        let result = RecipeDraftValidation.validate(
            RecipeDraftValidationInput(
                name: " ",
                notes: "Book page 12"
            )
        )

        guard case .failure(let error) = result else {
            return XCTFail("Expected blank recipe name to fail validation.")
        }

        XCTAssertEqual(error.message, "Recipe name is required.")
    }
}
