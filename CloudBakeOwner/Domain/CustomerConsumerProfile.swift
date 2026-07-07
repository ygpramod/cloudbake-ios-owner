import Foundation

struct ConsumerCustomerProfile: Equatable {
    let customerId: String
    let displayName: String
    let contactPhone: String
    let contactEmail: String?

    init(customerId: String, displayName: String, contactPhone: String, contactEmail: String?) {
        self.customerId = customerId
        self.displayName = displayName
        self.contactPhone = contactPhone
        self.contactEmail = contactEmail
    }

    init(customer: Customer) {
        customerId = customer.id
        displayName = customer.name
        contactPhone = customer.phone
        contactEmail = customer.email
    }
}
