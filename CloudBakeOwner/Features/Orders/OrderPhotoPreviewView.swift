import SwiftUI

struct OrderPhotoPreviewView: View {
    let photo: OrderPhoto
    let photoURL: URL
    let onSaveCaption: (String) -> OrderPhoto?
    let onPromoteToDesign: (String, String) -> Bool
    let onClose: () -> Void
    @State private var displayedPhoto: OrderPhoto
    @State private var draftCaption = ""
    @State private var isEditingCaption = false
    @State private var draftDesignName = ""
    @State private var draftDesignNotes = ""
    @State private var isPromotingToDesign = false

    init(
        photo: OrderPhoto,
        photoURL: URL,
        onSaveCaption: @escaping (String) -> OrderPhoto?,
        onPromoteToDesign: @escaping (String, String) -> Bool,
        onClose: @escaping () -> Void
    ) {
        self.photo = photo
        self.photoURL = photoURL
        self.onSaveCaption = onSaveCaption
        self.onPromoteToDesign = onPromoteToDesign
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

                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        ContentUnavailableView(
                            "Photo Unavailable",
                            systemImage: "photo",
                            description: Text("The saved image could not be opened.")
                        )
                        .foregroundStyle(.white)
                    }
                }
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
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
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
                .navigationTitle("Save Design")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPromotingToDesign = false
                        }
                        .accessibilityIdentifier("orders.detail.photos.design.cancel")
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if onPromoteToDesign(draftDesignName, draftDesignNotes) {
                                isPromotingToDesign = false
                            }
                        }
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
        .onChange(of: photo) { _, newPhoto in
            displayedPhoto = newPhoto
        }
    }
}
