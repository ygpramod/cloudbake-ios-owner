import XCTest
@testable import CloudBakeOwner

final class OrderDraftValidationTests: XCTestCase {
    func testValidateTrimsRequiredFieldsAndParsesAmounts() {
        let result = OrderDraftValidation.validate(
            OrderDraftValidationInput(
                title: " Vanilla Birthday ",
                customerName: " Amy ",
                recipeScaleMultiplier: "1.5",
                quotedPrice: "125.50",
                depositPaid: "25.50"
            )
        )

        XCTAssertEqual(
            try? result.get(),
            ValidatedOrderDraft(
                title: "Vanilla Birthday",
                customerName: "Amy",
                recipeScaleMultiplier: Decimal(string: "1.5")!,
                quotedPrice: Decimal(string: "125.50"),
                depositPaid: Decimal(string: "25.50")
            )
        )
    }

    func testValidateAllowsMissingOptionalAmounts() {
        let result = OrderDraftValidation.validate(
            OrderDraftValidationInput(
                title: "Vanilla Birthday",
                customerName: "Amy",
                recipeScaleMultiplier: "1",
                quotedPrice: "",
                depositPaid: " "
            )
        )

        XCTAssertEqual(
            try? result.get(),
            ValidatedOrderDraft(
                title: "Vanilla Birthday",
                customerName: "Amy",
                recipeScaleMultiplier: Decimal(1),
                quotedPrice: nil,
                depositPaid: nil
            )
        )
    }

    func testValidateRejectsMissingRequiredFields() {
        XCTAssertEqual(
            validationMessage(title: "", customerName: "Amy"),
            "Order title is required."
        )
        XCTAssertEqual(
            validationMessage(title: "Vanilla Birthday", customerName: ""),
            "Customer name is required."
        )
    }

    func testValidateRejectsInvalidAmounts() {
        XCTAssertEqual(
            validationMessage(quotedPrice: "-1"),
            "Quoted price must be a positive number."
        )
        XCTAssertEqual(
            validationMessage(depositPaid: "abc"),
            "Deposit paid must be a positive number."
        )
        XCTAssertEqual(
            validationMessage(recipeScaleMultiplier: "0"),
            "Recipe multiplier must be greater than zero."
        )
    }

    func testValidateRejectsDepositGreaterThanQuotedPrice() {
        XCTAssertEqual(
            validationMessage(quotedPrice: "100", depositPaid: "101"),
            "Deposit paid cannot be more than quoted price."
        )
    }

    private func validationMessage(
        title: String = "Vanilla Birthday",
        customerName: String = "Amy",
        recipeScaleMultiplier: String = "1",
        quotedPrice: String = "",
        depositPaid: String = ""
    ) -> String? {
        let result = OrderDraftValidation.validate(
            OrderDraftValidationInput(
                title: title,
                customerName: customerName,
                recipeScaleMultiplier: recipeScaleMultiplier,
                quotedPrice: quotedPrice,
                depositPaid: depositPaid
            )
        )

        guard case .failure(let error) = result else {
            return nil
        }

        return error.message
    }
}
