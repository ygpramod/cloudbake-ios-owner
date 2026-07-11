# ADR-0001: Use Swift and SwiftUI for the Owner App

## Status

Accepted

## Context

CloudBake starts as an owner-operated bakery app for iPhone. The app needs strong access to Apple
platform capabilities such as camera, Photos library, local notifications, adaptive layouts, offline
storage, and future iCloud possibilities.

## Decision

Build the owner app as a native iPhone app using Swift and SwiftUI.

iPad is not supported for the initial owner release. Supporting it later requires a focused RFC,
design validation, and an acceptance-test plan.

## Consequences

The owner app can provide a strong Apple-platform experience. Future Android customer support will be a separate frontend, not a migration of this SwiftUI app.
