# Slice RFC-0093: Designs Simplification And Order Picker

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Scope

1. Remove Internet Inspiration from the visible Designs and order-linking experiences.
2. Preserve historical Internet Inspiration provenance privately for migration safety.
3. Remove the broad simultaneous tap gesture that competed with vertical scrolling at the end of
   the Designs page.
4. Limit the filter ribbon to the ten tags used by the most visible design/reference records.
5. Replace the order design list with a photo-first, searchable, tag-filterable Designs grid.
6. Keep order selection limited to owner-made designs while retaining the separate customer
   reference link.

## Test Strategy

1. Unit tests cover frequency-ranked tag limits, owner-only order choices, AND-style name/tag
   search, and tag filtering.
2. Acceptance covers scrolling to the final design and returning to search without oscillation.
3. Acceptance covers the photo-first order picker, search, selection, and customer-reference state.

## Documentation Decision

The parent RFC and wiki sources are updated because visible product scope and an owner workflow
changed. Historical slice RFC-0083 remains as implementation history, not current capability.
