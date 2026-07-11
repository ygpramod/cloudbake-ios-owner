# Slice RFC-0082: Customer References Collection

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

Customer reference photos already belong to orders but were visible only inside each order. The
Designs library needs a private, provenance-safe collection without copying photos or creating a
second design record.

## Scope

1. Query order photos by `customerReference` kind.
2. Derive collection items from each photo and its originating order.
3. Show a counted Customer References preview row on Designs.
4. Show photo, customer, order, and caption context in reference detail.
5. Search reference captions, order titles, and customer names.
6. Remove a reference from the collection automatically when its order-photo record is deleted.

Out of scope:

1. Editing or deleting the order photo from Designs.
2. Reusing the reference for a new order.
3. Converting a customer reference into owner-made work.

## Design

The collection is a read-only projection over `OrderPhoto` and `Order`; it creates no duplicate
metadata or image binary. Source identity remains visible in both the tile accessibility label and
detail view. Photo rendering supports canonical Photos identifiers and transitional legacy order
photo references through the shared image pipeline.

## Test Strategy

1. View-model tests prove only customer-reference photos are included and order context is searchable.
2. Persistence tests prove kind-scoped ordering and deletion behavior.
3. Existing PhotoKit reference, missing-asset, and bounded-image tests remain active.

## Documentation Decision

The wiki is updated because Customer References is now an owner-facing Designs workflow.
