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
- Save the batch correction and parent inventory item update atomically.
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
- Saving a batch correction must not leave the parent item and stock batch out of sync if persistence fails.

## Design

`InventoryListViewModel.beginEditingBatch(_:)` prepares editable draft quantity and expiry state.

`InventoryListViewModel.saveEditedBatch()` validates quantity and asks the repository to save the
selected inventory item quantity delta and updated stock batch as one correction.

`InventoryStockBatchRepository.saveBatchCorrection(item:batch:)` keeps the parent item update and
batch update atomic in GRDB.

The item detail sheet uses `InventoryBatchForm`, replacing the previous expiry-only form.

## Test Plan

- Unit tests:
  - Editing quantity and expiry updates both the batch and current stock.
  - Negative quantity rejects without writes.
  - Persistence failure leaves the parent item and batch unchanged.

- Acceptance tests:
  - Existing inventory detail flow opens Edit Batch and exposes quantity plus expiry controls.

## Acceptance Criteria

- Owner can edit remaining quantity for a stock batch.
- The item current quantity stays consistent with the sum of stock batch corrections.
- Existing expiry editing still works.
