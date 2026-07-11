# Slice RFC-0079: Design Library Provenance

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

CloudBake already stores promoted final-cake designs, but the original model does not distinguish
owner-made work from customer references or internet inspiration. The Designs RFC requires this
trust boundary before expanding the visible library.

## Scope

In scope:

1. Add a persisted source kind for owner-made, customer-reference, and internet-inspiration items.
2. Record an optional originating order photo and order on design records.
3. Classify existing design records as owner-made during migration.
4. Preserve existing photo references and order design links.
5. Provide repository queries scoped by source kind.
6. Record final-photo promotions as owner-made with their order and photo provenance.

Out of scope:

1. Visible Designs screen changes.
2. Customer-reference collection derivation.
3. Internet inspiration import.
4. Search, tags, filters, favourites, usage history, and public portfolio state.
5. Photo binary migration or cleanup.

## Design

`CakeDesignSourceKind` is a typed domain enum persisted as a stable raw value. Migration `0020`
adds source and origin columns without rebuilding `cake_designs`, so existing design ids, photo
references, and foreign-key links from orders remain intact. Existing rows default to `ownerMade`
because all current design creation flows promote the owner's final cake photos.

Order photos remain the authority for photo kind and origin. The new optional origin ids preserve
that relationship without copying image binaries into SQLite.

## Test Strategy

1. Migration coverage verifies legacy designs become owner-made without losing photo references.
2. Persistence integration verifies source-kind round trips and source-scoped queries.
3. Order photo tests verify promotion records owner-made source, originating photo, and order ids.

## Documentation Decision

The wiki is updated because persisted provenance is durable product capability. The visible Designs
workflow remains listed as partially prepared until later slices complete owner-facing browsing.
