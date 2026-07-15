# Slice RFC-0055: Order Status And Payment Quick Actions

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Context

The owner needs faster order operations after the order list and pricing summary are in place.
Opening full edit is too heavy for common actions such as moving an order through its lifecycle or
recording money received.

This slice adds quick owner actions while keeping destructive or business-significant changes
confirmed before save.

## Scope

This slice applies to:

- order row quick actions,
- order detail status and payment controls,
- owner confirmation before quick status or payment saves,
- focused view-model coverage,
- RFC and wiki documentation.

This slice does not apply to:

- online payment collection,
- payment methods,
- refunds or discounts,
- currency configuration,
- automatic status changes from payment state,
- consumer-facing payment screens.

## Requirements

- Order rows must expose a quick status action.
- Order rows must expose a quick payment action.
- Row status changes must show a confirmation popup before saving.
- Row payment changes must show a confirmation popup before saving.
- Order detail must allow the owner to change payment status without opening full edit.
- Marking an order Paid must set paid amount to the quoted price, making balance due zero.
- Adding a partial payment must ask for the newly received amount.
- Partial payment must add the entered amount to the existing paid amount.
- Partial payment must reject missing, zero, negative, malformed, or excess amounts.
- Payment actions must require an existing quoted price.
- Existing owner-confirmed recipe inventory deduction rules must still apply to status changes.

## Design

The slice continues to use the existing order payment model:

- `quotedPrice` is the owner-controlled final price.
- `depositPaid` is the total amount received so far.
- `balanceDue` remains derived.
- `paymentStatus` remains derived.

Quick payment actions update `depositPaid` only:

- `Paid` sets `depositPaid` to `quotedPrice`.
- `Part Paid` adds the entered amount to the current `depositPaid` value.

The app does not store a separate payment-status field because status is still derivable from the
quote and paid amount.

## Testing

Required tests:

- View-model coverage for marking an order paid.
- View-model coverage for adding a partial payment to an existing paid amount.
- View-model coverage for rejecting invalid or excess partial payment amounts.
- Existing order status and recipe-usage tests must continue to pass.

## Documentation

When implemented, update:

- `docs/rfc/orders.md`,
- `wiki/Owner-Workflows.md`,
- `wiki/Current-App-Capabilities.md`,
- this slice RFC status and implementation notes.

## Implementation Notes

- Order rows now expose visible `Status` and `Payment` action chips. RFC-0069 replaced the original
  list-row swipe implementation when Orders moved to card-based second-level screen styling.
- Order card content uses the shared compact Home and Inventory row hierarchy so its icon,
  typography, metadata spacing, and chevron remain consistent across primary workflows.
- Row status changes use centered popups for status selection and confirmation.
- Row payment actions use centered popups with `Mark Paid` and `Add Partial Payment`.
- Order detail exposes a payment action beside payment status.
- `OrderListViewModel` now supports marking paid and adding partial payments while keeping balance
  due derived from the saved order.
