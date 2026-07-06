# Slice RFC-0064: Order Final Photo Design Promotion

## Status

Implemented

## Parent RFC

- `docs/rfc/slices/0057-order-photos.md`

## Context

Final cake photos are the owner's strongest design memory because they show what was actually
handmade and delivered. After an order is complete, the owner should be able to save a good final
photo as a reusable cake design without manually recreating the design record elsewhere.

## Scope

In scope:

- promoting a saved final cake order photo into the local cake design library,
- asking the owner for the design name and optional notes before saving,
- using the final photo's local path as the design photo reference,
- linking the current order to the newly saved design,
- focused unit and acceptance coverage.

Out of scope:

- promoting customer reference photos,
- editing the design after promotion,
- copying image files into a separate design-photo store,
- a full Designs screen,
- AI-assisted design suggestions.

## Requirements

- The owner must be able to start promotion from the saved final cake photo preview.
- Customer reference photos must not expose the save-as-design action.
- A promoted design must require a non-empty design name.
- The promoted design must preserve optional owner notes.
- The promoted design must reference the final photo's local stored path.
- The order must link to the newly promoted design after save.
- Existing photo preview, caption editing, and delete behavior must continue to work.

## Design

`OrderListViewModel.promoteFinalCakePhotoToDesign(_:name:notes:)` validates that the photo belongs
to the currently selected order and is a final cake photo. It creates a `CakeDesign` with the
owner-entered name, optional notes, and the order photo's local path as `photoReference`, then saves
the design and updates the selected order's `cakeDesignId`.

The preview UI shows a save-as-design action only for final cake photos. The action opens a compact
form with name and notes fields. After a successful save, the preview closes and order detail shows
the linked design section.

This slice intentionally reuses the existing local order-photo path. A later full design-library
slice can decide whether design photos need their own storage location or richer metadata.

## Testing

Focused tests cover:

- unit-level promotion of a final cake photo into a saved design,
- trimming name and notes,
- linking the selected order to the new design,
- rejecting customer reference photo promotion,
- acceptance coverage from final photo preview through linked design display.

## Follow-Up

- Add a full Designs screen for browsing and editing saved designs.
- Add richer design metadata and owner-reviewed improvement notes.
