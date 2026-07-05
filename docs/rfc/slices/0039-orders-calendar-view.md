# Slice RFC-0039: Orders Calendar View

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Authority And Scope

This slice adds a calendar-oriented order view so the owner can scan cake commitments by due date.

This slice includes:

- List and Calendar display modes inside Orders,
- calendar grouping by due date,
- due-time ordering inside each calendar day,
- existing order row and detail navigation from the calendar view,
- focused view-model and acceptance coverage.

This slice does not include:

- month grid navigation,
- Apple Calendar integration,
- order reminders,
- drag-and-drop rescheduling,
- capacity planning,
- delivery route planning,
- recipe or inventory actions from the calendar.

## Requirements

- The owner can switch between List and Calendar inside Orders.
- Calendar mode groups orders under due-date sections.
- Orders inside a calendar day appear by due time.
- Calendar order rows open the same order detail screen as list rows.
- The existing add, edit, and detail flows continue to work from the Orders screen.

## Design

`OrderListViewModel` exposes `calendarDays`, a derived read-only grouping of loaded orders. The
repository remains unchanged because the existing due-date sorted order fetch is enough for this
owner-facing view.

The first calendar implementation is a grouped list rather than a month grid. That keeps the slice
small and useful while preserving room for a richer calendar layout later.

## Testing

- View-model tests cover grouping orders by due date and ordering them by due time inside a day.
- Acceptance coverage confirms an owner can switch to Calendar mode, see an order, and open detail
  from that view.

## Documentation Updates

- `README.md` lists Slice RFC-0039.
- `docs/rfc/orders.md` records the calendar slice as implemented.
- `wiki/Current-App-Capabilities.md` lists the orders calendar view.
- `wiki/Owner-Workflows.md` describes the List and Calendar order modes.
