import Foundation
import PhotosUI
import SwiftUI
import UIKit

enum CakeDesignPhotoSource: Hashable {
    case photosAsset(String)
    case legacyFile(URL)
}

enum DesignLibraryFilter: Hashable, Identifiable {
    case all
    case favorites
    case tag(String)

    var id: String {
        switch self {
        case .all: "control:all"
        case .favorites: "control:favorites"
        case .tag(let tag): "tag:\(TextInputFormatting.normalizedSearchKey(tag))"
        }
    }

    var label: String {
        switch self {
        case .all: "All"
        case .favorites: "Favorites"
        case .tag(let tag): "#\(tag)"
        }
    }
}

enum DesignTagRanking {
    static func mostUsed(in tagCollections: [[String]], limit: Int = 10) -> [String] {
        guard limit > 0 else { return [] }
        var labelsByKey: [String: String] = [:]
        var countsByKey: [String: Int] = [:]
        for tags in tagCollections {
            for tag in DesignTags.normalized(tags) {
                let key = TextInputFormatting.normalizedSearchKey(tag)
                labelsByKey[key] = labelsByKey[key] ?? tag
                countsByKey[key, default: 0] += 1
            }
        }
        return countsByKey.keys.sorted { lhs, rhs in
            let lhsCount = countsByKey[lhs, default: 0]
            let rhsCount = countsByKey[rhs, default: 0]
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            return (labelsByKey[lhs] ?? lhs).localizedCaseInsensitiveCompare(
                labelsByKey[rhs] ?? rhs
            ) == .orderedAscending
        }
        .prefix(limit)
        .compactMap { labelsByKey[$0] }
    }
}

@MainActor
final class CakeDesignListViewModel: ObservableObject {
    @Published private(set) var designs: [CakeDesign] = []
    @Published private(set) var references: [CakeDesign] = []
    @Published private(set) var orders: [Order] = []
    @Published var searchText = ""
    @Published var selectedFilter: DesignLibraryFilter = .all
    @Published var errorMessage: String?

    private let repository: any CakeDesignRepository
    private let photoFileStore: OrderPhotoFileStore
    private let designPhotoLibrary: DesignPhotoLibrary
    private let customerReferenceRepository: (any OrderPhotoRepository & OrderRepository)?
    private let idGenerator: () -> String
    private let dateProvider: () -> Date

    init(
        repository: any CakeDesignRepository,
        photoFileStore: OrderPhotoFileStore = LocalOrderPhotoFileStore(),
        designPhotoLibrary: DesignPhotoLibrary = PhotoKitDesignPhotoLibrary(),
        customerReferenceRepository: (any OrderPhotoRepository & OrderRepository)? = nil,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.photoFileStore = photoFileStore
        self.designPhotoLibrary = designPhotoLibrary
        self.customerReferenceRepository = customerReferenceRepository
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    func load() {
        do {
            designs = try repository.fetchCakeDesigns(sourceKind: .ownerMade)
            references = try repository.fetchCakeDesigns(sourceKind: .customerReference)
            if let customerReferenceRepository {
                orders = try customerReferenceRepository.fetchOrders()
            } else {
                orders = []
            }
            if !availableFilters.contains(selectedFilter) {
                selectedFilter = .all
            }
            errorMessage = retryPendingPhotoCleanups()
                ? nil
                : "A local photo cleanup will be retried automatically."
        } catch {
            designs = []
            references = []
            orders = []
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

    var visibleDesigns: [CakeDesign] {
        let terms = searchTerms
        return designs.filter { design in
            (terms.isEmpty || matchesAllTerms(
                terms,
                values: [design.name, design.notes] + design.tags.map(Optional.some)
            ))
                && matchesSelectedFilter(tags: design.tags, isFavorite: design.isFavorite)
        }
    }

    var visibleReferences: [CakeDesign] {
        let terms = searchTerms
        return references.filter { design in
            (terms.isEmpty || matchesAllTerms(
                terms,
                values: [design.name, design.notes] + design.tags.map(Optional.some)
            )) && matchesSelectedFilter(tags: design.tags, isFavorite: design.isFavorite)
        }
    }

    var hasContent: Bool {
        !designs.isEmpty || !references.isEmpty
    }

    func usageOrders(for design: CakeDesign) -> [Order] {
        orders
            .filter { $0.cakeDesignId == design.id }
            .sorted(by: usageOrderSort)
    }

    func usageCount(for design: CakeDesign) -> Int {
        usageOrders(for: design).count
    }

    var hasEffectiveSearchQuery: Bool {
        !searchTerms.isEmpty
    }

    private func usageOrderSort(_ lhs: Order, _ rhs: Order) -> Bool {
        guard lhs.dueAt == rhs.dueAt else { return lhs.dueAt > rhs.dueAt }
        let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        guard titleOrder == .orderedSame else { return titleOrder == .orderedAscending }
        return lhs.id < rhs.id
    }

    var availableFilters: [DesignLibraryFilter] {
        let persistedDesigns = designs
        let topTags = DesignTagRanking.mostUsed(
            in: persistedDesigns.map(\.tags) + references.map(\.tags)
        )
        let hasFavorite = persistedDesigns.contains(where: \.isFavorite)
            || references.contains(where: \.isFavorite)
        return [.all]
            + (hasFavorite ? [.favorites] : [])
            + topTags.map(DesignLibraryFilter.tag)
    }

    func selectFilter(_ filter: DesignLibraryFilter) {
        selectedFilter = filter
    }

    func toggleFavorite(_ design: CakeDesign) -> CakeDesign? {
        saveDesignCopy(design, tags: design.tags, isFavorite: !design.isFavorite)
    }

    func updateTags(_ tagsText: String, for design: CakeDesign) -> CakeDesign? {
        saveDesignCopy(design, tags: DesignTags.parsed(tagsText), isFavorite: design.isFavorite)
    }

    func delete(_ design: CakeDesign) -> Bool {
        do {
            try repository.deleteCakeDesign(id: design.id)
            load()
            return true
        } catch {
            errorMessage = "Design could not be removed from CloudBake."
            return false
        }
    }

    private func retryPendingPhotoCleanups() -> Bool {
        guard let paths = try? repository.fetchPendingDesignPhotoCleanupPaths() else { return false }
        return paths.reduce(true) { result, path in cleanupPhoto(at: path) && result }
    }

    private func cleanupPhoto(at relativePath: String) -> Bool {
        do {
            try photoFileStore.deleteOrderPhoto(relativePath: relativePath)
            try repository.deletePendingDesignPhotoCleanupPath(relativePath)
            return true
        } catch {
            return false
        }
    }

    func importOwnerDesign(
        item: PhotosPickerItem,
        name: String,
        notes: String,
        tags: String = ""
    ) async -> Bool {
        guard let normalizedName = TextInputFormatting.optionalText(name) else {
            errorMessage = "Design name is required."
            return false
        }
        do {
            let photoReference = try await photosReference(for: item)
            return saveOwnerDesign(
                photoReference: photoReference,
                name: normalizedName,
                notes: notes,
                tags: tags
            )
        } catch {
            errorMessage = "Design photo could not be saved."
            return false
        }
    }

    func importReference(item: PhotosPickerItem, tags: String = "") async -> Bool {
        do {
            let photoReference = try await photosReference(for: item)
            return saveReference(photoReference: photoReference, tags: tags)
        } catch {
            errorMessage = "Reference photo could not be saved."
            return false
        }
    }

    func saveReference(photoReference: String, tags: String = "") -> Bool {
        guard Self.isValidPhotosReference(photoReference) else {
            errorMessage = "Reference photo must be stored in Photos."
            return false
        }
        do {
            let now = dateProvider()
            try repository.save(
                CakeDesign(
                    id: idGenerator(),
                    name: "Reference",
                    notes: nil,
                    photoReference: photoReference,
                    sourceKind: .customerReference,
                    tags: DesignTags.parsed(tags),
                    createdAt: now,
                    updatedAt: now
                )
            )
            load()
            return true
        } catch {
            errorMessage = "Reference photo could not be saved."
            return false
        }
    }

    func saveOwnerDesign(
        photoReference: String,
        name: String,
        notes: String,
        tags: String = ""
    ) -> Bool {
        guard let normalizedName = TextInputFormatting.optionalText(name) else {
            errorMessage = "Design name is required."
            return false
        }
        guard Self.isValidPhotosReference(photoReference) else {
            errorMessage = "Design photo must be stored in Photos."
            return false
        }
        do {
            let now = dateProvider()
            try repository.save(
                CakeDesign(
                    id: idGenerator(),
                    name: normalizedName,
                    notes: TextInputFormatting.optionalText(notes),
                    photoReference: photoReference,
                    sourceKind: .ownerMade,
                    tags: DesignTags.parsed(tags),
                    createdAt: now,
                    updatedAt: now
                )
            )
            load()
            return true
        } catch {
            errorMessage = "Design could not be saved."
            return false
        }
    }

    func photosReference(
        itemIdentifier: String?,
        fallbackData: Data?
    ) async throws -> String {
        if let itemIdentifier,
           !itemIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PhotoKitDesignPhotoLibrary.referencePrefix + itemIdentifier
        }
        guard let fallbackData, !fallbackData.isEmpty else {
            throw DesignPhotoLibraryError.assetCreationFailed
        }
        let reference = try await designPhotoLibrary.savePhoto(data: fallbackData)
        guard Self.isValidPhotosReference(reference) else {
            throw DesignPhotoLibraryError.assetCreationFailed
        }
        return reference
    }

    private func photosReference(for item: PhotosPickerItem) async throws -> String {
        if let identifier = item.itemIdentifier {
            return try await photosReference(itemIdentifier: identifier, fallbackData: nil)
        }
        let image = try await PhotoPickerImageLoader.image(from: item)
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw DesignPhotoLibraryError.assetCreationFailed
        }
        return try await photosReference(itemIdentifier: nil, fallbackData: data)
    }

    private static func isValidPhotosReference(_ reference: String) -> Bool {
        guard let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(from: reference) else {
            return false
        }
        return !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchTerms: [String] {
        searchText.split { character in
            !character.isLetter && !character.isNumber
        }
            .map(String.init)
            .map(TextInputFormatting.normalizedSearchKey)
            .filter { !$0.isEmpty }
    }

    private func matchesAllTerms(_ terms: [String], values: [String?]) -> Bool {
        let searchableValues = values.compactMap { $0 }.map(TextInputFormatting.normalizedSearchKey)
        return terms.allSatisfy { term in searchableValues.contains { $0.contains(term) } }
    }

    private func matchesSelectedFilter(tags: [String], isFavorite: Bool) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .favorites:
            return isFavorite
        case .tag(let tag):
            let selectedKey = TextInputFormatting.normalizedSearchKey(tag)
            return tags.contains { TextInputFormatting.normalizedSearchKey($0) == selectedKey }
        }
    }

    private func saveDesignCopy(
        _ design: CakeDesign,
        tags: [String],
        isFavorite: Bool
    ) -> CakeDesign? {
        let updated = CakeDesign(
            id: design.id,
            name: design.name,
            notes: design.notes,
            photoReference: design.photoReference,
            sourceKind: design.sourceKind,
            originatingOrderPhotoId: design.originatingOrderPhotoId,
            originatingOrderId: design.originatingOrderId,
            sourceName: design.sourceName,
            sourceURL: design.sourceURL,
            tags: tags,
            isFavorite: isFavorite,
            isPortfolioPublished: design.isPortfolioPublished,
            createdAt: design.createdAt,
            updatedAt: dateProvider()
        )
        do {
            try repository.save(updated)
            load()
            return updated
        } catch {
            errorMessage = "Design metadata could not be saved."
            return nil
        }
    }

    func accessibilityLabel(for design: CakeDesign) -> String {
        let favoriteSuffix = design.isFavorite ? ", favorite" : ""
        if design.photoReference == nil {
            return "\(design.name), design without a linked photo\(favoriteSuffix)"
        }
        if availablePhotoSource(for: design) == nil {
            return "\(design.name), photo unavailable\(favoriteSuffix)"
        }

        return "\(design.name), design photo\(favoriteSuffix)"
    }
}
