# Slice RFC-0088: Use Design for New Order

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

The owner needs to turn any library image into an order draft without silently creating an order
or losing whether the image is owner-made, customer-supplied, or internet inspiration.

## Scope

1. Add `Use for New Order` to saved-design and customer-reference detail.
2. Navigate to the standard add-order form with the selected reference pre-linked.
3. Keep the draft unsaved until the owner explicitly selects Save.
4. Continue using `cakeDesignId` for owner-made and internet-inspiration records.
5. Persist a separate customer-reference photo relationship for customer-supplied images.
6. Derive customer-reference usage from the originating order and later linked orders.
7. Clear the customer-reference relationship, without deleting an order, if its source metadata is
   removed from CloudBake.
8. Show explicit source provenance on the saved order detail for every linked reference type.

## Design

The cross-screen router carries a typed, transient new-order request. Opening the form initializes
draft state only. Saved designs retain their stable design link. Customer references retain their
stable order-photo link through `orders.customer_reference_photo_id`, so the app does not pretend
that customer-supplied work is an owner-made design. Repository writes validate that the linked
photo exists, is a Customer Reference, and is not combined with a saved-design link. The order
detail exposes the retained source explicitly. The Photos asset remains owned by Photos.

## Test Strategy

1. Router tests cover saved-design and customer-reference draft requests.
2. View-model tests prove selection creates no order before Save and persists the correct link on
   Save.
3. Persistence tests cover customer-reference link round-tripping and safe `ON DELETE SET NULL`.
   They also reject missing, final-cake, and ambiguous reference links.
4. Design tests cover derived usage after a customer reference is reused.
5. Focused acceptance covers opening an unsaved order draft with a saved design pre-linked.

## Documentation Decision

README and wiki source are updated because this adds a new owner workflow and durable order
provenance.
