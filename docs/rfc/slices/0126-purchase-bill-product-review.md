# Slice RFC-0126: Purchase Bill Product Review

## Status

Implemented

## Context

Real iPhone Vision output contains store metadata, OCR spacing errors, products outside the bundled
baking catalog, prices on either the product line or the following line, and uncertain charge rows.
Filtering drafts to known catalog items hides purchases and prevents the owner from deciding what
should become inventory.

## Scope

1. Treat the editable, on-device OCR transcript as the input source of truth.
2. Parse every measured product row after the receipt product section begins, whether or not it
   matches the bundled catalog or current inventory.
3. Normalize common OCR price spacing such as `3. 15` and a trailing unit period such as `2L.`.
4. Support a following price row such as `2 4.00`; multiply the package measurement by the count
   while retaining `4.00` as the total purchase amount.
5. Keep a product-like row without a measurement as `1 each`, but default it to Ignore because its
   classification is uncertain.
6. Stop product parsing at the receipt summary and ignore discounts, savings, totals, tax,
   payment, and loyalty metadata without attempting receipt reconciliation.
7. Auto-map a unique active inventory name or alias match.
8. Show an Add to Inventory toggle on every draft. Measured unmatched products default on and create
   new inventory; uncertain no-measurement rows default off. Included rows can be mapped to existing
   inventory instead.
9. Keep name, quantity, a compact explicitly bounded unit menu, amount paid, and expiry editable.
   Ask for minimum quantity only when creating new inventory.
10. Add the receipt product name as an alias when mapping to existing inventory.
11. Save all included inventory items and purchase batches atomically, including the parsed amount.

## Out Of Scope

1. Store-specific receipt templates.
2. Discount allocation, total reconciliation, tax allocation, or payment extraction.
3. Server OCR, generative AI, or a network fallback.
4. Hidden or automatic saving without the owner's final Save action.

## Example From On-Device OCR

`CHIPSMORE DOUBLE CHOCO 135G` followed by `2 4.00` becomes an unresolved draft for `270 g` with an
amount of `4.00`. `OREO S COOKIES VANILLA 105G` followed by `1.85` auto-maps when that exact name is
an inventory alias. `PLASTIC BAG CHARGE 0.05` becomes `1 each` and defaults to Ignore.

The exact owner-provided iPhone OCR transcript is retained as a deterministic parser fixture. This
ensures implementation and regression tests use the intelligence actually available on the phone,
including its original line breaks and spacing errors.

## Testing

1. Parser tests use the exact phone OCR transcript and assert all seven product candidates,
   quantities, units, prices, uncertainty defaults, and receipt aliases.
2. View-model tests verify existing matches, default Create New for measured products, default off
   for uncertain charges, and Save gating.
3. Workflow tests verify mapped aliases, priced purchase batches, compatible unit conversion,
   ignored rows, validation failures, and atomic persistence.

## Documentation Decision

This changes a visible inventory workflow and the meaning of purchase-bill drafts, so the Inventory
Guide, Owner Workflows, and Current App Capabilities wiki sources are updated in the same PR.
