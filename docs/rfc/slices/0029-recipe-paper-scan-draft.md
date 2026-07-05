# Slice RFC-0029: Recipe Paper Scan Draft

## Status

Accepted

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Let the owner scan or import a recipe from paper or a recipe book, review the recognized text, and
save it as an editable recipe draft.

## Scope

- Add an Import Recipe flow from the Recipes screen.
- Support recipe photo capture from camera.
- Support recipe image import from the photo library.
- Reuse local Apple Vision OCR through a generic document text recognizer boundary.
- Convert recognized text into a draft recipe:
  - first non-empty line becomes the recipe name,
  - remaining non-empty lines become recipe notes.
- Allow manual recognized-text entry for unclear handwriting or simulator testing.
- Let the owner edit draft name and notes before saving.
- Add focused unit and acceptance coverage.
- Update README and wiki source.

## Out Of Scope

- LLM-based recipe interpretation.
- Ingredient quantity extraction into structured recipe items.
- Matching recipe ingredients to inventory items.
- Recipe-driven inventory deduction.
- Scaling recipe quantities.
- Preserving the recipe photo as a saved attachment.

## Requirements

- The app must offer Import Recipe from the Recipes screen.
- The owner must be able to take or choose a recipe image.
- OCR must run locally on device through Apple Vision.
- The recognized text must remain editable before draft creation.
- The generated draft must remain editable before save.
- Blank or unreadable recognized text must show a clear error.
- Saving the draft must use the same local recipe persistence as manual recipe creation.

## Design

`DocumentTextRecognizing` is the generic OCR boundary. Existing purchase-bill OCR names remain as
type aliases so purchase-bill code keeps compiling without broad churn.

`RecipeDraftParser` is intentionally deterministic. It does not infer ingredient structure yet; it
only creates a recipe name and notes from recognized text. This avoids pretending handwritten recipe
understanding is reliable before the app has an owner review model for ingredients.

`RecipeImportView` owns the recipe import sheet:

- camera capture,
- photo library selection,
- selected image preview,
- recognized text editing,
- draft recipe editing,
- save/cancel actions.

`RecipeListViewModel` owns the draft state and OCR-to-draft transition.

## Tests

Unit coverage:

- parser creates draft name and notes from recognized text,
- parser rejects blank text,
- view model copies recognized text into draft fields,
- view model handles OCR success and failure.

Acceptance coverage:

- owner opens Recipes,
- opens Import Recipe,
- enters recognized text,
- creates an editable draft,
- saves the recipe,
- sees the saved recipe in the list.

## Documentation

Updated:

- `README.md`
- `wiki/Business-Concepts.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- Owner can convert a paper or book recipe into an editable saved recipe draft.
- OCR runs locally and does not require an external subscription.
- Ingredient quantity extraction is explicitly deferred to the next recipe modeling slice.
