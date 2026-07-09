# Slice RFC-0027: Inventory Expiry Reminder Notifications

## Status

Accepted

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Notify the owner before remaining inventory stock expires so handmade cake work can use or replace
stock before it becomes unusable.

## Scope

- Request local notification permission from the owner app.
- Schedule local expiry reminder notifications for remaining stock batches expiring within one
  month.
- Use the same one-month expiry window already used by low-inventory alerts.
- Refresh reminders when the app opens or returns to the foreground.
- Keep notification scheduling out of UI-test in-memory database runs.
- Add unit tests for reminder request creation and scheduling behavior.
- Update README and wiki product documentation.

## Out Of Scope

- Remote push notifications.
- Notification settings UI.
- Custom reminder times.
- Repeating reminders.
- Order delivery reminders.
- Recipe-driven reminder changes.

## Requirements

- The app must schedule reminders only for active inventory items.
- The app must schedule reminders only for stock batches with remaining quantity greater than zero.
- The app must schedule reminders only when the batch has an expiry date within one month and has
  not already expired.
- The reminder message must include item name, remaining batch quantity, unit, and expiry date.
- The app must request notification permission before scheduling reminders.
- Scheduling failure must not block normal app use.
- UI tests must not be interrupted by notification permission prompts.

## Design

`ExpiryReminderScheduler` owns notification scheduling. It depends on:

- `InventoryItemRepository`,
- `InventoryStockBatchRepository`,
- a small `ExpiryReminderNotificationCenter` protocol that wraps `UNUserNotificationCenter`.

The scheduler fetches active inventory items, fetches each item's remaining stock batches, and
creates one local notification request per expiring batch.

Notification identifiers use the stock batch id with an inventory-expiry prefix. On each refresh,
the scheduler removes pending requests for the batches it is about to schedule and then adds the
current reminder requests.

Reminder timing:

- preferred reminder date is one calendar month before expiry at 9 AM,
- if that date has already passed because the owner entered stock less than one month before
  expiry, the reminder is scheduled for the next available 9 AM before expiry,
- if the owner opens the app after the current day's 9 AM reminder time, CloudBake schedules the
  next reminder for 9 AM on the following day instead of sending repeated catch-up reminders,
- expired, no-expiry, zero-quantity, and later-than-one-month batches are ignored.

`RootView` refreshes reminders when the app appears and when the scene becomes active. It skips this
work when `CLOUDBAKE_USE_IN_MEMORY_DATABASE=1`, preventing UI-test runs from showing notification
permission prompts.

## Tests

Unit coverage:

- expiring batches within one month create notification requests,
- expired, far-future, no-expiry, and zero-quantity batches are ignored,
- refresh requests authorization, removes stale pending identifiers for scheduled batches, and adds
  reminder requests.

## Documentation

Updated:

- `README.md`
- `wiki/Business-Concepts.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Inventory-Guide.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- Owner receives local expiry reminder notifications after granting permission.
- Reminders use the existing one-month expiry window.
- Existing dashboard low-inventory expiry behavior remains unchanged.
