# Slice RFC-0067: Future Consumer Customer Profile Model

## Status

Implemented

## Parent RFC

- `docs/rfc/customers.md`

## Authority And Scope

This slice creates the first customer-safe profile model for future consumer-facing experiences. It
is a domain foundation only; it does not expose customer login, public profile screens, backend APIs,
sync behavior, or customer self-service editing.

This slice includes:

- a `ConsumerCustomerProfile` projection from owner `Customer`,
- a conservative safe field boundary for future authenticated customer-facing profile surfaces,
- tests that define which owner customer fields are not exposed.

This slice does not include:

- public customer accounts,
- customer-facing UI,
- contact verification,
- customer self-editing,
- backend serialization,
- sharing links,
- marketing, loyalty, or messaging workflows.

## Requirements

- The consumer profile must expose only fields appropriate for a future customer-facing surface.
- The profile must not expose owner-only customer details such as address, likes, dislikes,
  allergies, dietary restrictions, internal notes, timestamps, or order history.
- The first projection may expose customer id, display name, primary phone, and primary email.
- Tests must prove the projection and field boundary.

## Design

`ConsumerCustomerProfile` is a small value model built from a `Customer`.

Exposed fields are:

- customer id,
- display name,
- contact phone,
- contact email.

The model intentionally stays independent from persistence. Future backend or iCloud slices can
decide how and whether to serialize it, and future consumer-account RFCs can decide which fields a
customer may view or edit.

## Testing

- Domain tests verify projection from customer data.
- Domain tests verify private owner-only fields are not exposed by the profile shape.

## Documentation Updates

- `README.md` lists Slice RFC-0067.
- `docs/rfc/customers.md` records the consumer profile model foundation.
- `wiki/Business-Concepts.md` defines the consumer customer profile boundary.
- `wiki/Current-App-Capabilities.md` lists the model as a prepared foundation.
- `wiki/Product-Overview.md` notes that the future customer experience now has a safe customer
  profile boundary.
