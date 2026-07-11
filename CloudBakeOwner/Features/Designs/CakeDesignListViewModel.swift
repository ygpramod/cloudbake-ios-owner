import Foundation
import PhotosUI
import SwiftUI
import UIKit

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

@MainActor
final class CakeDesignListViewModel: ObservableObject {
    @Published private(set) var designs: [CakeDesign] = []
    @Published private(set) var customerReferences: [CustomerReferenceDesign] = []
    @Published private(set) var internetInspirations: [CakeDesign] = []
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
            internetInspirations = try repository.fetchCakeDesigns(sourceKind: .internetInspiration)
            if let customerReferenceRepository {
                orders = try customerReferenceRepository.fetchOrders()
                let ordersById = Dictionary(
                    uniqueKeysWithValues: orders.map { ($0.id, $0) }
                )
                customerReferences = try customerReferenceRepository
                    .fetchOrderPhotos(kind: .customerReference)
                    .compactMap { photo in
                        ordersById[photo.orderId].map { CustomerReferenceDesign(photo: photo, order: $0) }
                    }
            } else {
                customerReferences = []
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
            customerReferences = []
            internetInspirations = []
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

    func availablePhotoSource(for photo: OrderPhoto) -> CakeDesignPhotoSource? {
        if let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(from: photo.localPhotoPath) {
            return designPhotoLibrary.containsAsset(identifier: identifier) ? .photosAsset(identifier) : nil
        }
        let url = photoFileStore.fileURL(for: photo.localPhotoPath)
        return FileManager.default.fileExists(atPath: url.path) ? .legacyFile(url) : nil
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

    var visibleCustomerReferences: [CustomerReferenceDesign] {
        let terms = searchTerms
        return customerReferences.filter { reference in
            (terms.isEmpty || matchesAllTerms(
                terms,
                values: [reference.photo.caption, reference.order.title, reference.order.customerName]
                    + reference.photo.tags.map(Optional.some)
            )) && matchesSelectedFilter(
                tags: reference.photo.tags,
                isFavorite: reference.photo.isFavorite
            )
        }
    }

    var visibleInternetInspirations: [CakeDesign] {
        let terms = searchTerms
        return internetInspirations.filter { design in
            (terms.isEmpty || matchesAllTerms(
                terms,
                values: [design.name, design.notes, design.sourceName, design.sourceURL]
                    + design.tags.map(Optional.some)
            )) && matchesSelectedFilter(tags: design.tags, isFavorite: design.isFavorite)
        }
    }

    var hasContent: Bool {
        !designs.isEmpty || !customerReferences.isEmpty || !internetInspirations.isEmpty
    }

    func usageOrders(for design: CakeDesign) -> [Order] {
        orders
            .filter { $0.cakeDesignId == design.id }
            .sorted(by: usageOrderSort)
    }

    func usageCount(for design: CakeDesign) -> Int {
        usageOrders(for: design).count
    }

    func usageOrders(for reference: CustomerReferenceDesign) -> [Order] {
        orders
            .filter {
                $0.id == reference.order.id
                    || $0.customerReferencePhotoId == reference.photo.id
            }
            .sorted(by: usageOrderSort)
    }

    func usageCount(for reference: CustomerReferenceDesign) -> Int {
        usageOrders(for: reference).count
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
        let persistedDesigns = designs + internetInspirations
        let allTags = DesignTags.normalized(
            persistedDesigns.flatMap(\.tags) + customerReferences.flatMap { $0.photo.tags }
        )
        let suggested = ["Birthday", "Wedding", "Kids", "Cupcakes", "Chocolate", "Minimal", "Vintage", "Floral"]
        let suggestedKeys = Set(suggested.map(TextInputFormatting.normalizedSearchKey))
        let matchingSuggested = suggested.filter { suggestedTag in
            allTags.contains { TextInputFormatting.normalizedSearchKey($0) == TextInputFormatting.normalizedSearchKey(suggestedTag) }
        }
        let custom = allTags
            .filter { !suggestedKeys.contains(TextInputFormatting.normalizedSearchKey($0)) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let hasFavorite = persistedDesigns.contains(where: \.isFavorite)
            || customerReferences.contains { $0.photo.isFavorite }
        return [.all]
            + (hasFavorite ? [.favorites] : [])
            + matchingSuggested.map(DesignLibraryFilter.tag)
            + custom.map(DesignLibraryFilter.tag)
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

    func toggleFavorite(_ reference: CustomerReferenceDesign) -> CustomerReferenceDesign? {
        saveCustomerReferenceCopy(
            reference,
            tags: reference.photo.tags,
            isFavorite: !reference.photo.isFavorite
        )
    }

    func updateTags(_ tagsText: String, for reference: CustomerReferenceDesign) -> CustomerReferenceDesign? {
        saveCustomerReferenceCopy(
            reference,
            tags: DesignTags.parsed(tagsText),
            isFavorite: reference.photo.isFavorite
        )
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

    func delete(_ reference: CustomerReferenceDesign) -> Bool {
        guard let customerReferenceRepository else { return false }
        let cleanupRelativePath = PhotoKitDesignPhotoLibrary
            .assetIdentifier(from: reference.photo.localPhotoPath) == nil
            ? reference.photo.localPhotoPath
            : nil
        do {
            try customerReferenceRepository.deleteOrderPhoto(
                id: reference.photo.id,
                cleanupRelativePath: cleanupRelativePath
            )
            let didCleanup = cleanupRelativePath.map(cleanupPhoto(at:)) ?? true
            load()
            if !didCleanup {
                errorMessage = "Reference removed. The old local photo will be cleaned up automatically."
            }
            return true
        } catch {
            errorMessage = "Customer reference could not be removed from CloudBake."
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

    func importInternetInspiration(
        item: PhotosPickerItem,
        name: String,
        sourceName: String,
        sourceURL: String,
        notes: String,
        tags: String = ""
    ) async -> Bool {
        guard let normalizedName = TextInputFormatting.optionalText(name) else {
            errorMessage = "Inspiration name is required."
            return false
        }
        let normalizedURL = TextInputFormatting.optionalText(sourceURL)
        if let normalizedURL, !Self.isValidWebURL(normalizedURL) {
            errorMessage = "Source URL must be a valid http or https address."
            return false
        }

        let photoReference: String
        do {
            if let identifier = item.itemIdentifier {
                photoReference = try await internetInspirationPhotoReference(
                    itemIdentifier: identifier,
                    fallbackData: nil
                )
            } else {
                let image = try await PhotoPickerImageLoader.image(from: item)
                guard let data = image.jpegData(compressionQuality: 0.9) else {
                    throw DesignPhotoLibraryError.assetCreationFailed
                }
                photoReference = try await internetInspirationPhotoReference(
                    itemIdentifier: nil,
                    fallbackData: data
                )
            }
            return saveInternetInspiration(
                photoReference: photoReference,
                normalizedName: normalizedName,
                sourceName: sourceName,
                sourceURL: normalizedURL,
                notes: notes,
                tags: tags
            )
        } catch {
            errorMessage = "Internet inspiration could not be saved."
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
            let photoReference: String
            if let identifier = item.itemIdentifier {
                photoReference = try await internetInspirationPhotoReference(
                    itemIdentifier: identifier,
                    fallbackData: nil
                )
            } else {
                let image = try await PhotoPickerImageLoader.image(from: item)
                guard let data = image.jpegData(compressionQuality: 0.9) else {
                    throw DesignPhotoLibraryError.assetCreationFailed
                }
                photoReference = try await internetInspirationPhotoReference(
                    itemIdentifier: nil,
                    fallbackData: data
                )
            }
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

    func internetInspirationPhotoReference(
        itemIdentifier: String?,
        fallbackData: Data?
    ) async throws -> String {
        if let itemIdentifier, !itemIdentifier.isEmpty {
            return PhotoKitDesignPhotoLibrary.referencePrefix + itemIdentifier
        }
        guard let fallbackData, !fallbackData.isEmpty else {
            throw DesignPhotoLibraryError.assetCreationFailed
        }
        return try await designPhotoLibrary.savePhoto(data: fallbackData)
    }

    func saveInternetInspiration(
        photoReference: String,
        name: String,
        sourceName: String,
        sourceURL: String,
        notes: String,
        tags: String = ""
    ) -> Bool {
        guard let normalizedName = TextInputFormatting.optionalText(name) else {
            errorMessage = "Inspiration name is required."
            return false
        }
        let normalizedURL = TextInputFormatting.optionalText(sourceURL)
        if let normalizedURL, !Self.isValidWebURL(normalizedURL) {
            errorMessage = "Source URL must be a valid http or https address."
            return false
        }
        return saveInternetInspiration(
            photoReference: photoReference,
            normalizedName: normalizedName,
            sourceName: sourceName,
            sourceURL: normalizedURL,
            notes: notes,
            tags: tags
        )
    }

    private func saveInternetInspiration(
        photoReference: String,
        normalizedName: String,
        sourceName: String,
        sourceURL: String?,
        notes: String,
        tags: String
    ) -> Bool {
        do {
            let now = dateProvider()
            try repository.save(
                CakeDesign(
                    id: idGenerator(),
                    name: normalizedName,
                    notes: TextInputFormatting.optionalText(notes),
                    photoReference: photoReference,
                    sourceKind: .internetInspiration,
                    sourceName: TextInputFormatting.optionalText(sourceName),
                    sourceURL: sourceURL,
                    tags: DesignTags.parsed(tags),
                    createdAt: now,
                    updatedAt: now
                )
            )
            load()
            return true
        } catch {
            errorMessage = "Internet inspiration could not be saved."
            return false
        }
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

    private func saveCustomerReferenceCopy(
        _ reference: CustomerReferenceDesign,
        tags: [String],
        isFavorite: Bool
    ) -> CustomerReferenceDesign? {
        guard let customerReferenceRepository else { return nil }
        let photo = OrderPhoto(
            id: reference.photo.id,
            orderId: reference.photo.orderId,
            kind: reference.photo.kind,
            localPhotoPath: reference.photo.localPhotoPath,
            caption: reference.photo.caption,
            tags: tags,
            isFavorite: isFavorite,
            createdAt: reference.photo.createdAt,
            updatedAt: dateProvider()
        )
        do {
            try customerReferenceRepository.save(photo)
            load()
            return CustomerReferenceDesign(photo: photo, order: reference.order)
        } catch {
            errorMessage = "Reference metadata could not be saved."
            return nil
        }
    }

    private static func isValidWebURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else { return false }
        return components.host?.isEmpty == false
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
