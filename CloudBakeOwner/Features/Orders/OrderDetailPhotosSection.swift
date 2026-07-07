import PhotosUI
import SwiftUI
import UIKit

struct OrderDetailPhotosSection: View {
    let customerReferencePhotos: [OrderPhoto]
    let finalCakePhotos: [OrderPhoto]
    @Binding var selectedCustomerReferencePhotoItem: PhotosPickerItem?
    @Binding var selectedFinalCakePhotoItem: PhotosPickerItem?
    let photoURL: (OrderPhoto) -> URL
    let onPreviewPhoto: (OrderPhoto) -> Void
    let onDeletePhoto: (OrderPhoto) -> Void
    let onTakePhoto: (OrderPhotoKind) -> Void

    var body: some View {
        Section("Photos") {
            photoGroup(
                title: "Customer References",
                emptyText: "No reference photos",
                photos: customerReferencePhotos,
                pickerTitle: "Add Reference Photo",
                pickerIdentifier: "orders.detail.photos.reference.add",
                cameraIdentifier: "orders.detail.photos.reference.camera",
                selection: $selectedCustomerReferencePhotoItem,
                photoKind: .customerReference
            )

            photoGroup(
                title: "Final Cake Photos",
                emptyText: "No final cake photos",
                photos: finalCakePhotos,
                pickerTitle: "Add Final Cake Photo",
                pickerIdentifier: "orders.detail.photos.final.add",
                cameraIdentifier: "orders.detail.photos.final.camera",
                selection: $selectedFinalCakePhotoItem,
                photoKind: .finalCake
            )
        }
    }

    @ViewBuilder
    private func photoGroup(
        title: String,
        emptyText: String,
        photos: [OrderPhoto],
        pickerTitle: String,
        pickerIdentifier: String,
        cameraIdentifier: String,
        selection: Binding<PhotosPickerItem?>,
        photoKind: OrderPhotoKind
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("\(pickerIdentifier).header")

            Spacer()

            PhotosPicker(selection: selection, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "plus")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(pickerTitle)
            .accessibilityIdentifier(pickerIdentifier)

            Button {
                onTakePhoto(photoKind)
            } label: {
                Image(systemName: "camera")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            .accessibilityLabel("Take \(photoKind.displayName)")
            .accessibilityIdentifier(cameraIdentifier)
        }

        if photos.isEmpty {
            Text(emptyText)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("\(pickerIdentifier).empty")
        } else {
            ForEach(photos, id: \.id) { photo in
                orderPhotoRow(photo)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDeletePhoto(photo)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityIdentifier("orders.detail.photos.delete.\(photo.id)")
                    }
            }
        }
    }

    private func orderPhotoRow(_ photo: OrderPhoto) -> some View {
        Button {
            onPreviewPhoto(photo)
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: photoURL(photo)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.quaternary)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(photo.caption ?? photo.kind.displayName)
                        .font(.body)
                        .accessibilityIdentifier("orders.detail.photos.item.\(photo.id)")
                    Text(photo.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("orders.detail.photos.preview.\(photo.id)")
        .accessibilityElement(children: .combine)
    }
}

extension OrderPhotoKind {
    var displayName: String {
        switch self {
        case .customerReference:
            return "Reference Photo"
        case .finalCake:
            return "Final Cake Photo"
        }
    }
}
