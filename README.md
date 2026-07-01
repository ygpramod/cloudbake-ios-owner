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

## Engineering Guardrails

- Local guardrails: `docs/engineering-guardrails.md`
- Architecture decisions: `docs/adr/`
- Slice RFCs: `docs/rfc/slices/`

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
