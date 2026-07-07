import SwiftUI

struct OrderDetailCustomerSection: View {
    let order: Order

    var body: some View {
        Section("Customer") {
            LabeledContent("Name") {
                Text(order.customerName)
                    .accessibilityIdentifier("orders.detail.customerName")
            }
            if order.customerId != nil {
                LabeledContent("Record", value: "Linked")
            }
        }
    }
}

struct OrderDetailCustomerContextSection: View {
    let customer: Customer

    var body: some View {
        if customer.hasOrderContext {
            Section("Customer Details") {
                if let allergies = customer.orderAllergies {
                    LabeledContent("Allergies") {
                        Text(allergies)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("orders.detail.customerAllergies")
                    }
                }

                if let dietaryRestrictions = customer.orderDietaryRestrictions {
                    LabeledContent("Dietary Restrictions") {
                        Text(dietaryRestrictions)
                            .accessibilityIdentifier("orders.detail.customerDietaryRestrictions")
                    }
                }

                if let likes = customer.orderLikes {
                    LabeledContent("Likes") {
                        Text(likes)
                            .accessibilityIdentifier("orders.detail.customerLikes")
                    }
                }

                if let dislikes = customer.orderDislikes {
                    LabeledContent("Dislikes") {
                        Text(dislikes)
                            .accessibilityIdentifier("orders.detail.customerDislikes")
                    }
                }

                if let notes = customer.orderNotes {
                    LabeledContent("Notes") {
                        Text(notes)
                            .accessibilityIdentifier("orders.detail.customerNotes")
                    }
                }
            }
        }
    }
}

private extension Customer {
    var hasOrderContext: Bool {
        [orderAllergies, orderDietaryRestrictions, orderLikes, orderDislikes, orderNotes]
            .contains { $0 != nil }
    }

    var orderAllergies: String? {
        meaningful(allergies)
    }

    var orderDietaryRestrictions: String? {
        meaningful(dietaryRestrictions)
    }

    var orderLikes: String? {
        meaningful(likes)
    }

    var orderDislikes: String? {
        meaningful(dislikes)
    }

    var orderNotes: String? {
        meaningful(notes)
    }

    private func meaningful(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
