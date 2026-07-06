# Slice RFC-0066: Order Recipe Usage Scaling

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`
- `docs/rfc/slices/0047-order-recipe-usage-inventory-deduction.md`

## Context

The first order recipe usage slice deducts one exact linked recipe when a Confirmed order becomes
Ready or Completed. Handmade cakes often need the same trusted recipe at a larger or smaller batch
size. The owner needs a simple multiplier before the broader future work of partial usage,
multi-recipe orders, or inventory reservation.

## Scope

In scope:

- storing an order-level recipe multiplier,
- defaulting existing and new orders to a `1` multiplier,
- allowing the owner to set a positive multiplier from order add/edit,
- applying the multiplier during atomic recipe-driven inventory deduction,
- recording the multiplier on the one-time recipe usage event,
- showing the multiplier in order detail.

Out of scope:

- partial ingredient selection,
- multi-recipe orders,
- inventory reservation before usage,
- recipe serving/yield modeling,
- pricing changes.

## Requirements

- Orders with a linked recipe must default to a multiplier of `1`.
- The owner must be able to enter a positive recipe multiplier in order add/edit.
- Blank, zero, negative, and non-numeric multipliers must be rejected.
- Recipe usage must multiply each converted ingredient quantity by the order multiplier before
  validating stock and deducting inventory.
- The multiplier used for deduction must be recorded on `OrderRecipeUsage`.
- Existing one-time usage and oldest-expiry-first stock batch behavior must remain unchanged.

## Design

Migration `0013_add_order_recipe_scaling` adds `recipe_scale_multiplier_decimal` to `orders` and
`order_recipe_usages`. Both columns default to `1` so existing local data keeps current behavior.

`Order.recipeScaleMultiplier` stores the current planned multiplier. `OrderRecipeUsage` stores the
actual multiplier used at deduction time, which preserves the historical record if the order changes
later.

`OrderListViewModel` owns a `draftRecipeScaleMultiplier` string for the form. Validation requires a
positive decimal value. Clearing the linked recipe resets the draft multiplier to `1`.

`GRDBCoreDataRepository.recordRecipeUsage` passes the order multiplier into pending inventory usage
calculation. Ingredient quantities are still converted into the inventory item's unit first, then
multiplied, validated, consumed, and recorded in a single transaction.

## Testing

Focused tests cover:

- order add validation and persistence of a recipe multiplier,
- rejecting invalid multipliers,
- GRDB recipe usage deducting multiplied inventory quantities,
- recording the multiplier on the recipe usage event.

## Follow-Up

- Add partial recipe usage.
- Add multi-recipe order usage.
- Add inventory reservation before usage.
- Add serving/yield modeling if recipe scaling needs to move beyond a raw multiplier.
