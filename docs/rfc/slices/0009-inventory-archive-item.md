# Slice RFC-0009: Inventory Archive Item

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Allow the owner to remove accidental, duplicate, or no-longer-used inventory items from active workflows without permanently deleting history-sensitive data.

## Decision

This slice supports archive only. Permanent delete is deferred to a future data-cleanup slice because recipes, inventory transactions, orders, and audit history may later reference inventory items.

## Scope

- Add archive state to inventory items using an optional archive timestamp.
- Add a database migration for the archive timestamp.
- Show active inventory items only in the Inventory list.
- Exclude archived inventory items from duplicate checks.
- Exclude archived inventory items from dashboard low-inventory alerts.
- Add a swipe Archive action to inventory rows.
- Preserve direct fetch by inventory item id for future references and history.
- Add unit, integration, and acceptance tests.

## Out of Scope

- Permanent delete.
- Archived inventory list.
- Restore archived inventory item.
- Audit/history UI.
- Rules for deleting items referenced by recipes or transactions.

## Requirements

- Existing inventory rows must migrate as active.
- Archiving must set `archivedAt` and update `updatedAt`.
- Active inventory fetches must exclude archived items.
- Direct inventory fetch by id may return archived items.
- Dashboard low inventory must ignore archived items.
- Duplicate warning checks must ignore archived items.

## Design

### Model

`InventoryItem` gains:

- `archivedAt: Date?`
- `isArchived`

### Persistence

Migration `0004_add_inventory_archive_timestamp` adds nullable `archived_at_unix_time` to `inventory_items`.

`fetchInventoryItems()` returns active rows only. `fetchInventoryItem(id:)` still returns the matching row regardless of archive state.

### UI

Active inventory rows expose an `Archive` action. RFC-0069 moved the active inventory list to
card-based styling, so this action is now a visible row action chip instead of a list-row swipe
action.

## Test Plan

- Unit tests:
  - `InventoryItem.isArchived` is true when `archivedAt` is present.
  - View model archives an item and removes it from loaded inventory.
  - Duplicate checks ignore archived inventory items.
  - Dashboard low-inventory view model ignores archived low-stock items.

- Integration tests:
  - Repository list fetch excludes archived rows.
  - Repository direct id fetch still returns archived rows.

- Acceptance tests:
  - Owner can archive an inventory item from the list.
  - Archived item no longer appears in Inventory.
  - Archived low-stock item no longer appears on Dashboard.

## Acceptance Criteria

- Active inventory remains visible.
- Archived inventory is hidden from active owner workflows.
- Archiving is non-destructive.
- Tests pass locally and in CI.
