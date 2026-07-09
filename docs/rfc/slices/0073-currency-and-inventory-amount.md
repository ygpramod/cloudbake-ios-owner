# Slice RFC-0073: Currency And Inventory Amount

## Authority And Scope

This slice adds owner-level currency display and records amount on inventory stock batches.

In scope:

1. Settings currency choice,
2. supported currency symbols for dollar, Indian rupee, British pound, and Malaysian ringgit,
3. order money display using the selected currency symbol,
4. amount capture on inventory add, stock adjustment, and stock batch correction,
5. stock batch combining when quantity is added with the same expiry date and amount,
6. inventory CSV import/export support for amount.

Out of scope:

1. exchange rates,
2. multi-currency orders,
3. tax calculation,
4. ingredient cost rollups into recipe/order pricing,
5. cost-aware stock consumption accounting.

## Requirements Summary

The owner must be able to choose the app currency from Settings. The first supported symbols are
`$`, `₹`, `£`, and `RM`.

Order price, deposit, balance, and inventory amount display must use the selected symbol.

Inventory add and stock adjustment must allow an optional amount. Stock batch correction must
allow the owner to correct amount along with quantity and expiry date.

When stock is added to an existing item, CloudBake should combine the added quantity into an
existing stock batch only when the expiry date and amount match. If either the expiry date or
amount differs, CloudBake should create a separate stock batch so purchase-cost differences stay
visible.

Inventory CSV export must include amount. Inventory CSV import must accept the optional
`amount` column while remaining compatible with older CSVs that do not include it.

## Implementation Notes

Currency is persisted as a local app setting and defaults to `$`.

`InventoryStockBatch` stores optional `amount`. The local database migration adds
`amount_decimal` to `inventory_stock_batches`.

The combine rule is applied when owner-entered stock is added through stock adjustment or purchase
bill draft save. Consumption still deducts oldest-expiry-first and preserves each batch's amount
on the remaining quantity.

## Test Strategy

Required tests:

1. Acceptance coverage that Settings exposes currency selection.
2. Unit coverage that initial inventory stock stores amount.
3. Unit coverage that stock adjustment combines when expiry and amount match.
4. Unit coverage that stock adjustment creates a separate batch when amount differs.
5. Persistence coverage that stock batch amount round-trips.
6. CSV coverage that amount exports and imports.

## Non-Functional Requirements

1. Keep currency local-first and owner-controlled.
2. Do not add exchange-rate or localization complexity yet.
3. Keep amount optional so existing owner data remains valid.
4. Keep cost data owner-private and separate from future consumer-facing surfaces.

## Open Questions

1. Whether future pricing should use amount as a recipe/order cost input.
2. Whether purchase bill OCR should parse line item prices into amount drafts.
3. Whether inventory reports should show average cost, latest cost, or batch-level cost only.
