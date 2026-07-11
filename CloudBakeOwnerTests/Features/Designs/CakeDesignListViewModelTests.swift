import XCTest
@testable import CloudBakeOwner

@MainActor
final class CakeDesignListViewModelTests: XCTestCase {
    func testLoadFetchesDesigns() {
        let repository = FakeCakeDesignRepository()
        let design = makeDesign(id: "design-flowers", name: "Pink Flowers")
        repository.designs = [design]
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

    private func makeDesign(
        id: String,
        name: String,
        notes: String? = nil,
        photoReference: String? = "photos://asset"
    ) -> CakeDesign {
        let timestamp = Date(timeIntervalSince1970: 1_800_080_000)
        return CakeDesign(
            id: id,
            name: name,
            notes: notes,
            photoReference: photoReference,
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

    func fetchCakeDesign(id: String) throws -> CakeDesign? {
        designs.first { $0.id == id }
    }

    func fetchCakeDesigns() throws -> [CakeDesign] {
        designs
    }
}
