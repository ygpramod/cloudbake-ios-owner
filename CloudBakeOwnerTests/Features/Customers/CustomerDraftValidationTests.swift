import XCTest
@testable import CloudBakeOwner

final class CustomerDraftValidationTests: XCTestCase {
    func testValidateTrimsRequiredFields() throws {
        let draft = try CustomerDraftValidation.validate(
            CustomerDraftValidationInput(
                name: " Amy ",
                phone: " 5550101 "
            )
        ).get()

        XCTAssertEqual(
            draft,
            ValidatedCustomerDraft(
                name: "Amy",
                phone: "5550101"
            )
        )
    }

    func testValidateRejectsMissingRequiredFields() {
        XCTAssertEqual(
            validationMessage(name: " ", phone: "5550101"),
            "Customer name is required."
        )
        XCTAssertEqual(
            validationMessage(name: "Amy", phone: " "),
            "Customer phone is required."
        )
    }

    private func validationMessage(name: String, phone: String) -> String? {
        let result = CustomerDraftValidation.validate(
            CustomerDraftValidationInput(
                name: name,
                phone: phone
            )
        )

        guard case .failure(let error) = result else {
            return nil
        }

        return error.message
    }
}
