import Foundation

struct ConsumerDesignPreview: Equatable {
    let designId: String
    let name: String
    let photoReference: String
    let tags: [String]

    init(designId: String, name: String, photoReference: String, tags: [String]) {
        self.designId = designId
        self.name = name
        self.photoReference = photoReference
        self.tags = tags
    }

    init?(design: CakeDesign) {
        guard design.sourceKind == .ownerMade,
              design.isPortfolioPublished,
              let photoReference = design.photoReference else {
            return nil
        }
        self.init(
            designId: design.id,
            name: design.name,
            photoReference: photoReference,
            tags: design.tags
        )
    }
}

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
        let safeDesign = cakeDesign.flatMap(ConsumerDesignPreview.init)
        self.orderId = order.id
        cakeName = order.title
        status = ConsumerOrderPreviewStatus(orderStatus: order.status)
        dueAt = order.dueAt
        fulfillmentType = order.fulfillmentType
        designName = safeDesign?.name
        designPhotoReference = safeDesign?.photoReference
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
