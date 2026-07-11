# Slice RFC-0090: Consumer-Safe Design Projection

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

Future consumer surfaces need a projection that fails closed. Passing an arbitrary owner-side
design into an order preview must never expose customer references, Internet Inspiration, private
notes, source metadata, favourites, origin relationships, or unpublished owner work.

## Scope

1. Persist an owner-made portfolio-publication flag that defaults to private.
2. Force non-owner design sources to remain unpublished at the domain boundary.
3. Create a consumer design projection containing only stable id, name, and a validated Photos
   reference. Owner tags remain private until separately approved public metadata exists.
4. Require owner-made provenance, explicit publication, and an available photo reference.
5. Make the existing consumer order projection use the safe design projection.
6. Do not add a publication-management UI; that requires a separate owner workflow RFC.

## Design

`CakeDesign.isPortfolioPublished` defaults to `false`, including migrated records. The domain
initializer coerces the flag back to false for Customer Reference and Internet Inspiration sources.
`ConsumerDesignPreview` is failable and excludes every owner-private or provenance-sensitive field.
It rejects legacy paths, arbitrary schemes, and empty Photos identifiers. `ConsumerOrderPreview`
exposes design fields only when that projection succeeds and its stable id matches the order's
actual design link.

## Test Strategy

1. Domain tests prove private, customer, internet, missing-photo, legacy-path, and invalid-reference
   designs fail closed.
2. Domain tests prove the approved projection contains only the allow-listed fields.
3. Order projection tests prove only the order's linked, explicitly published owner-made design is
   included.
4. Persistence tests cover publication round-trip and private migration defaults.

## Documentation Decision

README and wiki source are updated because this establishes a durable privacy boundary, while the
owner publication workflow remains explicitly deferred.
