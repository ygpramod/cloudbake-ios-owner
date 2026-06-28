# ADR-0001: Use Swift and SwiftUI for the Owner App

## Status

Accepted

## Context

CloudBake starts as an owner-operated bakery app for iPhone and iPad. The app needs strong access to Apple platform capabilities such as camera, Photos library, local notifications, adaptive layouts, offline storage, and future iCloud possibilities.

## Decision

Build the owner app as a native iPhone and iPad app using Swift and SwiftUI.

The app will be iPhone-first, with adaptive iPad layouts for workflows that benefit from more space.

## Consequences

The owner app can provide a strong Apple-platform experience. Future Android customer support will be a separate frontend, not a migration of this SwiftUI app.
