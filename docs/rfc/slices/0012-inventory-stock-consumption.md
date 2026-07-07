# Slice RFC-0012: Inventory Stock Consumption

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Allow the owner to manually record stock usage for an active inventory item before recipe-driven inventory reduction is introduced.

## Scope

- Add a Use action to active inventory rows.
- Add a Use Stock sheet with the selected item, current quantity, quantity used, and optional note.
- Decrease the inventory item's current quantity by the entered amount.
- Store an `InventoryTransaction` with kind `consumption`.
- Keep consumption transaction quantities positive; the transaction kind carries the business meaning.
- Reject zero, negative, and over-current-stock consumption.
- Reload the inventory list after successful consumption.
- Add unit, integration, and acceptance tests.

## Out of Scope

- Recipe-driven stock reduction.
- Order completion workflows.
- Negative inventory.
- Unit conversion between inventory units.
- Transaction history UI.
- Editing or deleting consumption transactions.
- Consuming archived inventory items.

## Requirements

- The owner can start consumption from an active inventory row.
- Consumption quantity must be greater than zero.
- Consumption quantity cannot be greater than current stock.
- Successful consumption updates `currentQuantity` and `updatedAt`.
- Successful consumption records the quantity, timestamp, item id, kind, and optional note.
- Empty notes are stored as `nil`.
- Invalid consumption input leaves inventory and transaction data unchanged.

## Design

### View Model

`InventoryListViewModel` gains:

- `consumingItem`
- `draftConsumptionQuantity`
- `draftConsumptionNote`
- `beginConsuming(_:)`
- `recordStockConsumption()`
- `cancelStockConsumption()`

`recordStockConsumption()` validates a positive quantity, rejects over-current-stock usage, saves the updated inventory item, saves the consumption transaction, clears the consumption draft, and reloads active inventory.

### UI

Inventory rows expose a `Use` action. RFC-0069 moved the active inventory list to card-based
styling, so this action is now a visible row action chip instead of a list-row swipe action.

The Use Stock sheet shows the selected item name and current quantity, accepts a quantity used, and accepts an optional note.

### Persistence

This slice reuses the existing `inventory_transactions` table and `InventoryTransactionRepository`. No schema migration is required.

Consumption transactions store positive quantities with `kind = consumption`.

## Test Plan

- Unit tests:
  - Beginning consumption copies the selected item into consumption state.
  - Recording consumption decreases current quantity and stores a consumption transaction.
  - Zero consumption quantity is rejected without changing inventory or transactions.
  - Consumption greater than current stock is rejected without changing inventory or transactions.

- Integration tests:
  - Repository can persist a consumed item and its consumption transaction together.

- Acceptance tests:
  - Owner can add an inventory item, record stock usage from the row, and see the updated current quantity.
  - Owner cannot record stock usage greater than current stock.

## Acceptance Criteria

- Owner can manually record stock usage for an active inventory item.
- Consumption creates an inventory transaction record.
- Consumption cannot reduce stock below zero.
- Tests pass locally and in CI.
