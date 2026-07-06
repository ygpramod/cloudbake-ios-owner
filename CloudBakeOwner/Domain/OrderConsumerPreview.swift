import Foundation

enum ConsumerOrderPreviewStatus: String, Equatable, CaseIterable {
    case requested
    case accepted
    case inProgress
    case ready
    case fulfilled
    case cancelled
}

struct ConsumerOrderPreview: Equatable {
    let orderId: String
    let cakeName: String
    let status: ConsumerOrderPreviewStatus
    let dueAt: Date
    let fulfillmentType: OrderFulfillmentType
    let designName: String?
    let designPhotoReference: String?

    init(
        orderId: String,
        cakeName: String,
        status: ConsumerOrderPreviewStatus,
        dueAt: Date,
        fulfillmentType: OrderFulfillmentType,
        designName: String?,
        designPhotoReference: String?
    ) {
        self.orderId = orderId
        self.cakeName = cakeName
        self.status = status
        self.dueAt = dueAt
        self.fulfillmentType = fulfillmentType
        self.designName = designName
        self.designPhotoReference = designPhotoReference
    }

    init(order: Order, cakeDesign: CakeDesign? = nil) {
        self.orderId = order.id
        cakeName = order.title
        status = ConsumerOrderPreviewStatus(orderStatus: order.status)
        dueAt = order.dueAt
        fulfillmentType = order.fulfillmentType
        designName = cakeDesign?.name
        designPhotoReference = cakeDesign?.photoReference
    }
}

private extension ConsumerOrderPreviewStatus {
    init(orderStatus: OrderStatus) {
        switch orderStatus {
        case .draft:
            self = .requested
        case .confirmed:
            self = .accepted
        case .inProgress:
            self = .inProgress
        case .ready:
            self = .ready
        case .completed:
            self = .fulfilled
        case .cancelled:
            self = .cancelled
        }
    }
}
