# Slice RFC-0037: Orders List Add And Detail

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Authority And Scope

This slice creates the first owner-facing order workflow in the CloudBake iOS owner app.

This slice includes:

- Orders navigation replacing the placeholder screen,
- order list grouped as a simple due-date sorted list,
- add order flow,
- order detail view,
- local order persistence expansion,
- optional link to an existing customer record,
- required customer name snapshot,
- due date and time,
- draft or confirmed status at creation,
- pickup or delivery fulfillment type,
- optional delivery address,
- optional cake notes,
- focused unit, integration, and acceptance tests.

This slice does not include:

- editing an order after creation,
- status changes after creation,
- calendar view,
- reminders,
- pricing and payment,
- design references and photos,
- recipe links,
- inventory deduction,
- allergy alert presentation in the order workflow.

## Requirements

- The owner can open Orders from the app navigation.
- The owner can see an empty state when there are no orders.
- The owner can add an order with cake name, customer name, due date/time, status, fulfillment type,
  and optional cake notes.
- The owner can select an existing customer record while adding an order.
- Selecting a customer record prefills the customer name and address as editable draft values.
- Saved orders appear in the Orders list sorted by due date.
- The owner can open an order detail view and see order, customer, fulfillment, and cake notes.
- Order data is local-first and persisted through the existing GRDB repository.

## Design

The existing `Order` core model is expanded with the fields needed by the first owner workflow:

- `customerName`,
- `fulfillmentType`,
- `deliveryAddress`,
- `cakeNotes`.

`customerId` remains optional so the owner can create a quick draft order without first creating a
customer record. `customerName` is required as an order snapshot because a draft order only requires
a name.

`OrderListViewModel` owns order list loading, customer list loading, add-order draft state, customer
selection, validation, save, and detail selection. The view follows the existing feature pattern used
by inventory, recipes, and customers.

The first form exposes only Draft and Confirmed statuses. The model already includes later lifecycle
states so the next order slice can add edit and status transitions without another domain change.

## Testing

- Core model test covers order status and fulfillment raw values.
- Persistence test covers expanded order round trip and list fetch.
- View-model tests cover load, validation, save, customer selection prefill, and detail selection.
- Acceptance test covers add order and view order detail from the Orders screen.

## Documentation Updates

- `README.md` lists Slice RFC-0037.
- `docs/rfc/orders.md` records the implemented first slice foundation.
- `wiki/Current-App-Capabilities.md` lists Orders list/add/detail.
- `wiki/Owner-Workflows.md` describes the current order workflow and remaining future slices.
