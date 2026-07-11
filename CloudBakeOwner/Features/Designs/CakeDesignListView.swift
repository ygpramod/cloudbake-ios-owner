import ImageIO
import SwiftUI
import UIKit

struct CakeDesignListView: View {
    @StateObject private var viewModel: CakeDesignListViewModel
    @State private var previewingDesign: CakeDesign?
    @FocusState private var isSearchFocused: Bool

    init(viewModel: CakeDesignListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        CloudBakeScreenScaffold(
            title: "Designs",
            selectedDestination: .designs
        ) {
            if viewModel.designs.isEmpty {
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
                    photoURL: viewModel.availablePhotoURL(for: design),
                    accessibilityLabel: viewModel.accessibilityLabel(for: design)
                )
            }
        }
        .onAppear {
            viewModel.load()
        }
    }

    @ViewBuilder
    private var designResults: some View {
        if viewModel.visibleDesigns.isEmpty {
            CloudBakeEmptyState(
                title: "No matching designs",
                systemImage: "magnifyingglass",
                message: "Try another cake name, note, tag, or photo reference."
            )
        } else {
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
    }

    private func designTile(_ design: CakeDesign) -> some View {
        Button {
            previewingDesign = design
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                DesignThumbnailView(photoURL: viewModel.availablePhotoURL(for: design))
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text(design.name)
                    .font(CloudBakeTheme.Typography.rowTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let notes = design.notes {
                    Text(notes)
                        .font(CloudBakeTheme.Typography.rowDetail)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cloudBakeCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.accessibilityLabel(for: design))
        .accessibilityIdentifier("designs.item.\(design.id)")
    }

}

private struct CakeDesignPreviewView: View {
    let design: CakeDesign
    let photoURL: URL?
    let accessibilityLabel: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AsyncImage(url: photoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        ContentUnavailableView("Photo Unavailable", systemImage: "photo.badge.exclamationmark")
                            .foregroundStyle(Color.cloudBakePink)
                            .background(Color.cloudBakePink.opacity(0.10))
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier("designs.preview.photo")

                CloudBakeDetailCard {
                    CloudBakeDetailRow("Name") {
                        Text(design.name)
                    }

                    CloudBakeDetailDivider()
                    CloudBakeDetailRow("Collection") {
                        Text("My Designs")
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
        .background(Color.cloudBakeBlush.ignoresSafeArea())
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
    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 24 * 1_024 * 1_024
        return cache
    }()

    func thumbnail(for url: URL, maximumPixelSize: Int) async -> UIImage? {
        if let cachedImage = cache.object(forKey: url as NSURL) {
            return cachedImage
        }
        let image: UIImage? = await Task<UIImage?, Never>.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(
                    source,
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
        if let image {
            let pixelCount = image.size.width * image.size.height * image.scale * image.scale
            let cacheCost = Int(pixelCount * 4)
            cache.setObject(
                image,
                forKey: url as NSURL,
                cost: cacheCost
            )
        }
        return image
    }
}

private struct DesignThumbnailView: View {
    let photoURL: URL?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ContentUnavailableView("Photo Unavailable", systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(Color.cloudBakePink)
                    .background(Color.cloudBakePink.opacity(0.10))
            }
        }
        .task(id: photoURL) {
            guard let photoURL else {
                image = nil
                return
            }
            image = await DesignThumbnailLoader.shared.thumbnail(for: photoURL, maximumPixelSize: 600)
        }
    }
}
