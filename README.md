# CloudBake Owner App

Native iPhone and iPad owner app for CloudBake.

This repository implements the owner-facing Swift/SwiftUI app. The app is iPhone-first, supports iPad, and follows the CloudBake foundation RFCs and ADRs.

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

## Base RFCs

- Customers: `docs/rfc/customers.md`
- Orders: `docs/rfc/orders.md`

## Engineering Guardrails

- Local guardrails: `docs/engineering-guardrails.md`
- Architecture decisions: `docs/adr/`
- Slice RFCs: `docs/rfc/slices/`
- Wiki source: `wiki/`

The repo-local `wiki/` directory is the authored source for GitHub Wiki pages. Update it in the
same PR when owner-facing, operator-facing, or cross-repository guidance changes.

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

Before opening or merging implementation pull requests, run the full scheme test command or confirm CI has passed both jobs:

```sh
xcodebuild test -project CloudBakeOwner.xcodeproj -scheme CloudBakeOwner -destination 'platform=iOS Simulator,name=iPhone 17'
```
