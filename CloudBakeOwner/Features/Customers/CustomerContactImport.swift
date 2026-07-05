import Contacts
import Foundation

struct CustomerContactDraft: Equatable {
    let name: String
    let phone: String
    let email: String
    let address: String
    let importantDateLabel: String
    let importantDate: Date?
}

struct CustomerContactDraftMapper {
    private let calendar: Calendar
    private let fallbackYear: Int

    init(calendar: Calendar = .current, fallbackYear: Int? = nil) {
        self.calendar = calendar
        self.fallbackYear = fallbackYear ?? calendar.component(.year, from: Date())
    }

    func draft(from contact: CNContact) -> CustomerContactDraft {
        let name = CNContactFormatter.string(from: contact, style: .fullName)
            ?? [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
        let email = contact.emailAddresses.first.map { String($0.value) } ?? ""
        let addressFormatter = CNPostalAddressFormatter()
        let address = contact.postalAddresses.first.map { addressFormatter.string(from: $0.value) } ?? ""
        let importantDate = firstImportantDate(from: contact)

        return CustomerContactDraft(
            name: name,
            phone: phone,
            email: email,
            address: address,
            importantDateLabel: importantDate?.label ?? "",
            importantDate: importantDate?.date
        )
    }

    private func firstImportantDate(from contact: CNContact) -> (label: String, date: Date)? {
        if let birthday = date(from: contact.birthday) {
            return ("Birthday", birthday)
        }

        for contactDate in contact.dates {
            if let date = date(from: contactDate.value as DateComponents) {
                let label = contactDate.label.map(CNLabeledValue<NSDateComponents>.localizedString(forLabel:)) ?? "Important Date"
                return (label, date)
            }
        }

        return nil
    }

    private func date(from components: DateComponents?) -> Date? {
        guard let components else {
            return nil
        }

        var resolved = DateComponents()
        resolved.calendar = calendar
        resolved.year = components.year ?? fallbackYear
        resolved.month = components.month
        resolved.day = components.day
        return calendar.date(from: resolved)
    }
}
