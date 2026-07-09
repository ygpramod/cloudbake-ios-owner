# Slice RFC-0074: Reminder Currency And Overdue Polish

## Status

Implemented

## Parent RFCs

- `docs/rfc/orders.md`
- `docs/rfc/slices/0027-inventory-expiry-reminder-notifications.md`
- `docs/rfc/slices/0073-currency-and-inventory-amount.md`

## Context

The owner reported repeated low-inventory/expiry notifications during the same day. The owner also
needs Singapore dollar in Settings and clearer status action prompts when an order passes its due
time.

## Scope

In scope:

1. Schedule expiry reminders only once per day at 9 AM.
2. Add Singapore dollar to Settings currency choices.
3. Add due-time local notifications for active scheduled orders.
4. Route order notification taps to the matching order.
5. Show overdue order context in-app and mark overdue order rows.

Out of scope:

1. Reminder snooze.
2. Configurable reminder time.
3. Remote push notifications.
4. Backend reminder sync.

## Requirements Summary

Expiry reminders must not produce repeated same-day catch-up notifications when the app refreshes
after 9 AM. If a reminder is still relevant, the next notification should be scheduled for the next
9 AM before expiry.

Settings must include Singapore dollar as `S$ Singapore Dollar`.

Confirmed, In Progress, and Ready orders must schedule a local notification at due time. The
notification message is `{Name} was due at {time}, update status?` and tapping it must route the
owner to the order.

When an active order is past due, CloudBake must show an Overdue pill on the order row. CloudBake
must also show an in-app banner for the earliest overdue active order:

1. same day: `{Name} was due at {time}, update status?`
2. later day: `{Name} is overdue. Update status?`

Completed and Cancelled orders must not show overdue state.

## Test Strategy

Unit coverage verifies:

1. expiry reminders schedule the next 9 AM instead of immediate catch-up,
2. expiry reminders do not schedule after the last valid 9 AM for same-day expiry,
3. order reminders include due-time notifications and order metadata,
4. Dashboard exposes the primary overdue order alert,
5. Orders expose same-day and later-day overdue messages and row state.
