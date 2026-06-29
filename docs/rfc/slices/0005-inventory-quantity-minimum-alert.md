# Slice RFC-0005: Inventory Quantity and Minimum Alert

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Make the Inventory screen practically useful by tracking current stock, comparing it to the minimum quantity, and highlighting low-stock items.

## Scope

- Add current quantity to `InventoryItem`.
- Add a database migration for current quantity.
- Capture current quantity in the add-item form.
- Show current quantity and minimum quantity in the inventory list.
- Add low-stock state when current quantity is below minimum quantity.
- Add tests for current quantity persistence, validation, and low-stock logic.

## Out of Scope

- Dashboard low-inventory summary.
- Editing existing inventory quantities.
- Inventory transactions from the UI.
- Unit conversion between different measurement units.
- Recipe-driven inventory consumption.

## Requirements

- Existing inventory rows must migrate safely with current quantity set to zero.
- Current quantity must not be negative.
- Low-stock state must be derived from current quantity and minimum quantity.
- SwiftUI views must not access GRDB directly.
- Tests must cover below-minimum and at-minimum behavior.

## Design

### Model

`InventoryItem` gains `currentQuantity` and an `isLowStock` derived property.

### Persistence

Migration `0003_add_inventory_current_quantity` adds `current_quantity` to existing inventory rows with a default of zero.

### UI

The add-item sheet captures current quantity. The list row shows current and minimum quantities and displays a low-stock warning icon when needed.

## Test Plan

- Unit tests:
  - Low-stock when current quantity is below minimum.
  - Not low-stock when current quantity equals minimum.
  - View model rejects negative current quantity.

- Integration tests:
  - Inventory item current quantity round-trips through GRDB.

- Acceptance tests:
  - Owner can add an inventory item with current and minimum quantities.
  - Inventory list shows both current and minimum quantities.

## Acceptance Criteria

- Inventory rows show current stock.
- Inventory rows still show minimum stock.
- Low-stock items are visually marked.
- Existing databases migrate safely.
- Tests pass locally and in CI.
