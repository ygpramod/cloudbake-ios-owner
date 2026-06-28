# CloudBake Owner App

Native iPhone and iPad owner app for CloudBake.

This repository implements the owner-facing Swift/SwiftUI app. The app is iPhone-first, supports iPad, and follows the CloudBake foundation RFCs and ADRs.

## Current Slice

- Slice RFC-0001: Owner App Shell

## Build

Open `CloudBakeOwner.xcodeproj` in Xcode, or run:

```sh
xcodebuild test -project CloudBakeOwner.xcodeproj -scheme CloudBakeOwner -destination 'platform=iOS Simulator,name=iPhone 16'
```
