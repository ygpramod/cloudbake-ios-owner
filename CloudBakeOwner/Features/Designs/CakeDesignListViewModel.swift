import Foundation

@MainActor
final class CakeDesignListViewModel: ObservableObject {
    @Published private(set) var designs: [CakeDesign] = []
    @Published var searchText = ""
    @Published var errorMessage: String?

    private let repository: any CakeDesignRepository

    init(repository: any CakeDesignRepository) {
        self.repository = repository
    }

    func load() {
        do {
            designs = try repository.fetchCakeDesigns()
            errorMessage = nil
        } catch {
            designs = []
            errorMessage = "Designs could not be loaded."
        }
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

        return "\(design.name), design photo"
    }
}
