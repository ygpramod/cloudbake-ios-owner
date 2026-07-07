# Slice RFC-0010: Archived Inventory Restore

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Allow the owner to review archived inventory items and restore one if it was archived by mistake.

## Scope

- Add repository support for fetching archived inventory items.
- Add an Archived Inventory view reachable from the Inventory screen.
- Show archived item name, quantities, and archived date.
- Restore an archived item to active inventory.
- Keep permanent delete out of scope.
- Add unit, integration, and acceptance tests.

## Out of Scope

- Permanent delete.
- Bulk restore.
- Search/filter within archived inventory.
- Editing archived items before restore.
- Archived inventory in dashboard alerts.

## Requirements

- Active inventory fetches continue to exclude archived items.
- Archived inventory fetches return archived items only.
- Restore must clear `archivedAt` and update `updatedAt`.
- Restored low-stock items should appear again in active inventory and dashboard low-inventory alerts.
- The owner must be able to close the Archived view without changes.

## Design

### Repository

`InventoryItemRepository` gains `fetchArchivedInventoryItems()`.

The GRDB implementation fetches rows where `archived_at_unix_time IS NOT NULL`, ordered by most recently archived first.

### View Model

`InventoryListViewModel` gains:

- `archivedItems`
- `loadArchivedItems()`
- `restoreItem(_:)`

Restore saves the same inventory item with `archivedAt` cleared and `updatedAt` set to the current time.

### UI

Inventory toolbar includes an Archived button. The Archived sheet lists archived items and supports
a visible `Restore` action.

RFC-0070 replaced the original trailing swipe presentation with a visible card action so archived
inventory matches the CloudBake detail-screen style.

## Test Plan

- Unit tests:
  - Archived items load into `archivedItems`.
  - Restore moves an archived item back to active inventory.

- Integration tests:
  - Repository archived fetch returns archived rows.
  - Restored rows move back to active fetch results.

- Acceptance tests:
  - Owner can archive an item, open Archived, restore it, and see it in active Inventory again.

## Acceptance Criteria

- Archived items can be viewed.
- Archived items can be restored.
- Restored items no longer appear in Archived.
- Restored items appear in active Inventory.
- Tests pass locally and in CI.
