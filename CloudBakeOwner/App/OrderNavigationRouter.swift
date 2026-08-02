import Foundation

enum NewOrderDesignReference: Equatable {
    case cakeDesign(id: String)
    case customerReference(photoId: String)
}

struct NewOrderRequest: Equatable {
    let customerId: String?
    let designReference: NewOrderDesignReference?
    let sourceOrderId: String?
}

@MainActor
final class OrderNavigationRouter: ObservableObject {
    @Published private(set) var pendingNewOrderRequest: NewOrderRequest?

    func beginNewOrder(customerId: String) {
        pendingNewOrderRequest = NewOrderRequest(
            customerId: customerId,
            designReference: nil,
            sourceOrderId: nil
        )
    }

    func beginNewOrder(designReference: NewOrderDesignReference) {
        pendingNewOrderRequest = NewOrderRequest(
            customerId: nil,
            designReference: designReference,
            sourceOrderId: nil
        )
    }

    func beginNewOrder(from sourceOrderId: String) {
        pendingNewOrderRequest = NewOrderRequest(
            customerId: nil,
            designReference: nil,
            sourceOrderId: sourceOrderId
        )
    }

    func clearPendingNewOrder() {
        pendingNewOrderRequest = nil
    }
}
