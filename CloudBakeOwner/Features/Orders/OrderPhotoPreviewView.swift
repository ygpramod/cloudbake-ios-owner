import SwiftUI

struct OrderPhotoPreviewView: View {
    let photo: OrderPhoto
    let photoSource: CakeDesignPhotoSource?
    let onSaveCaption: (String) -> OrderPhoto?
    let onPromoteToDesign: (String, String) async -> Bool
    let onAddToDesignReferences: (String) async -> Bool
    let onClose: () -> Void
    @State private var displayedPhoto: OrderPhoto
    @State private var draftCaption = ""
    @State private var isEditingCaption = false
    @State private var draftDesignName = ""
    @State private var draftDesignNotes = ""
    @State private var isPromotingToDesign = false
    @State private var isSavingDesign = false
    @State private var isAddingToReferences = false
    @State private var draftReferenceTags = ""

    init(
        photo: OrderPhoto,
        photoSource: CakeDesignPhotoSource?,
        onSaveCaption: @escaping (String) -> OrderPhoto?,
        onPromoteToDesign: @escaping (String, String) async -> Bool,
        onAddToDesignReferences: @escaping (String) async -> Bool,
        onClose: @escaping () -> Void
    ) {
        self.photo = photo
        self.photoSource = photoSource
        self.onSaveCaption = onSaveCaption
        self.onPromoteToDesign = onPromoteToDesign
        self.onAddToDesignReferences = onAddToDesignReferences
        self.onClose = onClose
        _displayedPhoto = State(initialValue: photo)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Button {
                        draftCaption = displayedPhoto.caption ?? ""
                        isEditingCaption = true
                    } label: {
                        Label("Edit Caption", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Edit Photo Caption")
                    .accessibilityIdentifier("orders.detail.photos.preview.editCaption")

                    if displayedPhoto.kind == .finalCake {
                        Button {
                            draftDesignName = displayedPhoto.caption ?? "Design From Final Cake"
                            draftDesignNotes = displayedPhoto.caption ?? ""
                            isPromotingToDesign = true
                        } label: {
                            Label("Save As Design", systemImage: "photo.on.rectangle.angled")
                                .labelStyle(.iconOnly)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Save Final Photo As Design")
                        .accessibilityIdentifier("orders.detail.photos.preview.promoteDesign")
                    }

                    if displayedPhoto.kind == .customerReference {
                        Button { isAddingToReferences = true } label: {
                            Label("Add to Design References", systemImage: "photo.badge.plus")
                                .labelStyle(.iconOnly)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Add to Design References")
                        .accessibilityIdentifier("orders.detail.photos.preview.addToReferences")
                    }

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close Photo Preview")
                    .accessibilityIdentifier("orders.detail.photos.preview.close")
                }

                Spacer(minLength: 0)

                DesignPhotoView(source: photoSource, maximumPixelSize: 2_400, contentMode: .fit)
                .accessibilityIdentifier("orders.detail.photos.preview.image")

                Spacer(minLength: 0)

                VStack(spacing: 6) {
                    Text(displayedPhoto.caption ?? displayedPhoto.kind.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("orders.detail.photos.preview.caption")

                    Text(displayedPhoto.kind.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .accessibilityIdentifier("orders.detail.photos.preview.kind")

                    Text(displayedPhoto.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.64))
                        .accessibilityIdentifier("orders.detail.photos.preview.createdAt")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(displayedPhoto.caption ?? displayedPhoto.kind.displayName), \(displayedPhoto.kind.displayName)")
                .accessibilityIdentifier("orders.detail.photos.preview.metadata")
                .padding(.bottom, 12)
            }
            .accessibilityElement(children: .contain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .accessibilityIdentifier("orders.detail.photos.preview.screen")
        .accessibilityLabel("\(displayedPhoto.caption ?? displayedPhoto.kind.displayName), \(displayedPhoto.kind.displayName)")
        .sheet(isPresented: $isPromotingToDesign) {
            NavigationStack {
                Form {
                    Section("Design") {
                        TextField("Name", text: $draftDesignName)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("orders.detail.photos.design.name")
                        TextField("Notes", text: $draftDesignNotes, axis: .vertical)
                            .lineLimit(2...4)
                            .accessibilityIdentifier("orders.detail.photos.design.notes")
                    }
                }
                .cloudBakeFormScreenStyle()
                .navigationTitle("Save Design")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPromotingToDesign = false
                        }
                        .disabled(isSavingDesign)
                        .accessibilityIdentifier("orders.detail.photos.design.cancel")
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard !isSavingDesign else { return }
                            isSavingDesign = true
                            Task {
                                if await onPromoteToDesign(draftDesignName, draftDesignNotes) {
                                    isPromotingToDesign = false
                                }
                                isSavingDesign = false
                            }
                        }
                        .disabled(isSavingDesign)
                        .accessibilityIdentifier("orders.detail.photos.design.save")
                    }
                }
            }
        }
        .sheet(isPresented: $isEditingCaption) {
            NavigationStack {
                Form {
                    Section("Caption") {
                        TextField("Caption", text: $draftCaption, axis: .vertical)
                            .lineLimit(2...4)
                            .accessibilityIdentifier("orders.detail.photos.caption.text")
                    }
                }
                .cloudBakeFormScreenStyle()
                .navigationTitle("Photo Caption")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isEditingCaption = false
                        }
                        .accessibilityIdentifier("orders.detail.photos.caption.cancel")
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let updatedPhoto = onSaveCaption(draftCaption) {
                                displayedPhoto = updatedPhoto
                                isEditingCaption = false
                            }
                        }
                        .accessibilityIdentifier("orders.detail.photos.caption.save")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingToReferences) {
            NavigationStack {
                Form {
                    Section("Reference") {
                        TextField("Tags separated by commas", text: $draftReferenceTags)
                            .accessibilityIdentifier("orders.detail.photos.reference.tags")
                    }
                }
                .cloudBakeFormScreenStyle()
                .navigationTitle("Add to References")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isAddingToReferences = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            guard !isSavingDesign else { return }
                            isSavingDesign = true
                            Task {
                                if await onAddToDesignReferences(draftReferenceTags) {
                                    isAddingToReferences = false
                                }
                                isSavingDesign = false
                            }
                        }
                        .disabled(isSavingDesign)
                        .accessibilityIdentifier("orders.detail.photos.reference.add")
                    }
                }
            }
        }
        .onChange(of: photo) { _, newPhoto in
            displayedPhoto = newPhoto
        }
    }
}
