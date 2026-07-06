# Slice RFC-0050: Future Consumer Order Preview Model

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Authority And Scope

This slice creates the first customer-safe order preview model for future consumer-facing
experiences. It is a domain foundation only; it does not expose a customer app, public ordering UI,
backend API, or sync behavior.

This slice includes:

- a `ConsumerOrderPreview` projection from owner `Order`,
- customer-facing order status language,
- optional display data from an existing cake design,
- tests that define the safe field boundary.

This slice does not include:

- customer login,
- customer-facing screens,
- public order creation,
- sharing links,
- backend serialization,
- payment or pricing display,
- design request editing.

## Requirements

- The consumer preview must expose only fields appropriate for a future customer-facing surface.
- The preview must not expose owner-only order details such as internal recipe links, cake notes,
  private customer names, delivery addresses, checklist items, inventory usage, or operational
  reminders.
- Owner order statuses must map to customer-safe status language.
- Optional cake design display data may be included when an order links to a design.
- Tests must prove the projection and field boundary.

## Design

`ConsumerOrderPreview` is a small value model built from an `Order` and optional `CakeDesign`.

Exposed fields are:

- order id,
- cake name,
- customer-facing status,
- due date/time,
- fulfillment type,
- design name,
- design photo reference.

`ConsumerOrderPreviewStatus` maps owner lifecycle language into customer-facing terms:

- Draft -> Requested
- Confirmed -> Accepted
- In Progress -> In Progress
- Ready -> Ready
- Completed -> Fulfilled
- Cancelled -> Cancelled

This model intentionally stays independent from persistence. Future backend or iCloud slices can
decide how and whether to serialize it.

## Testing

- Domain tests verify projection from order and design data.
- Domain tests verify private owner-only fields are not exposed by the preview shape.
- Domain tests verify status mapping.

## Documentation Updates

- `README.md` lists Slice RFC-0050.
- `docs/rfc/orders.md` records the consumer preview model foundation.
- `wiki/Business-Concepts.md` defines the consumer order preview boundary.
- `wiki/Current-App-Capabilities.md` lists the model as a prepared foundation.
- `wiki/Product-Overview.md` notes that the future customer experience now has a safe preview
  model boundary.
