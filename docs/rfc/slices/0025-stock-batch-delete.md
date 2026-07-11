# Slice RFC-0025: Stock Batch Delete

## Status

Implemented

## Context

Stock batches now preserve separate quantities and expiry dates for an inventory item. The owner can
correct batch quantity and expiry, but mistaken or obsolete batches still need a direct removal path.

Without batch deletion, the owner must reduce the batch to zero or compensate with a separate stock
usage flow, which is noisy for simple data cleanup.

## Scope

Allow the owner to delete a stock batch from inventory detail.

This slice includes:

1. deleting a selected stock batch,
2. reducing the parent inventory item's current quantity by the deleted batch quantity,
3. saving the item update and batch delete atomically,
4. refreshing inventory detail and low-inventory state after delete,
5. updating owner documentation and wiki pages.

This slice excludes:

1. deleting inventory items,
2. creating stock history transactions for batch corrections,
3. undo support,
4. bulk stock batch deletion.

## Requirements

- Inventory detail must expose a delete action for each stock batch row.
- Deleting a stock batch must remove that batch from the expiry table.
- Deleting a stock batch must reduce the parent item current quantity by the deleted remaining
  quantity.
- Batch deletion must not allow the parent item current quantity to go below zero.
- Persistence must not leave the parent item and stock batch table out of sync if deletion fails.
- Inventory detail and inventory list state must refresh after deletion.

## Design

`InventoryItemDetailView` exposes a visible destructive delete action on stock batch rows.

RFC-0070 replaced the original trailing swipe presentation with a visible card-row action because
inventory detail now uses a custom scroll-view layout rather than a native `List`.

`InventoryListViewModel.deleteBatch(_:)` validates the selected item, calculates the new current
quantity, and asks the repository to save the item correction and delete the batch together.

`InventoryStockBatchRepository.deleteBatchCorrection(item:batch:)` keeps the parent item update and
batch delete atomic in GRDB.

The GRDB item fetch path derives expiry state from remaining stock batches, so deleting an expired
or expiring batch refreshes low-inventory and expiry indicators when inventory reloads.

## Tests

Unit and integration coverage:

- Deleting a batch removes it from detail state.
- Deleting a batch reduces the parent item current quantity by the deleted batch quantity.
- Persistence failure leaves the parent item and batch unchanged.

## Documentation

Updated:

- `README.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Inventory-Guide.md`
- `wiki/Owner-Workflows.md`
- `wiki/Business-Concepts.md`

## Acceptance

- Owner can delete an incorrect stock batch from inventory detail.
- Current quantity remains consistent with remaining stock after deletion.
- The app keeps batch deletion as a correction workflow, separate from stock usage history.
