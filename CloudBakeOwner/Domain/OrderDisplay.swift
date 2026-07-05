import Foundation

extension OrderStatus {
    var displayName: String {
        switch self {
        case .draft:
            return "Draft"
        case .confirmed:
            return "Confirmed"
        case .inProgress:
            return "In Progress"
        case .ready:
            return "Ready"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }
}

extension OrderFulfillmentType {
    var displayName: String {
        switch self {
        case .pickup:
            return "Pickup"
        case .delivery:
            return "Delivery"
        }
    }
}
