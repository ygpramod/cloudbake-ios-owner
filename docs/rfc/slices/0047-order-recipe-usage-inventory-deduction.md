# Slice RFC-0047: Order Recipe Usage And Inventory Deduction

## Authority And Scope

This slice implements the first owner-controlled recipe usage workflow for orders. It depends on
orders being able to link to one saved recipe and recipes being able to store inventory-backed
ingredient rows.

In scope:

- recording that a linked recipe has been used for an order,
- deducting linked recipe ingredients from inventory,
- converting ingredient units into the inventory item's stored unit,
- consuming stock batches from the oldest expiry first,
- preventing the same order from deducting inventory more than once,
- showing recipe usage state in order detail.

Out of scope:

- recipe scaling for different cake sizes,
- partial recipe usage,
- reservations before recipe usage,
- multi-recipe orders,
- order checklist integration,
- pricing or payment changes.

## Requirements Summary

- Order detail must show whether the linked recipe has been used.
- An order with a linked recipe must expose an owner action to use that recipe.
- Using a linked recipe must ask for confirmation before changing inventory.
- The app must deduct each recipe ingredient from its linked inventory item.
- Deduction must convert from the recipe ingredient unit to the inventory item unit when compatible.
- Deduction must fail with an owner-visible error when units are incompatible.
- Deduction must fail with an owner-visible error when stock is insufficient.
- If inventory batches exist, deduction must consume the oldest expiring batches first, with
  no-expiry batches last.
- The app must record inventory consumption transactions for recipe usage.
- The app must record one recipe usage per order and reject duplicate usage for the same order.

## Non-Functional Requirements

- Recipe usage and inventory deduction must be atomic in persistence.
- Tests must cover the view-model command, the GRDB deduction path, duplicate protection, and the
  owner acceptance flow.
- The implementation must reuse existing local-first GRDB patterns.
- The workflow must remain owner-driven; no automatic inventory deduction happens merely because an
  order status changes.

## Design

`OrderRecipeUsage` records a one-time usage event for an order and recipe. Migration
`0009_create_order_recipe_usages` creates `order_recipe_usages` with a unique `order_id` so one
order cannot deduct the same linked recipe more than once.

`OrderRecipeUsageRepository.recordRecipeUsage` performs the full domain operation inside one GRDB
write transaction:

- validate the order has a linked recipe,
- reject existing usage for that order,
- load all recipe ingredients,
- load each linked inventory item,
- convert required quantities into the item unit,
- validate current stock and batch stock,
- deduct oldest-expiring stock batches first,
- save updated inventory items,
- write inventory consumption transactions,
- save the usage record.

`OrderDetailView` shows linked recipe usage state. When usage is not recorded, it exposes a
`Use Recipe` toolbar action with confirmation.

## Testing

- Unit tests cover `OrderListViewModel.recordSelectedOrderRecipeUsage`.
- Integration tests cover GRDB recipe usage deduction, unit conversion, oldest-expiry-first batch
  consumption, consumption transaction creation, and duplicate usage rejection.
- Acceptance test covers adding inventory, creating a recipe ingredient, linking the recipe to an
  order, using the recipe, and seeing inventory current quantity reduce.

## Documentation Updates

- `docs/rfc/orders.md` records the slice as implemented.
- `wiki/Current-App-Capabilities.md` lists order recipe usage and inventory deduction.
- `wiki/Owner-Workflows.md` explains the owner workflow and one-time deduction behavior.
- `wiki/Business-Concepts.md` describes order recipe usage as the first recipe-driven inventory
  deduction path.
