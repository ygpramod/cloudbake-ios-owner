# Slice RFC-0021: Purchase Bill Draft Review

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Let the owner turn recognized purchase bill text into reviewable inventory drafts and save selected
drafts into inventory.

## Scope

- Add purchase bill import entry point from Inventory.
- Allow recognized bill text entry for the first UI slice.
- Generate draft inventory items from recognized text using the baking catalog and parser.
- Let the owner select which draft items to save.
- Let the owner edit draft name, current quantity, unit, minimum quantity, and expiry date.
- Save selected drafts as normal inventory items.
- Create initial stock batches for saved drafts with positive current quantity.
- Add unit and acceptance tests.
- Update README and wiki product documentation.

## Out of Scope

- Camera scanning UI.
- Photo picker UI.
- Direct connection from `VisionPurchaseBillTextRecognizer` to the import sheet.
- Duplicate matching during draft save.
- Merging drafts into existing inventory items.
- Price parsing.
- Supplier tracking.
- In-app baking catalog editing.

## Requirements

- The owner must be able to create drafts from recognized bill text.
- The app must ignore non-baking lines according to the baking catalog.
- The owner must be able to review and edit generated drafts before saving.
- Only selected drafts should be saved.
- Saving a draft must create a normal inventory item with an initial stock batch when quantity is
  greater than zero.
- Invalid draft data must not save partial inventory.

## Design

### View Model

`InventoryListViewModel` owns:

- `purchaseBillRecognizedText`,
- `purchaseBillDrafts`,
- `createPurchaseBillDrafts(catalog:)`,
- `savePurchaseBillDrafts()`,
- `cancelPurchaseBillImport()`.

Draft creation maps parser output to `PurchaseBillInventoryDraft`, defaulting missing quantity to an
empty field, missing unit to grams, minimum quantity to zero, expiry to the existing default expiry
date, and selection to true.

Draft save validates all selected drafts before writing any inventory rows. It then saves inventory
items and initial stock batches through the existing repository boundaries.

### UI

Inventory adds an Import Bill toolbar action.

The import sheet accepts recognized bill text, creates draft rows, and lets the owner edit fields
before saving selected drafts.

### Cleanup

Draft cleanup runs when the sheet dismisses. This avoids mutating the draft collection while SwiftUI
is still rendering row bindings during the save action.

## Test Plan

- Unit tests:
  - Recognized text creates drafts for baking lines only.
  - No matching baking items shows an error.
  - Selected drafts save as inventory items and stock batches.
  - Invalid draft quantity rejects save without partial writes.

- Acceptance tests:
  - Owner opens Import Bill, enters recognized bill text, creates drafts, saves, and sees the new
    inventory item.

## Acceptance Criteria

- Owner can create inventory drafts from recognized purchase bill text.
- Owner can save selected drafts into inventory.
- Non-baking bill lines are ignored.
- Saved drafts appear in the inventory list with quantity and unit.
- Tests pass locally and in CI.
