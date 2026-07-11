import XCTest
@testable import CloudBakeOwner

@MainActor
final class CakeDesignListViewModelTests: XCTestCase {
    func testLoadFetchesDesigns() {
        let repository = FakeCakeDesignRepository()
        let design = makeDesign(id: "design-flowers", name: "Pink Flowers")
        let inspiration = makeDesign(
            id: "design-inspiration",
            name: "Saved Inspiration",
            sourceKind: .internetInspiration
        )
        repository.designs = [design, inspiration]
        let viewModel = CakeDesignListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.designs, [design])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testVisibleDesignsSearchesNameNotesAndPhotoReference() {
        let repository = FakeCakeDesignRepository()
        let flowers = makeDesign(
            id: "design-flowers",
            name: "Pink Flowers",
            notes: "Birthday buttercream",
            photoReference: "photos://flowers"
        )
        let ganache = makeDesign(
            id: "design-ganache",
            name: "Chocolate Ganache",
            notes: "Anniversary",
            photoReference: "photos://ganache"
        )
        repository.designs = [flowers, ganache]
        let viewModel = CakeDesignListViewModel(repository: repository)

        viewModel.load()
        viewModel.searchText = "buttercream"

        XCTAssertEqual(viewModel.visibleDesigns, [flowers])

        viewModel.searchText = "ganache"

        XCTAssertEqual(viewModel.visibleDesigns, [ganache])
    }

    func testAccessibilityLabelCallsOutMissingPhoto() {
        let viewModel = CakeDesignListViewModel(repository: FakeCakeDesignRepository())
        let design = makeDesign(
            id: "design-sketch",
            name: "Customer Sketch",
            photoReference: nil
        )

        XCTAssertEqual(
            viewModel.accessibilityLabel(for: design),
            "Customer Sketch, design without a linked photo"
        )
    }

    func testAccessibilityLabelCallsOutDeletedPhotoFile() {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let viewModel = CakeDesignListViewModel(
            repository: FakeCakeDesignRepository(),
            photoFileStore: LocalOrderPhotoFileStore(rootDirectoryURL: rootURL)
        )
        let design = makeDesign(
            id: "design-deleted-photo",
            name: "Deleted Photo",
            photoReference: "OrderPhotos/deleted.jpg"
        )

        XCTAssertEqual(
            viewModel.accessibilityLabel(for: design),
            "Deleted Photo, photo unavailable"
        )
    }

    func testPhotosAssetReferenceIsAvailableWithoutAnAppOwnedFile() {
        let photoLibrary = FakeDesignPhotoLibrary()
        photoLibrary.savedReference = "photos://library-asset"
        let viewModel = CakeDesignListViewModel(
            repository: FakeCakeDesignRepository(),
            designPhotoLibrary: photoLibrary
        )
        let design = makeDesign(
            id: "design-photos-asset",
            name: "Photos Cake",
            photoReference: photoLibrary.savedReference
        )

        XCTAssertEqual(
            viewModel.availablePhotoSource(for: design),
            .photosAsset("library-asset")
        )
        XCTAssertEqual(viewModel.accessibilityLabel(for: design), "Photos Cake, design photo")
    }

    func testLoadDerivesCustomerReferencesFromOrderPhotos() {
        let designRepository = FakeCakeDesignRepository()
        let orderRepository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-reference",
            title: "Blue wedding cake",
            dueAt: Date(timeIntervalSince1970: 1_800_090_000)
        )
        let reference = OrderPhoto(
            id: "photo-customer-reference",
            orderId: order.id,
            kind: .customerReference,
            localPhotoPath: "OrderPhotos/reference.jpg",
            caption: "Blue flowers",
            createdAt: Date(timeIntervalSince1970: 1_800_080_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_080_000)
        )
        let finalPhoto = OrderPhoto(
            id: "photo-final",
            orderId: order.id,
            kind: .finalCake,
            localPhotoPath: "OrderPhotos/final.jpg",
            caption: nil,
            createdAt: reference.createdAt,
            updatedAt: reference.updatedAt
        )
        orderRepository.orders = [order]
        orderRepository.orderPhotos = [finalPhoto, reference]
        let viewModel = CakeDesignListViewModel(
            repository: designRepository,
            customerReferenceRepository: orderRepository
        )

        viewModel.load()

        XCTAssertEqual(
            viewModel.customerReferences,
            [CustomerReferenceDesign(photo: reference, order: order)]
        )
        viewModel.searchText = "blue amy"
        XCTAssertEqual(viewModel.visibleCustomerReferences.map(\.id), [reference.id])
        viewModel.searchText = "unknown"
        XCTAssertTrue(viewModel.visibleCustomerReferences.isEmpty)
    }

    private func makeDesign(
        id: String,
        name: String,
        notes: String? = nil,
        photoReference: String? = "photos://asset",
        sourceKind: CakeDesignSourceKind = .ownerMade
    ) -> CakeDesign {
        let timestamp = Date(timeIntervalSince1970: 1_800_080_000)
        return CakeDesign(
            id: id,
            name: name,
            notes: notes,
            photoReference: photoReference,
            sourceKind: sourceKind,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}

private final class FakeCakeDesignRepository: CakeDesignRepository {
    var designs: [CakeDesign] = []

    func save(_ design: CakeDesign) throws {
        designs.removeAll { $0.id == design.id }
        designs.append(design)
    }

    func savePromotedDesign(
        _ design: CakeDesign,
        linking order: Order,
        photo: OrderPhoto,
        cleanupRelativePath: String?
    ) throws {
        try save(design)
    }

    func fetchPendingDesignPhotoCleanupPaths() throws -> [String] { [] }
    func deletePendingDesignPhotoCleanupPath(_ relativePath: String) throws {}

    func fetchCakeDesign(id: String) throws -> CakeDesign? {
        designs.first { $0.id == id }
    }

    func fetchCakeDesigns() throws -> [CakeDesign] {
        designs
    }
}
