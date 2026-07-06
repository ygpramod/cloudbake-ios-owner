# Slice RFC-0057: Order Photos

## Status

Proposed

## Parent RFC

- `docs/rfc/orders.md`

## Context

Orders can already link to one saved cake design reference. That is useful design memory, but it is
not enough for day-to-day handmade cake work. The owner also needs order-specific photos: customer
reference images before preparation and final cake photos after completion.

This slice starts order photo capture without adding AI design suggestions or a full design library
workflow.

## Scope

In scope:

- storing order-specific photo references locally,
- distinguishing customer reference photos from final cake photos,
- adding photos from camera or photo library,
- showing order photos in order detail,
- deleting mistaken order photo references,
- preserving photo entry order,
- updating RFC and wiki documentation,
- adding focused persistence, view-model, and acceptance coverage.

Out of scope:

- AI design suggestions,
- automatic design improvement suggestions,
- cloud photo sync,
- sharing photos with customers,
- editing/cropping/filtering photos,
- multiple design references per order,
- replacing the saved cake design library,
- backend media upload.

## Requirements

- The owner must be able to add a customer reference photo to an order.
- The owner must be able to add a final cake photo to an order.
- The owner must be able to choose camera capture or photo library import when adding a photo.
- Order detail must show saved order photos grouped by photo type.
- Order photos must remain ordered by entry order inside each type.
- The owner must be able to delete a mistaken order photo.
- Photo storage must remain local-first.
- Photo records must reference the order by stable order id.
- Deleting a photo record must not delete the order or linked design reference.
- Existing orders must remain valid after the migration.

## Design

Add an `OrderPhoto` domain model:

- `id`,
- `orderId`,
- `kind`,
- `localPhotoPath`,
- optional `caption`,
- `createdAt`,
- `updatedAt`.

Add `OrderPhotoKind` with:

- `customerReference`,
- `finalCake`.

Add an `order_photos` local table with an order id, kind, local photo path, optional caption, and
timestamps. Photo files should be saved in app-owned local storage and the database should store the
relative app-local path rather than image binary data.

Order detail should add a Photos section with compact thumbnail rows grouped as Customer References
and Final Cake Photos. The add action should offer Reference Photo and Final Cake Photo choices.
Each choice can then use camera capture or photo library import, following the existing purchase
bill and recipe scan patterns.

## Testing

Focused tests should cover:

- domain mapping for `OrderPhotoKind`,
- persistence save/fetch/delete for order photos,
- fetching photos ordered by entry order,
- view-model loading photos when an order is selected,
- view-model deleting only the selected photo,
- acceptance flow for adding a reference photo from the photo library where simulator-safe,
- acceptance flow for deleting a saved photo from order detail.

Camera capture can be covered through manual device testing and unit-level picker routing because
simulators and CI do not reliably provide camera hardware.

## Owner Workflow

From order detail, the owner can add customer reference photos before making the cake and final cake
photos after completion. The photos belong to the order itself. Linking a saved cake design remains
separate design memory, while order photos capture what this customer asked for and what was
delivered.

## Future Work

- captions and design notes per photo,
- promoting a final order photo into the saved design library,
- customer-safe photo sharing,
- iCloud or backend media sync,
- AI-assisted design comparison and minor improvement suggestions,
- storage cleanup for orphaned files.
