import GRDB
import XCTest
@testable import CloudBakeOwner

final class GRDBOrderPhotoDesignRepositoryTests: XCTestCase {
    func testOrderPhotosAreFetchedByKindThenEntryOrderAndCanBeDeleted() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let order = Order(
            id: "order-photos",
            customerId: nil,
            cakeDesignId: nil,
            title: "Photo cake",
            customerName: "Amy",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_050_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let finalPhoto = OrderPhoto(
            id: "photo-final",
            orderId: order.id,
            kind: .finalCake,
            localPhotoPath: "OrderPhotos/order-photos/final.jpg",
            caption: nil,
            createdAt: timestamp.addingTimeInterval(20),
            updatedAt: timestamp.addingTimeInterval(20)
        )
        let firstReference = OrderPhoto(
            id: "photo-reference-1",
            orderId: order.id,
            kind: .customerReference,
            localPhotoPath: "OrderPhotos/order-photos/reference-1.jpg",
            caption: "First reference",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let secondReference = OrderPhoto(
            id: "photo-reference-2",
            orderId: order.id,
            kind: .customerReference,
            localPhotoPath: "OrderPhotos/order-photos/reference-2.jpg",
            caption: "Second reference",
            createdAt: timestamp.addingTimeInterval(10),
            updatedAt: timestamp.addingTimeInterval(10)
        )

        try repository.save(order)
        try repository.save(finalPhoto)
        try repository.save(secondReference)
        try repository.save(firstReference)

        XCTAssertEqual(
            try repository.fetchOrderPhotos(orderId: order.id),
            [firstReference, secondReference, finalPhoto]
        )
        XCTAssertEqual(
            try repository.fetchOrderPhotos(kind: .customerReference),
            [secondReference, firstReference]
        )

        try repository.deleteOrderPhoto(id: secondReference.id)
        XCTAssertEqual(
            try repository.fetchOrderPhotos(orderId: order.id),
            [firstReference, finalPhoto]
        )
        XCTAssertEqual(try repository.fetchOrderPhotos(kind: .customerReference), [firstReference])
        XCTAssertEqual(try repository.fetchOrder(id: order.id), order)

        try repository.deleteOrderPhoto(
            id: firstReference.id,
            cleanupRelativePath: firstReference.localPhotoPath
        )
        XCTAssertTrue(try repository.fetchOrderPhotos(kind: .customerReference).isEmpty)
        XCTAssertEqual(
            try repository.fetchPendingDesignPhotoCleanupPaths(),
            [firstReference.localPhotoPath]
        )
    }

    func testPromotedDesignTransactionRollsBackWhenPhotoUpdateFails() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let originalOrder = Order(
            id: "order-atomic-promotion",
            customerId: nil,
            cakeDesignId: nil,
            title: "Atomic promotion",
            customerName: "Amy",
            status: .confirmed,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let design = CakeDesign(
            id: "design-atomic-promotion",
            name: "Atomic design",
            notes: nil,
            photoReference: "photos://atomic-asset",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let linkedOrder = Order(
            id: originalOrder.id,
            customerId: nil,
            cakeDesignId: design.id,
            title: originalOrder.title,
            customerName: originalOrder.customerName,
            status: originalOrder.status,
            dueAt: originalOrder.dueAt,
            fulfillmentType: originalOrder.fulfillmentType,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let invalidPhoto = OrderPhoto(
            id: "photo-invalid-order",
            orderId: "missing-order",
            kind: .finalCake,
            localPhotoPath: design.photoReference ?? "",
            caption: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(originalOrder)

        XCTAssertThrowsError(
            try repository.savePromotedDesign(
                design,
                linking: linkedOrder,
                photo: invalidPhoto,
                cleanupRelativePath: "OrderPhotos/atomic.jpg"
            )
        )
        XCTAssertNil(try repository.fetchCakeDesign(id: design.id))
        XCTAssertNil(try repository.fetchOrder(id: originalOrder.id)?.cakeDesignId)
        XCTAssertTrue(try repository.fetchOrderPhotos(orderId: originalOrder.id).isEmpty)
        XCTAssertTrue(try repository.fetchPendingDesignPhotoCleanupPaths().isEmpty)
    }

    func testPromotedDesignTransactionPersistsAndClearsCleanupWork() throws {
        let database = try AppDatabase.makeInMemory()
        let repository = database.makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let originalOrder = Order(
            id: "order-cleanup-lifecycle",
            customerId: nil,
            cakeDesignId: nil,
            title: "Cleanup lifecycle",
            customerName: "Amy",
            status: .confirmed,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let originalPhoto = OrderPhoto(
            id: "photo-cleanup-lifecycle",
            orderId: originalOrder.id,
            kind: .finalCake,
            localPhotoPath: "OrderPhotos/cleanup-lifecycle.jpg",
            caption: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let design = CakeDesign(
            id: "design-cleanup-lifecycle",
            name: "Cleanup design",
            notes: nil,
            photoReference: "photos://cleanup-asset",
            sourceKind: .ownerMade,
            originatingOrderPhotoId: originalPhoto.id,
            originatingOrderId: originalOrder.id,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let linkedOrder = Order(
            id: originalOrder.id,
            customerId: nil,
            cakeDesignId: design.id,
            title: originalOrder.title,
            customerName: originalOrder.customerName,
            status: originalOrder.status,
            dueAt: originalOrder.dueAt,
            fulfillmentType: originalOrder.fulfillmentType,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let migratedPhoto = OrderPhoto(
            id: originalPhoto.id,
            orderId: originalPhoto.orderId,
            kind: originalPhoto.kind,
            localPhotoPath: design.photoReference ?? "",
            caption: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(originalOrder)
        try repository.save(originalPhoto)

        try repository.savePromotedDesign(
            design,
            linking: linkedOrder,
            photo: migratedPhoto,
            cleanupRelativePath: originalPhoto.localPhotoPath
        )

        let reloadedRepository = database.makeCoreDataRepository()
        XCTAssertEqual(try reloadedRepository.fetchCakeDesign(id: design.id), design)
        XCTAssertEqual(try reloadedRepository.fetchOrder(id: originalOrder.id)?.cakeDesignId, design.id)
        XCTAssertEqual(
            try reloadedRepository.fetchOrderPhotos(orderId: originalOrder.id),
            [migratedPhoto]
        )
        XCTAssertEqual(
            try reloadedRepository.fetchPendingDesignPhotoCleanupPaths(),
            [originalPhoto.localPhotoPath]
        )

        try reloadedRepository.deletePendingDesignPhotoCleanupPath(originalPhoto.localPhotoPath)
        XCTAssertTrue(try reloadedRepository.fetchPendingDesignPhotoCleanupPaths().isEmpty)
    }

    func testPromotedDesignRejectsASecondDesignForTheSameOriginPhoto() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let order = makeOrder(id: "order-unique-origin", dueAt: timestamp)
        let photo = OrderPhoto(
            id: "photo-unique-origin",
            orderId: order.id,
            kind: .finalCake,
            localPhotoPath: "photos://unique-origin",
            caption: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let firstDesign = CakeDesign(
            id: "design-first-origin",
            name: "First",
            notes: nil,
            photoReference: photo.localPhotoPath,
            sourceKind: .ownerMade,
            originatingOrderPhotoId: photo.id,
            originatingOrderId: order.id,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let secondDesign = CakeDesign(
            id: "design-second-origin",
            name: "Second",
            notes: nil,
            photoReference: photo.localPhotoPath,
            sourceKind: .ownerMade,
            originatingOrderPhotoId: photo.id,
            originatingOrderId: order.id,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(order)
        try repository.save(photo)
        try repository.savePromotedDesign(
            firstDesign,
            linking: makeOrder(id: order.id, cakeDesignId: firstDesign.id, dueAt: timestamp),
            photo: photo,
            cleanupRelativePath: nil
        )

        XCTAssertThrowsError(
            try repository.savePromotedDesign(
                secondDesign,
                linking: makeOrder(id: order.id, cakeDesignId: secondDesign.id, dueAt: timestamp),
                photo: photo,
                cleanupRelativePath: nil
            )
        ) { error in
            XCTAssertEqual(
                error as? CakeDesignPromotionError,
                .originatingPhotoAlreadyPromoted
            )
        }
        XCTAssertEqual(
            try repository.fetchCakeDesign(originatingOrderPhotoId: photo.id)?.id,
            firstDesign.id
        )
        XCTAssertNil(try repository.fetchCakeDesign(id: secondDesign.id))
        XCTAssertEqual(try repository.fetchOrder(id: order.id)?.cakeDesignId, firstDesign.id)
    }

    func testDeletingCakeDesignUnlinksOrderWithoutDeletingIt() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let design = makeCakeDesign(id: "design-delete", name: "Delete")
        let order = makeOrder(
            id: "order-design-delete",
            cakeDesignId: design.id,
            dueAt: Date(timeIntervalSince1970: 1_800_100_000)
        )
        try repository.save(design)
        try repository.save(order)

        try repository.deleteCakeDesign(id: design.id)

        XCTAssertNil(try repository.fetchCakeDesign(id: design.id))
        XCTAssertNil(try repository.fetchOrder(id: order.id)?.cakeDesignId)
    }

    func testOrderPersistsCustomerReferencePhotoLinkAndClearsItWhenPhotoIsRemoved() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_100_000)
        let sourceOrder = makeOrder(id: "order-reference-source", dueAt: timestamp)
        let referencePhoto = OrderPhoto(
            id: "photo-order-reference",
            orderId: sourceOrder.id,
            kind: .customerReference,
            localPhotoPath: "photos://order-reference",
            caption: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let reusedOrder = Order(
            id: "order-reference-reuse",
            customerId: nil,
            cakeDesignId: nil,
            customerReferencePhotoId: referencePhoto.id,
            title: "Reused reference",
            customerName: "Amy",
            status: .draft,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(sourceOrder)
        try repository.save(referencePhoto)
        try repository.save(reusedOrder)

        XCTAssertEqual(
            try repository.fetchOrder(id: reusedOrder.id)?.customerReferencePhotoId,
            referencePhoto.id
        )

        try repository.deleteOrderPhoto(id: referencePhoto.id)

        XCTAssertNil(
            try repository.fetchOrder(id: reusedOrder.id)?.customerReferencePhotoId
        )
        XCTAssertNotNil(try repository.fetchOrder(id: reusedOrder.id))
    }

    func testOrderRejectsMissingOrFinalCakePhotoAsCustomerReference() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_100_000)
        let sourceOrder = makeOrder(id: "order-reference-validation", dueAt: timestamp)
        let finalPhoto = OrderPhoto(
            id: "photo-final-not-reference",
            orderId: sourceOrder.id,
            kind: .finalCake,
            localPhotoPath: "photos://final-not-reference",
            caption: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(sourceOrder)
        try repository.save(finalPhoto)

        for photoId in [finalPhoto.id, "photo-missing"] {
            let invalidOrder = Order(
                id: "order-invalid-\(photoId)",
                customerId: nil,
                cakeDesignId: nil,
                customerReferencePhotoId: photoId,
                title: "Invalid reference",
                customerName: "Amy",
                status: .draft,
                dueAt: timestamp,
                fulfillmentType: .pickup,
                deliveryAddress: nil,
                cakeNotes: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )

            XCTAssertThrowsError(try repository.save(invalidOrder)) { error in
                XCTAssertEqual(
                    error as? OrderPersistenceError,
                    .invalidCustomerReferencePhoto
                )
            }
            XCTAssertNil(try repository.fetchOrder(id: invalidOrder.id))
        }

        let customerReference = OrderPhoto(
            id: "photo-valid-reference",
            orderId: sourceOrder.id,
            kind: .customerReference,
            localPhotoPath: "photos://valid-reference",
            caption: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let design = makeCakeDesign(id: "design-ambiguous-reference", name: "Ambiguous")
        try repository.save(customerReference)
        try repository.save(design)
        let ambiguousOrder = Order(
            id: "order-ambiguous-reference",
            customerId: nil,
            cakeDesignId: design.id,
            customerReferencePhotoId: customerReference.id,
            title: "Ambiguous reference",
            customerName: "Amy",
            status: .draft,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        XCTAssertThrowsError(try repository.save(ambiguousOrder)) { error in
            XCTAssertEqual(error as? OrderPersistenceError, .multipleDesignReferences)
        }
        XCTAssertNil(try repository.fetchOrder(id: ambiguousOrder.id))
    }

}
