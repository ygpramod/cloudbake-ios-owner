import Foundation

enum NewOrderDesignReference: Equatable {
    case cakeDesign(id: String)
    case customerReference(photoId: String)
}

struct NewOrderRequest: Equatable {
    let customerId: String?
    let designReference: NewOrderDesignReference?
}

@MainActor
final class OrderNavigationRouter: ObservableObject {
    @Published private(set) var pendingNewOrderRequest: NewOrderRequest?

    func beginNewOrder(customerId: String) {
        pendingNewOrderRequest = NewOrderRequest(
            customerId: customerId,
            designReference: nil
        )
    }

    func beginNewOrder(designReference: NewOrderDesignReference) {
        pendingNewOrderRequest = NewOrderRequest(
            customerId: nil,
            designReference: designReference
        )
    }

    func clearPendingNewOrder() {
        pendingNewOrderRequest = nil
    }
}
