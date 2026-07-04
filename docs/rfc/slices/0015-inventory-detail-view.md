# Slice RFC-0015: Inventory Detail View

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Make inventory row taps open a read-only item detail view so the owner can inspect item summary
fields and stock batches before choosing to edit.

## Scope

- Change active inventory row tap from direct edit to view mode.
- Show item name, unit, current quantity, and minimum quantity in view mode.
- Show an expiry table with remaining quantity and expiry date for each remaining stock batch.
- Add an Edit action from the detail view.
- Restrict edit mode to name and minimum quantity only.
- Preserve current quantity, unit, and stock batches during item edit.
- Update unit and acceptance tests.
- Update owner-facing documentation and wiki pages.

## Out Of Scope

- Editing individual stock batches.
- Editing current quantity from item edit mode.
- Editing unit from item edit mode.
- Editing expiry from item edit mode.
- Batch delete, merge, or split workflows.
- Recipe-driven stock usage.

## Requirements

- Tapping an inventory row opens item detail view.
- Detail view displays name, unit, current quantity, minimum quantity, and remaining stock batches.
- Batch rows show remaining quantity and expiry date.
- Edit is available from the detail view toolbar.
- Edit allows changing only name and minimum quantity.
- Quantity changes continue to happen through stock adjustment and stock consumption workflows.
- Expiry changes continue to happen through stock entry workflows until direct batch editing exists.

## Design

### View Model

`InventoryListViewModel` gains selected-item state:

- `selectedItem`
- `selectedItemBatches`
- `beginViewingItem(_:)`
- `loadSelectedItemBatches()`
- `closeSelectedItem()`

The view model loads stock batches through `InventoryStockBatchRepository` so SwiftUI views remain
behind the repository boundary.

`saveEditedItem()` now preserves the existing unit, current quantity, and batch state. It validates
and saves name and minimum quantity only.

### UI

Inventory rows open `InventoryItemDetailView`.

The detail view shows item summary fields and an Expiry section with a quantity/expiry table.

The detail toolbar has:

- `Done`, which closes detail view.
- `Edit`, which opens the restricted edit form.

The edit form hides unit, current quantity, and expiry date for edits. Add Item still captures unit,
current quantity, minimum quantity, and expiry date.

## Test Plan

- Unit tests:
  - Viewing an item loads its stock batches.
  - Editing preserves current quantity and unit.
  - Editing does not update stock batches.
  - Editing accepts formatted minimum quantity.

- Acceptance tests:
  - Owner can tap inventory row and see detail view.
  - Detail view shows expiry table data.
  - Edit from detail allows minimum quantity change.
  - Edit from detail does not expose current quantity or unit fields.
  - Existing row swipe workflows still work.

## Acceptance Criteria

- Inventory row tap opens view mode.
- View mode shows stock batches as quantity and expiry rows.
- Edit is reachable from view mode.
- Edit allows name and minimum quantity only.
- Tests pass locally and in CI.
