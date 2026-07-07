import SwiftUI

struct OrderDetailPaymentSection: View {
    let order: Order
    let onChangePaymentStatus: () -> Void

    var body: some View {
        Section("Pricing And Payment") {
            LabeledContent("Status") {
                HStack(spacing: 8) {
                    Text(order.paymentStatus)
                        .accessibilityIdentifier("orders.detail.paymentStatus")
                    Button {
                        onChangePaymentStatus()
                    } label: {
                        Image(systemName: "banknote")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Change Payment Status")
                    .accessibilityIdentifier("orders.detail.paymentStatusMenu")
                }
            }

            if let quotedPrice = order.quotedPrice {
                LabeledContent("Quoted Price") {
                    Text(formattedMoney(quotedPrice))
                        .accessibilityIdentifier("orders.detail.quotedPrice")
                }
            }

            if let depositPaid = order.depositPaid {
                LabeledContent("Deposit Paid") {
                    Text(formattedMoney(depositPaid))
                        .accessibilityIdentifier("orders.detail.depositPaid")
                }
            }

            if let balanceDue = order.balanceDue {
                LabeledContent("Balance Due") {
                    Text(formattedMoney(balanceDue))
                        .accessibilityIdentifier("orders.detail.balanceDue")
                }
            }

            if let paymentNotes = order.paymentNotes {
                LabeledContent("Notes") {
                    Text(paymentNotes)
                        .accessibilityIdentifier("orders.detail.paymentNotes")
                }
            }
        }
    }

    private func formattedMoney(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }
}
