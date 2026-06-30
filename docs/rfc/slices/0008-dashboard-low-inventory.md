# Slice RFC-0008: Dashboard Low Inventory

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Show low inventory alerts on the dashboard so the owner can see restock needs without opening the Inventory screen first.

## Scope

- Load inventory items for the dashboard through the existing repository boundary.
- Filter dashboard inventory alerts to items where current quantity is below minimum quantity.
- Show an empty low-inventory state when there are no alerts.
- Show up to three low-inventory items with current and minimum quantities.
- Show a compact overflow count when more than three items are low.
- Add unit and acceptance test coverage.

## Out of Scope

- Push notifications or reminder alerts.
- Supplier ordering.
- Dashboard navigation directly to an inventory item.
- Inventory transaction history.
- Low-inventory sorting beyond existing repository order.

## Requirements

- The dashboard must not access GRDB directly.
- Low-inventory state must reuse `InventoryItem.isLowStock`.
- The dashboard must refresh when it appears so updates made in Inventory are reflected when the owner returns.
- Tests must cover filtering healthy inventory out of dashboard alerts.

## Design

`DashboardViewModel` loads inventory through `InventoryItemRepository` and exposes `lowInventoryItems`.

`DashboardView` renders:

- `No alerts yet` when no low-stock items exist.
- The first three low-stock items with `current / minimum unit`.
- A compact `+ n more` message when more than three alerts exist.

`RootView` injects the same local repository implementation already used by Inventory.

## Test Plan

- Unit tests:
  - Dashboard view model includes low-stock items.
  - Dashboard view model excludes healthy items.

- Acceptance tests:
  - Owner can add a low-stock inventory item and see it on the dashboard.

## Acceptance Criteria

- Dashboard Low inventory section reflects stored inventory data.
- Low-stock items show name, current quantity, minimum quantity, and unit.
- Healthy inventory items do not appear in the Low inventory dashboard section.
- Tests pass locally and in CI.
