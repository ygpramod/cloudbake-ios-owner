# Slice RFC-0077: Inventory Aliases For Bill Scanning

## Status

Implemented

## Parent RFC

- `docs/rfc/slices/0019-purchase-bill-draft-parser.md`
- `docs/rfc/slices/0021-purchase-bill-draft-review.md`

## Context

Purchase bills often use names that differ from the owner's inventory names. A bill may say
`Aashirvaad Maida`, `plain flour`, or a brand-specific name while CloudBake inventory stores the
ingredient as `Cake Flour`.

The bundled baking catalog already has static aliases, but the owner needs per-inventory aliases so
bill scanning can improve as real bills are reviewed.

## Scope

In scope:

- storing aliases on inventory items,
- editing aliases from the inventory add/edit form,
- showing aliases on inventory detail,
- using active inventory item names and aliases while parsing purchase bill text,
- keeping aliases when stock changes, archive/restore, and order recipe usage update inventory.

Out of scope:

- a separate alias management screen,
- alias conflict review,
- automatically learning aliases from corrected bill drafts,
- exporting or importing aliases through inventory CSV.

## Requirements

- Aliases must be optional.
- The owner may enter aliases separated by commas or new lines.
- Blank aliases and case-insensitive duplicates must be removed before saving.
- Purchase bill parsing must match active inventory item aliases in addition to the bundled baking
  catalog.
- When an alias matches a bill line, the generated draft name must use the inventory item name so
  saving the draft updates the existing item.

## Design

Migration `0018_add_inventory_aliases` adds `aliases_json` to `inventory_items`.

`InventoryAliases` owns alias parsing and display formatting. `InventoryListViewModel` exposes a
single alias draft text field for inventory add/edit forms and builds a purchase bill catalog by
combining the bundled catalog with active inventory item names and aliases.

## Testing

Focused tests cover:

- alias parsing, trimming, and de-duplication,
- inventory form alias persistence,
- purchase bill draft parsing using a saved inventory alias,
- repository round-trip and update behavior for aliases.
