# Slice RFC-0133: Continuous Recipe Ingredient Entry

## Status

Implemented.

## Parent RFC

- `docs/rfc/screens/recipes.md`

## Context

Previously, the owner had to save a recipe before adding inventory-linked ingredient rows and had
to reopen Add Ingredient for every row. That interrupts recipe capture when several ingredients
are entered together.

## Scope

1. Show an Ingredients section in Add Recipe with a `+` action on its header line.
2. Let the owner add and remove inventory-linked ingredient drafts before saving the recipe.
3. Keep the existing native top-toolbar Save action in Add Ingredient.
4. Show Continue adding ingredients only for new ingredient entry, not Edit Ingredient.
5. With Continue adding ingredients off, Save stores the row and returns to Add Recipe.
6. With Continue adding ingredients on, Save stores the row, clears the ingredient fields, and
   remains in Add Ingredient for the next row.
7. Keep Save disabled until the ingredient input is valid.
8. Persist the new recipe, default Ingredients component, and all ingredient drafts in one atomic
   repository operation.
9. Keep drafts intact and show an error if the atomic save fails.
10. Cancelling Add Recipe discards its unsaved ingredient drafts.

## Validation

1. Unit tests cover multiple ingredient drafts, atomic persistence, reset after success, and draft
   preservation after failure.
2. Acceptance coverage creates inventory, enters two ingredients continuously, saves the recipe,
   and verifies both rows persisted.
3. Strict Swift formatting and acceptance-test registration checks pass.

## Documentation Decision

This changes the durable recipe-creation workflow. Update the Recipes screen RFC and canonical
slice map in the companion CloudBake foundation change, and update Owner Workflows and Current App
Capabilities in this implementation PR.
