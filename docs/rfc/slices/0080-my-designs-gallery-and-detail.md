# Slice RFC-0080: My Designs Gallery And Detail

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

With persisted provenance established, the owner needs a trustworthy photo-first view of cakes
made by the bakery. The existing Designs view listed every design source and displayed placeholders
instead of the referenced final-cake photos. The owner subsequently clarified that Photos, not the
app container, must own every Designs-library image.

## Scope

In scope:

1. Scope the first collection to owner-made designs.
2. Present the collection as a compact photo-first grid with a visible count.
3. Load promoted final-cake photos from their stored reference in the gallery and detail view.
4. Keep missing files explicit and accessible rather than misrepresenting them as valid photos.
5. Show the design name, notes, and My Designs collection identity in detail.

Out of scope:

1. Customer references and internet inspiration.
2. Tags, filters, favourites, and usage history.
3. Use for New Order, zoom, swipe, and thumbnail caching.

## Design

`CakeDesignListViewModel` requests only `.ownerMade` records. It resolves canonical Photos asset
identifiers through PhotoKit and retains read-only compatibility for legacy app-relative order-photo
references. Missing or deleted assets use an explicit unavailable state.

## Test Strategy

1. View-model coverage proves non-owner sources are excluded.
2. Existing search and missing-photo accessibility coverage remains active.
3. Persistence coverage from Slice 0079 protects the source query and photo relationship.

## Documentation Decision

The wiki is updated because My Designs is now an owner-facing gallery and detail workflow.
