# Slice RFC-0069: Second Level Screen Look And Feel

## Status

Implemented

## Parent RFC

- `requirements.md`

## Authority And Scope

This slice extends the warm CloudBake visual language from the dashboard and order template to the
owner app's second-level destination screens.

This slice includes:

- a shared second-level screen scaffold,
- warm CloudBake background, compact title, circular top action buttons, and bottom
  navigation,
- styled list/card rows for Orders, Inventory, Recipes, and Customers,
- styled empty states for Designs and Settings placeholders,
- acceptance-test updates for the refreshed custom navigation surface.

This slice does not include:

- new business behavior,
- new order, inventory, recipe, customer, design, or settings fields,
- a center bottom add button,
- restyling every modal form and detail screen.

## Requirements

- Orders, Inventory, Recipes, Customers, Designs, and Settings must feel visually consistent when
  opened from the dashboard.
- Existing add, import, archive, row tap, status, payment, and detail workflows must remain
  available.
- Second-level screens must not repeat the CloudBake logo in the header; that space is reserved for
  screen actions.
- Screens with several top actions may collapse them behind a compact `...` action menu.
- Existing accessibility identifiers used by critical workflows must remain stable or be updated in
  tests with a clear reason.
- The bottom navigation must preserve the Home, Orders, Inventory, and More quick links.
- Second-level screens must be pushed from Home with the platform right-to-left navigation
  animation.
- Moving between second-level screens must use the same platform push animation instead of an
  abrupt replacement.
- Second-level screens must not show a custom back button.
- The iOS left-edge back gesture must use the platform interactive behavior and return the owner to
  the previous screen, even though CloudBake hides the standard navigation bar chrome.
- The app should keep only a short section history of roughly two to three previous pages. Tapping
  a section that is already in that recent history should pop back to it instead of pushing a
  duplicate screen.
- The implementation must avoid duplicating styling rules across feature screens.

## Design

The slice introduces shared SwiftUI components in `CloudBakeScreenStyle.swift`:

- `CloudBakeScreenScaffold`,
- `CloudBakeScreenAction`,
- `CloudBakeSection`,
- `CloudBakeListCard`,
- `CloudBakeEmptyState`,
- `CloudBakeErrorBanner`,
- `CloudBakeRowIcon`,
- shared CloudBake colors and card styling.

Feature list screens keep their existing view models and domain behavior. The shared scaffold owns
visual chrome only: background, title/header actions, optional action menu, and bottom navigation.

## Testing

- Build the app for the iPhone simulator.
- Run primary navigation acceptance coverage.
- Run representative acceptance tests for touched Orders, Inventory, Recipes, and Customers
  workflows.

## Documentation Updates

- `README.md` lists Slice RFC-0069.
- `wiki/Owner-Workflows.md` describes the shared second-level screen style.
- `wiki/Current-App-Capabilities.md` lists the styled second-level owner screens.
