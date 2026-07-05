# Slice RFC-0031: Structured Recipe Import Draft

## Status

Accepted

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Turn scanned or manually entered recipe text into a structured, owner-reviewable recipe draft instead
of saving raw OCR text as notes.

## Scope

- Parse recognized recipe text into:
  - recipe name,
  - notes,
  - draft ingredient rows.
- Support common handmade recipe shorthand such as:
  - `APF - 130 g`,
  - `BP - 1/2 tsp`,
  - `Cocoa powder - 30 g`.
- Show parsed ingredient rows in the import review screen.
- Let the owner edit ingredient name, quantity, unit, inventory item link, and note before saving.
- Try simple inventory matching by ingredient name.
- Require imported ingredient rows to be linked to inventory items before saving.
- Save the recipe and linked ingredient rows together.
- Add focused unit and acceptance coverage.
- Update README and wiki source.

## Out Of Scope

- LLM-based interpretation.
- Automatic correction of poor OCR output.
- Camera-page crop/deskew UI.
- Recipe scaling.
- Recipe-driven inventory deduction.
- Creating new inventory items from recipe import.

## Requirements

- Parsed ingredient rows must be visible before save.
- The owner must be able to edit parsed rows before save.
- Ingredient rows must not be silently saved as notes when quantity and unit can be parsed.
- Imported ingredient rows must link to inventory before save.
- Non-ingredient lines must remain available as recipe notes.
- The parser must support fractions such as `1/2 tsp`.

## Design

`RecipeDraftParser` now produces a richer `RecipeDraft`:

- `name`,
- `notes`,
- `ingredients`.

The first non-ingredient line becomes the recipe name. Lines with a name, quantity, and supported
unit become ingredient drafts. Remaining lines become notes.

`RecipeListViewModel` maps parsed ingredient drafts into editable import rows. It attempts a simple
inventory match by normalized name and requires every import ingredient row to be linked before
save.

`RecipeImportView` shows a Draft Ingredients section so the owner can review and correct the app's
best guess. This is intentionally a review workflow, not a silent automation.

## Tests

Unit coverage:

- chocolate cake handwritten-style text parses into recipe name, notes, and ingredient rows,
- fractions parse into decimal quantities,
- import draft creation maps recognized text to editable ingredient rows,
- matched inventory items are preselected,
- saving an import draft persists recipe and linked ingredients,
- saving rejects unlinked imported ingredients.

Acceptance coverage:

- owner creates matching inventory,
- owner imports recognized recipe text,
- parsed ingredient rows appear for review,
- owner saves,
- recipe detail shows the linked ingredient quantity.

## Documentation

Updated:

- `README.md`
- `wiki/Business-Concepts.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- Recipe import is useful for handwritten recipe pages because it creates structured draft rows for
  owner review.
- Raw OCR text is no longer the only output of recipe import.
