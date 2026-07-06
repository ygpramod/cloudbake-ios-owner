# Slice RFC-0058: Order Photo Persistence

## Status

Implemented

## Parent RFC

- `docs/rfc/slices/0057-order-photos.md`

## Context

Order photos need a local data foundation before the app can add camera, photo-library, and order
detail UI flows. This slice stores the order-photo metadata in SQLite while leaving image capture
and file writing for the next UI slice.

## Scope

In scope:

- order photo domain types,
- local `order_photos` table,
- repository save, fetch, and delete operations,
- stable ordering by photo kind and entry order,
- focused domain and persistence tests.

Out of scope:

- camera capture,
- photo library import,
- writing image files to app storage,
- thumbnails and order detail UI,
- acceptance tests for photo flows,
- promoting order photos into the design library.

## Requirements

- The model must distinguish customer reference photos from final cake photos.
- Photo records must reference the parent order by stable order id.
- Photo records must store a local app-owned relative path instead of image binary data.
- Photo records may store an optional caption.
- Fetching photos for an order must preserve entry order within each photo kind.
- Deleting a photo record must not delete its order.
- Existing orders must remain valid after migration.

## Design

Add `OrderPhotoKind` with `customerReference` and `finalCake`.

Add `OrderPhoto` with:

- `id`,
- `orderId`,
- `kind`,
- `localPhotoPath`,
- optional `caption`,
- `createdAt`,
- `updatedAt`.

Add migration `0012_create_order_photos` with an `order_photos` table. The table references
`orders(id)` with cascade delete so photo metadata does not survive after its parent order is
deleted. The app stores only the relative local photo path in SQLite; binary image storage remains
outside the database.

Add `OrderPhotoRepository` to the existing core repository surface:

- `save(_:)`,
- `fetchOrderPhotos(orderId:)`,
- `deleteOrderPhoto(id:)`.

## Testing

Focused tests cover:

- `OrderPhotoKind` raw values and cases,
- order photo round trip through the fresh in-memory database,
- fetching customer references before final cake photos,
- preserving entry order within the same photo kind,
- deleting a photo record without deleting the order.

Acceptance tests are deferred to the UI slice because this slice has no owner-facing controls.
