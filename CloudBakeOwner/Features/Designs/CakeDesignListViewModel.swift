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

@MainActor
final class CakeDesignListViewModel: ObservableObject {
    @Published private(set) var designs: [CakeDesign] = []
    @Published private(set) var customerReferences: [CustomerReferenceDesign] = []
    @Published private(set) var internetInspirations: [CakeDesign] = []
    @Published var searchText = ""
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
            internetInspirations = []
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
        guard !terms.isEmpty else { return designs }
        return designs.filter { design in
            matchesAllTerms(terms, values: [design.name, design.notes])
        }
    }

    var visibleCustomerReferences: [CustomerReferenceDesign] {
        let terms = searchTerms
        guard !terms.isEmpty else { return customerReferences }
        return customerReferences.filter { reference in
            matchesAllTerms(
                terms,
                values: [reference.photo.caption, reference.order.title, reference.order.customerName]
            )
        }
    }

    var visibleInternetInspirations: [CakeDesign] {
        let terms = searchTerms
        guard !terms.isEmpty else { return internetInspirations }
        return internetInspirations.filter { design in
            matchesAllTerms(
                terms,
                values: [design.name, design.notes, design.sourceName, design.sourceURL]
            )
        }
    }

    var hasContent: Bool {
        !designs.isEmpty || !customerReferences.isEmpty || !internetInspirations.isEmpty
    }

    var hasEffectiveSearchQuery: Bool {
        !searchTerms.isEmpty
    }

    func importInternetInspiration(
        item: PhotosPickerItem,
        name: String,
        sourceName: String,
        sourceURL: String,
        notes: String
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
                notes: notes
            )
        } catch {
            errorMessage = "Internet inspiration could not be saved."
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
        notes: String
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
            notes: notes
        )
    }

    private func saveInternetInspiration(
        photoReference: String,
        normalizedName: String,
        sourceName: String,
        sourceURL: String?,
        notes: String
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

    private static func isValidWebURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else { return false }
        return components.host?.isEmpty == false
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
