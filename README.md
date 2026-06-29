# CloudBake Owner App

Native iPhone and iPad owner app for CloudBake.

This repository implements the owner-facing Swift/SwiftUI app. The app is iPhone-first, supports iPad, and follows the CloudBake foundation RFCs and ADRs.

## Current Slice

- Slice RFC-0001: Owner App Shell
- Slice RFC-0002: Local Persistence Foundation

## Engineering Guardrails

- Local guardrails: `docs/engineering-guardrails.md`
- Architecture decisions: `docs/adr/`
- Slice RFCs: `docs/rfc/slices/`

## Build

Open `CloudBakeOwner.xcodeproj` in Xcode, or run:

```sh
xcodebuild test -project CloudBakeOwner.xcodeproj -scheme CloudBakeOwner -destination 'platform=iOS Simulator,name=iPhone 16'
```

The project uses Swift Package Manager for dependencies. Xcode should resolve `GRDB.swift` from the checked-in package lockfile. Local builds require an installed iOS platform/runtime that matches the active Xcode version.
