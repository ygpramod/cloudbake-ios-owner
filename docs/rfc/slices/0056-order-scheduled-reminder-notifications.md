# Slice RFC-0056: Order Scheduled Reminder Notifications

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Context

Order detail already shows the next reminder from the three-day, two-day, and one-day reminder
plan. The owner also needs local iOS notifications so accepted work can be remembered even when the
app is not open.

## Scope

This slice adds local owner notification scheduling for order reminders.

In scope:

- schedule local iOS notifications for future three-day, two-day, one-day, and due-time order
  reminders,
- refresh scheduled order reminders when the app opens or returns to the foreground,
- schedule notifications only for active scheduled order states,
- remove stale order reminder notifications before scheduling current ones,
- keep inventory expiry reminder scheduling intact,
- add focused scheduler tests,
- update owner-facing documentation.

Out of scope:

- reminder snooze,
- custom reminder offsets,
- preparation-start reminders,
- calendar integration,
- customer-facing notifications,
- backend reminder sync.

## Requirements

- Confirmed, In Progress, and Ready orders must schedule local notifications at future reminder
  offsets three days, two days, one day, and due time.
- Draft, Completed, and Cancelled orders must not schedule local notifications.
- Past-due orders must not schedule local notifications.
- Reminder offsets that have already passed must not schedule notifications.
- Due-time notification taps must carry the order id so the app can open the order directly.
- Refreshing reminders must remove stale order reminder notifications without removing unrelated
  inventory expiry notifications.
- Notification scheduling failures must not block app launch or foreground resume.
- UI test runs that use the in-memory database must continue to skip local reminder scheduling.

## Design

`OrderReminderScheduler` reads orders from the local repository and creates `UNNotificationRequest`
values for eligible reminder offsets. Notification identifiers use the stable format
`order-reminder-{orderId}-{offsetDays}d`, which allows the scheduler to replace stale order
reminders while leaving other local notifications alone.

Due-time notifications use the message `{Order title} was due at {time}, update status?` and include
order metadata for local deep linking. Tapping the notification routes the owner to the matching
order in the Orders workflow.

`RootView` refreshes both inventory expiry reminders and order reminders on app launch and when the
app becomes active. Both schedulers share the local notification abstraction so tests can verify
permission requests, stale notification removal, and scheduled requests without touching
`UNUserNotificationCenter`.

## Tests

Focused unit coverage verifies that:

- future active orders produce three-day, two-day, one-day, and due-time notification requests,
- draft, completed, cancelled, past-due, and already-missed reminder cases do not schedule
  notifications,
- refresh requests notification permission, removes only stale order notifications, and adds the
  current order reminders.

Acceptance tests are not required for this slice because the behavior is background notification
scheduling and is intentionally skipped in the in-memory UI-test configuration.
