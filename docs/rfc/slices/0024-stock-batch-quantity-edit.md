# Slice RFC-0024: Stock Batch Quantity Edit

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Allow the owner to correct remaining quantity on an existing stock batch without recreating the
inventory item.

## Scope

- Expand the existing batch expiry editor into an Edit Batch flow.
- Allow editing remaining batch quantity.
- Keep expiry editing in the same flow.
- Update the parent inventory item's current quantity by the batch quantity delta.
- Reject invalid negative quantities.
- Add unit and impacted acceptance coverage.
- Update README and wiki documentation.

## Out Of Scope

- Deleting stock batches.
- Editing the inventory item's unit.
- Changing a batch's inventory item.
- Creating adjustment transactions for manual batch corrections.

## Requirements

- The owner must be able to edit a stock batch quantity from inventory item detail.
- A batch quantity cannot be negative.
- Saving a batch quantity change must update current inventory stock by the same delta.
- Saving an expiry-only change must keep current stock unchanged.

## Design

`InventoryListViewModel.beginEditingBatch(_:)` prepares editable draft quantity and expiry state.

`InventoryListViewModel.saveEditedBatch()` validates quantity, updates the selected inventory item by
the batch quantity delta, then saves the updated stock batch.

The item detail sheet uses `InventoryBatchForm`, replacing the previous expiry-only form.

## Test Plan

- Unit tests:
  - Editing quantity and expiry updates both the batch and current stock.
  - Negative quantity rejects without writes.

- Acceptance tests:
  - Existing inventory detail flow opens Edit Batch and exposes quantity plus expiry controls.

## Acceptance Criteria

- Owner can edit remaining quantity for a stock batch.
- The item current quantity stays consistent with the sum of stock batch corrections.
- Existing expiry editing still works.
