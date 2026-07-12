# Slice RFC-0095: Section Header Add Actions

## Status

Implemented

## Scope

1. Move Add Ingredient from the recipe detail header to a compact `+` beside Ingredients.
2. Move Add Inventory Item from the Inventory screen header to a compact `+` beside Items.
3. Keep both actions visible with populated and empty sections.
4. Reuse one shared section-action treatment and preserve the existing accessibility identifiers.

## Test Strategy

1. Run the full unit and integration suite because the shared section component changes.
2. Run the recipe ingredient owner journey to verify the relocated action opens and completes the
   existing add flow.
3. Run the inventory add/duplicate journey to verify the relocated action opens the existing form.

## Documentation Decision

The owner workflow wiki is updated because the visible location of two primary creation actions
changed. No persistence, migration, or domain behavior changes in this slice.
