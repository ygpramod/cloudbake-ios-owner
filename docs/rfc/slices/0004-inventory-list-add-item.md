# Slice RFC-0004: Inventory List and Add Item

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Add the first usable owner inventory workflow: view inventory items and add a new item that persists locally on the device.

## Scope

- Replace the Inventory placeholder with an Inventory screen.
- List inventory items from the local SQLite database.
- Add an inventory item with name, unit, and minimum quantity.
- Persist newly added inventory items through the repository boundary.
- Add unit, integration, and acceptance tests for the workflow.

## Out of Scope

- Current quantity tracking.
- Low-stock alert calculation.
- Editing or deleting inventory items.
- Inventory transactions from the UI.
- Dashboard low-inventory integration.

## Requirements

- SwiftUI views must not access GRDB directly.
- Inventory items must be loaded from and saved to local persistence.
- Add-item validation must prevent blank names and negative minimum quantities.
- The workflow must remain usable on supported iPhone layouts.
- Tests must cover the view model, repository list query, and UI add flow.

## Design

### Screen

`InventoryListView` shows an empty state when no inventory exists and a list of persisted items when inventory is present. A toolbar add button opens a sheet for entering the item.

### State

`InventoryListViewModel` owns presentation state and talks to `InventoryItemRepository`. It trims names, validates minimum quantity, creates stable IDs, saves through the repository, and reloads the list.

### Persistence

`InventoryItemRepository` gains a `fetchInventoryItems()` list query. The GRDB implementation orders items by name.

## Test Plan

- Unit tests:
  - View model loads items.
  - View model saves a valid item and reloads.
  - View model rejects blank names.

- Integration tests:
  - Repository fetches inventory items in stable name order.

- Acceptance tests:
  - Owner can navigate to Inventory, add an item, and see it in the list.

## Acceptance Criteria

- Inventory screen is reachable from the dashboard.
- Owner can add an inventory item.
- Added inventory item persists locally.
- Tests pass locally and in CI.
