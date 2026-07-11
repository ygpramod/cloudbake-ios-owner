# Slice RFC-0081: Design Photos Library References

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

The owner requires the iPhone Photos library to remain the sole owner of every Designs-library
image. CloudBake may retain metadata and a Photos local asset identifier, but not a second image
binary in its app container.

## Scope

1. Save newly promoted final-cake images into Photos with explicit system authorization.
2. Persist only the returned Photos local asset identifier on `CakeDesign`.
3. Render Photos assets in gallery thumbnails and design detail through PhotoKit.
4. Keep bounded thumbnail decoding and explicit missing-asset accessibility states.
5. Preserve read-only compatibility for existing app-relative design references.
6. Never delete a Photos asset when a design record is removed.
7. Atomically save the design, order link, and migrated order-photo reference.
8. After the atomic save, remove the promoted photo's former app-owned file so the order and design
   share the same Photos identifier without retaining a duplicate binary.

## Test Strategy

1. Unit tests use a photo-library boundary fake and prove only its asset identifier is persisted.
2. Failure tests prove denied or failed Photos saves do not create a design or update an order.
3. Existing gallery filtering, missing-photo, provenance, and persistence tests remain active.
4. Physical-device validation confirms authorization and PhotoKit rendering.

## Documentation Decision

The parent RFC and wiki must state that Photos owns image binaries and CloudBake stores references
only. Slice 0080 remains partial until this boundary is implemented.
