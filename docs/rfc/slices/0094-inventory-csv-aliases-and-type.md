# Slice RFC-0094: Inventory CSV Aliases And Type

## Status

Implemented

## Scope

1. Add required `aliases` and `type` columns to inventory CSV export and import.
2. Export normalized aliases as a comma-separated value inside the CSV field.
3. Export inventory type as Standard or Perishable.
4. Apply imported aliases and inventory type when creating or updating an item.
5. Reject CSV files that omit either new header or contain an unsupported type.
6. Reject conflicting aliases, type, or minimum quantity across batch rows for the same item.

Backward compatibility with the earlier seven-column CSV schema is intentionally out of scope.

## Test Strategy

1. Export coverage verifies aliases, type, quoting, amount, and expiry.
2. Import coverage verifies new-item creation and existing-item replacement for aliases and type.
3. Validation coverage verifies missing headers, unsupported types, and conflicting batch-row
   metadata are rejected.
4. The full unit and integration suite provides repository regression coverage.

## Documentation Decision

The CSV contract is durable owner-facing behavior, so the original CSV slice, inventory wiki guide,
business concepts, workflow documentation, and repository README are updated in this slice.
