# Slice RFC-0028: Recipe List And Add Recipe

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Let the owner begin storing cake recipes in the app with a simple recipe list and add-recipe flow.

## Scope

- Replace the Recipes placeholder with an owner-facing recipe list.
- Add a recipe creation form for recipe name and owner notes.
- Persist recipes locally through the existing SQLite/GRDB recipe table.
- Fetch recipes in case-insensitive name order.
- Add unit, integration, and acceptance coverage for the new recipe workflow.
- Update README and wiki product documentation.

## Out Of Scope

- Recipe components.
- Recipe ingredients.
- Recipe scaling.
- Recipe-book photo or text conversion.
- Recipe-driven inventory reduction.
- Recipe pricing.
- Customer-facing recipe or flavor suggestions.

## Requirements

- The Recipes destination must show an empty state when no recipes exist.
- The owner must be able to add a recipe with a required name.
- Notes are optional and must be trimmed before storage.
- Blank recipe names must be rejected with a clear error.
- Saved recipes must appear in the Recipes list.
- Recipes must be stored locally on the device.

## Design

`RecipeListView` owns the SwiftUI screen for the Recipes destination.

`RecipeListViewModel` owns owner interactions:

- load recipes,
- validate the draft recipe,
- save a recipe,
- reset the draft after save or cancel,
- expose user-facing error messages.

The existing `RecipeRepository` protocol now includes `fetchRecipes()`. `GRDBCoreDataRepository`
implements it by reading from the existing `recipes` table ordered by recipe name.

This slice intentionally stores only recipe name and notes. That creates a useful owner workflow
without prematurely designing recipe components, recipe ingredients, scaling, or automatic stock
consumption.

## Tests

Unit and integration coverage:

- recipe list view model loads recipes,
- recipe creation trims and saves the draft,
- blank recipe names are rejected,
- persisted recipes fetch in name order.

Acceptance coverage:

- owner opens Recipes,
- sees the empty state,
- adds a recipe,
- sees the saved recipe in the list.

## Documentation

Updated:

- `README.md`
- `wiki/Business-Concepts.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- Recipes is no longer a placeholder screen.
- Owner can add a named recipe with optional notes.
- Saved recipes remain available through local persistence.
