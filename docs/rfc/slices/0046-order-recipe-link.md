# Slice RFC-0046: Order Recipe Link

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Authority And Scope

This slice lets the owner link an order to an existing saved recipe for planning and preparation
context.

This slice includes:

- adding an optional recipe reference to persisted orders,
- selecting or clearing a linked recipe from order add/edit,
- showing the linked recipe name in order detail,
- refreshing recipe choices when opening the order form,
- focused view-model, persistence, and acceptance coverage.

This slice does not include:

- marking a recipe as used,
- deducting inventory from recipe ingredients,
- recipe scaling for order size or servings,
- price calculation from recipe ingredients,
- customer-facing recipe visibility.

## Requirements

- Orders may be saved with no linked recipe.
- Orders may link to one existing recipe.
- The order form must show a recipe selection option when saved recipes exist.
- The owner must be able to clear a linked recipe before saving.
- Order detail must show the linked recipe name when an order has a recipe link.
- Order persistence must round-trip the optional recipe link.
- Deleting a recipe later should not make old orders unreadable.

## Design

`Order` now carries an optional `recipeId`. GRDB migration `0008_add_order_recipe_link` adds
`orders.recipe_id` as a nullable foreign key to `recipes(id)` with `ON DELETE SET NULL`.

`OrderListViewModel` loads recipes alongside orders and customers. Add/edit draft state holds the
selected recipe id, and the order form presents a searchable recipe selection sheet that mirrors the
customer selection pattern. Order detail resolves the linked recipe by id and clears stale recipe
state when viewing unlinked orders or closing detail.

Inventory deduction remains deliberately separate. The next recipe/order slice should define when a
recipe is considered used, how quantities are scaled, and how stock batches are consumed.

## Testing

- View-model tests cover loading recipes, selecting and clearing recipe draft state, saving new and
  edited orders with recipe links, and clearing stale linked recipe detail.
- Persistence tests cover order round-trip with `recipeId`.
- A targeted acceptance test covers creating a recipe, linking it from an order, and seeing the
  linked recipe in order detail.

## Documentation Updates

- `README.md` lists Slice RFC-0046.
- `docs/rfc/orders.md` records recipe link from order as implemented.
- `wiki/Current-App-Capabilities.md` lists optional recipe links from orders.
- `wiki/Owner-Workflows.md` describes the owner recipe-link workflow.
