# Slice RFC-0041: Customer Order History

## Status

Implemented

## Parent RFCs

- `docs/rfc/customers.md`
- `docs/rfc/orders.md`

## Authority And Scope

This slice shows linked orders inside customer detail so the owner can understand a customer's cake
history without leaving the Customers workflow.

This slice includes:

- loading orders linked to the selected customer record,
- sorting linked orders by due date and cake title,
- displaying a read-only order history section in customer detail,
- clearing stale linked orders when customer detail closes,
- focused view-model coverage for linked order filtering and sorting.

This slice does not include:

- opening an order directly from customer detail,
- editing orders from the customer screen,
- completed-vs-upcoming filtering,
- customer analytics,
- customer-facing order history.

## Requirements

- Customer detail must show linked orders when saved orders reference the selected customer record.
- Orders shown in customer detail must belong only to the selected customer.
- Linked orders must be sorted by due date, then title.
- Customer detail must show a clear empty state when there are no linked orders.
- Closing customer detail must clear loaded order history state.

## Design

`CustomerListViewModel` now depends on `OrderRepository` in addition to customer repositories. The
shared app repository already conforms to all three protocols, so no persistence or schema change is
required.

Customer order history is read-only in this slice. Order detail remains the authoritative place to
edit operational order information.

## Testing

- View-model tests cover loading important dates and linked orders together.
- Tests verify unrelated customer orders are excluded and linked orders are sorted consistently.
- Existing customer detail acceptance coverage remains the broad end-to-end guard for opening a
  customer detail screen.

## Documentation Updates

- `README.md` lists Slice RFC-0041.
- `docs/rfc/customers.md` records customer order history as implemented.
- `docs/rfc/orders.md` records that linked orders can now appear from customer detail.
- `wiki/Current-App-Capabilities.md` lists customer order history.
- `wiki/Owner-Workflows.md` describes the customer detail order-history section.
