# Slice RFC-0019: Purchase Bill Draft Parser

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Turn recognized purchase bill text into draft inventory candidates that future scan and review flows
can show to the owner.

## Scope

- Add a domain model for purchase bill draft inventory items.
- Parse recognized bill text line by line.
- Keep only bill lines that match active baking catalog items.
- Capture common quantity and unit pairs from matched lines.
- Support separated and combined quantity/unit text, such as `1 kg`, `500g`, and `250ml`.
- Ignore non-baking bill lines even if they contain valid measurements.
- Add focused unit tests.
- Update README and wiki product documentation.

## Out of Scope

- Camera scanning.
- Apple Vision OCR integration.
- Photo library import.
- Inventory draft review UI.
- Saving draft items into inventory.
- Duplicate matching against existing inventory from parsed bill drafts.
- Price parsing.
- Expiry parsing.
- AI or LLM document analysis.

## Requirements

- Draft parsing must be deterministic and testable without camera, OCR, network, or LLM dependencies.
- The parser must use the baking catalog as the source of truth for deciding which bill lines matter.
- Inactive catalog items must not create draft items.
- Bill lines without recognized quantity/unit can still become draft candidates when they match the
  catalog, because the owner may fill in the missing values during review.
- The parser must not save inventory directly.

## Design

### Domain

`PurchaseBillDraftInventoryItem` contains:

- `name`: owner-friendly catalog item name,
- `sourceLine`: original recognized bill line,
- `quantity`: optional parsed quantity,
- `unit`: optional parsed inventory unit.

`PurchaseBillDraftParser` exposes:

- `draftItems(from:catalog:)`

The parser splits recognized text into non-empty lines, matches each line against
`BakingCatalog.matches(in:catalog:)`, and parses the first supported quantity/unit pair when present.

### Supported Units

The first parser version recognizes:

- kg, kilogram, kilograms,
- g, gm, gram, grams,
- l, liter, liters, litre, litres,
- ml, milliliter, milliliters, millilitre, millilitres,
- tsp, teaspoon, teaspoons,
- tbsp, tablespoon, tablespoons,
- cup, cups,
- pc, pcs, piece, pieces, each.

### Future Flow

Future slices can connect:

1. Apple Vision OCR or document scanning,
2. parser output,
3. owner review/edit UI,
4. inventory save flow with duplicate checks, expiry capture, and stock batches.

## Test Plan

- Unit tests:
  - Catalog-matched bill lines become draft items.
  - Non-baking bill lines are ignored.
  - Aliases create draft items.
  - Combined quantity/unit tokens are parsed.
  - Common receipt units are mapped to `InventoryUnit`.
  - Matched lines without quantity/unit remain draft candidates.
  - Inactive catalog items are ignored.

- Integration tests:
  - Not required for this slice because no persistence or repository boundary is added.

- Acceptance tests:
  - Not required for this slice because there is no owner-facing UI yet.

## Acceptance Criteria

- Recognized purchase bill text can be converted into draft inventory candidates.
- Only baking catalog matches produce drafts.
- Drafts carry source text for owner review.
- Quantity and unit are filled when a common receipt measurement is recognized.
- Tests pass locally and in CI.
