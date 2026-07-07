# Slice RFC-0068: Dashboard Home Look And Feel

## Status

Implemented

## Parent RFC

- `requirements.md`

## Authority And Scope

This slice updates the owner dashboard home screen visual structure and navigation ergonomics. It
does not change inventory, order, recipe, customer, reminder, pricing, persistence, or sync business
rules.

This slice includes:

- a warmer custom CloudBake home header,
- compact Today cards for upcoming orders and low inventory,
- Soon rows for reminders and recent designs,
- an Areas card for all owner work areas,
- bottom quick navigation for Home, Orders, Inventory, Recipes, and Designs,
- acceptance-test navigation updates for repeated home labels.

This slice does not include:

- a new order creation shortcut,
- new dashboard order counts,
- live reminders or recent-design data,
- customer-facing navigation,
- backend or iCloud changes.

## Requirements

- The home screen must preserve the existing dashboard low-inventory behavior.
- The dashboard must continue loading low inventory through `DashboardViewModel`.
- The visible top navigation title must not duplicate the custom home header.
- The bottom quick navigation must not include a center add button.
- Main app areas must remain reachable from the dashboard.
- The owner app must force light appearance for now because the refreshed home design is not yet
  usable in dark mode.
- Acceptance tests must avoid brittle visible-text navigation when the home design intentionally
  repeats destination labels.

## Design

`DashboardView` changes from a plain `List` to a custom SwiftUI scroll view with reusable private
subviews for sections, metric cards, action rows, area rows, and bottom navigation.

The dashboard keeps UI-only styling in the view and leaves low-inventory loading and alert counting
inside `DashboardViewModel`.

## Testing

- Build the app for the iPhone simulator.
- Run dashboard ViewModel unit tests.
- Run launch and primary navigation acceptance checks.

## Documentation Updates

- `README.md` lists Slice RFC-0068.
- `wiki/Owner-Workflows.md` describes the new home workflow structure.
- `wiki/Current-App-Capabilities.md` lists the visual dashboard home screen capability.
