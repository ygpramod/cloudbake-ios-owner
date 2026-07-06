# Slice RFC-0060: Order Photo Detail Library UI

## Status

Implemented

## Parent RFC

- `docs/rfc/slices/0057-order-photos.md`

## Context

The order photo model, persistence, file store, and view-model foundation are in place. The owner
now needs visible order detail controls to see saved photos and attach existing reference or final
cake photos from the iOS photo library.

## Scope

In scope:

- showing saved order photos in order detail,
- grouping photos as customer references and final cake photos,
- importing a customer reference photo from the photo library,
- importing a final cake photo from the photo library,
- converting imported images to local JPEG data before storing,
- deleting saved order photo rows from order detail,
- updating the photo-library privacy description,
- adding an acceptance fixture for saved order photos,
- focused acceptance coverage for saved photo display.

Out of scope:

- camera capture,
- retaking or replacing an existing order photo,
- image crop/edit tools,
- full-screen image preview,
- promoting final cake photos into the design library,
- AI design suggestions.

## Requirements

- Order detail must show a Photos section.
- The Photos section must separate customer reference photos from final cake photos.
- Each photo group must show an add action.
- The add action must use the iOS photo library and save through the order photo view-model path.
- Imported photos must remain local-first and app-owned.
- Saved photos must show a thumbnail area, caption or type fallback, and entry timestamp.
- The owner must be able to delete a saved photo row from order detail.
- The app's photo-library permission copy must include order photos.
- CI must not depend on automating the system photo picker.

## Design

`OrderDetail` adds a Photos section after the design section. Each group uses `PhotosPicker`:

- `Add Reference Photo`,
- `Add Final Cake Photo`.

When the owner selects an image, the view converts it to JPEG data where possible and calls
`OrderListViewModel.addOrderPhoto(kind:imageData:)`. The view model continues to own file storage
and metadata persistence.

Saved photo rows use the view model's app-local file URL to render a compact thumbnail. If the file
is missing or not renderable, the row still shows a photo placeholder so the metadata remains
visible and deletable.

Deletion uses a trailing swipe action and calls `OrderListViewModel.deleteOrderPhoto(_:)`, which
removes metadata and requests local file deletion.

## Testing

Focused tests cover:

- existing order photo view-model tests for add, delete, grouping, and local file storage,
- an in-memory acceptance fixture containing one customer reference photo and one final cake photo,
- an acceptance test proving order detail shows both photo groups, saved photo rows, and add actions.

Photo-library picker automation is intentionally not used in CI because the system picker is
outside the app process and is less reliable than testing the deterministic app-owned state.

## Follow-Up

- Add camera capture for reference and final cake photos.
- Add optional caption editing.
- Add full-screen photo preview.
