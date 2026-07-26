import Foundation

struct OrderPaymentHistory: Equatable {
    let receipts: [PaymentReceipt]
    let legacyPaidAmount: Decimal
}

struct OrderPaymentWorkflowError: Error, Equatable {
    let ownerMessage: String
}

struct OrderPaymentWorkflow {
    private let repository: any OrderRepository & PaymentReceiptRepository
    private let dateProvider: () -> Date

    init(
        repository: any OrderRepository & PaymentReceiptRepository,
        dateProvider: @escaping () -> Date
    ) {
        self.repository = repository
        self.dateProvider = dateProvider
    }

    func markPaid(_ order: Order) -> Result<Order, OrderPaymentWorkflowError> {
        let now = dateProvider()
        do {
            _ = try repository.recordRemainingBalancePayment(
                orderId: order.id,
                receivedAt: now,
                note: nil,
                createdAt: now
            )
            return refreshedOrder(id: order.id)
        } catch {
            return .failure(paymentError(for: error))
        }
    }

    func record(
        order: Order,
        amountText: String,
        note: String
    ) -> Result<Order, OrderPaymentWorkflowError> {
        let trimmedAmount = TextInputFormatting.trimmed(amountText)
        guard let amount = Decimal(string: trimmedAmount), amount > 0 else {
            return .failure(
                OrderPaymentWorkflowError(
                    ownerMessage: "Payment amount must be greater than zero."
                )
            )
        }

        let now = dateProvider()
        do {
            _ = try repository.recordPayment(
                orderId: order.id,
                amount: amount,
                receivedAt: now,
                note: note,
                createdAt: now
            )
            return refreshedOrder(id: order.id)
        } catch {
            return .failure(paymentError(for: error))
        }
    }

    func void(
        _ receipt: PaymentReceipt,
        reason: String
    ) -> Result<Order, OrderPaymentWorkflowError> {
        let now = dateProvider()
        do {
            _ = try repository.voidPaymentReceipt(
                receiptId: receipt.id,
                reason: reason,
                voidedAt: now,
                createdAt: now
            )
            return refreshedOrder(id: receipt.orderId)
        } catch PaymentReceiptPersistenceError.alreadyVoided {
            return .failure(
                OrderPaymentWorkflowError(
                    ownerMessage: "This payment has already been voided."
                )
            )
        } catch PaymentReceiptPersistenceError.receiptNotFound {
            return .failure(
                OrderPaymentWorkflowError(
                    ownerMessage: "Payment could not be found."
                )
            )
        } catch {
            return .failure(
                OrderPaymentWorkflowError(
                    ownerMessage: "Payment correction could not be saved."
                )
            )
        }
    }

    func history(orderId: String) -> Result<OrderPaymentHistory, OrderPaymentWorkflowError> {
        do {
            return .success(
                OrderPaymentHistory(
                    receipts: try repository.fetchPaymentReceipts(orderId: orderId),
                    legacyPaidAmount: try repository.fetchLegacyPaidAmount(orderId: orderId)
                )
            )
        } catch {
            return .failure(
                OrderPaymentWorkflowError(
                    ownerMessage: "Payment history could not be loaded."
                )
            )
        }
    }

    private func refreshedOrder(id: String) -> Result<Order, OrderPaymentWorkflowError> {
        do {
            guard let order = try repository.fetchOrder(id: id) else {
                return .failure(
                    OrderPaymentWorkflowError(
                        ownerMessage: "Order could not be found."
                    )
                )
            }
            return .success(order)
        } catch {
            return .failure(
                OrderPaymentWorkflowError(
                    ownerMessage: "Payment was recorded, but the order could not be refreshed."
                )
            )
        }
    }

    private func paymentError(for error: Error) -> OrderPaymentWorkflowError {
        let message: String
        switch error as? PaymentReceiptPersistenceError {
        case .quotedPriceMissing:
            message = "Add quoted price before recording payment."
        case .invalidAmount:
            message = "Payment amount must be greater than zero."
        case .exceedsBalance:
            message = "Payment received cannot be more than balance due."
        case .orderNotFound:
            message = "Order could not be found."
        case .receiptNotFound, .alreadyVoided, .invalidStoredAmount,
             .directPaidTotalMutation, .none:
            message = "Payment could not be updated."
        }
        return OrderPaymentWorkflowError(ownerMessage: message)
    }
}
