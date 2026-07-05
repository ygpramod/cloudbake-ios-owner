# Slice RFC-0032: Recipe Detail Edit

## Status

Accepted

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Let the owner edit recipe name and notes from recipe detail.

## Scope

- Add a recipe edit action to recipe detail.
- Reuse the recipe form for edit mode.
- Persist edited recipe name and notes.
- Refresh recipe detail and recipe list after save.
- Add unit and acceptance coverage.
- Update README and wiki source.

## Out Of Scope

- Editing ingredient rows beyond the existing ingredient edit flow.
- Recipe photo editing.
- Recipe version history.
- Recipe-driven inventory deduction.

## Requirements

- Recipe detail must expose an edit action.
- The edit form must show the current recipe name and notes.
- Recipe name remains required.
- Saved edits must update recipe detail.
- Saved edits must update the recipe list.

## Design

`RecipeListViewModel` adds edit-recipe state transitions:

- `beginEditingRecipe()`,
- `saveEditedRecipe()`.

The existing `RecipeForm` is reused by add and edit flows through injected save and cancel handlers.
Recipe detail exposes a direct pencil button so editing notes is visible and easy to reach.

## Tests

Unit coverage:

- edited recipe name and notes are persisted,
- selected recipe and recipe list refresh after save.

Acceptance coverage:

- owner creates a recipe,
- opens recipe detail,
- edits recipe notes,
- sees the updated notes in detail.

## Documentation

Updated:

- `README.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- Recipe notes are editable from recipe detail.
