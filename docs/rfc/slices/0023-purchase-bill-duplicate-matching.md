# Slice RFC-0023: Purchase Bill Duplicate Matching

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Prevent purchase bill imports from creating duplicate inventory rows when a draft represents stock
for an existing active inventory item.

## Scope

- Match purchase bill drafts to existing active inventory by the same normalized name rules used by
  manual duplicate warnings.
- Show matched drafts as stock that will be added to the existing item.
- On save, update the matched inventory item's current quantity instead of creating a new item.
- Create a new stock batch for the matched item using the draft expiry date.
- Convert compatible units before adding stock to an existing item.
- Reject incompatible matched units without partial writes.
- Add focused unit coverage.
- Update README and wiki documentation.

## Out Of Scope

- Matching archived inventory items.
- Letting the owner manually choose a different match.
- Merging unmatched drafts that resemble each other inside the same bill.
- Supplier, price, tax, or payment metadata extraction.

## Requirements

- Matching draft save must not create a duplicate inventory item.
- Matching draft save must preserve the existing item name, unit, and minimum quantity.
- Matching draft save must add a stock batch for the matched item when quantity is positive.
- Compatible units must be converted into the existing item's unit.
- Incompatible units must show a clear error and avoid partial inventory changes.

## Design

`InventoryListViewModel.createPurchaseBillDrafts(catalog:)` annotates each draft with the active
inventory item it matches, when one exists.

`PurchaseBillDraftRow` displays matched drafts with an Adds To Existing note so the owner knows the
save will update stock rather than create a new inventory row.

`InventoryListViewModel.savePurchaseBillDrafts()` re-checks matches at save time, converts quantities
into the matched item's unit, accumulates multiple draft lines that target the same item, and saves
new stock batches against the existing item.

## Test Plan

- Unit tests:
  - Draft creation marks an existing inventory match.
  - Saving a matched draft updates existing stock and creates a matched stock batch.
  - Multiple drafts for the same item accumulate stock correctly.
  - Incompatible matched units reject without writes.

## Acceptance Criteria

- Scanning or entering `Cake Flour 1 kg` when `Cake flour` already exists adds stock to the existing
  item.
- The inventory list does not gain a second Cake Flour item for matched drafts.
- New expiry batches are preserved for matched imports.
