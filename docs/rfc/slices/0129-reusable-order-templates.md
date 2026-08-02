# Slice 0129: Reusable Order Templates

## Status

Implemented

## Parent RFC

`docs/rfc/orders.md`

## Goal

Let the owner save a named combination of reusable order details and apply it to a new order without
copying customer or commercial history.

## Workflow

1. Configure reusable fields in Add Order.
2. Choose `Save Current as Template`, enter a name, and save.
3. In any new Add Order form, choose `Use Order Template` and select a template.
4. Review the populated unsaved Draft, enter customer, due date, and quoted price, then save normally.
5. Rename or delete templates from the template library. Deletion never changes existing orders.

## Included Data

- cake name, notes, and message,
- pickup or delivery and optional delivery address,
- linked saved design,
- linked recipe and multiplier,
- extra ingredients,
- reminder configuration,
- checklist titles.

## Excluded Data

The template persistence schema has no fields for customer, due date, order status, quoted price,
payments, payment notes, photos, reservations, inventory consumption, actual costs, or history.
Applying a template preserves the customer and due date already entered in the current draft, resets
status to Draft, and clears quoted price and payment inputs.

## Persistence

- templates and ordered child rows are stored locally in dedicated GRDB tables,
- recipe and saved-design deletion clears the optional link,
- inventory used by a template extra ingredient remains protected from deletion,
- saving a template and replacing its child rows is atomic,
- deleting a template cascades only to its own template child rows.

## Tests

- unit tests cover safe application and create/rename/delete behavior,
- integration tests cover complete round-trip and child deletion,
- acceptance coverage proves a saved template can populate a later unsaved order without customer
  or quoted price.

## Out Of Scope

- automatically remembered or suggested combinations,
- creating from a customer's previous order,
- template sharing or cloud synchronization beyond whole-app backup.
