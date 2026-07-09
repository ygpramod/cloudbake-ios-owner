# Slice RFC-0053: Order Pricing And Payment Summary

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Context

The Orders RFC requires owner-controlled pricing and payment tracking. Handmade cake pricing should
support the owner's final judgment without introducing automated pricing rules too early.

This slice adds the first practical pricing summary to an order: quoted price, deposit paid, balance
due, payment status, and payment notes.

## Scope

This slice applies to:

- order domain model,
- local order persistence,
- order add/edit form,
- order detail summary,
- focused tests and owner workflow documentation.

This slice does not apply to:

- pricing suggestions,
- ingredient-cost calculation,
- tax, discounts, refunds, or payment method breakdowns,
- online payment processing,
- consumer-facing payment views,
- backend or iCloud sync.

## Requirements

- Order add/edit must allow the owner to enter quoted price.
- Order add/edit must allow the owner to enter deposit paid.
- Order add/edit must allow the owner to enter payment notes.
- Quoted price and deposit paid must be optional.
- Quoted price and deposit paid must reject malformed or negative numbers.
- Deposit paid must not exceed quoted price when both are provided.
- Order detail must show payment status.
- Order detail must show quoted price when present.
- Order detail must show deposit paid when present.
- Order detail must derive and show balance due when quoted price is present.
- Order detail must show payment notes when present.
- Balance due must be derived from quoted price and deposit paid rather than stored separately.
- Existing orders must remain valid after migration with no pricing data.

## Design

Pricing remains owner-entered. The order stores:

- `quotedPrice`,
- `depositPaid`,
- `paymentNotes`.

The order derives:

- `balanceDue = quotedPrice - depositPaid`,
- `paymentStatus` as Not Priced, Unpaid, Part Paid, or Paid.

Money amounts are stored as decimal strings in SQLite to avoid floating-point rounding drift.
Currency display now comes from the owner-selected app currency setting implemented in
`docs/rfc/slices/0073-currency-and-inventory-amount.md`.

## Testing

Required tests:

- Domain coverage for derived balance and payment status.
- View model coverage for saving pricing fields on add/edit.
- View model coverage for invalid price/deposit validation.
- Persistence coverage for saving/fetching order pricing fields.
- Acceptance coverage through an existing order add/open flow that verifies pricing detail fields.

## Documentation

When implemented, update:

- `docs/rfc/orders.md`,
- `README.md`,
- `wiki/Owner-Workflows.md`,
- `wiki/Current-App-Capabilities.md`,
- this slice RFC status and implementation notes.

## Implementation Notes

- `Order` now stores optional quoted price, deposit paid, and payment notes.
- `Order.balanceDue` and `Order.paymentStatus` are derived in the domain model.
- SQLite migration `0011_add_order_pricing_summary` adds nullable pricing columns to `orders`.
- `GRDBCoreDataRepository` stores money amounts as decimal strings.
- Order add/edit exposes optional pricing and payment fields.
- Order detail shows the pricing and payment summary.
