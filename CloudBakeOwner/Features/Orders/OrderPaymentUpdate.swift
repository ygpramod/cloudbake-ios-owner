import Foundation

struct OrderPaymentUpdateError: Error, Equatable {
    let message: String
}

enum OrderPaymentUpdate {
    static func markingPaid(_ order: Order, updatedAt: Date) -> Result<Order, OrderPaymentUpdateError> {
        guard let quotedPrice = order.quotedPrice else {
            return .failure(OrderPaymentUpdateError(message: "Add quoted price before recording payment."))
        }

        return .success(
            copy(
                order,
                depositPaid: quotedPrice,
                updatedAt: updatedAt
            )
        )
    }

    static func addingPayment(
        _ amountText: String,
        to order: Order,
        updatedAt: Date
    ) -> Result<Order, OrderPaymentUpdateError> {
        guard let quotedPrice = order.quotedPrice else {
            return .failure(OrderPaymentUpdateError(message: "Add quoted price before recording payment."))
        }

        let trimmed = TextInputFormatting.trimmed(amountText)
        guard let amount = Decimal(string: trimmed), amount > 0 else {
            return .failure(OrderPaymentUpdateError(message: "Payment amount must be greater than zero."))
        }

        let existingPaid = order.depositPaid ?? 0
        let updatedPaid = existingPaid + amount
        guard updatedPaid <= quotedPrice else {
            return .failure(OrderPaymentUpdateError(message: "Payment received cannot be more than balance due."))
        }

        return .success(
            copy(
                order,
                depositPaid: updatedPaid,
                updatedAt: updatedAt
            )
        )
    }

    private static func copy(
        _ order: Order,
        depositPaid: Decimal,
        updatedAt: Date
    ) -> Order {
        Order(
            id: order.id,
            customerId: order.customerId,
            cakeDesignId: order.cakeDesignId,
            recipeId: order.recipeId,
            recipeScaleMultiplier: order.recipeScaleMultiplier,
            title: order.title,
            customerName: order.customerName,
            status: order.status,
            dueAt: order.dueAt,
            fulfillmentType: order.fulfillmentType,
            deliveryAddress: order.deliveryAddress,
            cakeNotes: order.cakeNotes,
            quotedPrice: order.quotedPrice,
            depositPaid: depositPaid,
            paymentNotes: order.paymentNotes,
            createdAt: order.createdAt,
            updatedAt: updatedAt
        )
    }
}
