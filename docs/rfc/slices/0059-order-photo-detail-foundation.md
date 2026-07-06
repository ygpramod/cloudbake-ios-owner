# Slice RFC-0059: Order Photo Detail Foundation

## Status

Implemented

## Parent RFC

- `docs/rfc/slices/0057-order-photos.md`

## Context

Order photo metadata exists in local SQLite, but the order detail workflow still needs a tested
application layer before camera and photo-library UI can safely write photos. This slice connects
order detail state to order photos and adds app-owned local file storage for image data.

## Scope

In scope:

- loading order photos when an order is selected,
- grouping selected order photos by customer reference and final cake type,
- adding an order photo from image data,
- storing photo bytes in app-owned local storage,
- persisting only the relative local photo path in SQLite,
- deleting photo metadata and its local file,
- focused view-model and file-store tests.

Out of scope:

- camera capture UI,
- photo-library picker UI,
- thumbnail rendering,
- captions editing UI,
- acceptance tests for photo picking,
- promoting final cake photos into the design library.

## Requirements

- Selecting an order must load the order's photos.
- Closing the order detail must clear selected photo state.
- The app must expose customer reference photos separately from final cake photos.
- Adding a photo must reject empty image data.
- Adding a photo must write image data to app-owned local storage before saving metadata.
- Photo metadata must store only a relative local path.
- Deleting a photo must remove the metadata and request deletion of the local file.
- The implementation must remain testable without camera hardware or photo-library access.

## Design

Add `OrderPhotoFileStore` as a small dependency owned by the order feature:

- `saveOrderPhoto(data:orderId:photoId:)`,
- `deleteOrderPhoto(relativePath:)`,
- `fileURL(for:)`.

`LocalOrderPhotoFileStore` stores photo data below the app-owned CloudBake Application Support
directory using this relative layout:

```text
OrderPhotos/<order-id>/<photo-id>.jpg
```

The order and photo identifiers are sanitized before becoming path components. The repository keeps
only this relative path in `order_photos.local_photo_path`.

`OrderListViewModel` now loads `selectedOrderPhotos` alongside recipe usage and checklist state.
It also exposes:

- `selectedCustomerReferencePhotos`,
- `selectedFinalCakePhotos`,
- `addOrderPhoto(kind:imageData:caption:)`,
- `deleteOrderPhoto(_:)`.

The UI picker slice can call `addOrderPhoto` after camera or photo-library selection without adding
database or file-system behavior to the SwiftUI view.

## Testing

Focused tests cover:

- selected order photo loading and grouping,
- clearing photo state when order detail closes,
- adding a photo saves bytes through the file store and metadata through the repository,
- empty image data is rejected,
- deleting a photo removes metadata and requests file deletion,
- the local file store writes, sanitizes, and deletes the stored file.

Acceptance tests are deferred to the picker UI slice because this slice has no visible owner-facing
photo controls yet.
