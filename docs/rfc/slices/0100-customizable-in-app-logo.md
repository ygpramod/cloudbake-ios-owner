# Slice RFC-0100: Customizable In-App Logo

## Status

Implemented.

## Parent

- User-requested owner app customization before CloudKit disaster-recovery implementation.

## Goal

Let the bakery owner replace the CloudBake logo shown inside the app with a photo selected from the
iPhone photo library.

## Scope

1. Add an Appearance section in Settings with the current logo preview and **Choose** action.
2. Copy the selected image into app-managed Application Support storage.
3. Show the custom logo in the dashboard header immediately after selection.
4. Allow the owner to restore the bundled default CloudBake logo.
5. Keep the installed iOS Home Screen icon unchanged.

## Out Of Scope

- Alternate iOS app icons, logo editing/cropping tools, cloud backup, and multiple saved logos.

## Design

`AppLogoStore` owns atomic file persistence and loading. Settings uses the shared photo picker loader,
updates a lightweight revision preference after successful persistence, and reports recoverable
errors. The dashboard observes that revision and renders the app-managed image with the existing
circular logo treatment, falling back to the bundled asset whenever no valid custom image exists.

## Test Plan

- Unit: save, load, and remove the app-managed logo file.
- Acceptance: Settings exposes the logo picker alongside existing Settings controls.
- Local validation: full unit/integration lane and targeted Settings acceptance test.

## Acceptance Criteria

- A selected photo becomes the dashboard's in-app logo without relaunching.
- Relaunch preserves the custom logo.
- Restore Default removes the custom file and immediately restores the bundled logo.
- An unreadable or unsavable image leaves the last valid logo unchanged and shows an error.
- The Home Screen app icon is not modified.

## Wiki Decision

Owner Workflows and Current App Capabilities are updated because logo customization is durable,
owner-visible behavior.
