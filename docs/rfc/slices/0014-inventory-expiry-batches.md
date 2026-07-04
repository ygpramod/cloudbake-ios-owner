# Slice RFC-0014: Inventory Expiry And Stock Batches

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Track inventory expiry at the stock-batch level so the owner can see expiry-sensitive low inventory
alerts and stock usage can consume older stock before newer stock.

## Scope

- Add inventory stock batches with remaining quantity and optional expiry date.
- Create an initial stock batch when an inventory item is added with current quantity.
- Create a separate stock batch when stock is adjusted upward.
- Preserve multiple batches for the same inventory item when expiry dates differ.
- Deduct stock from the oldest expiry batch first, then continue into newer batches.
- Treat expired remaining stock as low inventory even when current quantity is above minimum.
- Show expiry fields in add, edit, and stock adjustment flows.
- Show earliest expiry on inventory rows.
- Add unit, integration, and targeted acceptance coverage.
- Update owner wiki product pages for expiry and batch behavior.

## Out Of Scope

- Editing individual stock batches directly.
- Deleting stock batches.
- Lot numbers, supplier references, or purchase invoices.
- Recipe-driven automatic stock reduction.
- Push notifications for upcoming expiry.
- Unit conversion between inventory units.

## Requirements

- New stock must have an expiry date captured through the owner workflow.
- Adding an item with current quantity creates a stock batch for that starting stock.
- Adjusting stock upward creates a new stock batch rather than merging into existing stock.
- Multiple stock batches can exist for one inventory item.
- Stock consumption uses oldest-expiring remaining stock before newer-expiring stock.
- Low inventory includes items below minimum quantity and items with expired remaining stock.
- Existing inventory rows migrate into legacy batches without expiry so current stock is preserved.

## Design

### Domain

`InventoryStockBatch` represents a quantity of one inventory item with its own expiry date.

`InventoryItem` remains the owner-facing summary record. It now also exposes:

- `earliestExpiryAt`
- `hasExpiredStock`

`isLowStock` is true when current quantity is below minimum quantity or when any remaining batch is
expired.

### Persistence

Migration `0005_create_inventory_stock_batches` creates `inventory_stock_batches`.

Existing inventory item quantities are copied into legacy batches with no expiry date so older local
databases keep their current stock after migration.

`InventoryStockBatchRepository` supports saving and fetching batches. Fetching returns batches by
oldest expiry first, with no-expiry legacy batches last.

### View Model

Adding an inventory item saves the item summary and, when current quantity is greater than zero,
saves the first stock batch.

Adjusting stock upward saves a new batch with the selected expiry date and records the adjustment
transaction.

Consuming stock validates available batch quantity and drains batches in oldest-expiry order before
saving the item summary and consumption transaction.

Editing current quantity remains supported for corrections. Increases create a correction batch with
the selected expiry date. Decreases drain oldest batches. Editing expiry without changing quantity
updates the earliest remaining batch, matching the expiry shown on the inventory row.

### UI

Add Item, Edit Item, and Adjust Stock include an `Expiry Date` field.

Inventory rows show earliest expiry when known. Rows with expired remaining stock use the same
warning icon as low quantity.

The dashboard continues to show low inventory alerts and labels expiry-driven alerts as expired
stock.

## Test Plan

- Unit tests:
  - Adding an item stores an initial batch with expiry.
  - Adjusting stock stores a separate batch.
  - Consuming stock drains the oldest expiry batch first.
  - Consuming stock continues into the newer batch when the older batch is exhausted.
  - Dashboard low inventory includes expired stock.

- Integration tests:
  - Stock batches round-trip through GRDB.
  - Stock batches fetch oldest expiry first with no-expiry batches last.
  - Expired remaining batches mark inventory items as low stock.

- Acceptance tests:
  - Owner can add inventory.
  - Owner can adjust stock.
  - Owner can consume stock.
  - Dashboard shows low inventory items.

## Acceptance Criteria

- Owner can capture expiry when adding or adjusting stock.
- Older stock is consumed before newer stock for the same item.
- Expired remaining stock appears as a low inventory alert.
- Existing current stock is preserved through migration.
- Tests pass locally and in CI.
