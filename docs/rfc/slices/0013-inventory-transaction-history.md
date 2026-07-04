# Slice RFC-0013: Inventory Transaction History

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Let the owner view the stock change history for an active inventory item so manual stock movement is visible and auditable before recipe-driven inventory reduction is introduced.

## Scope

- Add a History action to active inventory rows.
- Add a Stock History sheet for the selected inventory item.
- Show stock adjustment and consumption transactions for the selected item.
- Sort transactions newest first by occurrence time.
- Show transaction kind, signed quantity, timestamp, and optional note.
- Add repository support for fetching transactions by inventory item.
- Add unit, integration, and acceptance tests.
- Update owner wiki product pages for the new visible inventory behavior.

## Out of Scope

- Editing or deleting inventory transactions.
- Filtering or searching transaction history.
- Transaction history for archived inventory items.
- Cross-item inventory ledger screens.
- Recipe-driven transaction creation.
- Unit conversion between inventory units.

## Requirements

- The owner can open stock history from an active inventory row.
- The history view only shows transactions for the selected inventory item.
- The newest stock changes appear first.
- Adjustment and purchase transactions display as positive stock movement.
- Consumption transactions display as negative stock movement.
- Empty history shows a clear empty state.
- Repository access remains behind `InventoryTransactionRepository`.

## Design

### Repository

`InventoryTransactionRepository` gains `fetchInventoryTransactions(inventoryItemId:)`.

The GRDB implementation queries `inventory_transactions` by `inventory_item_id` and orders by
`occurred_at_unix_time DESC`, then `created_at_unix_time DESC`.

### View Model

`InventoryListViewModel` gains:

- `historyItem`
- `historyTransactions`
- `beginViewingHistory(_:)`
- `loadHistory()`
- `closeHistory()`

The view model loads only the selected item's transaction records and exposes them to the sheet.

### UI

Inventory rows expose a leading swipe action labeled `History`.

The Stock History sheet shows the selected item, current quantity, and a newest-first list of stock
changes. Adjustment and purchase rows display positive quantities. Consumption rows display negative
quantities.

## Test Plan

- Unit tests:
  - Beginning history loads only the selected item's transactions.
  - Transactions are ordered newest first.
  - Closing history clears selected item and transactions.

- Integration tests:
  - Repository fetches transactions for one inventory item only.
  - Repository orders fetched transactions newest first.

- Acceptance tests:
  - Owner can adjust stock, consume stock, open history, and see both stock changes.

## Acceptance Criteria

- Owner can view stock history for an active inventory item.
- History shows adjustment and consumption stock movement with clear signs.
- History excludes transactions for other inventory items.
- Tests pass locally and in CI.
