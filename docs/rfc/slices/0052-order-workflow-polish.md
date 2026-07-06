# Slice RFC-0052: Order Workflow Polish

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Context

After the core Orders workflow, customer/recipe/design linking, checklist support, iPad layout, and
inventory deduction slices, the Orders screen needs a tighter owner workflow for daily use. The
owner primarily needs to see active work by due date, keep completed work available without
cluttering active screens, and keep checklist tasks simple to maintain.

This slice should be implemented after PR 61 lands because PR 61 changes order design references and
acceptance coverage on the Orders screen.

## Scope

This slice applies to:

- Orders screen view modes,
- active versus completed order presentation,
- order sorting,
- removal of the standalone Orders screen due-reminders section,
- order checklist ordering and deletion.

This slice does not apply to:

- pricing and payment summary,
- order-specific photo capture,
- local notification scheduling,
- consumer-facing order views,
- backend or iCloud sync.

## Requirements

- Calendar view must be the default Orders screen view.
- Completed orders must be moved out of the active Orders view into a Completed tab.
- Active Orders list and Completed tab must order orders by entry order.
- Calendar mode may still group active orders by due date, but orders within each calendar day must
  preserve entry order.
- Cancelled order behavior must remain explicit: cancelled orders are historical but are not part of
  this Completed tab unless a later RFC says otherwise.
- The standalone `Reminders Due` section must be removed from the Orders screen.
- Reminder context must remain available through the main order presentation and order detail.
- Checklist items must display in entry order.
- Checklist items must support deletion from order detail.
- Checklist deletion must remove the checklist row from local persistence without affecting the
  parent order.

## Design

Orders should separate active work from completed work at the screen level. The proposed structure is:

- a primary active-orders area that opens in Calendar mode by default,
- a Completed tab for fulfilled work,
- no standalone due-reminder section below the active order content.

The existing `OrderDisplayMode` can continue to support List and Calendar inside active work. The
default selected display mode should become Calendar. Completed orders should be filtered from active
order collections and exposed through a completed collection in the view model.

Entry order should use existing creation metadata where available. If the current persistence model
does not expose a stable created-at field, this slice must introduce a migration or repository-level
ordering rule before changing UI sort behavior.

Checklist items already have `sortOrder` and `createdAt`. Fetching and presentation should preserve
entry order consistently. Deletion should be an explicit owner action, likely via swipe action or a
small destructive control on each checklist row.

## Testing

Required tests:

- Unit/integration coverage for active versus completed order filtering.
- Unit/integration coverage for active list ordering by entry order.
- Unit/integration coverage for calendar day ordering by entry order within the day.
- Unit/integration coverage for checklist deletion persistence.
- Acceptance coverage for:
  - Calendar being the default Orders view,
  - a completed order moving to the Completed tab,
  - deleting a checklist item from order detail.

Local development should run only the impacted Orders acceptance tests. CI remains the full safety
net.

## Documentation

When implemented, update:

- `docs/rfc/orders.md`,
- `README.md`,
- `wiki/Owner-Workflows.md`,
- `wiki/Current-App-Capabilities.md`,
- this slice RFC status and implementation notes.

## Implementation Notes

- `OrderListView` now opens Active orders in Calendar mode by default.
- Active and Completed order scopes are separated with an Orders screen segmented control.
- Active work excludes completed and cancelled orders; completed orders appear in the Completed
  scope.
- Active and Completed collections are derived in `OrderListViewModel` and ordered by `createdAt`.
- Calendar grouping remains date-based, but orders within a day preserve entry order.
- The standalone Orders screen `Reminders Due` section was removed; order detail continues to show
  the next relevant reminder.
- Checklist rows remain in entry order after completion toggles and can be deleted from order
  detail. Persistence deletes only the checklist row and keeps the parent order.

## Superseded Behavior

Slice RFC-0054 supersedes this slice's Orders screen view-mode and order-sorting rules. Active work
is now always calendar-style due-day grouping, active orders are sorted by delivery/pickup date-time
ascending, and completed orders are sorted by delivery/pickup date-time descending.
