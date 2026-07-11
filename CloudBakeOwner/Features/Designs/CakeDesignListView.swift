import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UIKit

struct CakeDesignListView: View {
    @StateObject private var viewModel: CakeDesignListViewModel
    @State private var previewingDesign: CakeDesign?
    @State private var previewingCustomerReference: CustomerReferenceDesign?
    @State private var isImportingInternetInspiration = false
    @FocusState private var isSearchFocused: Bool

    init(viewModel: CakeDesignListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        CloudBakeScreenScaffold(
            title: "Designs",
            selectedDestination: .designs
        ) {
            CloudBakeSearchField(
                text: $viewModel.searchText,
                prompt: "Search designs",
                accessibilityIdentifier: "designs.search",
                isFocused: $isSearchFocused
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableFilters) { filter in
                        Button(filter.label) { viewModel.selectFilter(filter) }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .tint(
                                viewModel.selectedFilter == filter
                                    ? Color.cloudBakePink
                                    : Color.secondary
                            )
                            .accessibilityAddTraits(
                                viewModel.selectedFilter == filter
                                    ? .isSelected
                                    : []
                            )
                    }
                }
            }
            .accessibilityIdentifier("designs.filters")

            designResults
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        isSearchFocused = false
                    }
                )

            if let errorMessage = viewModel.errorMessage {
                CloudBakeErrorBanner(
                    message: errorMessage,
                    accessibilityIdentifier: "designs.error"
                )
            }
        }
        .accessibilityIdentifier(AppDestination.designs.screenAccessibilityIdentifier)
        .sheet(item: $previewingDesign) { design in
            NavigationStack {
                CakeDesignPreviewView(
                    design: design,
                    photoSource: viewModel.availablePhotoSource(for: design),
                    accessibilityLabel: viewModel.accessibilityLabel(for: design),
                    onToggleFavorite: { viewModel.toggleFavorite($0) },
                    onUpdateTags: { viewModel.updateTags($0, for: $1) },
                    onDelete: { viewModel.delete($0) }
                )
            }
        }
        .sheet(item: $previewingCustomerReference) { reference in
            NavigationStack {
                CustomerReferencePreviewView(
                    reference: reference,
                    photoSource: viewModel.availablePhotoSource(for: reference.photo),
                    onToggleFavorite: { viewModel.toggleFavorite($0) },
                    onUpdateTags: { viewModel.updateTags($0, for: $1) },
                    onDelete: { viewModel.delete($0) }
                )
            }
        }
        .sheet(isPresented: $isImportingInternetInspiration) {
            InternetInspirationImportView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.load()
        }
    }

    @ViewBuilder
    private var designResults: some View {
        if viewModel.visibleDesigns.isEmpty
            && viewModel.visibleCustomerReferences.isEmpty
            && viewModel.visibleInternetInspirations.isEmpty
            && (viewModel.hasEffectiveSearchQuery || viewModel.selectedFilter != .all) {
            CloudBakeEmptyState(
                title: "No matching designs",
                systemImage: "magnifyingglass",
                message: "Try another cake name, note, customer, order, or inspiration source."
            )
            Button("Clear Search and Filters") {
                viewModel.searchText = ""
                viewModel.selectFilter(.all)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.cloudBakePink)
            .accessibilityIdentifier("designs.clearSearchAndFilters")
        } else {
            Text("My Designs (\(viewModel.visibleDesigns.count))")
                .font(CloudBakeTheme.Typography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("designs.myDesigns.title")

            if viewModel.visibleDesigns.isEmpty {
                Text("No owner designs saved")
                    .font(CloudBakeTheme.Typography.rowDetail)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(viewModel.visibleDesigns, id: \.id) { design in
                        designTile(design)
                    }
                }
            }

            Text("Customer References (\(viewModel.visibleCustomerReferences.count))")
                    .font(CloudBakeTheme.Typography.sectionTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("designs.customerReferences.title")

            if viewModel.visibleCustomerReferences.isEmpty {
                Text("No customer references saved")
                    .font(CloudBakeTheme.Typography.rowDetail)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("designs.customerReferences.empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(viewModel.visibleCustomerReferences) { reference in
                            customerReferenceTile(reference)
                                .frame(width: 150)
                        }
                    }
                }
                }
            }

            HStack {
                Text("Internet Inspiration (\(viewModel.visibleInternetInspirations.count))")
                    .font(CloudBakeTheme.Typography.sectionTitle)
                    .accessibilityIdentifier("designs.internetInspiration.title")
                Spacer()
                Button {
                    isImportingInternetInspiration = true
                } label: {
                    Label("Add inspiration", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .accessibilityLabel("Add Internet Inspiration")
                .accessibilityIdentifier("designs.internetInspiration.add")
            }

            if viewModel.visibleInternetInspirations.isEmpty {
                Text("No internet inspiration saved")
                    .font(CloudBakeTheme.Typography.rowDetail)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(viewModel.visibleInternetInspirations, id: \.id) { design in
                            designTile(design)
                                .frame(width: 150)
                        }
                    }
                }
            }
    }

    private func customerReferenceTile(_ reference: CustomerReferenceDesign) -> some View {
        Button {
            previewingCustomerReference = reference
        } label: {
            photoTile(
                source: viewModel.availablePhotoSource(for: reference.photo),
                isFavorite: reference.photo.isFavorite
            )
        }
        .buttonStyle(.plain)
        .cloudBakeCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(reference.title), customer reference from \(reference.order.customerName)"
                + (reference.photo.isFavorite ? ", favorite" : "")
        )
        .accessibilityIdentifier("designs.customerReference.\(reference.id)")
    }

    private func designTile(_ design: CakeDesign) -> some View {
        Button {
            previewingDesign = design
        } label: {
            photoTile(
                source: viewModel.availablePhotoSource(for: design),
                isFavorite: design.isFavorite
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cloudBakeCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.accessibilityLabel(for: design))
        .accessibilityIdentifier("designs.item.\(design.id)")
    }

    private func photoTile(source: CakeDesignPhotoSource?, isFavorite: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            DesignPhotoView(source: source, maximumPixelSize: 600, contentMode: .fill)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            if isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.cloudBakePink, in: Capsule())
                    .padding(8)
                    .accessibilityLabel("Favorite")
            }
        }
    }

}

private struct CustomerReferencePreviewView: View {
    @State private var reference: CustomerReferenceDesign
    let photoSource: CakeDesignPhotoSource?
    let onToggleFavorite: (CustomerReferenceDesign) -> CustomerReferenceDesign?
    let onUpdateTags: (String, CustomerReferenceDesign) -> CustomerReferenceDesign?
    let onDelete: (CustomerReferenceDesign) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingTags = false
    @State private var tagsText = ""
    @State private var isConfirmingDelete = false

    init(
        reference: CustomerReferenceDesign,
        photoSource: CakeDesignPhotoSource?,
        onToggleFavorite: @escaping (CustomerReferenceDesign) -> CustomerReferenceDesign?,
        onUpdateTags: @escaping (String, CustomerReferenceDesign) -> CustomerReferenceDesign?,
        onDelete: @escaping (CustomerReferenceDesign) -> Bool
    ) {
        _reference = State(initialValue: reference)
        self.photoSource = photoSource
        self.onToggleFavorite = onToggleFavorite
        self.onUpdateTags = onUpdateTags
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DesignPhotoView(source: photoSource, maximumPixelSize: 2_400, contentMode: .fit)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .accessibilityIdentifier("designs.customerReference.preview.photo")

                CloudBakeDetailCard {
                    CloudBakeDetailRow("Source") { Text("Customer Reference") }
                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Customer") { Text(reference.order.customerName) }
                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Order") { Text(reference.order.title) }
                    if let caption = reference.photo.caption {
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Caption") { Text(caption) }
                    }
                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Tags") {
                        Text(reference.photo.tags.isEmpty ? "None" : reference.photo.tags.joined(separator: ", "))
                    }
                }
            }
            .padding(CloudBakeTheme.Spacing.screenHorizontal)
        }
        .background(CloudBakeScreenBackground().ignoresSafeArea())
        .navigationTitle(reference.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let updated = onToggleFavorite(reference) { reference = updated }
                } label: {
                    Image(systemName: reference.photo.isFavorite ? "heart.fill" : "heart")
                }
                .accessibilityLabel(reference.photo.isFavorite ? "Remove Favorite" : "Add Favorite")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Tags") {
                    tagsText = reference.photo.tags.joined(separator: ", ")
                    isEditingTags = true
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) { isConfirmingDelete = true } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Remove Customer Reference")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Edit Tags", isPresented: $isEditingTags) {
            TextField("Comma-separated tags", text: $tagsText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let updated = onUpdateTags(tagsText, reference) { reference = updated }
            }
        }
        .alert("Remove Customer Reference?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if onDelete(reference) { dismiss() }
            }
        } message: {
            Text("This removes the reference from CloudBake and its order. The image remains in Photos.")
        }
    }
}

private struct InternetInspirationImportView: View {
    @ObservedObject var viewModel: CakeDesignListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var name = ""
    @State private var sourceName = ""
    @State private var sourceURL = ""
    @State private var notes = ""
    @State private var tags = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label(
                            selectedItem == nil ? "Choose from Photos" : "Photo selected",
                            systemImage: selectedItem == nil ? "photo.on.rectangle" : "checkmark.circle.fill"
                        )
                    }
                    .accessibilityIdentifier("designs.internetInspiration.photo")
                }

                Section("Inspiration") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("designs.internetInspiration.name")
                    TextField("Source or creator (optional)", text: $sourceName)
                        .accessibilityIdentifier("designs.internetInspiration.sourceName")
                    TextField("Source URL (optional)", text: $sourceURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .accessibilityIdentifier("designs.internetInspiration.sourceURL")
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("designs.internetInspiration.notes")
                    TextField("Tags, comma-separated (optional)", text: $tags)
                        .accessibilityIdentifier("designs.internetInspiration.tags")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .cloudBakeFormScreenStyle()
            .navigationTitle("Add Inspiration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let selectedItem, !isSaving else {
                            if self.selectedItem == nil {
                                viewModel.errorMessage = "Inspiration photo is required."
                            }
                            return
                        }
                        isSaving = true
                        Task {
                            if await viewModel.importInternetInspiration(
                                item: selectedItem,
                                name: name,
                                sourceName: sourceName,
                                sourceURL: sourceURL,
                                notes: notes,
                                tags: tags
                            ) {
                                dismiss()
                            }
                            isSaving = false
                        }
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("designs.internetInspiration.save")
                }
            }
        }
    }
}

private struct CakeDesignPreviewView: View {
    @State private var design: CakeDesign
    let photoSource: CakeDesignPhotoSource?
    let accessibilityLabel: String
    let onToggleFavorite: (CakeDesign) -> CakeDesign?
    let onUpdateTags: (String, CakeDesign) -> CakeDesign?
    let onDelete: (CakeDesign) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingTags = false
    @State private var tagsText = ""
    @State private var isConfirmingDelete = false

    init(
        design: CakeDesign,
        photoSource: CakeDesignPhotoSource?,
        accessibilityLabel: String,
        onToggleFavorite: @escaping (CakeDesign) -> CakeDesign?,
        onUpdateTags: @escaping (String, CakeDesign) -> CakeDesign?,
        onDelete: @escaping (CakeDesign) -> Bool
    ) {
        _design = State(initialValue: design)
        self.photoSource = photoSource
        self.accessibilityLabel = accessibilityLabel
        self.onToggleFavorite = onToggleFavorite
        self.onUpdateTags = onUpdateTags
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DesignPhotoView(source: photoSource, maximumPixelSize: 2_400, contentMode: .fit)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier("designs.preview.photo")

                CloudBakeDetailCard {
                    CloudBakeDetailRow("Name") {
                        Text(design.name)
                    }

                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Collection") {
                        Text(design.sourceKind == .internetInspiration ? "Internet Inspiration" : "My Designs")
                    }

                    if let sourceName = design.sourceName {
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Source") { Text(sourceName) }
                    }

                    if let sourceURL = design.sourceURL {
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Source URL") { Text(sourceURL) }
                    }

                    if let notes = design.notes {
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Notes") {
                            Text(notes)
                        }
                    }

                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Tags") {
                        Text(design.tags.isEmpty ? "None" : design.tags.joined(separator: ", "))
                    }

                    if design.photoReference == nil {
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Photo") {
                            Text("Unavailable")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(CloudBakeTheme.Spacing.screenHorizontal)
        }
        .background(CloudBakeScreenBackground().ignoresSafeArea())
        .navigationTitle(design.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let updated = onToggleFavorite(design) { design = updated }
                } label: {
                    Image(systemName: design.isFavorite ? "heart.fill" : "heart")
                }
                .accessibilityLabel(design.isFavorite ? "Remove Favorite" : "Add Favorite")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Tags") {
                    tagsText = design.tags.joined(separator: ", ")
                    isEditingTags = true
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) { isConfirmingDelete = true } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Remove Design")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .accessibilityIdentifier("designs.preview.done")
            }
        }
        .alert("Edit Tags", isPresented: $isEditingTags) {
            TextField("Comma-separated tags", text: $tagsText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let updated = onUpdateTags(tagsText, design) { design = updated }
            }
        }
        .alert("Remove Design?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if onDelete(design) { dismiss() }
            }
        } message: {
            Text("This removes the design from CloudBake. The image remains in Photos.")
        }
    }
}

extension CakeDesign: Identifiable {}

private actor DesignThumbnailLoader {
    static let shared = DesignThumbnailLoader()
    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 24 * 1_024 * 1_024
        return cache
    }()

    func image(for source: CakeDesignPhotoSource, maximumPixelSize: Int) async -> UIImage? {
        let cacheKey = NSString(string: "\(String(describing: source))@\(maximumPixelSize)")
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }
        let image: UIImage?
        switch source {
        case .legacyFile(let url):
            image = await Task<UIImage?, Never>.detached(priority: .utility) {
                guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(
                    imageSource,
                    0,
                    [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                        kCGImageSourceShouldCacheImmediately: true
                    ] as CFDictionary
                  ) else { return nil }
                return UIImage(cgImage: cgImage)
            }.value
        case .photosAsset(let identifier):
            image = await requestPhotosImage(identifier: identifier, maximumPixelSize: maximumPixelSize)
        }
        if let image {
            let pixelCount = image.size.width * image.size.height * image.scale * image.scale
            let cacheCost = Int(pixelCount * 4)
            cache.setObject(
                image,
                forKey: cacheKey,
                cost: cacheCost
            )
        }
        return image
    }

    private func requestPhotosImage(identifier: String, maximumPixelSize: Int) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            return nil
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: maximumPixelSize, height: maximumPixelSize),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if (info?[PHImageCancelledKey] as? Bool) == true {
                    continuation.resume(returning: nil)
                    return
                }
                guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
                continuation.resume(returning: image)
            }
        }
    }
}

struct DesignPhotoView: View {
    let source: CakeDesignPhotoSource?
    let maximumPixelSize: Int
    let contentMode: ContentMode
    @State private var image: UIImage?

    private var loadRequest: DesignPhotoLoadRequest {
        DesignPhotoLoadRequest(source: source, maximumPixelSize: maximumPixelSize)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ContentUnavailableView("Photo Unavailable", systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(Color.cloudBakePink)
                    .background(Color.cloudBakePink.opacity(0.10))
            }
        }
        .task(id: loadRequest) {
            image = nil
            guard let source else {
                return
            }
            let loadedImage = await DesignThumbnailLoader.shared.image(
                for: source,
                maximumPixelSize: maximumPixelSize
            )
            guard !Task.isCancelled else { return }
            image = loadedImage
        }
    }
}

private struct DesignPhotoLoadRequest: Hashable {
    let source: CakeDesignPhotoSource?
    let maximumPixelSize: Int
}
