# Customers RFC

## Status

Implemented for current owner MVP

## Authority And Scope

This RFC is the product and engineering authority for owner-side customer management in the
CloudBake iOS owner app. Slice RFCs for customer implementation must reference this document and
capture any deliberate changes to this model.

This RFC applies to:

- customer records owned by the bakery owner,
- customer contact details,
- import from Apple Contacts,
- likes, dislikes, allergies, and special notes,
- order links,
- future customer-facing extension points.

This RFC does not cover:

- public customer accounts,
- customer login,
- marketing campaigns,
- bulk messaging,
- loyalty programs,
- shared staff access,
- backend sync.

Those areas can be added later through separate RFCs when the owner workflow needs them.

## Product Goals

Customers should help the owner answer:

1. who is ordering,
2. how to contact them,
3. what they like,
4. what they dislike,
5. what allergies or dietary restrictions matter,
6. what cakes they ordered before,
7. what details should be reused when creating a new order.

The app should make customer memory useful without becoming a heavy CRM.

## Requirements Summary

- The owner must be able to create a customer manually.
- When adding a customer, the app must ask whether the owner wants to import from Contacts.
- If the owner chooses Contacts import, the app must request Contacts permission only when needed.
- If permission is granted, the owner must be able to choose a contact.
- The app must prefill available details from the selected contact.
- The owner must be able to review and edit imported details before saving.
- The owner must be able to save customer name and phone as required fields.
- The owner must be able to save address and email when available.
- The owner must be able to save important customer dates.
- The owner must be able to save likes, dislikes, allergies, dietary restrictions, and owner notes.
- Customer fields other than name and phone must be optional.
- The app must warn when a new customer appears to duplicate an existing customer.
- Customer records must be linkable from orders.
- Orders should use customer records instead of duplicating long-term customer details.
- The owner must be able to edit customer details after creation.
- The owner must be able to delete a customer record after confirmation.
- The owner must be able to search or select an existing customer when creating an order.

## Non Functional Requirements

- Customer data must be local-first and usable without network access.
- Contacts permission must be requested just-in-time.
- The app must continue to support manual customer entry when Contacts permission is denied.
- Imported Contacts data must not be written until the owner saves the customer.
- Allergy and dietary details must be easy to notice before order confirmation and preparation.
- Private customer details must not leak into future customer-facing surfaces.
- Customer persistence must be migration-friendly.
- Tests are required for customer business rules, persistence, and critical owner workflows.
- The UI must work well on iPhone and remain extendable for iPad.
- Future backend communication must carry correlation IDs for end-to-end traceability.

## Contacts Import

Contacts import is an optional helper in the add customer flow.

Flow:

1. Owner chooses Add Customer.
2. App asks whether to import from Contacts.
3. If yes, app requests Contacts access when needed.
4. If access is granted, owner selects a contact.
5. App creates an editable draft from available contact fields.
6. Owner reviews and edits the draft.
7. Owner saves the customer.

If Contacts access is denied or unavailable, the app should fall back to manual entry without
blocking customer creation.

Imported fields may include:

- full name,
- phone numbers,
- email addresses,
- postal addresses.
- birthdays or other important dates when available.

CloudBake-specific fields must remain owner-entered:

- likes,
- dislikes,
- allergies,
- dietary restrictions,
- cake preference notes,
- internal owner notes.

## Domain Model

Core concepts:

- `Customer`: the aggregate root for owner-managed customer details.
- `CustomerContactDetails`: phone, email, and address data.
- `CustomerImportantDate`: birthdays, anniversaries, or other dates the owner wants to remember.
- `CustomerPreference`: likes, dislikes, dietary notes, and cake preferences.
- `CustomerAllergyNote`: allergy or dietary risk information.
- `CustomerOrderLink`: relationship between customer and orders.

The first implementation should keep the model small and explicit. Repeatable contact details can
be added later if the owner needs multiple phone numbers, emails, addresses, or important dates per
customer.

## Decisions

- Customer name is required.
- Customer phone is required.
- The first customer model uses one primary phone and one primary email.
- Address is optional and starts as a single text field.
- Email is optional.
- Important dates are optional.
- Important dates should start as a flexible label and date list.
- Likes, dislikes, allergies, dietary restrictions, and owner notes are optional.
- Duplicate detection is required when adding customers.
- Customer deletion is supported for the owner MVP after explicit confirmation. Deleting a customer
  clears order record links but preserves each order's customer name snapshot.
- Contacts import uses Apple's explicit contact picker for one owner-selected contact.
- Contacts import must create an editable draft and must not save until the owner taps Save.
- Orders can optionally link to an existing customer record while keeping a customer name snapshot.

## Order Relationship

Orders should link to a customer record once customer foundations exist.

An order may also store a small customer snapshot for historical accuracy, but the long-term source
of customer preferences, allergy notes, and contact details should be the customer record.

Customer implementation should happen before order slices that depend on customer preferences,
allergy details, or customer history.

The first order foundation supports optional customer record linking. Customer preference and allergy
presentation inside order detail is implemented in
`docs/rfc/slices/0040-order-customer-preferences.md`.
Customer order history in customer detail is implemented in
`docs/rfc/slices/0041-customer-order-history.md`.
Searchable customer record selection from the order form is implemented in
`docs/rfc/slices/0042-order-customer-search-selection.md`.
Regular-width iPad customer list/detail layout is implemented in
`docs/rfc/slices/0043-ipad-customer-layout.md`.
A customer-safe profile projection for future consumer-facing surfaces is implemented through
`docs/rfc/slices/0067-future-consumer-customer-profile-model.md`.
Customer creation from order linking and customer deletion are implemented in
`docs/rfc/slices/0072-customer-order-link-delete-inventory-csv.md`.

## Owner Experience

Customers should eventually include these screens:

- Customers list.
- Add customer choice for Contacts import or manual entry.
- Contact picker import flow.
- Customer detail view.
- Edit customer flow.
- Customer order history.
- Customer selection from add order.
- Customer deletion from detail.

The first slice should establish list, add, detail, and local persistence foundations. Customer edit
is the next slice.

## Privacy And Safety

Contacts import must be owner initiated. The app should not scan or copy the owner's address book
in the background.

Allergy information is sensitive business-critical information. It should be presented as an alert
to the owner in order workflows, but should not block order confirmation by itself.

## Implementation Slices

Recommended customer slices:

1. Customers List, Add Customer, And Detail
2. Customer Edit
3. Contacts Import Draft
4. Customer Search And Selection From Orders
5. Customer Preferences And Allergy Alerts In Orders
6. Customer Order History
7. iPad Customer Layout
8. Future Consumer Profile Model

Each slice must include its own RFC under `docs/rfc/slices/`, focused tests, and wiki updates when
owner workflow truth changes.

## First Slice Recommendation

The first implementation slice should create the minimum useful customer foundation:

- list customers,
- add a customer manually,
- view customer detail,
- persist customer data locally,
- capture name,
- capture phone,
- capture optional email,
- capture optional address,
- capture optional important dates,
- capture likes, dislikes, allergies, dietary restrictions, and notes,
- include focused unit, integration, and acceptance coverage.

Contacts import is implemented as an editable draft flow. Customer selection for orders is done
through the searchable selection flow, and creating a customer from that order selection flow offers
the same Contacts import or manual entry choices as the main Customers screen. Customer detail now
shows linked order history once orders reference a customer record. iPad customer navigation now
uses a regular-width split layout.
The customer domain now includes a conservative consumer profile projection that exposes only safe
profile contact fields and excludes owner-only preferences, allergies, dietary notes, internal
notes, address, timestamps, and order history.

## Open Questions

- None.
