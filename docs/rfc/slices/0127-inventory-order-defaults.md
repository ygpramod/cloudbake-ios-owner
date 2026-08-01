# Slice RFC-0127: Inventory And Order Workflow Defaults

## Status

Implemented.

## Goal

Use practical defaults for newly entered stock and orders without turning optional recipe and
inventory planning into a prerequisite for completing real bakery work.

## Requirements

1. Standard inventory defaults a new stock batch expiry to three calendar months after the stock
   addition date.
2. Perishable inventory keeps its four-day default expiry date.
3. An item-level positive default-expiry duration continues to override the type default.
4. Standard inventory receives one expiry notification fourteen calendar days before expiry at
   the existing 9:00 AM notification time.
5. Perishable inventory does not receive expiry reminder notifications. Its expiry remains visible
   in inventory detail and continues to affect usable stock and expiry status.
6. A newly started order defaults its due time to one calendar day after creation, rounded to the
   nearest whole hour. Minutes below 30 round down; minutes at or above 30 round up. Seconds are
   removed.
7. Recipe and inventory links remain optional. An order without either can be created and moved to
   Ready and Completed without an inventory confirmation or a recipe-usage record.
8. When a recipe is linked, the existing one-time deduction, shortage confirmation, costing, and
   reservation rules remain unchanged.

## Validation

- Unit tests cover both due-time rounding examples, the three-month Standard default, the retained
  four-day Perishable default, the fourteen-day Standard reminder, and Perishable suppression.
- Persistence integration tests prove that a recipe-free order moves through Ready and Completed
  without creating recipe usage.
- Existing recipe-backed lifecycle tests continue to prove that linked ingredients cannot bypass
  deduction validation.

## Documentation Decision

This slice changes durable Inventory, Reminders, and Orders behavior, so the inventory and order
wiki guidance and current-capabilities inventory are updated in the same PR.
