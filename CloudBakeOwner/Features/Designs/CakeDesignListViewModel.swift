import Foundation

@MainActor
final class CakeDesignListViewModel: ObservableObject {
    @Published private(set) var designs: [CakeDesign] = []
    @Published var searchText = ""
    @Published var errorMessage: String?

    private let repository: any CakeDesignRepository
    private let photoFileStore: OrderPhotoFileStore

    init(
        repository: any CakeDesignRepository,
        photoFileStore: OrderPhotoFileStore = LocalOrderPhotoFileStore()
    ) {
        self.repository = repository
        self.photoFileStore = photoFileStore
    }

    func load() {
        do {
            designs = try repository.fetchCakeDesigns(sourceKind: .ownerMade)
            errorMessage = nil
        } catch {
            designs = []
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

    func accessibilityLabel(for design: CakeDesign) -> String {
        if design.photoReference == nil {
            return "\(design.name), design without a linked photo"
        }
        if availablePhotoURL(for: design) == nil {
            return "\(design.name), photo unavailable"
        }

        return "\(design.name), design photo"
    }
}
