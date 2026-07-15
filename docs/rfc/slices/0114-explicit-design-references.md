# Slice RFC-0114: Explicit Design References

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Scope

1. Rename the Designs collection from Customer References to References.
2. Stop deriving the Designs library from every customer-reference order photo.
3. Add an explicit Photos picker for importing a tagged Reference.
4. Add an explicit `Add to Design References` action to customer-reference photos in order detail.
5. Keep the originating order photo intact and do not link the new library Reference back to the
   order automatically.
6. Let the order design picker search and link explicit References as normal `CakeDesign` records.
7. Preserve any existing customer-reference design metadata and order links; the prior derived UI
   did not materialize a separate record that requires destructive cleanup.

## Persistence

References are private `CakeDesign` records with `sourceKind = customerReference`. Their images
remain owned by Photos and CloudBake stores the Photos asset identifier. When created from an order
photo, originating photo and order identifiers preserve provenance without transferring ownership
or changing the order's linked design.

## Test Strategy

1. View-model coverage proves raw order photos do not appear automatically, imports normalize tags,
   and deleting a Reference preserves its originating order photo.
2. Order coverage proves explicit References are searchable and adding an order photo creates the
   correct provenance without relinking the order.

## Documentation Decision

The parent Designs RFC and current-capabilities wiki are updated because the ownership model and
visible workflow changed.
