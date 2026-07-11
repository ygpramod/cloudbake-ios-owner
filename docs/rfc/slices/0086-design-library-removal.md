# Slice RFC-0086: Design Library Removal

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

The owner needs to remove obsolete designs and references from CloudBake while retaining direct
ownership of the underlying image in the iPhone Photos library.

## Scope

1. Offer a destructive Remove action from saved-design and customer-reference detail.
2. Require explicit confirmation that distinguishes CloudBake metadata from the Photos asset.
3. Delete My Designs and Internet Inspiration metadata without deleting the Photos asset.
4. Unlink orders safely when a linked saved design is removed.
5. Delete a customer-reference `OrderPhoto` record from its originating order and Designs projection.
6. Preserve the Photos asset for customer references.
7. Remove transitional legacy app-owned customer-reference files when their metadata is deleted.
8. Enqueue legacy file cleanup in the same transaction as metadata deletion and retry failures on
   later loads.

## Design

CloudBake never requests deletion of a Photos asset. Removing a saved `CakeDesign` relies on the
existing `ON DELETE SET NULL` order relationship. Customer References remain derived from order
photos, so removing one deletes that single metadata record and the collection updates naturally.
Legacy file paths use the existing durable cleanup queue; Photos-backed records never request image
deletion.

## Test Strategy

1. Persistence integration proves deleting a design unlinks rather than deletes its order.
2. View-model tests prove Photos-backed design/reference removal does not invoke image deletion.
3. Existing source and deletion projection tests remain active.
4. Focused acceptance covers cancelling and confirming the shared centered destructive popup.

## Documentation Decision

The wiki is updated because removal is now an owner-facing Designs workflow.
