# Slice RFC-0042: Order Customer Search Selection

## Status

Implemented

## Parent RFCs

- `docs/rfc/customers.md`
- `docs/rfc/orders.md`

## Authority And Scope

This slice replaces the compact customer picker in the order form with a searchable customer
selection flow. It makes existing customer records practical to use once the owner has more than a
few customers.

This slice includes:

- opening customer record selection from the add/edit order form,
- searching customers by name, phone, email, or address,
- selecting an existing customer and applying its saved name and address to the order draft,
- clearing the customer record link while keeping manually entered order text intact,
- focused view-model and acceptance coverage for linking a customer from an order.

This slice does not include:

- creating a customer from inside the order form,
- editing customer details from the order form,
- advanced fuzzy matching,
- customer archival,
- consumer-facing customer selection.

## Requirements

- The order form must show the currently linked customer record name when a customer is linked.
- The owner must be able to open a separate customer selection screen from the order form.
- The owner must be able to search customers by name, phone, email, and address.
- The owner must be able to choose no linked customer.
- Selecting a customer must prefill the order draft customer name and delivery address from the
  selected record.
- Clearing the customer link must not erase manually entered customer name or order delivery text.

## Design

The order form keeps the direct customer name field for quick drafts. Customer record linking is a
separate sheet so the form remains readable and the selection list can grow without cluttering the
order fields.

Search is intentionally local and simple. It performs case-insensitive matching across saved
customer name, phone, email, and address. More advanced duplicate or fuzzy matching can be added
later if the customer list grows enough to need it.

## Testing

- View-model tests cover selecting a customer, clearing a customer link, and search matching across
  customer fields.
- Acceptance coverage verifies that an order can link a customer through the selection flow and
  then show customer allergy context in order detail.

## Documentation Updates

- `README.md` lists Slice RFC-0042.
- `docs/rfc/customers.md` records order customer search selection as implemented.
- `docs/rfc/orders.md` records the searchable customer selection flow in the order foundation.
- `wiki/Current-App-Capabilities.md` lists searchable customer selection from orders.
- `wiki/Owner-Workflows.md` describes searchable customer linking in the order workflow.
