# Slice RFC-0011: Inventory Stock Adjustment

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Allow the owner to manually add stock to an active inventory item and keep an inventory transaction record for the adjustment.

## Scope

- Add an Adjust action to active inventory rows.
- Add an Adjust Stock sheet with the selected item, current quantity, quantity to add, and optional note.
- Increase the inventory item's current quantity by the entered amount.
- Store an `InventoryTransaction` with kind `adjustment`.
- Reload the inventory list after a successful adjustment.
- Add unit, integration, and acceptance tests.

## Out of Scope

- Recipe-driven stock reduction.
- Manual stock reduction.
- Negative inventory handling.
- Transaction history UI.
- Editing or deleting adjustment transactions.
- Adjusting archived inventory items.

## Requirements

- The owner can start an adjustment from an active inventory row.
- Adjustment quantity must be greater than zero.
- Successful adjustment updates `currentQuantity` and `updatedAt`.
- Successful adjustment records the quantity, timestamp, item id, kind, and optional note.
- Empty notes are stored as `nil`.
- Invalid adjustment input leaves inventory and transaction data unchanged.

## Design

### View Model

`InventoryListViewModel` depends on a repository that supports both inventory items and inventory transactions.

The view model gains:

- `adjustingItem`
- `draftAdjustmentQuantity`
- `draftAdjustmentNote`
- `beginAdjusting(_:)`
- `recordStockAdjustment()`
- `cancelStockAdjustment()`

`recordStockAdjustment()` validates a positive quantity, saves the updated inventory item, saves the adjustment transaction, clears the adjustment draft, and reloads active inventory.

### UI

Inventory rows expose a leading swipe action labeled `Adjust`.

The Adjust Stock sheet shows the selected item name and current quantity, accepts a quantity to add, and accepts an optional note.

### Persistence

This slice reuses the existing `inventory_transactions` table and `InventoryTransactionRepository`. No schema migration is required.

## Test Plan

- Unit tests:
  - Beginning an adjustment copies the selected item into adjustment state.
  - Recording an adjustment increases current quantity and stores an adjustment transaction.
  - Zero adjustment quantity is rejected without changing inventory or transactions.

- Integration tests:
  - Repository can persist an adjusted item and its adjustment transaction together.

- Acceptance tests:
  - Owner can add an inventory item, adjust stock from the row, and see the updated current quantity.

## Acceptance Criteria

- Owner can manually add stock to an active inventory item.
- Adjustment creates an inventory transaction record.
- Invalid adjustment quantity is rejected.
- Tests pass locally and in CI.
