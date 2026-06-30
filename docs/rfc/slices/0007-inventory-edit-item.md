# Slice RFC-0007: Inventory Edit Item

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Allow the owner to correct and maintain existing inventory items without creating duplicate rows.

This follows RFC-0005, where duplicate-name detection warned the owner that editing an existing item may be better than adding another one.

## Scope

- Open an existing inventory item from the Inventory list.
- Reuse the inventory item form in edit mode.
- Allow editing item name, unit, current quantity, and minimum quantity.
- Save edits back to the same inventory record.
- Preserve the original `createdAt` timestamp and update `updatedAt`.
- Keep add-item duplicate warning behavior intact.
- Avoid warning about a duplicate when an edited item still matches its own existing name.
- Add unit, integration, and acceptance tests for the edit flow.

## Out of Scope

- Delete inventory item.
- Inventory transaction history.
- Stock adjustment audit trail.
- Unit conversion between measurement units.
- Recipe-driven inventory consumption.

## Requirements

- Editing must update the existing row, not append a new row.
- Editing must use the same validation as add:
  - Name is required.
  - Current quantity cannot be negative.
  - Minimum quantity cannot be negative.
- Editing an item with the same or similar name as itself must not show a duplicate warning.
- Editing an item to match a different inventory item should warn before saving the duplicate-like name.
- SwiftUI views must not access GRDB directly.
- The owner must be able to cancel editing without changing the stored item.

## Design

### View Model

`InventoryListViewModel` tracks an optional `editingItem` and provides:

- `beginEditing(_:)`
- `saveEditedItem()`
- `cancelEditing()`

The save path reuses draft validation and persists an `InventoryItem` with the original `id` and `createdAt`.

### Persistence

No schema change is required. The existing inventory repository `save(_:)` behavior is an upsert by item `id`.

### UI

Inventory rows are tappable. Tapping a row opens the shared inventory form with the title `Edit Item`.

The add flow still opens the same form with the title `Add Item`.

## Test Plan

- Unit tests:
  - Beginning edit copies the selected item into draft fields.
  - Saving edit updates the existing item and preserves `createdAt`.
  - Blank edited names are rejected.
  - Editing a name that still matches itself does not show duplicate warning.

- Integration tests:
  - Saving an inventory item with the same `id` updates the existing GRDB row.

- Acceptance tests:
  - Owner can add an inventory item, open it, edit current quantity, save, and see the updated quantity in the list.

## Acceptance Criteria

- Inventory item rows can be opened for editing.
- Edits update the existing item in place.
- Updated current quantity is visible in the inventory list after saving.
- Add-item duplicate warning behavior still works.
- Tests pass locally and in CI.
