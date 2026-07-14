# Slice RFC-0109: Inventory Default Expiry Days

## Status

Implemented

## Context

Standard and Perishable type defaults are useful starting points, but individual ingredients can
have a known shelf life that differs from those broad categories. Re-entering the same expiry for
every purchase or adjustment is avoidable work and increases the chance of an incorrect date.

## Scope

1. Store an optional default expiry duration on each inventory item as a number of days.
2. Allow the owner to set or clear it while adding or editing an inventory item.
3. Apply it to initial stock, upward stock adjustments, and matched purchase-bill drafts.
4. Preserve the ability to change or remove the expiry date on each stock batch.
5. Include the value in inventory CSV import and export.

Voice inventory entry and supplier-specific expiry rules are outside this slice.

## Requirements

1. Default expiry days must be blank or a positive whole number.
2. An item-level value overrides the type default.
3. Without an item-level value, Standard inventory defaults to one calendar month and Perishable
   inventory defaults to four days, preserving existing behavior.
4. Changing the item-level value affects future stock only and must not rewrite existing batches.
5. A matched purchase-bill draft uses the saved item default; an unmatched draft retains the
   Standard fallback.
6. The owner can change or disable the calculated expiry before saving a batch.

## Persistence And CSV

Migration `0028_add_inventory_default_expiry_days` adds nullable integer column
`default_expiry_days` to `inventory_items`.

Inventory CSV adds the required `default_expiry_days` column. Blank represents no item override.
Import rejects zero, negative, fractional, non-numeric, or conflicting values. Backward
compatibility with CSV files that omit this column is intentionally out of scope.

## Testing

Focused coverage verifies persistence, add and edit validation, stock-adjustment defaults,
purchase-bill matching, CSV round trips and validation, and the owner-facing edit flow.

## Documentation Decision

This slice changes durable inventory and CSV behavior, so the Inventory Guide, Business Concepts,
Owner Workflows, Current App Capabilities, earlier expiry RFC, and repository README are updated.
