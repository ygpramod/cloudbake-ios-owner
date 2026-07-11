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

    func testVisibleDesignsUsesAndSearchAcrossNameAndNotes() {
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
        viewModel.searchText = "pink,buttercream"

        XCTAssertEqual(viewModel.visibleDesigns, [flowers])

        viewModel.searchText = "ganache"

        XCTAssertEqual(viewModel.visibleDesigns, [ganache])

        viewModel.searchText = "pink anniversary"

        XCTAssertTrue(viewModel.visibleDesigns.isEmpty)

        viewModel.searchText = " , / "

        XCTAssertEqual(viewModel.visibleDesigns, [flowers, ganache])
        XCTAssertFalse(viewModel.hasEffectiveSearchQuery)
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

    func testAccessibilityLabelIncludesFavoriteState() {
        let viewModel = CakeDesignListViewModel(repository: FakeCakeDesignRepository())
        let design = makeDesign(
            id: "design-favorite",
            name: "Favorite Cake",
            photoReference: nil,
            isFavorite: true
        )

        XCTAssertEqual(
            viewModel.accessibilityLabel(for: design),
            "Favorite Cake, design without a linked photo, favorite"
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

    func testSaveInternetInspirationPersistsPrivateSourceMetadata() {
        let repository = FakeCakeDesignRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_100_000)
        let viewModel = CakeDesignListViewModel(
            repository: repository,
            idGenerator: { "design-internet" },
            dateProvider: { timestamp }
        )

        XCTAssertTrue(
            viewModel.saveInternetInspiration(
                photoReference: "photos://internet-asset",
                name: "  Blue Lambeth  ",
                sourceName: "  Cake Artist  ",
                sourceURL: " https://example.com/cake ",
                notes: "  Piping reference  "
            )
        )

        XCTAssertEqual(
            repository.designs,
            [
                CakeDesign(
                    id: "design-internet",
                    name: "Blue Lambeth",
                    notes: "Piping reference",
                    photoReference: "photos://internet-asset",
                    sourceKind: .internetInspiration,
                    sourceName: "Cake Artist",
                    sourceURL: "https://example.com/cake",
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            ]
        )
        XCTAssertEqual(viewModel.internetInspirations, repository.designs)
        viewModel.searchText = "artist piping"
        XCTAssertEqual(viewModel.visibleInternetInspirations.map(\.id), ["design-internet"])
    }

    func testSaveInternetInspirationRejectsInvalidSourceURL() {
        let repository = FakeCakeDesignRepository()
        let viewModel = CakeDesignListViewModel(repository: repository)

        XCTAssertFalse(
            viewModel.saveInternetInspiration(
                photoReference: "photos://internet-asset",
                name: "Inspiration",
                sourceName: "",
                sourceURL: "example.com/no-scheme",
                notes: ""
            )
        )
        XCTAssertTrue(repository.designs.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "Source URL must be a valid http or https address.")
    }

    func testInternetInspirationReusesPickerIdentifierWithoutSavingACopy() async throws {
        let photoLibrary = FakeDesignPhotoLibrary()
        let viewModel = CakeDesignListViewModel(
            repository: FakeCakeDesignRepository(),
            designPhotoLibrary: photoLibrary
        )

        let reference = try await viewModel.internetInspirationPhotoReference(
            itemIdentifier: "picker-selected-asset",
            fallbackData: Data([0xCA, 0xFE])
        )

        XCTAssertEqual(reference, "photos://picker-selected-asset")
        XCTAssertTrue(photoLibrary.savedData.isEmpty)
    }

    func testInternetInspirationSavesFallbackDataWhenPickerHasNoIdentifier() async throws {
        let photoLibrary = FakeDesignPhotoLibrary()
        let viewModel = CakeDesignListViewModel(
            repository: FakeCakeDesignRepository(),
            designPhotoLibrary: photoLibrary
        )
        let data = Data([0xCA, 0xFE])

        let reference = try await viewModel.internetInspirationPhotoReference(
            itemIdentifier: nil,
            fallbackData: data
        )

        XCTAssertEqual(reference, photoLibrary.savedReference)
        XCTAssertEqual(photoLibrary.savedData, [data])
    }

    func testTagsFiltersAndFavoritesApplyAcrossSources() {
        let designRepository = FakeCakeDesignRepository()
        let ownerDesign = makeDesign(
            id: "design-floral",
            name: "Floral Cake",
            sourceKind: .ownerMade,
            tags: ["Floral"],
            isFavorite: true
        )
        let internetDesign = makeDesign(
            id: "design-chocolate",
            name: "Chocolate Cake",
            sourceKind: .internetInspiration,
            tags: ["Chocolate"]
        )
        designRepository.designs = [ownerDesign, internetDesign]
        let orderRepository = FakeOrderRepository()
        let order = makeOrder(id: "order-wedding", dueAt: Date(timeIntervalSince1970: 1_800_100_000))
        orderRepository.orders = [order]
        orderRepository.orderPhotos = [
            OrderPhoto(
                id: "photo-wedding",
                orderId: order.id,
                kind: .customerReference,
                localPhotoPath: "photos://wedding",
                caption: "Wedding reference",
                tags: ["Wedding"],
                createdAt: order.createdAt,
                updatedAt: order.updatedAt
            )
        ]
        let viewModel = CakeDesignListViewModel(
            repository: designRepository,
            customerReferenceRepository: orderRepository
        )
        viewModel.load()

        XCTAssertEqual(
            viewModel.availableFilters,
            [.all, .favorites, .tag("Wedding"), .tag("Chocolate"), .tag("Floral")]
        )
        viewModel.selectFilter(.favorites)
        XCTAssertEqual(viewModel.visibleDesigns.map(\.id), [ownerDesign.id])
        XCTAssertTrue(viewModel.visibleInternetInspirations.isEmpty)
        XCTAssertTrue(viewModel.visibleCustomerReferences.isEmpty)

        viewModel.selectFilter(.tag("Wedding"))
        XCTAssertEqual(viewModel.visibleCustomerReferences.map(\.id), ["photo-wedding"])
        XCTAssertTrue(viewModel.visibleDesigns.isEmpty)

        viewModel.selectFilter(.all)
        viewModel.searchText = "floral"
        XCTAssertEqual(viewModel.visibleDesigns.map(\.id), [ownerDesign.id])
    }

    func testUpdatingTagsNormalizesDuplicatesAndFavoritePersists() {
        let repository = FakeCakeDesignRepository()
        let design = makeDesign(id: "design-metadata", name: "Metadata")
        repository.designs = [design]
        let viewModel = CakeDesignListViewModel(repository: repository)
        viewModel.load()

        let tagged = viewModel.updateTags(" Floral, floral,  Birthday ", for: design)
        XCTAssertEqual(tagged?.tags, ["Floral", "Birthday"])
        let favorite = tagged.flatMap(viewModel.toggleFavorite)
        XCTAssertEqual(favorite?.isFavorite, true)
        XCTAssertEqual(repository.designs.first, favorite)
    }

    func testReservedLabelsRemainDistinctTagFiltersAndStaleSelectionResets() {
        let repository = FakeCakeDesignRepository()
        let design = makeDesign(
            id: "design-reserved-tags",
            name: "Reserved Tags",
            tags: ["All", "Favorites"]
        )
        repository.designs = [design]
        let viewModel = CakeDesignListViewModel(repository: repository)
        viewModel.load()

        XCTAssertEqual(
            viewModel.availableFilters,
            [.all, .tag("All"), .tag("Favorites")]
        )
        XCTAssertEqual(viewModel.availableFilters.map(\.label), ["All", "#All", "#Favorites"])
        viewModel.selectFilter(.tag("Favorites"))
        XCTAssertEqual(viewModel.visibleDesigns.map(\.id), [design.id])

        _ = viewModel.updateTags("Other", for: design)

        XCTAssertEqual(viewModel.selectedFilter, .all)
        XCTAssertEqual(viewModel.visibleDesigns.map(\.id), [design.id])
    }

    func testDeletingDesignRemovesMetadataButNotPhotosAsset() {
        let repository = FakeCakeDesignRepository()
        let design = makeDesign(id: "design-delete", name: "Delete", photoReference: "photos://keep-me")
        repository.designs = [design]
        let photoLibrary = FakeDesignPhotoLibrary()
        let viewModel = CakeDesignListViewModel(
            repository: repository,
            designPhotoLibrary: photoLibrary
        )
        viewModel.load()

        XCTAssertTrue(viewModel.delete(design))
        XCTAssertTrue(repository.designs.isEmpty)
        XCTAssertTrue(photoLibrary.savedFileURLs.isEmpty)
        XCTAssertTrue(photoLibrary.savedData.isEmpty)
    }

    func testDeletingPhotosBackedCustomerReferenceRemovesOnlyOrderMetadata() {
        let designRepository = FakeCakeDesignRepository()
        let orderRepository = FakeOrderRepository()
        let photoFileStore = FakeOrderPhotoFileStore()
        let order = makeOrder(id: "order-delete-reference", dueAt: Date(timeIntervalSince1970: 1_800_100_000))
        let photo = OrderPhoto(
            id: "photo-delete-reference",
            orderId: order.id,
            kind: .customerReference,
            localPhotoPath: "photos://keep-reference",
            caption: nil,
            createdAt: order.createdAt,
            updatedAt: order.updatedAt
        )
        orderRepository.orders = [order]
        orderRepository.orderPhotos = [photo]
        let viewModel = CakeDesignListViewModel(
            repository: designRepository,
            photoFileStore: photoFileStore,
            customerReferenceRepository: orderRepository
        )
        viewModel.load()
        guard let reference = viewModel.customerReferences.first else {
            return XCTFail("Expected customer reference")
        }

        XCTAssertTrue(viewModel.delete(reference))
        XCTAssertTrue(orderRepository.orderPhotos.isEmpty)
        XCTAssertTrue(photoFileStore.deletedRelativePaths.isEmpty)
    }

    private func makeDesign(
        id: String,
        name: String,
        notes: String? = nil,
        photoReference: String? = "photos://asset",
        sourceKind: CakeDesignSourceKind = .ownerMade,
        tags: [String] = [],
        isFavorite: Bool = false
    ) -> CakeDesign {
        let timestamp = Date(timeIntervalSince1970: 1_800_080_000)
        return CakeDesign(
            id: id,
            name: name,
            notes: notes,
            photoReference: photoReference,
            sourceKind: sourceKind,
            tags: tags,
            isFavorite: isFavorite,
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

    func deleteCakeDesign(id: String) throws {
        designs.removeAll { $0.id == id }
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
