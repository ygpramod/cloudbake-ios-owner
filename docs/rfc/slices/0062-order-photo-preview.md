# Slice RFC-0062: Order Photo Preview

## Status

Implemented

## Parent RFC

- `docs/rfc/slices/0057-order-photos.md`

## Context

Order detail can now store customer reference photos and final cake photos from the photo library or
camera. The owner needs a clearer way to inspect a saved handmade cake reference without relying on
the small thumbnail in the order detail list.

## Scope

In scope:

- opening a saved order photo from order detail,
- showing the selected photo in a focused full-screen preview,
- showing the photo caption or fallback type, photo kind, and captured/saved timestamp,
- closing the preview back to the order detail screen,
- focused acceptance coverage for the preview flow.

Out of scope:

- caption editing,
- retaking or replacing an existing photo,
- crop or annotation tools,
- promoting final cake photos into the cake design library.

## Requirements

- Saved order photo rows must be tappable from order detail.
- Tapping a saved order photo must open a full-screen preview.
- The preview must show the selected image when the local file is available.
- The preview must provide readable metadata even when the image file cannot be opened.
- The preview must include an explicit close action.
- Existing photo deletion must remain available from order detail.

## Design

`OrderDetailView` stores the selected `OrderPhoto` in local view state and presents an
`OrderPhotoPreviewView` with `fullScreenCover`. The preview uses the existing
`OrderListViewModel.orderPhotoURL(_:)` path, so no new persistence behavior is introduced.

The row itself becomes a plain-styled button so the whole photo row is an inspection target.

RFC-0070 later moved order detail to card-based styling and replaced swipe-delete with a visible
delete row action.

The preview uses a dark background so cake photos and customer references can be inspected without
the surrounding form competing for attention. If the saved image file cannot be opened, the preview
still shows the caption/type metadata and an unavailable-photo placeholder.

## Testing

Focused tests cover:

- the existing saved-photo acceptance fixture,
- opening a customer reference photo preview,
- verifying the preview caption and kind,
- closing the preview back to order detail.

## Follow-Up

- Add optional caption editing.
- Add a promote-to-design-library flow for final cake photos.
