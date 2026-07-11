import SwiftUI

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
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cloudBakePink.opacity(0.16),
                                    Color.cloudBakeMint.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 8) {
                        Image(systemName: design.photoReference == nil ? "photo.badge.exclamationmark" : "photo")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Color.cloudBakePink)

                        Text(design.photoReference == nil ? "No photo" : "Photo reference")
                            .font(CloudBakeTheme.Typography.metadata.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(12)
                }
                .aspectRatio(1, contentMode: .fit)

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
    let accessibilityLabel: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cloudBakePink.opacity(0.18),
                                    Color.cloudBakePurple.opacity(0.16),
                                    Color.cloudBakeMint.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 12) {
                        Image(systemName: design.photoReference == nil ? "photo.badge.exclamationmark" : "photo.on.rectangle.angled")
                            .font(.system(size: 58, weight: .semibold))
                            .foregroundStyle(Color.cloudBakePink)

                        Text(design.photoReference == nil ? "Photo unavailable" : "Referenced Photos asset")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier("designs.preview.photo")

                CloudBakeDetailCard {
                    CloudBakeDetailRow("Name") {
                        Text(design.name)
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
