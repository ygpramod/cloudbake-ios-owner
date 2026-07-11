# Slice RFC-0091: Direct Owner Design Import

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

My Designs must accept completed owner work that was not first recorded as an order final photo,
while preserving the Photos-owned storage boundary.

## Scope

1. Add a compact add action beside the My Designs heading.
2. Open a shared-style form that selects an existing image through Photos.
3. Require a design name and accept optional notes and normalized tags.
4. Persist an owner-made `CakeDesign` with only the `photos://` reference and metadata.
5. Keep new records private from future consumer projections by default.
6. Do not duplicate the selected image in the app container or SQLite.

## Test Strategy

1. View-model tests cover normalized metadata, owner-made provenance, private defaults, and required
   name validation.
2. Focused acceptance proves the My Designs add action opens the Photos-owned import form.
3. Photos picker hand-off remains covered through unit-level routing and physical-device validation.

## Documentation Decision

README and wiki source are updated because this adds a new owner workflow.
