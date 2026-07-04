# Completed Work

This page summarizes owner app capabilities that have been completed or are present in the current
slice branch. Source RFCs remain authoritative for scope, test plans, and detailed acceptance
criteria.

## App Foundation

| Slice | Source | Owner-visible result |
| --- | --- | --- |
| RFC-0001 | `docs/rfc/slices/0001-owner-app-shell.md` | Native SwiftUI iPhone/iPad app shell with Dashboard, Orders, Inventory, Recipes, Designs, Customers, and Settings destinations. |
| RFC-0002 | `docs/rfc/slices/0002-local-persistence-foundation.md` | Local SQLite persistence foundation using GRDB and explicit migrations. |
| RFC-0003 | `docs/rfc/slices/0003-core-data-model.md` | Base domain model for inventory, recipes, orders, customers, designs, pricing, reminders, and inventory transactions. |
| RFC-0006 | `docs/rfc/slices/0006-ios-test-workflow.md` | Split local and CI test lanes for unit/integration tests and acceptance UI tests. |

## Inventory

| Slice | Source | Owner-visible result |
| --- | --- | --- |
| RFC-0004 | `docs/rfc/slices/0004-inventory-list-add-item.md` | Inventory screen lists local items and allows the owner to add persisted inventory items. |
| RFC-0005 | `docs/rfc/slices/0005-inventory-quantity-minimum-alert.md` | Inventory items track current and minimum quantities, show low-stock state, and warn on possible duplicate names. |
| RFC-0007 | `docs/rfc/slices/0007-inventory-edit-item.md` | Owner can edit active inventory item details from the list. |
| RFC-0008 | `docs/rfc/slices/0008-dashboard-low-inventory.md` | Dashboard summarizes low-inventory items and exposes a quick path back to inventory. |
| RFC-0009 | `docs/rfc/slices/0009-inventory-archive-item.md` | Owner can archive active inventory items instead of deleting operational history. |
| RFC-0010 | `docs/rfc/slices/0010-archived-inventory-restore.md` | Owner can view archived inventory and restore items when needed. |
| RFC-0011 | `docs/rfc/slices/0011-inventory-stock-adjustment.md` | Owner can add stock to active inventory items and store adjustment transactions. |
| RFC-0012 | `docs/rfc/slices/0012-inventory-stock-consumption.md` | Owner can manually record stock usage, reduce current quantity, and store consumption transactions. |

## Current Operating Notes

1. The owner app is local-first; backend and sync are not required for the completed owner workflows.
2. Inventory stock changes are auditable through inventory transaction records, though transaction history UI is not implemented yet.
3. Recipe-driven inventory reduction is intentionally future work; current stock usage is manual.
4. Acceptance tests should be updated for owner-critical workflows as each slice adds behavior.

## Wiki Update Rule

For each future slice:

1. update this page when owner-visible completed behavior changes,
2. add a focused page when a topic becomes too large for this summary,
3. keep RFCs and ADRs as the detailed source of engineering truth,
4. publish or request publication to GitHub Wiki after the source changes merge to `main`.
