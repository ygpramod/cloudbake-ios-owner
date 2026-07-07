# Slice RFC-0034: Customer List Add And Detail

## Status

Implemented

## Parent RFC

- `docs/rfc/customers.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Create the first usable customer foundation so the owner can manually record customer details before
orders start linking to customer records.

## Scope

- Expand the local customer model with name, phone, email, address, preferences, allergy notes,
  dietary restrictions, owner notes, and important dates.
- Add local persistence for customer important dates.
- Add the Customers app screen.
- Support manual customer add.
- Show customer list and customer detail.
- Warn before saving likely duplicate customers.
- Add focused unit, integration, and acceptance coverage.
- Update README and wiki source.

## Out Of Scope

- Contacts import.
- Customer edit.
- Customer archive or delete.
- Customer order history.
- Order customer selection.
- Multiple phone numbers, emails, or addresses.

## Requirements

- Customers must be reachable from the app navigation.
- Empty customer state must tell the owner there are no customers yet.
- Add customer must require name and phone.
- Add customer must allow optional email, address, important date, likes, dislikes, allergies,
  dietary restrictions, and notes.
- Important dates must be stored as label and date rows.
- The app must warn before saving a customer that has the same or similar name, or same phone, as
  an existing customer.
- Tapping Save again after the duplicate warning must allow the owner to intentionally save the
  separate customer.
- Customer detail must show saved contact details, important dates, preferences, allergies, dietary
  restrictions, and notes.

## Design

Customers follow the existing owner feature pattern:

- `CustomerListView`
- `CustomerListViewModel`
- `CustomerRepository`
- `CustomerImportantDateRepository`
- GRDB-backed persistence through `GRDBCoreDataRepository`

The first slice keeps add and detail only. Edit is intentionally a separate slice so the owner can
review the foundation before we add mutation complexity.

## Tests

Unit coverage:

- customer view model loads customers,
- add customer trims and saves required and optional fields,
- name and phone are required,
- duplicate warning appears before saving,
- detail loading includes important dates.

Integration coverage:

- customer and important date repository round-trip,
- customers fetch in name order.

Acceptance coverage:

- owner adds and views a customer,
- duplicate customer warning appears before saving.

## Documentation

Updated:

- `README.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- The owner can add and view customers from the Customers screen.
- The app protects against accidental duplicate customers while still allowing an intentional
  duplicate after confirmation.
