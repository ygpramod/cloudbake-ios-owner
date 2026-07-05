# Slice RFC-0035: Customer Edit

## Status

Accepted

## Parent RFC

- `docs/rfc/customers.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Allow the owner to correct customer details after creation.

## Scope

- Add edit entry point from customer detail.
- Reuse the customer form for editing.
- Edit customer name, phone, email, address, likes, dislikes, allergies, dietary restrictions, and
  notes.
- Keep existing important dates unchanged during this slice.
- Preserve duplicate warning behavior when an edited customer matches another customer.
- Add focused unit and acceptance coverage.
- Update README and wiki source.

## Out Of Scope

- Contacts import.
- Important date add/edit/delete after customer creation.
- Customer archive or delete.
- Customer order history.
- Order customer selection.

## Requirements

- Customer detail must expose an edit action.
- Edit form must require name and phone.
- Edit form must save optional fields when present and clear optional fields when blank.
- Edited customers must preserve the original created timestamp.
- Editing must not warn when the customer still matches itself.
- Editing must warn before saving when the customer matches another customer by name or phone.
- Existing important dates must remain attached to the customer.

## Tests

Unit coverage:

- edit saves changed customer fields and preserves created timestamp,
- edit warns when using another customer's phone.

Acceptance coverage:

- owner opens customer detail,
- taps edit,
- changes customer name,
- saves,
- sees the updated detail title and value.

## Documentation

Updated:

- `README.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- The owner can correct customer details from customer detail without recreating the customer.
