# Slice RFC-0044: Order Reminders

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Authority And Scope

This slice adds owner-visible order reminder planning to the local-first Orders workflow.

This slice includes:

- calculating reminder dates three days, two days, and one day before the order due date,
- showing reminder dates in order detail,
- showing due or overdue reminders grouped by order at the top of Orders,
- excluding completed and cancelled orders from due reminder alerts,
- focused view-model and acceptance coverage.

This slice does not include:

- local notification permission prompts,
- scheduled iOS order notifications,
- reminder snooze,
- configurable reminder offsets,
- calendar integration,
- customer-facing reminders.

## Requirements

- Each order must expose reminder dates for three days, two days, and one day before due date.
- The Orders screen must surface reminders whose reminder time has been reached.
- Due reminders should be grouped by order so one overdue cake does not create multiple list rows.
- Completed and cancelled orders must not appear in due reminders.
- Tapping a due reminder must open the order detail.
- Order detail must show the full reminder plan for owner review.

## Design

`OrderListViewModel` derives reminder state from the current orders, the current time, and the
configured calendar. No new persistence is introduced in this slice because reminder dates are
deterministic from `Order.dueAt`.

The Orders screen shows a `Reminders Due` section before the list/calendar mode picker when at
least one active order has a reminder at or before the current time. Each order appears once in that
section with its due reminder offsets summarized. Order detail shows the full three/two/one-day
reminder plan.

Local notifications remain a later slice so notification permission, scheduling, rescheduling, and
snooze behavior can be designed deliberately.

## Testing

- View-model tests cover the three/two/one-day reminder plan.
- View-model tests cover due reminder filtering, ordering, and exclusion of completed or cancelled
  orders.
- A targeted acceptance test verifies that due reminders appear in Orders and open order detail,
  where the full reminder plan is visible.

## Documentation Updates

- `README.md` lists Slice RFC-0044.
- `docs/rfc/orders.md` records order reminders as implemented in-app reminder planning.
- `wiki/Current-App-Capabilities.md` lists owner-visible order reminders.
- `wiki/Owner-Workflows.md` describes the order reminder workflow.
