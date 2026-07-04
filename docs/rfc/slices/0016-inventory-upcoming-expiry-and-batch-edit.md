# Slice RFC-0016: Inventory Upcoming Expiry And Batch Edit

## Status

Accepted

## Context

Inventory expiry is tracked at stock-batch level. The owner needs earlier warning before handmade
cake ingredients expire, and expiry dates sometimes need correction after stock has been entered.

## Scope

This slice adds upcoming-expiry alerts and expiry-only editing for existing stock batches.

In scope:

- Treat remaining stock that expires within one calendar month as an inventory alert.
- Keep expired stock as the highest-priority expiry alert.
- Show upcoming-expiry alerts in inventory rows and dashboard low inventory.
- Allow the owner to edit the expiry date for each remaining stock batch from inventory detail.
- Preserve item edit mode as name and minimum quantity only.
- Update owner wiki pages for the new alert and batch-edit behavior.

Out of scope:

- Editing stock batch quantity directly.
- Deleting stock batches.
- Push notifications for expiry reminders.
- Recipe-driven stock consumption.

## Requirements

- A remaining batch expiring before the current date must mark the item as expired stock.
- A remaining batch expiring from today through one calendar month from today must mark the item as
  expiring soon.
- Expired and expiring-soon stock must make the item appear in low inventory, even when current
  quantity is above minimum quantity.
- Inventory detail must show remaining batch quantity and expiry date.
- Selecting a remaining batch from inventory detail must open an expiry edit flow.
- Saving the expiry edit flow must update only the selected batch expiry and updated timestamp.

## Design

`InventoryItem` now exposes `hasExpiringSoonStock` alongside `hasExpiredStock`. `isLowStock` is true
when quantity is below minimum, any remaining batch has expired, or any remaining batch expires
within one calendar month.

`GRDBCoreDataRepository` calculates expiry state from `inventory_stock_batches` for each item. The
upcoming-expiry threshold uses `Calendar.current.date(byAdding: .month, value: 1, to: Date())`.

`InventoryListViewModel` owns the batch expiry edit draft:

- `editingBatch`
- `draftBatchExpiryDate`
- `beginEditingBatchExpiry(_:)`
- `saveEditedBatchExpiry()`
- `cancelEditingBatchExpiry()`

The item edit flow remains intentionally narrow: name and minimum quantity. Current quantity changes
continue through stock adjustment and stock consumption.

## Testing

Unit and integration coverage:

- Core model treats expiring-soon stock as low inventory.
- Dashboard includes expiring-soon items above minimum quantity.
- Persistence marks batches expiring within one month as low inventory.
- Persistence does not mark batches expiring after one month as low inventory.
- View model updates only the selected batch expiry.

Acceptance coverage:

- Inventory detail opens an expiry edit flow from a stock batch row.

## Documentation

Update:

- `README.md` slice list.
- `wiki/Business-Concepts.md`
- `wiki/Inventory-Guide.md`
- `wiki/Owner-Workflows.md`
- `wiki/Current-App-Capabilities.md`

## Acceptance Criteria

- Owner can see expiring-soon stock before the one-month threshold passes.
- Owner can open an inventory item and edit each batch expiry date.
- Owner cannot accidentally change unit or current quantity from the item edit flow.
- Tests cover the domain, persistence, view model, and acceptance flow.
