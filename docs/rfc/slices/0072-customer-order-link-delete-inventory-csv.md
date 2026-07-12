# Slice RFC-0072: Customer Linking And Inventory Data Tools

## Status

Implemented

## Authority And Scope

This slice improves owner data-management workflows that were too awkward once customers and
inventory became real operating data.

In scope:

1. create a new customer while linking a customer from the order form,
2. delete a customer from customer detail after confirmation,
3. import active inventory from CSV through Settings,
4. export active inventory and stock batches to CSV through Settings.

Out of scope:

1. bulk customer import/export,
2. inventory CSV conflict review screens,
3. supplier catalog import,
4. cloud backup,
5. automatic CSV sync.

## Requirements Summary

The owner must be able to create a missing customer without leaving the order form customer-linking
flow. The order customer selection add flow must offer the same choices as the main Customers add
flow: import from Apple Contacts or enter manually. After saving, the new customer should be
selected for the order draft.

The owner must be able to delete a customer from customer detail only after confirming the action.
Deleting a customer must not delete historical orders. Existing orders should keep their customer
name snapshot and clear only the optional customer record link.

Settings must expose inventory CSV import and export so inventory data can be moved into or out of
CloudBake without adding more actions to the Inventory tab.

Inventory CSV export must include active inventory items and stock batches. Inventory CSV import
must create new items or update matching active items by name and unit. Imported stock batches
replace the imported item's saved batches so the CSV can be used as an owner-controlled correction
source.

## CSV Format

Inventory CSV columns:

1. `name`
2. `aliases`
3. `type`
4. `unit`
5. `current_quantity`
6. `minimum_quantity`
7. `batch_quantity`
8. `amount`
9. `expiry_date`

Export writes one row per stock batch. If an item has no stock batches, export writes one row with
the item current quantity as the batch quantity and a blank expiry date.

Import accepts supported CloudBake units by stored value or display value. Amount is optional.
Expiry dates use `yyyy-MM-dd`. The `aliases` and `type` headers are required; type accepts Standard
or Perishable. See Slice RFC-0094.

## Implementation Notes

The slice adds a Settings screen with Import Inventory CSV and Export Inventory CSV actions.

Inventory CSV behavior lives in `InventoryCSVService` so parsing, validation, grouping, and export
formatting are testable outside SwiftUI.

Customer deletion is implemented at repository level by unlinking orders from the customer before
deleting the customer row. Customer important dates remain owned by the customer record and are
removed with it.

## Test Strategy

Required tests:

1. ViewModel/unit coverage for creating and selecting a customer from order customer selection.
2. ViewModel/unit coverage for customer deletion and order unlinking behavior.
3. Unit coverage for inventory CSV export, import creation, and import update/replacement.
4. Acceptance coverage for the New Customer option in order customer selection.
5. Acceptance coverage for deleting a customer from customer detail.
6. Acceptance coverage that Settings exposes inventory CSV import/export actions.

## Non-Functional Requirements

1. Keep all behavior local-first.
2. Keep CSV parsing and formatting in testable service code, not inside SwiftUI views.
3. Do not expose internal error details to the owner.
4. Preserve historical order snapshots when customer records are deleted.
5. Keep Settings as the home for cross-cutting app data tools.

## Open Questions

1. Whether future CSV import should offer an explicit conflict review screen before replacing
   existing stock batches.
2. Whether inventory export should later include archived inventory.
3. Whether customer data import/export should be added after the owner validates inventory CSV.
