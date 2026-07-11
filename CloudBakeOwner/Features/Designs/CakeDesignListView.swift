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
            if !viewModel.hasContent {
                CloudBakeEmptyState(
                    title: "No designs yet",
                    systemImage: "photo.on.rectangle",
                    message: "Save final cake photos as designs from an order to build a searchable inspiration board."
                )
            } else {
                CloudBakeSearchField(
                    text: $viewModel.searchText,
                    prompt: "Search designs",
                    accessibilityIdentifier: "designs.search",
                    isFocused: $isSearchFocused
                )

                designResults
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            isSearchFocused = false
                        }
                    )
            }

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
                    accessibilityLabel: viewModel.accessibilityLabel(for: design)
                )
            }
        }
        .sheet(item: $previewingCustomerReference) { reference in
            NavigationStack {
                CustomerReferencePreviewView(
                    reference: reference,
                    photoSource: viewModel.availablePhotoSource(for: reference.photo)
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
            && !viewModel.searchText.isEmpty {
            CloudBakeEmptyState(
                title: "No matching designs",
                systemImage: "magnifyingglass",
                message: "Try another cake name, note, tag, or photo reference."
            )
        } else {
            if !viewModel.visibleDesigns.isEmpty {
            Text("My Designs (\(viewModel.visibleDesigns.count))")
                .font(CloudBakeTheme.Typography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("designs.myDesigns.title")

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 14)
                ],
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
            DesignPhotoView(
                source: viewModel.availablePhotoSource(for: reference.photo),
                maximumPixelSize: 600,
                contentMode: .fill
            )
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .cloudBakeCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reference.title), customer reference from \(reference.order.customerName)")
        .accessibilityIdentifier("designs.customerReference.\(reference.id)")
    }

    private func designTile(_ design: CakeDesign) -> some View {
        Button {
            previewingDesign = design
        } label: {
            DesignPhotoView(
                source: viewModel.availablePhotoSource(for: design),
                maximumPixelSize: 600,
                contentMode: .fill
            )
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cloudBakeCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.accessibilityLabel(for: design))
        .accessibilityIdentifier("designs.item.\(design.id)")
    }

}

private struct CustomerReferencePreviewView: View {
    let reference: CustomerReferenceDesign
    let photoSource: CakeDesignPhotoSource?
    @Environment(\.dismiss) private var dismiss

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
                }
            }
            .padding(CloudBakeTheme.Spacing.screenHorizontal)
        }
        .background(CloudBakeScreenBackground().ignoresSafeArea())
        .navigationTitle(reference.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
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
                                notes: notes
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
    let design: CakeDesign
    let photoSource: CakeDesignPhotoSource?
    let accessibilityLabel: String
    @Environment(\.dismiss) private var dismiss

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
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .accessibilityIdentifier("designs.preview.done")
            }
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
