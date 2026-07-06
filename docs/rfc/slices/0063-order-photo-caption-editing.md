# Slice RFC-0063: Order Photo Caption Editing

## Status

Implemented

## Parent RFC

- `docs/rfc/slices/0057-order-photos.md`

## Context

Order detail can store and preview customer reference photos and final cake photos. Captions make
those photos more useful as handmade cake references because the owner can note what the image is
for, such as customer sketch, finished cake, topper placement, or a design improvement idea.

## Scope

In scope:

- editing a saved order photo caption from the photo preview,
- persisting the updated caption locally,
- refreshing the order detail photo row and preview after save,
- trimming blank space and allowing an empty caption to clear the caption,
- focused unit and acceptance coverage.

Out of scope:

- editing photo kind,
- replacing or retaking the photo,
- crop or annotation tools,
- promoting final cake photos into the cake design library.

## Requirements

- The owner must be able to open caption editing from the saved photo preview.
- Saving a caption must update the existing photo metadata without changing the stored image file.
- Caption values must be trimmed before persistence.
- An empty caption must clear the saved caption and fall back to the photo kind label.
- The preview and order detail row must show the updated caption after save.
- Existing preview and delete behavior must continue to work.

## Design

`OrderListViewModel.updateOrderPhotoCaption(_:caption:)` creates an updated `OrderPhoto` with the
same id, order id, kind, local photo path, and created timestamp. It trims the owner-entered caption
through the existing optional text normalization and saves through the current order photo repository
upsert path.

`OrderPhotoPreviewView` exposes an edit button in the preview toolbar. The edit flow is a small
sheet with a caption text field and Save/Cancel actions. After a successful save, the preview updates
its displayed photo and the parent order detail state is refreshed from `selectedOrderPhotos`.

No schema change is needed because order photo captions already exist in the local model.

## Testing

Focused tests cover:

- unit-level caption update persistence and timestamp behavior,
- opening a saved photo preview,
- editing and saving a caption from the preview,
- verifying the updated caption in preview and order detail.

## Follow-Up

- Add a promote-to-design-library flow for final cake photos.
