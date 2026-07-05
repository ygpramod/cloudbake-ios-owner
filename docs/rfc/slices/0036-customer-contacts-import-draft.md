# Slice RFC-0036: Customer Contacts Import Draft

## Status

Implemented

## Parent RFC

- `docs/rfc/customers.md`

## Authority And Scope

This slice adds an optional Apple Contacts import path to customer creation. It is scoped to creating
an editable local draft from one owner-selected contact.

This slice includes:

- an add-customer choice between Contacts import and manual entry,
- Apple Contacts picker presentation,
- mapping selected contact fields into the customer draft form,
- owner review and edit before save,
- Contacts privacy usage description,
- focused mapping, view-model, and acceptance coverage.

This slice does not include:

- background address-book scanning,
- bulk import,
- multiple phone numbers, emails, or addresses per customer,
- Contacts sync after the customer is saved,
- automated UI control of Apple's system contact picker.

## Requirements

- The owner can choose whether to import from Contacts or enter customer details manually.
- Contacts import must be owner initiated.
- A selected contact can prefill name, phone, email, address, and one important date when available.
- Imported data must remain a draft until the owner taps Save.
- The owner must be able to edit imported data before saving.
- Manual customer creation must continue to work without Contacts.
- Existing duplicate warning behavior must still apply when saving imported or manual drafts.

## Design

`CustomerContactDraftMapper` maps `CNContact` into a small `CustomerContactDraft` value. The view
model owns draft application through `beginAddingCustomer(importedDraft:)`, which resets stale form
state and copies imported fields into the same form used by manual add.

The SwiftUI screen uses `CNContactPickerViewController` through a small representable wrapper. The
picker lets the owner choose one contact explicitly and avoids any CloudBake background access to the
address book.

Birthday or contact-date values are converted into CloudBake important dates when a date can be
resolved. If Apple Contacts does not provide a year, the current year is used only so the owner has
an editable draft date to correct before saving.

## Testing

- Unit coverage maps contact fields and birthdays into a draft.
- View-model coverage verifies imported drafts prefill the add form without saving.
- Acceptance coverage verifies the customer add flow offers both Contacts import and manual entry.

Apple's system contact picker itself is not automated in acceptance tests.

## Documentation Updates

- `README.md` lists Slice RFC-0036.
- `wiki/Current-App-Capabilities.md` marks Contacts import draft support as available.
- `wiki/Owner-Workflows.md` describes manual and Contacts-import add customer workflows.
