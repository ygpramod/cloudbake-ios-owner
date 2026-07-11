import Foundation

enum CakeDesignPhotoSource: Hashable {
    case photosAsset(String)
    case legacyFile(URL)
}

struct CustomerReferenceDesign: Identifiable, Equatable {
    let photo: OrderPhoto
    let order: Order

    var id: String { photo.id }
    var title: String { photo.caption ?? order.title }
}

@MainActor
final class CakeDesignListViewModel: ObservableObject {
    @Published private(set) var designs: [CakeDesign] = []
    @Published private(set) var customerReferences: [CustomerReferenceDesign] = []
    @Published var searchText = ""
    @Published var errorMessage: String?

    private let repository: any CakeDesignRepository
    private let photoFileStore: OrderPhotoFileStore
    private let designPhotoLibrary: DesignPhotoLibrary
    private let customerReferenceRepository: (any OrderPhotoRepository & OrderRepository)?

    init(
        repository: any CakeDesignRepository,
        photoFileStore: OrderPhotoFileStore = LocalOrderPhotoFileStore(),
        designPhotoLibrary: DesignPhotoLibrary = PhotoKitDesignPhotoLibrary(),
        customerReferenceRepository: (any OrderPhotoRepository & OrderRepository)? = nil
    ) {
        self.repository = repository
        self.photoFileStore = photoFileStore
        self.designPhotoLibrary = designPhotoLibrary
        self.customerReferenceRepository = customerReferenceRepository
    }

    func load() {
        do {
            designs = try repository.fetchCakeDesigns(sourceKind: .ownerMade)
            if let customerReferenceRepository {
                let ordersById = Dictionary(
                    uniqueKeysWithValues: try customerReferenceRepository.fetchOrders().map { ($0.id, $0) }
                )
                customerReferences = try customerReferenceRepository
                    .fetchOrderPhotos(kind: .customerReference)
                    .compactMap { photo in
                        ordersById[photo.orderId].map { CustomerReferenceDesign(photo: photo, order: $0) }
                    }
            } else {
                customerReferences = []
            }
            errorMessage = nil
        } catch {
            designs = []
            customerReferences = []
            errorMessage = "Designs could not be loaded."
        }
    }

    func photoURL(for design: CakeDesign) -> URL? {
        design.photoReference.map(photoFileStore.fileURL(for:))
    }

    func availablePhotoURL(for design: CakeDesign) -> URL? {
        guard let photoURL = photoURL(for: design),
              FileManager.default.fileExists(atPath: photoURL.path) else {
            return nil
        }
        return photoURL
    }

    func availablePhotoSource(for design: CakeDesign) -> CakeDesignPhotoSource? {
        guard let reference = design.photoReference else { return nil }
        if let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(from: reference) {
            return designPhotoLibrary.containsAsset(identifier: identifier) ? .photosAsset(identifier) : nil
        }
        return availablePhotoURL(for: design).map(CakeDesignPhotoSource.legacyFile)
    }

    func availablePhotoSource(for photo: OrderPhoto) -> CakeDesignPhotoSource? {
        if let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(from: photo.localPhotoPath) {
            return designPhotoLibrary.containsAsset(identifier: identifier) ? .photosAsset(identifier) : nil
        }
        let url = photoFileStore.fileURL(for: photo.localPhotoPath)
        return FileManager.default.fileExists(atPath: url.path) ? .legacyFile(url) : nil
    }

    var visibleDesigns: [CakeDesign] {
        let query = TextInputFormatting.normalizedSearchKey(searchText)
        guard !query.isEmpty else {
            return designs
        }

        return designs.filter { design in
            [
                design.name,
                design.notes,
                design.photoReference
            ]
            .compactMap { $0 }
            .map(TextInputFormatting.normalizedSearchKey)
            .contains { $0.contains(query) }
        }
    }

    var visibleCustomerReferences: [CustomerReferenceDesign] {
        let terms = searchText
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(TextInputFormatting.normalizedSearchKey)
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return customerReferences }
        return customerReferences.filter { reference in
            let searchableValues = [reference.photo.caption, reference.order.title, reference.order.customerName]
                .compactMap { $0 }
                .map(TextInputFormatting.normalizedSearchKey)
            return terms.allSatisfy { term in
                searchableValues.contains { $0.contains(term) }
            }
        }
    }

    var hasContent: Bool {
        !designs.isEmpty || !customerReferences.isEmpty
    }

    func accessibilityLabel(for design: CakeDesign) -> String {
        if design.photoReference == nil {
            return "\(design.name), design without a linked photo"
        }
        if availablePhotoSource(for: design) == nil {
            return "\(design.name), photo unavailable"
        }

        return "\(design.name), design photo"
    }
}
