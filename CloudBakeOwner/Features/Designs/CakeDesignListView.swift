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
                    designs: design.sourceKind == .internetInspiration
                        ? viewModel.visibleInternetInspirations
                        : viewModel.visibleDesigns,
                    photoSource: viewModel.availablePhotoSource,
                    accessibilityLabel: viewModel.accessibilityLabel,
                    usageOrders: viewModel.usageOrders,
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
                    references: viewModel.visibleCustomerReferences,
                    photoSource: { viewModel.availablePhotoSource(for: $0.photo) },
                    usageOrders: viewModel.usageOrders,
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
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(viewModel.visibleCustomerReferences) { reference in
                        customerReferenceTile(reference)
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
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(viewModel.visibleInternetInspirations, id: \.id) { design in
                        designTile(design)
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
                isFavorite: reference.photo.isFavorite,
                usageCount: viewModel.usageCount(for: reference)
            )
        }
        .buttonStyle(.plain)
        .cloudBakeCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(reference.title), customer reference from \(reference.order.customerName)"
                + (reference.photo.isFavorite ? ", favorite" : "")
                + usageAccessibilitySuffix(count: viewModel.usageCount(for: reference))
        )
        .accessibilityIdentifier("designs.customerReference.\(reference.id)")
    }

    private func designTile(_ design: CakeDesign) -> some View {
        Button {
            previewingDesign = design
        } label: {
            photoTile(
                source: viewModel.availablePhotoSource(for: design),
                isFavorite: design.isFavorite,
                usageCount: viewModel.usageCount(for: design)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cloudBakeCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            viewModel.accessibilityLabel(for: design)
                + usageAccessibilitySuffix(count: viewModel.usageCount(for: design))
        )
        .accessibilityIdentifier("designs.item.\(design.id)")
    }

    private func usageAccessibilitySuffix(count: Int) -> String {
        ", used in \(count) \(count == 1 ? "order" : "orders")"
    }

    private func photoTile(
        source: CakeDesignPhotoSource?,
        isFavorite: Bool,
        usageCount: Int
    ) -> some View {
        ZStack {
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            if usageCount > 0 {
                Text("Used \(usageCount)×")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.58), in: Capsule())
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }

}

private struct CustomerReferencePreviewView: View {
    @State private var reference: CustomerReferenceDesign
    let references: [CustomerReferenceDesign]
    let photoSource: (CustomerReferenceDesign) -> CakeDesignPhotoSource?
    let usageOrders: (CustomerReferenceDesign) -> [Order]
    let onToggleFavorite: (CustomerReferenceDesign) -> CustomerReferenceDesign?
    let onUpdateTags: (String, CustomerReferenceDesign) -> CustomerReferenceDesign?
    let onDelete: (CustomerReferenceDesign) -> Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var orderNavigationRouter: OrderNavigationRouter
    @State private var isEditingTags = false
    @State private var tagsText = ""
    @State private var isConfirmingDelete = false

    init(
        reference: CustomerReferenceDesign,
        references: [CustomerReferenceDesign],
        photoSource: @escaping (CustomerReferenceDesign) -> CakeDesignPhotoSource?,
        usageOrders: @escaping (CustomerReferenceDesign) -> [Order],
        onToggleFavorite: @escaping (CustomerReferenceDesign) -> CustomerReferenceDesign?,
        onUpdateTags: @escaping (String, CustomerReferenceDesign) -> CustomerReferenceDesign?,
        onDelete: @escaping (CustomerReferenceDesign) -> Bool
    ) {
        _reference = State(initialValue: reference)
        self.references = references
        self.photoSource = photoSource
        self.usageOrders = usageOrders
        self.onToggleFavorite = onToggleFavorite
        self.onUpdateTags = onUpdateTags
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZoomableDesignPhoto(
                    source: photoSource(reference),
                    accessibilityLabel: "\(reference.title), customer reference",
                    accessibilityIdentifier: "designs.customerReference.preview.photo"
                )
                .id(reference.id)

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

                CloudBakeDetailCard {
                    CloudBakeDetailRow("Used In") {
                        Text("\(currentUsageOrders.count) order\(currentUsageOrders.count == 1 ? "" : "s")")
                    }
                    ForEach(currentUsageOrders, id: \.id) { order in
                        CloudBakeDetailDivider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(order.title)
                                .font(.body.weight(.semibold))
                            Text(order.dueAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                }

                Button {
                    orderNavigationRouter.beginNewOrder(
                        designReference: .customerReference(photoId: reference.photo.id)
                    )
                    dismiss()
                } label: {
                    Label("Use for New Order", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cloudBakePink)
                .controlSize(.large)
                .accessibilityIdentifier("designs.customerReference.useForNewOrder")
            }
            .padding(CloudBakeTheme.Spacing.screenHorizontal)
        }
        .simultaneousGesture(adjacentReferenceSwipe)
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
        .cloudBakeCenteredPopup(
            isPresented: isConfirmingDelete,
            title: "Remove Customer Reference?",
            subtitle: "Remove this reference from CloudBake and its order. The image remains in Photos.",
            systemImage: "trash",
            cancelAccessibilityIdentifier: "designs.customerReference.delete.cancel",
            onCancel: { isConfirmingDelete = false }
        ) {
            centeredPopupButton("Remove Customer Reference", role: .destructive) {
                if onDelete(reference) { dismiss() }
            }
            .accessibilityIdentifier("designs.customerReference.delete.confirm")
        }
    }

    private var currentUsageOrders: [Order] {
        usageOrders(reference)
    }

    private var adjacentReferenceSwipe: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.4,
                      abs(value.translation.width) >= 72,
                      let index = references.firstIndex(where: { $0.id == reference.id }) else {
                    return
                }
                let nextIndex = value.translation.width < 0 ? index + 1 : index - 1
                guard references.indices.contains(nextIndex) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    reference = references[nextIndex]
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
    let designs: [CakeDesign]
    let photoSource: (CakeDesign) -> CakeDesignPhotoSource?
    let accessibilityLabel: (CakeDesign) -> String
    let usageOrders: (CakeDesign) -> [Order]
    let onToggleFavorite: (CakeDesign) -> CakeDesign?
    let onUpdateTags: (String, CakeDesign) -> CakeDesign?
    let onDelete: (CakeDesign) -> Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var orderNavigationRouter: OrderNavigationRouter
    @State private var isEditingTags = false
    @State private var tagsText = ""
    @State private var isConfirmingDelete = false

    init(
        design: CakeDesign,
        designs: [CakeDesign],
        photoSource: @escaping (CakeDesign) -> CakeDesignPhotoSource?,
        accessibilityLabel: @escaping (CakeDesign) -> String,
        usageOrders: @escaping (CakeDesign) -> [Order],
        onToggleFavorite: @escaping (CakeDesign) -> CakeDesign?,
        onUpdateTags: @escaping (String, CakeDesign) -> CakeDesign?,
        onDelete: @escaping (CakeDesign) -> Bool
    ) {
        _design = State(initialValue: design)
        self.designs = designs
        self.photoSource = photoSource
        self.accessibilityLabel = accessibilityLabel
        self.usageOrders = usageOrders
        self.onToggleFavorite = onToggleFavorite
        self.onUpdateTags = onUpdateTags
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZoomableDesignPhoto(
                    source: photoSource(design),
                    accessibilityLabel: accessibilityLabel(design),
                    accessibilityIdentifier: "designs.preview.photo"
                )
                .id(design.id)

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

                Button {
                    orderNavigationRouter.beginNewOrder(
                        designReference: .cakeDesign(id: design.id)
                    )
                    dismiss()
                } label: {
                    Label("Use for New Order", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cloudBakePink)
                .controlSize(.large)
                .accessibilityIdentifier("designs.preview.useForNewOrder")

                CloudBakeDetailCard {
                    CloudBakeDetailRow("Used In") {
                        Text(currentUsageOrders.isEmpty ? "No linked orders" : "\(currentUsageOrders.count) order\(currentUsageOrders.count == 1 ? "" : "s")")
                    }
                    ForEach(currentUsageOrders, id: \.id) { order in
                        CloudBakeDetailDivider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(order.title)
                                .font(.body.weight(.semibold))
                            Text(order.dueAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(CloudBakeTheme.Spacing.screenHorizontal)
        }
        .simultaneousGesture(adjacentDesignSwipe)
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
        .cloudBakeCenteredPopup(
            isPresented: isConfirmingDelete,
            title: "Remove Design?",
            subtitle: "Remove this design from CloudBake. The image remains in Photos.",
            systemImage: "trash",
            cancelAccessibilityIdentifier: "designs.delete.cancel",
            onCancel: { isConfirmingDelete = false }
        ) {
            centeredPopupButton("Remove Design", role: .destructive) {
                if onDelete(design) { dismiss() }
            }
            .accessibilityIdentifier("designs.delete.confirm")
        }
    }

    private var currentUsageOrders: [Order] {
        usageOrders(design)
    }

    private var adjacentDesignSwipe: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.4,
                      abs(value.translation.width) >= 72,
                      let index = designs.firstIndex(where: { $0.id == design.id }) else {
                    return
                }
                let nextIndex = value.translation.width < 0 ? index + 1 : index - 1
                guard designs.indices.contains(nextIndex) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    design = designs[nextIndex]
                }
            }
    }
}

extension CakeDesign: Identifiable {}

private struct ZoomableDesignPhoto: View {
    let source: CakeDesignPhotoSource?
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    @State private var scale: CGFloat = 1
    @State private var gestureStartScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 10) {
            DesignPhotoView(source: source, maximumPixelSize: 2_400, contentMode: .fit)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .center)
                .scaleEffect(scale)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = clampedScale(gestureStartScale * value)
                        }
                        .onEnded { _ in
                            gestureStartScale = scale
                        }
                )
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: zoom(by: 0.5)
                    case .decrement: zoom(by: -0.5)
                    @unknown default: break
                    }
                }

            HStack(spacing: 12) {
                zoomButton(systemImage: "minus.magnifyingglass", label: "Zoom Out") {
                    zoom(by: -0.5)
                }
                zoomButton(systemImage: "1.magnifyingglass", label: "Reset Zoom") {
                    setScale(1)
                }
                zoomButton(systemImage: "plus.magnifyingglass", label: "Zoom In") {
                    zoom(by: 0.5)
                }
            }
            .accessibilityIdentifier("designs.preview.zoomControls")
        }
    }

    private func zoomButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(minWidth: 44, minHeight: 32)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .accessibilityLabel(label)
    }

    private func zoom(by amount: CGFloat) {
        setScale(scale + amount)
    }

    private func setScale(_ value: CGFloat) {
        withAnimation(.easeInOut(duration: 0.15)) {
            scale = clampedScale(value)
            gestureStartScale = scale
        }
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), 4)
    }
}

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
