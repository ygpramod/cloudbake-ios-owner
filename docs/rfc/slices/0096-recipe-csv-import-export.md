# Slice RFC-0096: Recipe CSV Import And Export

## Status

Implemented

## Scope

1. Export recipes from Settings using `name`, `recipe`, and `ingredients` CSV columns.
2. Encode ingredients as `name:quantity:unit` values separated by `|`.
3. Include a `# Example` row in every export and ignore comment rows during import.
4. Match imported ingredient names against exactly one active inventory item name or alias.
5. Create recipes and their default Ingredients component only after the complete file validates.
6. Reject malformed ingredients, unsupported units, missing/ambiguous inventory matches, and names
   that already exist locally.
7. Validate unit compatibility and the complete file before saving all imported records in one
   database transaction.
8. Resolve archived inventory during export so existing recipe ingredients are not silently lost;
   fail export when a stored inventory reference is missing entirely.

## Format

```csv
name,recipe,ingredients
# Example - ignored during import,,"Cake Flour:250:g | Sugar:200:g"
Vanilla Sponge,"Bake at 170°C","Cake Flour:250:g | Sugar:200:g"
```

The `recipe` column contains owner notes or instructions. Recipe import does not create inventory,
change stock, or import ingredient notes/components beyond the default Ingredients component.

## Test Strategy

1. Unit coverage verifies export quoting, the example row, and pipe-separated ingredient encoding.
2. Unit coverage verifies comment skipping and inventory alias matching.
3. Unit coverage verifies unmatched inventory fails before any recipe is saved.
4. Unit coverage verifies duplicate headers, incompatible units, atomic failure, archived inventory,
   and missing export references.
5. Acceptance verifies Settings exposes both recipe CSV actions.

## Documentation Decision

The recipe CSV contract and Settings workflow are durable owner-facing behavior, so the repository
README and authored wiki sources are updated.
