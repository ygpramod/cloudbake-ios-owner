import XCTest
@testable import CloudBakeOwner

@MainActor
final class OrderPhotoViewModelTests: XCTestCase {
    func testBeginViewingOrderLoadsOrderPhotosGroupedByKind() {
        let repository = FakeOrderRepository()
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let referencePhoto = makeOrderPhoto(
            id: "photo-reference",
            orderId: order.id,
            kind: .customerReference
        )
        let finalPhoto = makeOrderPhoto(
            id: "photo-final",
            orderId: order.id,
            kind: .finalCake
        )
        repository.orderPhotos = [finalPhoto, referencePhoto]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(viewModel.selectedOrderPhotos, [referencePhoto, finalPhoto])
        XCTAssertEqual(viewModel.selectedCustomerReferencePhotos, [referencePhoto])
        XCTAssertEqual(viewModel.selectedFinalCakePhotos, [finalPhoto])
    }

    func testAddOrderPhotoStoresImageAndPersistsPhotoMetadata() {
        let repository = FakeOrderRepository()
        let photoFileStore = FakeOrderPhotoFileStore()
        let now = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let imageData = Data([0xCA, 0xFE])
        let viewModel = OrderListViewModel(
            repository: repository,
            photoFileStore: photoFileStore,
            idGenerator: { "photo-reference" },
            dateProvider: { now }
        )

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.addOrderPhoto(
            kind: .customerReference,
            imageData: imageData,
            caption: " Customer sketch "
        ))
        XCTAssertEqual(
            photoFileStore.savedPhotos,
            [
                FakeOrderPhotoFileStore.SavedPhoto(
                    data: imageData,
                    orderId: order.id,
                    photoId: "photo-reference"
                )
            ]
        )
        XCTAssertEqual(
            repository.orderPhotos,
            [
                OrderPhoto(
                    id: "photo-reference",
                    orderId: order.id,
                    kind: .customerReference,
                    localPhotoPath: "OrderPhotos/order-vanilla/photo-reference.jpg",
                    caption: "Customer sketch",
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
        XCTAssertEqual(viewModel.selectedCustomerReferencePhotos, repository.orderPhotos)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddOrderPhotoRejectsEmptyImageData() {
        let repository = FakeOrderRepository()
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertFalse(viewModel.addOrderPhoto(kind: .finalCake, imageData: Data()))
        XCTAssertTrue(repository.orderPhotos.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "Order photo is required.")
    }

    func testUpdateOrderPhotoCaptionPersistsTrimmedCaption() {
        let repository = FakeOrderRepository()
        let now = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let photo = makeOrderPhoto(
            id: "photo-reference",
            orderId: order.id,
            kind: .customerReference,
            caption: "Customer sketch"
        )
        repository.orderPhotos = [photo]
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { now }
        )

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.updateOrderPhotoCaption(photo, caption: "  Lace and pearl reference  "))
        XCTAssertEqual(repository.orderPhotos.first?.caption, "Lace and pearl reference")
        XCTAssertEqual(repository.orderPhotos.first?.createdAt, photo.createdAt)
        XCTAssertEqual(repository.orderPhotos.first?.updatedAt, now)
        XCTAssertEqual(viewModel.selectedOrderPhotos.first?.caption, "Lace and pearl reference")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testPromoteFinalCakePhotoToDesignSavesDesignAndLinksOrder() async {
        let repository = FakeOrderRepository()
        let photoFileStore = FakeOrderPhotoFileStore()
        let designPhotoLibrary = FakeDesignPhotoLibrary()
        let now = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        repository.orders = [order]
        let photo = makeOrderPhoto(
            id: "photo-final",
            orderId: order.id,
            kind: .finalCake,
            caption: "Finished cake"
        )
        let viewModel = OrderListViewModel(
            repository: repository,
            photoFileStore: photoFileStore,
            designPhotoLibrary: designPhotoLibrary,
            idGenerator: { "design-finished-cake" },
            dateProvider: { now }
        )

        viewModel.beginViewingOrder(order)

        let didPromote = await viewModel.promoteFinalCakePhotoToDesign(
            photo,
            name: "  Pink Pearl Cake  ",
            notes: "  Use taller border next time  "
        )
        XCTAssertTrue(didPromote)
        XCTAssertEqual(repository.cakeDesigns.count, 1)
        XCTAssertEqual(repository.cakeDesigns.first?.id, "design-finished-cake")
        XCTAssertEqual(repository.cakeDesigns.first?.name, "Pink Pearl Cake")
        XCTAssertEqual(repository.cakeDesigns.first?.notes, "Use taller border next time")
        XCTAssertEqual(repository.cakeDesigns.first?.photoReference, designPhotoLibrary.savedReference)
        XCTAssertEqual(
            designPhotoLibrary.savedFileURLs,
            [photoFileStore.fileURL(for: photo.localPhotoPath)]
        )
        XCTAssertEqual(repository.cakeDesigns.first?.sourceKind, .ownerMade)
        XCTAssertEqual(repository.cakeDesigns.first?.originatingOrderPhotoId, photo.id)
        XCTAssertEqual(repository.cakeDesigns.first?.originatingOrderId, order.id)
        XCTAssertEqual(repository.cakeDesigns.first?.createdAt, now)
        XCTAssertEqual(repository.orders.first?.cakeDesignId, "design-finished-cake")
        XCTAssertEqual(repository.orders.first?.updatedAt, now)
        XCTAssertEqual(viewModel.selectedOrder?.cakeDesignId, "design-finished-cake")
        XCTAssertEqual(viewModel.selectedOrderCakeDesign?.name, "Pink Pearl Cake")
        XCTAssertEqual(viewModel.cakeDesigns.first?.id, "design-finished-cake")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testPromoteReferencePhotoToDesignIsRejected() async {
        let repository = FakeOrderRepository()
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let photo = makeOrderPhoto(id: "photo-reference", orderId: order.id, kind: .customerReference)
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        let didPromote = await viewModel.promoteFinalCakePhotoToDesign(
            photo,
            name: "Reference",
            notes: ""
        )
        XCTAssertFalse(didPromote)
        XCTAssertTrue(repository.cakeDesigns.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "Only final cake photos can be saved as designs.")
    }

    func testPromoteFinalCakePhotoDoesNotPersistWhenPhotosSaveFails() async {
        let repository = FakeOrderRepository()
        let designPhotoLibrary = FakeDesignPhotoLibrary()
        designPhotoLibrary.saveError = DesignPhotoLibraryError.accessDenied
        let order = makeOrder(id: "order-denied", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        repository.orders = [order]
        let photo = makeOrderPhoto(id: "photo-final", orderId: order.id, kind: .finalCake)
        let viewModel = OrderListViewModel(
            repository: repository,
            designPhotoLibrary: designPhotoLibrary
        )
        viewModel.beginViewingOrder(order)

        let didPromote = await viewModel.promoteFinalCakePhotoToDesign(
            photo,
            name: "Denied Design",
            notes: ""
        )

        XCTAssertFalse(didPromote)
        XCTAssertTrue(repository.cakeDesigns.isEmpty)
        XCTAssertNil(repository.orders.first?.cakeDesignId)
        XCTAssertEqual(viewModel.errorMessage, "Design photo could not be saved to Photos.")
    }

    func testDeleteOrderPhotoRemovesMetadataAndStoredFile() {
        let repository = FakeOrderRepository()
        let photoFileStore = FakeOrderPhotoFileStore()
        let order = makeOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let firstPhoto = makeOrderPhoto(id: "photo-first", orderId: order.id, kind: .customerReference)
        let secondPhoto = makeOrderPhoto(id: "photo-second", orderId: order.id, kind: .finalCake)
        repository.orderPhotos = [firstPhoto, secondPhoto]
        let viewModel = OrderListViewModel(repository: repository, photoFileStore: photoFileStore)

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.deleteOrderPhoto(firstPhoto))
        XCTAssertEqual(repository.orderPhotos, [secondPhoto])
        XCTAssertEqual(viewModel.selectedOrderPhotos, [secondPhoto])
        XCTAssertEqual(photoFileStore.deletedRelativePaths, [firstPhoto.localPhotoPath])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLocalOrderPhotoFileStoreWritesAndDeletesPhotoData() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloudbake-order-photo-store-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        let store = LocalOrderPhotoFileStore(rootDirectoryURL: rootURL)
        let imageData = Data([0x01, 0x02, 0x03])

        let relativePath = try store.saveOrderPhoto(
            data: imageData,
            orderId: "order rose/garden",
            photoId: "photo reference"
        )

        XCTAssertEqual(relativePath, "OrderPhotos/order-rose-garden/photo-reference.jpg")
        XCTAssertEqual(try Data(contentsOf: store.fileURL(for: relativePath)), imageData)

        try store.deleteOrderPhoto(relativePath: relativePath)

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL(for: relativePath).path))
    }
}
