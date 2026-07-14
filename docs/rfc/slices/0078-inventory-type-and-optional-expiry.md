# Slice RFC-0078: Inventory Type And Optional Expiry

## Status

Implemented

## Parent RFC

- `requirements.md`
- `docs/rfc/slices/0014-inventory-expiry-and-stock-batches.md`
- `docs/rfc/slices/0075-reminder-screen.md`

## Context

Not every inventory item should behave the same. Shelf-stable pantry items and supplies can be
tracked by minimum stock level, but perishable items such as fruit should not create restock noise
unless they are needed for an upcoming cake order.

The owner also needs to add stock without an expiry date. Some supplies do not expire in a useful
operational sense, and forcing an expiry date creates bad data.

## Scope

In scope:

- inventory item type: Standard or Perishable,
- optional expiry when adding inventory and adjusting stock,
- four-day default expiry when an item is marked Perishable,
- perishable low-inventory alert suppression unless an active order needs the item through a
  linked recipe or order-specific extra ingredients,
- persistence migration for inventory type.

Out of scope:

- custom per-item expiry duration (introduced later by RFC-0109),
- recipe planning beyond active orders already stored in CloudBake,
- purchase bill type inference,
- supplier-level shelf-life rules.

## Requirements

- Existing inventory items must default to Standard.
- Standard inventory defaults to having an expiry date, but the owner can turn expiry off before saving.
- Perishable inventory must default the expiry date to four days from the action date.
- The owner may still change the perishable expiry date before saving.
- Dashboard and Reminders low-inventory alerts must hide perishable items unless an active order
  needs that inventory item.
- Active-order need includes linked recipe ingredients and order-specific extra ingredients.

## Design

Migration `0019_add_inventory_type` adds `inventory_type` to `inventory_items` with a Standard
default.

`InventoryItemType` represents Standard and Perishable. `InventoryListViewModel` owns draft type
and optional expiry state for add, edit, batch edit, and stock adjustment flows.

`InventoryLowInventoryAlertRules` centralizes the perishable alert rule so Dashboard and Reminders
use the same behavior.

## Testing

Focused tests cover:

- optional no-expiry initial stock,
- perishable four-day default expiry,
- persistence round-trip and update for inventory type,
- stock adjustment behavior with optional expiry,
- dashboard and reminder low-inventory suppression for perishable items,
- dashboard and reminder low-inventory visibility when an active order needs the perishable item.
