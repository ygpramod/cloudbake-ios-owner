# Slice RFC-0028: In-App Expiry Reminder Snooze

## Status

Accepted

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Show the owner an in-app reminder whenever the app opens and inventory has expired stock or stock
expiring within one week, while allowing the owner to snooze the reminder.

## Scope

- Detect active inventory stock batches that are expired or expiring within seven days.
- Show an in-app expiry reminder sheet when the app opens or returns to the foreground.
- Show the earliest expired or expiring batch first.
- Let the owner snooze the reminder.
- Default snooze duration to one day.
- Allow snoozing from one to seven days through a menu picker.
- Persist snooze state locally per stock batch.
- Add unit, integration, and launch acceptance coverage.
- Update product documentation and wiki pages.

## Out Of Scope

- Push notifications.
- Multiple reminders in one popup.
- Notification settings UI.
- Custom snooze dates outside one to seven days.
- Order delivery reminder snooze.

## Requirements

- The in-app reminder must include item name, remaining quantity, unit, and expiry date.
- Expired batches must qualify for the in-app reminder.
- Remaining batches expiring within seven days must qualify for the in-app reminder.
- Zero-quantity, no-expiry, and later-than-seven-day batches must not qualify.
- Snoozed batches must not show again until the snooze time has passed.
- Snooze defaults to one day.
- Snooze options must support one through seven days.
- Snooze state must survive app restarts.

## Design

`InAppExpiryReminderViewModel` owns the in-app reminder selection and snooze workflow. It depends on:

- `InventoryItemRepository`,
- `InventoryStockBatchRepository`,
- `InventoryExpirySnoozeRepository`.

`inventory_expiry_snoozes` stores one snooze row per stock batch:

- `stock_batch_id`,
- `snoozed_until_unix_time`,
- `updated_at_unix_time`.

The app shell refreshes the ViewModel when `RootView` appears and when the scene becomes active. If
a qualifying reminder exists, `RootView` presents `InAppExpiryReminderView`.

The reminder sheet shows the relevant stock batch details and a `Remind Me Again` menu picker with
one to seven days. The picker defaults to one day every time a new reminder is loaded.

## Tests

Unit and integration coverage:

- earliest expired or expiring-within-one-week batch is selected,
- snoozed batches are hidden until the snooze expires,
- selected snooze day count is persisted,
- snooze rows round-trip through GRDB.

Acceptance coverage:

- app launch still reaches the dashboard in a clean in-memory UI-test database.

## Documentation

Updated:

- `README.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Inventory-Guide.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- Owner sees an in-app reminder on app open for expired stock or stock expiring within one week.
- Owner can snooze the reminder for one to seven days.
- Default snooze duration is one day.
