# Slice RFC-0030: Recipe Ingredient Rows

## Status

Accepted

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Let the owner define the inventory items and quantities needed by a recipe so recipes can later
deduct inventory accurately when used.

## Scope

- Add a recipe detail view.
- Show recipe notes in detail.
- Show recipe ingredient rows.
- Add manually linked recipe ingredients.
- Edit existing ingredient rows by tapping them.
- Delete ingredient rows from recipe detail.
- Link each recipe ingredient to an active inventory item.
- Store quantity, unit, and optional note for each ingredient.
- Create the default `Ingredients` recipe component automatically when the first ingredient is
  saved.
- Add repository methods for fetching recipe components, fetching recipe ingredients, and deleting
  recipe ingredients.
- Add unit, integration, and acceptance coverage.
- Update README and wiki source.

## Out Of Scope

- Parsing scanned recipe text into ingredient rows.
- Inventory-item fuzzy matching from recipe text.
- Recipe scaling.
- Recipe-driven inventory deduction.
- Inventory transaction creation from recipe use.
- Optional/unlinked recipe ingredients.

## Requirements

- The owner must be able to tap a recipe to view its detail.
- Recipe detail must show an empty ingredient state when no ingredients exist.
- The owner must be able to add an ingredient row linked to an active inventory item.
- Ingredient quantity must be greater than zero.
- Ingredient rows must show inventory item name, quantity, unit, and note when present.
- The owner must be able to edit an ingredient row.
- The owner must be able to delete an ingredient row.
- Ingredient rows must persist locally.

## Design

The existing `recipe_components` and `recipe_ingredients` tables are used without schema changes.

Because `recipe_ingredients.inventory_item_id` is required, this slice intentionally requires every
ingredient row to link to an active inventory item. That keeps the model ready for recipe-driven
deduction and avoids a later migration from unlinked text rows to inventory-backed rows.

`RecipeListViewModel` owns recipe detail state:

- selected recipe,
- available inventory items,
- ingredient rows with display inventory names,
- add/edit ingredient draft fields,
- save/delete ingredient behavior.

When the first ingredient is saved, the view model creates a default `Ingredients` component for
the recipe. Future slices can add richer component grouping if the owner needs sections like
Sponge, Filling, and Frosting.

`InventoryUnitDisplay` moves shared unit labels from Inventory UI into the domain layer so Recipes
and Inventory use the same labels.

## Tests

Unit and integration coverage:

- recipe detail loads ingredient rows with inventory names,
- add ingredient defaults to the first inventory item,
- saving creates the default component and persists the ingredient,
- invalid quantities are rejected,
- deleting an ingredient removes it and reloads rows,
- GRDB fetches recipe components and ingredients,
- GRDB deletes recipe ingredients.

Acceptance coverage:

- owner creates inventory,
- owner creates a recipe,
- owner opens recipe detail,
- owner adds a linked ingredient quantity,
- saved ingredient appears in recipe detail.

## Documentation

Updated:

- `README.md`
- `wiki/Business-Concepts.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- A recipe can now carry structured inventory-backed ingredient rows.
- Recipe ingredient rows are ready for a future Use Recipe inventory deduction flow.
