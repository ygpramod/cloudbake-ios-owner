# Slice 0130: New Order From Customer History

## Status

Implemented

## Parent RFCs

- `docs/rfc/orders.md`
- `docs/rfc/customers.md`

## Goal

Let the owner start a new order from a specific previous order while reviewing a customer's order
history.

## Workflow

1. Open a customer.
2. Find a previous order in the Orders section.
3. Choose the new-order icon on that order.
4. CloudBake opens the standard Add Order form as an unsaved Draft using the safe duplication
   contract from slice 0128.
5. Review the new due date and enter a new quoted price before saving.

## Safety

- the source order is fetched directly by identifier even when it is outside the first Orders page,
- customer and reusable cake details are copied,
- required reminder, checklist, ingredient, and form-reference data is loaded as one preparation
  step; any read failure leaves the current draft unchanged and does not open a partial duplicate,
- quoted price, payments, photos, status, completion, inventory, and transaction history are not
  copied,
- checklist rows restart incomplete with fresh identifiers,
- Cancel creates nothing and never changes the source order.

## Tests

- navigation-router coverage proves the source order identifier is carried safely,
- view-model duplication coverage remains the shared business-rule authority,
- customer acceptance coverage proves the previous order opens as an unsaved Add Order draft.

## Out Of Scope

- automatic suggestions from customer history,
- common-combination ranking,
- copying commercial history.
