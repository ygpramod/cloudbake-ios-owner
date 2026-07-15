import XCTest
@testable import CloudBakeOwner

private enum TestDesignRepositoryError: Error {
    case forcedFailure
}

@MainActor
final class CakeDesignListViewModelTests: XCTestCase {
    func testPhotoZoomClampsScaleAndPanToVisibleBounds() {
        XCTAssertEqual(DesignPhotoZoom.clampedScale(0.5), 1)
        XCTAssertEqual(DesignPhotoZoom.clampedScale(5), 4)
        XCTAssertEqual(
            DesignPhotoZoom.clampedOffset(
                CGSize(width: 500, height: -500),
                scale: 2,
                in: CGSize(width: 300, height: 200)
            ),
            CGSize(width: 150, height: -100)
        )
        XCTAssertEqual(
            DesignPhotoZoom.clampedOffset(
                CGSize(width: 50, height: 50),
                scale: 1,
                in: CGSize(width: 300, height: 200)
            ),
            .zero
        )
    }

    func testLoadFetchesDesigns() {
        let repository = FakeCakeDesignRepository()
        let design = makeDesign(id: "design-flowers", name: "Pink Flowers")
        let inspiration = makeDesign(
            id: "design-inspiration",
            name: "Saved Inspiration",
            sourceKind: .internetInspiration,
            tags: ["Hidden Internet Tag"]
        )
        repository.designs = [design, inspiration]
        let viewModel = CakeDesignListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.designs, [design])
        XCTAssertEqual(viewModel.availableFilters, [.all])
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

    func testReferencePresentationNeverLabelsCustomerWorkAsMyDesigns() {
        let reference = makeDesign(
            id: "reference-presentation",
            name: "Customer sketch",
            photoReference: "photos://reference-presentation",
            sourceKind: .customerReference
        )
        let photoLibrary = FakeDesignPhotoLibrary()
        photoLibrary.savedReference = reference.photoReference ?? ""
        let viewModel = CakeDesignListViewModel(
            repository: FakeCakeDesignRepository(),
            designPhotoLibrary: photoLibrary
        )

        XCTAssertEqual(CakeDesignPresentation.collectionName(for: reference), "References")
        XCTAssertEqual(CakeDesignPresentation.itemName(for: reference), "Reference")
        XCTAssertEqual(
            viewModel.accessibilityLabel(for: reference),
            "Customer sketch, reference photo"
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

    func testLoadShowsOnlyExplicitReferencesAndIgnoresRawOrderPhotos() {
        let designRepository = FakeCakeDesignRepository()
        let explicitReference = makeDesign(
            id: "design-reference",
            name: "Blue flowers",
            sourceKind: .customerReference,
            tags: ["Wedding"]
        )
        designRepository.designs = [explicitReference]
        let orderRepository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-reference",
            dueAt: Date(timeIntervalSince1970: 1_800_090_000)
        )
        orderRepository.orders = [order]
        orderRepository.orderPhotos = [
            OrderPhoto(
                id: "raw-order-photo",
                orderId: order.id,
                kind: .customerReference,
                localPhotoPath: "photos://raw-reference",
                caption: "Not added",
                createdAt: order.createdAt,
                updatedAt: order.updatedAt
            )
        ]
        let viewModel = CakeDesignListViewModel(
            repository: designRepository,
            customerReferenceRepository: orderRepository
        )

        viewModel.load()

        XCTAssertEqual(viewModel.references, [explicitReference])
        XCTAssertEqual(viewModel.visibleReferences, [explicitReference])
    }

    func testSaveOwnerDesignPersistsPhotosReferenceAndNormalizedMetadata() {
        let repository = FakeCakeDesignRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_100_000)
        let viewModel = CakeDesignListViewModel(
            repository: repository,
            idGenerator: { "design-owner-direct" },
            dateProvider: { timestamp }
        )

        XCTAssertTrue(
            viewModel.saveOwnerDesign(
                photoReference: "photos://owner-direct-asset",
                name: "  Blue Birthday Cake  ",
                notes: "  First birthday  ",
                tags: "Blue, Birthday, blue"
            )
        )

        XCTAssertEqual(
            repository.designs,
            [
                CakeDesign(
                    id: "design-owner-direct",
                    name: "Blue Birthday Cake",
                    notes: "First birthday",
                    photoReference: "photos://owner-direct-asset",
                    sourceKind: .ownerMade,
                    tags: ["Blue", "Birthday"],
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            ]
        )
        XCTAssertEqual(viewModel.designs, repository.designs)
    }

    func testSaveReferencePersistsPhotosReferenceAndNormalizedTags() {
        let repository = FakeCakeDesignRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_100_000)
        let viewModel = CakeDesignListViewModel(
            repository: repository,
            idGenerator: { "design-reference-direct" },
            dateProvider: { timestamp }
        )

        XCTAssertTrue(
            viewModel.saveReference(
                photoReference: "photos://reference-asset",
                tags: " Wedding, wedding, Blue "
            )
        )
        XCTAssertEqual(
            repository.designs,
            [
                CakeDesign(
                    id: "design-reference-direct",
                    name: "Reference",
                    notes: nil,
                    photoReference: "photos://reference-asset",
                    sourceKind: .customerReference,
                    tags: ["Wedding", "Blue"],
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            ]
        )
        XCTAssertEqual(viewModel.references, repository.designs)
    }

    func testSaveOwnerDesignRequiresNameBeforePersisting() {
        let repository = FakeCakeDesignRepository()
        let viewModel = CakeDesignListViewModel(repository: repository)

        XCTAssertFalse(
            viewModel.saveOwnerDesign(
                photoReference: "photos://owner-direct-asset",
                name: "  ",
                notes: "",
                tags: ""
            )
        )
        XCTAssertTrue(repository.designs.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "Design name is required.")
    }

    func testSaveOwnerDesignRejectsNonPhotosReferences() {
        for reference in ["", "photos://", "photos://   ", "OrderPhotos/legacy.jpg", "https://example.com/cake.jpg"] {
            let repository = FakeCakeDesignRepository()
            let viewModel = CakeDesignListViewModel(repository: repository)

            XCTAssertFalse(
                viewModel.saveOwnerDesign(
                    photoReference: reference,
                    name: "Owner Cake",
                    notes: "",
                    tags: ""
                )
            )
            XCTAssertTrue(repository.designs.isEmpty)
            XCTAssertEqual(viewModel.errorMessage, "Design photo must be stored in Photos.")
        }
    }

    func testDesignImportReusesPickerIdentifierWithoutSavingACopy() async throws {
        let photoLibrary = FakeDesignPhotoLibrary()
        let viewModel = CakeDesignListViewModel(
            repository: FakeCakeDesignRepository(),
            designPhotoLibrary: photoLibrary
        )

        let reference = try await viewModel.photosReference(
            itemIdentifier: "picker-selected-asset",
            fallbackData: Data([0xCA, 0xFE])
        )

        XCTAssertEqual(reference, "photos://picker-selected-asset")
        XCTAssertTrue(photoLibrary.savedData.isEmpty)
    }

    func testDesignImportSavesFallbackDataWhenPickerHasNoIdentifier() async throws {
        let photoLibrary = FakeDesignPhotoLibrary()
        let viewModel = CakeDesignListViewModel(
            repository: FakeCakeDesignRepository(),
            designPhotoLibrary: photoLibrary
        )
        let data = Data([0xCA, 0xFE])

        let reference = try await viewModel.photosReference(
            itemIdentifier: nil,
            fallbackData: data
        )

        XCTAssertEqual(reference, photoLibrary.savedReference)
        XCTAssertEqual(photoLibrary.savedData, [data])
    }

    func testTagsFiltersAndFavoritesApplyAcrossVisibleSources() {
        let designRepository = FakeCakeDesignRepository()
        let ownerDesign = makeDesign(
            id: "design-floral",
            name: "Floral Cake",
            sourceKind: .ownerMade,
            tags: ["Floral"],
            isFavorite: true
        )
        let reference = makeDesign(
            id: "design-wedding-reference",
            name: "Wedding reference",
            sourceKind: .customerReference,
            tags: ["Wedding"]
        )
        designRepository.designs = [ownerDesign, reference]
        let viewModel = CakeDesignListViewModel(repository: designRepository)
        viewModel.load()

        XCTAssertEqual(
            viewModel.availableFilters,
            [.all, .favorites, .tag("Floral"), .tag("Wedding")]
        )
        viewModel.selectFilter(.favorites)
        XCTAssertEqual(viewModel.visibleDesigns.map(\.id), [ownerDesign.id])
        XCTAssertTrue(viewModel.visibleReferences.isEmpty)

        viewModel.selectFilter(.tag("Wedding"))
        XCTAssertEqual(viewModel.visibleReferences.map(\.id), [reference.id])
        XCTAssertTrue(viewModel.visibleDesigns.isEmpty)

        viewModel.selectFilter(.all)
        viewModel.searchText = "floral"
        XCTAssertEqual(viewModel.visibleDesigns.map(\.id), [ownerDesign.id])
    }

    func testFilterRibbonShowsOnlyTenMostUsedTags() {
        let repository = FakeCakeDesignRepository()
        repository.designs = (0..<12).map { index in
            makeDesign(
                id: "design-tag-\(index)",
                name: "Tagged \(index)",
                tags: ["Tag \(index)"] + (index < 3 ? ["Popular"] : [])
            )
        }
        let viewModel = CakeDesignListViewModel(repository: repository)

        viewModel.load()

        let visibleTags = viewModel.availableFilters.compactMap { filter -> String? in
            guard case .tag(let tag) = filter else { return nil }
            return tag
        }
        XCTAssertEqual(visibleTags.count, 10)
        XCTAssertEqual(visibleTags.first, "Popular")
        XCTAssertFalse(visibleTags.contains("Tag 9"))
        XCTAssertFalse(visibleTags.contains("Tag 8"))
        XCTAssertFalse(visibleTags.contains("Tag 7"))
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

    func testDeletingExplicitReferencePreservesOriginatingOrderPhoto() {
        let designRepository = FakeCakeDesignRepository()
        let orderRepository = FakeOrderRepository()
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
        let reference = makeDesign(
            id: "design-delete-reference",
            name: "Reference",
            photoReference: photo.localPhotoPath,
            sourceKind: .customerReference
        )
        designRepository.designs = [reference]
        let viewModel = CakeDesignListViewModel(
            repository: designRepository,
            customerReferenceRepository: orderRepository
        )
        viewModel.load()

        XCTAssertTrue(viewModel.delete(reference))
        XCTAssertTrue(designRepository.designs.isEmpty)
        XCTAssertEqual(orderRepository.orderPhotos, [photo])
    }

    func testUsageHistoryDerivesLinkedOrdersNewestDueDateFirst() {
        let designRepository = FakeCakeDesignRepository()
        let design = makeDesign(id: "design-used", name: "Used Design")
        designRepository.designs = [design]
        let orderRepository = FakeOrderRepository()
        let earlier = makeOrder(
            id: "order-earlier",
            title: "Earlier Cake",
            cakeDesignId: design.id,
            dueAt: Date(timeIntervalSince1970: 1_800_100_000)
        )
        let later = makeOrder(
            id: "order-later",
            title: "Same Cake",
            cakeDesignId: design.id,
            dueAt: Date(timeIntervalSince1970: 1_800_200_000)
        )
        let sameDateAndTitle = makeOrder(
            id: "order-after-later",
            title: "Same Cake",
            cakeDesignId: design.id,
            dueAt: later.dueAt
        )
        let unrelated = makeOrder(
            id: "order-unrelated",
            title: "Unrelated",
            dueAt: Date(timeIntervalSince1970: 1_800_300_000)
        )
        orderRepository.orders = [earlier, sameDateAndTitle, unrelated, later]
        let viewModel = CakeDesignListViewModel(
            repository: designRepository,
            customerReferenceRepository: orderRepository
        )

        viewModel.load()

        XCTAssertEqual(viewModel.usageCount(for: design), 3)
        XCTAssertEqual(
            viewModel.usageOrders(for: design).map(\.id),
            [sameDateAndTitle.id, later.id, earlier.id]
        )
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

    func fetchCakeDesign(originatingOrderPhotoId: String) throws -> CakeDesign? {
        designs.first { $0.originatingOrderPhotoId == originatingOrderPhotoId }
    }

    func fetchCakeDesigns() throws -> [CakeDesign] {
        designs
    }
}
