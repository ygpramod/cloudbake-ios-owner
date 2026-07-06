# Slice RFC-0054: Order Active And Completed Tabs

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Context

The Orders screen had both an Active/Completed scope control and an additional List/Calendar view
control. That made the screen feel cluttered for daily owner use. The owner wants Orders to have a
clear two-tab model: Active work is the working calendar, and Completed work is a simple history
list.

## Scope

This slice applies to:

- Orders screen tab structure,
- active order calendar grouping,
- active order due-time ordering,
- completed order history ordering.

This slice does not apply to:

- order pricing and payment fields,
- order detail layout,
- checklist behavior,
- reminder scheduling,
- backend or iCloud sync.

## Requirements

- The Orders screen must show only two top-level tabs: Active and Completed.
- The Active tab must always use the calendar-oriented day grouping.
- Active day groups must be ordered by due day ascending.
- Orders inside each Active day must be ordered by delivery/pickup date-time ascending.
- The Completed tab must be a simple ungrouped history list.
- Completed and cancelled orders must be ordered by delivery/pickup date-time descending.
- Cancelled orders must be visually marked with a small red cancellation indicator.

## Testing

Required tests:

- Unit/integration coverage for active versus completed order filtering.
- Unit/integration coverage for active order due date-time ascending ordering.
- Unit/integration coverage for active calendar day grouping and within-day due time ordering.
- Unit/integration coverage for completed and cancelled order due date-time descending ordering.
- Focused Orders acceptance coverage for opening an active order from the calendar-style list and
  moving completed or cancelled work to the Completed tab.

## Documentation

When implemented, update:

- `docs/rfc/orders.md`,
- `README.md`,
- `wiki/Owner-Workflows.md`,
- `wiki/Current-App-Capabilities.md`.

## Implementation Notes

- `OrderListView` now exposes only the `orders.scope` segmented control for Active and Completed.
- The older Orders display-mode segmented control was removed.
- Active orders use `OrderListViewModel.calendarDays` for presentation.
- Active ordering uses due date-time ascending with entry-order/id tie breakers.
- Completed ordering includes completed and cancelled orders and uses due date-time descending with
  stable tie breakers.
- Cancelled rows show a red cancellation badge in the Completed tab.
