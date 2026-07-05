import Contacts
import XCTest
@testable import CloudBakeOwner

final class CustomerContactImportTests: XCTestCase {
    func testDraftMapsPrimaryContactFieldsAndBirthday() {
        let contact = CNMutableContact()
        contact.givenName = "Amy"
        contact.familyName = "Baker"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "5550101"))
        ]
        contact.emailAddresses = [
            CNLabeledValue(label: CNLabelHome, value: "amy@example.com" as NSString)
        ]
        let address = CNMutablePostalAddress()
        address.street = "10 Cake Street"
        address.city = "Singapore"
        contact.postalAddresses = [
            CNLabeledValue(label: CNLabelHome, value: address)
        ]
        contact.birthday = DateComponents(year: 1990, month: 8, day: 15)
        let mapper = CustomerContactDraftMapper(
            calendar: Calendar(identifier: .gregorian),
            fallbackYear: 2026
        )

        let draft = mapper.draft(from: contact)

        XCTAssertEqual(draft.name, "Amy Baker")
        XCTAssertEqual(draft.phone, "5550101")
        XCTAssertEqual(draft.email, "amy@example.com")
        XCTAssertTrue(draft.address.contains("10 Cake Street"))
        XCTAssertTrue(draft.address.contains("Singapore"))
        XCTAssertEqual(draft.importantDateLabel, "Birthday")
        XCTAssertEqual(
            Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: try XCTUnwrap(draft.importantDate)),
            DateComponents(year: 1990, month: 8, day: 15)
        )
    }

    func testDraftUsesFallbackYearForBirthdayWithoutYear() {
        let contact = CNMutableContact()
        contact.givenName = "Zoe"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "5550102"))
        ]
        contact.birthday = DateComponents(month: 9, day: 30)
        let calendar = Calendar(identifier: .gregorian)

        let draft = CustomerContactDraftMapper(calendar: calendar, fallbackYear: 2026).draft(from: contact)

        XCTAssertEqual(draft.importantDateLabel, "Birthday")
        XCTAssertEqual(
            calendar.dateComponents([.year, .month, .day], from: try XCTUnwrap(draft.importantDate)),
            DateComponents(year: 2026, month: 9, day: 30)
        )
    }
}
