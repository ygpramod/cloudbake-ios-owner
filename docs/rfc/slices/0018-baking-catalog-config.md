# Slice RFC-0018: Baking Catalog Config

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Create the catalog foundation that future purchase bill scanning can use to draft inventory only for
baking-related items.

## Scope

- Add a bundled JSON baking catalog config.
- Represent catalog items with name, aliases, category, and active flag.
- Decode the catalog through domain code.
- Match purchase bill text lines against active catalog items.
- Match aliases as whole token phrases so similar non-baking words do not create false positives.
- Add unit tests for decoding, alias matching, inactive entries, plural handling, and bundled JSON
  validity.
- Update README and wiki product documentation.

## Out of Scope

- Camera scanning.
- OCR through Vision or VisionKit.
- Purchase bill parsing into item quantity, unit, price, or expiry.
- Inventory draft creation UI.
- In-app catalog editing.
- Persisting owner-edited catalog entries.
- AI/cloud bill analysis.

## Requirements

- The catalog must be human-readable JSON.
- Catalog items must support aliases so local purchase bill names can map to owner-friendly names.
- Inactive catalog items must not match purchase bill text.
- Matching must avoid substring false positives, such as `egg` matching `eggplant`.
- The bundled catalog must include common baking ingredients, decorations, and packaging.
- The implementation must be testable without camera, OCR, or network dependencies.

## Design

### JSON Shape

```json
[
  {
    "name": "Cake Flour",
    "aliases": ["flour", "plain flour", "maida"],
    "category": "Ingredient",
    "active": true
  }
]
```

### Domain

`BakingCatalogItem` is a Codable domain model for config entries.

`BakingCatalog` owns:

- JSON decoding,
- bundled catalog loading,
- active-only matching,
- token normalization,
- whole-phrase matching.

The matching logic is intentionally deterministic for this slice. It creates a reliable filter before
OCR and inventory draft flows are introduced.

### Config

`CloudBakeOwner/Resources/BakingCatalog.json` is bundled with the app. It is the first version of the
owner-editable catalog idea. Future slices can copy it into local app storage or expose an in-app
management screen.

## Test Plan

- Unit tests:
  - Decode catalog JSON into domain items.
  - Match by catalog name.
  - Match by alias.
  - Do not match inactive items.
  - Do not match aliases as arbitrary substrings.
  - Validate the bundled JSON contains expected baking entries.

- Integration tests:
  - Not required for this slice because no persistence or repository boundary is added.

- Acceptance tests:
  - Not required for this slice because there is no owner-facing UI yet.

## Acceptance Criteria

- The app target bundles `BakingCatalog.json`.
- Domain code can decode and match catalog entries.
- Only active baking catalog items match bill text.
- Tests pass locally and in CI.
