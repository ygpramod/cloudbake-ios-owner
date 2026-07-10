# Slice RFC-0076: Order Extra Ingredients

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`
- `docs/rfc/slices/0047-order-recipe-usage-inventory-deduction.md`
- `docs/rfc/slices/0066-order-recipe-usage-scaling.md`

## Context

Some handmade cake orders need small changes to the linked recipe without changing the original
saved recipe. Examples include extra nuts, decoration ingredients, flavor additions, or other
customer-specific adjustments.

## Scope

In scope:

- storing order-specific extra ingredients linked to inventory items,
- adding extra ingredients from order detail under Recipe Information,
- showing a simple extra-ingredient list with quantity and unit,
- deleting an extra ingredient before recipe usage is recorded,
- deducting extra ingredients together with the linked recipe when a Confirmed order becomes Ready
  or Completed.

Out of scope:

- editing existing extra ingredient rows,
- applying the order recipe multiplier to extra ingredients,
- pricing from extra ingredients,
- extra ingredients on orders without a linked recipe,
- partial recipe usage or inventory reservation.

## Requirements

- Extra ingredients must belong to one order and must not modify the original recipe.
- Each extra ingredient must link to an inventory item and store quantity, unit, and optional note.
- Order detail must show extra ingredients as a simple list under the linked recipe section.
- The owner must be able to add extra ingredients before recipe usage is recorded.
- The owner must be able to delete mistaken extra ingredients before recipe usage is recorded.
- When recipe usage is recorded, extra ingredient quantities must be converted into the inventory
  item unit when compatible and deducted in the same atomic operation as the linked recipe.
- Extra ingredients must be deducted exactly once because the existing one-time order recipe usage
  record still gates inventory deduction.

## Design

Migration `0017_create_order_extra_ingredients` adds `order_extra_ingredients`, linked to `orders`
and `inventory_items`.

`OrderExtraIngredientRepository` handles save, fetch, and delete. `OrderListViewModel` owns the add
draft and displays `OrderExtraIngredientRow` values with inventory item names.

`GRDBCoreDataRepository.recordRecipeUsage` now builds pending inventory usage from both saved recipe
ingredients and the order's extra ingredients. Recipe ingredients still use the order recipe
multiplier; extra ingredients are exact order quantities and are not multiplied.

## Testing

Focused tests cover:

- saving, fetching, deleting, and displaying order extra ingredients,
- recipe usage deducting order extra ingredients,
- preserving existing one-time recipe usage and inventory transaction behavior.

