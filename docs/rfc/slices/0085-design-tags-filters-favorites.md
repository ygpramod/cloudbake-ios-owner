# Slice RFC-0085: Design Tags, Filters, And Favourites

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

As the photo library grows, the owner needs lightweight organization without duplicating source
collections or introducing implied public popularity.

## Scope

1. Persist normalized free-form tags and one owner favourite Boolean on saved designs.
2. Persist the same private metadata on customer-reference order photos.
3. Prevent blank and case-only duplicate tags while preserving the first display spelling.
4. Edit tags and favourite state from owner-facing detail.
5. Show a compact favourite state overlay without adding thumbnail names.
6. Generate filter chips only for tags represented in the current library.
7. Prioritize Birthday, Wedding, Kids, Cupcakes, Chocolate, Minimal, Vintage, and Floral when present.
8. Provide a Favourites filter only when at least one item is favourited.
9. Compose the selected filter with tokenized search across all three provenance groups.

## Design

Tags remain metadata rather than separate collections. One filter may be selected at a time. The
heart is explicitly the bakery owner's private favourite state; no public likes or counts exist.
Customer-reference tags and favourites remain on the source `OrderPhoto`, so the Designs projection
does not duplicate metadata.

## Test Strategy

1. Domain and view-model tests cover normalization, favourites, available chips, source-spanning
   filters, search composition, and empty results.
2. Persistence tests round-trip design and order-photo tags/favourites.
3. Migration coverage ensures legacy rows receive empty tags and a false favourite state.

## Documentation Decision

The wiki is updated because tags, filters, and private favourites are owner-facing capabilities.
