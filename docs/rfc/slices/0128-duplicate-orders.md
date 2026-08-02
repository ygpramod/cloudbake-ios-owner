# Slice 0128: Duplicate Orders

## Status

Implemented

## Parent RFC

`docs/rfc/orders.md`

## Goal

Let the owner reuse the operational details of an existing order without carrying forward its
commercial history or committing a new order before review.

## Owner Workflow

1. Open an existing order.
2. Choose `Duplicate Order` from the order-detail actions.
3. CloudBake opens the standard Add Order form as an unsaved Draft.
4. Review or change the copied details and the newly calculated due date.
5. Choose Save to create the order, or Cancel to discard the draft.

## Copied Data

- linked customer and customer-name snapshot,
- cake name, notes, and message,
- pickup or delivery selection and delivery address,
- linked recipe and recipe multiplier,
- order-specific extra ingredients with new identifiers,
- linked saved design,
- reminder configuration,
- checklist titles with new identifiers and incomplete state.

## Deliberately Reset Data

- status resets to Draft,
- due date uses the normal next-day nearest-hour default,
- quoted price stays blank,
- initial/received payments and payment notes stay blank,
- completion timestamps and actual ingredient-cost history are not copied,
- customer-reference and final-cake photos are not copied,
- inventory reservations, deductions, and other transaction history are not copied.

## Persistence

The new order, its extra ingredients, checklist items, reminder configuration, and optional opening
payment are committed in one database transaction. A failure in any child write rolls back the new
order. Existing source records are never mutated.

## UI And Accessibility

- `Duplicate Order` is a secondary native order-detail action.
- The duplicate opens the existing Add Order form rather than a special-purpose screen.
- New-order checklist rows are visible and removable before Save, and owners can add more rows.
- Duplicate and checklist controls have stable accessibility identifiers and full-size tap targets.

## Tests

- view-model coverage proves copied and reset fields,
- view-model coverage proves fresh identifiers and incomplete checklist state,
- persistence coverage proves atomic checklist creation and rollback,
- focused acceptance coverage proves the owner can open and review a duplicate before saving.

## Out Of Scope

- reusable named templates,
- automatic suggestions from frequently used combinations,
- starting from a customer's previous order,
- copying quoted prices or payment history.
