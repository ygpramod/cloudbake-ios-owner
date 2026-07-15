# CloudBake Owner App

Native iPhone owner app for CloudBake.

This repository implements the owner-facing Swift/SwiftUI app. The app supports iPhone for the
initial owner release; iPad is deferred until a future RFC explicitly reintroduces it.

## Current Slice

- Slice RFC-0001: Owner App Shell
- Slice RFC-0002: Local Persistence Foundation
- Slice RFC-0003: Core Data Model
- Slice RFC-0004: Inventory List and Add Item
- Slice RFC-0005: Inventory Quantity and Minimum Alert
- Slice RFC-0006: iOS Test Workflow Split
- Slice RFC-0007: Inventory Edit Item
- Slice RFC-0008: Dashboard Low Inventory
- Slice RFC-0009: Inventory Archive Item
- Slice RFC-0010: Archived Inventory Restore
- Slice RFC-0011: Inventory Stock Adjustment
- Slice RFC-0012: Inventory Stock Consumption
- Slice RFC-0013: Inventory Transaction History
- Slice RFC-0014: Inventory Expiry and Stock Batches
- Slice RFC-0015: Inventory Detail View
- Slice RFC-0016: Inventory Upcoming Expiry and Batch Edit
- Slice RFC-0017: Inventory Unit Conversion
- Slice RFC-0018: Baking Catalog Config
- Slice RFC-0019: Purchase Bill Draft Parser
- Slice RFC-0020: Purchase Bill OCR Service
- Slice RFC-0021: Purchase Bill Draft Review
- Slice RFC-0022: Purchase Bill Camera Import
- Slice RFC-0023: Purchase Bill Duplicate Matching
- Slice RFC-0024: Stock Batch Quantity Edit
- Slice RFC-0025: Stock Batch Delete
- Slice RFC-0026: Purchase Bill Photo Retake And Library Import
- Slice RFC-0027: Inventory Expiry Reminder Notifications
- Slice RFC-0028: Recipe List And Add Recipe
- Slice RFC-0029: Recipe Paper Scan Draft
- Slice RFC-0030: Recipe Ingredient Rows
- Slice RFC-0031: Structured Recipe Import Draft
- Slice RFC-0032: Recipe Detail Edit
- Slice RFC-0033: Inventory Detail Actions
- Slice RFC-0034: Customer List Add And Detail
- Slice RFC-0035: Customer Edit
- Slice RFC-0036: Customer Contacts Import Draft
- Slice RFC-0037: Orders List Add And Detail
- Slice RFC-0038: Order Edit And Status Changes
- Slice RFC-0039: Orders Calendar View
- Slice RFC-0040: Order Customer Preferences
- Slice RFC-0041: Customer Order History
- Slice RFC-0042: Order Customer Search Selection
- Slice RFC-0043: Deferred iPad Customer Layout
- Slice RFC-0044: Order Reminders
- Slice RFC-0045: Parallel Acceptance CI Shards
- Slice RFC-0046: Order Recipe Link
- Slice RFC-0047: Order Recipe Usage And Inventory Deduction
- Slice RFC-0048: Order Checklist
- Slice RFC-0049: Deferred iPad Order Layout
- Slice RFC-0050: Future Consumer Order Preview Model
- Slice RFC-0051: Order Design Reference
- Slice RFC-0052: Order Workflow Polish
- Slice RFC-0053: Order Pricing And Payment Summary
- Slice RFC-0054: Order Active And Completed Tabs
- Slice RFC-0055: Order Status And Payment Quick Actions
- Slice RFC-0056: Order Scheduled Reminder Notifications
- Slice RFC-0057: Order Photos
- Slice RFC-0058: Order Photo Persistence
- Slice RFC-0059: Order Photo Detail Foundation
- Slice RFC-0060: Order Photo Detail Library UI
- Slice RFC-0061: Order Photo Camera Capture
- Slice RFC-0062: Order Photo Preview
- Slice RFC-0063: Order Photo Caption Editing
- Slice RFC-0064: Order Final Photo Design Promotion
- Slice RFC-0065: Order Checklist Item Editing
- Slice RFC-0066: Order Recipe Usage Scaling
- Slice RFC-0067: Future Consumer Customer Profile Model
- Slice RFC-0068: Dashboard Home Look And Feel
- Slice RFC-0069: Second Level Screen Look And Feel
- Slice RFC-0070: Detail Screen Look And Feel
- Slice RFC-0071: Form Screen Look And Feel
- Slice RFC-0072: Customer Order Link Delete Inventory CSV
- Slice RFC-0073: Currency And Inventory Amount
- Slice RFC-0074: Reminder Currency And Overdue Polish
- Slice RFC-0075: Reminder Screen
- Slice RFC-0077: Inventory Aliases For Bill Scanning
- Slice RFC-0078: Inventory Type And Optional Expiry
- Slice RFC-0079: Design Library Provenance
- Slice RFC-0080: My Designs Gallery And Detail
- Slice RFC-0081: Design Photos Library References
- Slice RFC-0082: Customer References Collection
- Slice RFC-0083: Internet Inspiration Import
- Slice RFC-0084: Design Library Search
- Slice RFC-0085: Design Tags, Filters, And Favourites
- Slice RFC-0086: Design Library Removal
- Slice RFC-0087: Design Usage History
- Slice RFC-0088: Use Design For New Order
- Slice RFC-0089: Design Photo Navigation And Performance
- Slice RFC-0090: Consumer-Safe Design Projection
- Slice RFC-0091: Direct Owner Design Import
- Slice RFC-0092: Designs RFC Closeout
- Slice RFC-0093: Designs Simplification And Order Picker
- Slice RFC-0094: Inventory CSV Aliases And Type
- Slice RFC-0095: Section Header Add Actions
- Slice RFC-0096: Recipe CSV Import And Export
- Slice RFC-0097: Expired Inventory Exclusion And Disposal
- Slice RFC-0098: Projected Order Ingredient Demand
- Slice RFC-0099: Estimated And Actual Order Ingredient Cost
- Slice RFC-0100: Customizable In-App Logo
- Slice RFC-0101: Cloud Backup Snapshot Foundation
- Slice RFC-0102: CloudKit Atomic Backup Publication
- Slice RFC-0103: Cloud Backup Scheduling And Connectivity
- Slice RFC-0104: Cloud Backup Settings And Status
- Slice RFC-0105: CloudKit Full Restore
- Slice RFC-0106: Cloud Backup Account And Deletion Lifecycle
- Slice RFC-0107: Manual Full App Backup
- Slice RFC-0108: Manual Full App Restore
- Slice RFC-0109: Inventory Default Expiry Days
- Slice RFC-0110: On-Device Voice Inventory Drafts
- Slice RFC-0111: Native Order Actions And Upcoming Window
- Slice RFC-0112: Inventory Card Swipe Actions And Guarded Delete

## Base RFCs

- Customers: `docs/rfc/customers.md`
- Designs: `docs/rfc/designs.md`
- Orders: `docs/rfc/orders.md`

## Engineering Guardrails

- Local guardrails: `docs/engineering-guardrails.md`
- Architecture decisions: `docs/adr/`
- Slice RFCs: `docs/rfc/slices/`
- Wiki source: `wiki/`

The repo-local `wiki/` directory is the authored source for GitHub Wiki pages. Update it in the
same PR when owner-facing, operator-facing, or cross-repository guidance changes.

## UI Consistency

CloudBake has an established owner-app visual language. New implementation slices should reuse the
shared UI primitives instead of introducing one-off styling:

- `CloudBakeTheme` for semantic color, typography, spacing, shape, and elevation tokens.
- `CloudBakeScreenScaffold` for second-level screens.
- `CloudBakeDetailCard`, `CloudBakeDetailRow`, and `CloudBakeDetailDivider` for detail/settings
  sections.
- `CloudBakeStatusBadge` and `CloudBakeLabeledField` for compact status and metadata display.
- `cloudBakeFormScreenStyle()` for native data-entry forms.
- native `Menu` for compact status/payment choices.
- `cloudBakeCenteredPopup` with `centeredPopupButton` for confirmations, input workflows,
  destructive actions, and owner decisions.

Popups should match the existing centered CloudBake style used by Orders, Customers, and Inventory:
dimmed backdrop, rounded dialog, CloudBake pink action tint, full-width pill buttons, and clear
accessibility identifiers. Do not add a new popup, alert, sheet, or dialog style unless the slice is
explicitly changing the design system and updates the guardrails/RFCs with that decision.

## Build

Open `CloudBakeOwner.xcodeproj` in Xcode, or run:

```sh
xcodebuild test -project CloudBakeOwner.xcodeproj -scheme CloudBakeOwner -destination 'platform=iOS Simulator,name=iPhone 17'
```

The project uses Swift Package Manager for dependencies. Xcode should resolve `GRDB.swift` from the checked-in package lockfile. Local builds require an installed iOS platform/runtime that matches the active Xcode version.

## Test Lanes

During development, run the fast unit and integration lane first:

```sh
xcodebuild test -project CloudBakeOwner.xcodeproj -scheme CloudBakeOwnerUnitIntegration -destination 'platform=iOS Simulator,name=iPhone 17'
```

Before opening or merging implementation pull requests, run the full scheme test command or confirm
CI has passed the unit/integration job and all feature-sharded acceptance jobs:

```sh
xcodebuild test -project CloudBakeOwner.xcodeproj -scheme CloudBakeOwner -destination 'platform=iOS Simulator,name=iPhone 17'
```

GitHub Actions runs acceptance UI tests in six feature shards: `core-recipes`, `orders-core`,
`order-links`, `customers`, `inventory`, and `designs`. Customer workflows have their own shard so
their runtime and failures do not extend the order-link shard. When adding a new acceptance test,
add it to the matching CI shard in `.github/workflows/ci.yml`.
