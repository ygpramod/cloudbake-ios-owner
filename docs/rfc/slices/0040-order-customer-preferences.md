# Slice RFC-0040: Order Customer Preferences

## Status

Implemented

## Parent RFCs

- `docs/rfc/orders.md`
- `docs/rfc/customers.md`

## Authority And Scope

This slice surfaces linked customer context inside order detail so allergy and preference details
are visible when the owner is preparing or reviewing a cake order.

This slice includes:

- loading the linked `Customer` when an order detail is opened,
- clearing linked customer context when an unlinked order is opened or detail is closed,
- refreshing linked customer context when an order is edited to link a different customer,
- displaying non-empty allergies, dietary restrictions, likes, dislikes, and notes in order detail,
- focused view-model coverage for linked customer loading and refresh behavior.

This slice does not include:

- copying preference fields into an immutable order snapshot,
- customer order history,
- blocking order confirmation for allergies,
- customer-facing allergy or preference display,
- reminder scheduling,
- pricing or payment details.

## Requirements

- Order detail must show customer allergy and preference context when the order is linked to a
  customer record.
- Only saved, non-empty customer context should be shown.
- Unlinked orders must not show stale customer preference details from a previous detail view.
- Editing an order to link a different customer must refresh the visible customer context.
- Allergy and preference details are owner-facing only and must remain private.

## Design

`OrderListViewModel` now exposes `selectedOrderCustomer` as read-only detail state. The value is
loaded from `CustomerRepository.fetchCustomer(id:)` whenever an order with `customerId` is opened.
The value is cleared for unlinked orders and when the order detail closes.

`OrderDetailView` shows a `Customer Details` section only when the linked customer has at least one
non-empty preparation-relevant field. The section keeps the customer record as the source of truth
and avoids duplicating long-term preferences into the order model.

## Testing

- View-model tests cover selecting a linked order, clearing context for an unlinked order, and
  refreshing customer details after editing an order link.
- Existing order detail acceptance coverage remains the end-to-end guard for opening order detail.

## Documentation Updates

- `README.md` lists Slice RFC-0040.
- `docs/rfc/orders.md` records customer preferences in order detail as implemented.
- `wiki/Current-App-Capabilities.md` lists linked customer allergy and preference display in orders.
- `wiki/Owner-Workflows.md` describes how linked order detail surfaces customer context.
