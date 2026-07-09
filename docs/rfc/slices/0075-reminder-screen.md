# Slice RFC-0075: Reminder Screen

## Status

Implemented

## Parent RFCs

- `docs/rfc/orders.md`
- `docs/rfc/slices/0027-inventory-expiry-reminder-notifications.md`
- `docs/rfc/slices/0074-reminder-currency-overdue-polish.md`

## Context

The owner needs one screen that gathers urgent operational reminders without opening Orders,
Inventory, or individual order details.

## Scope

In scope:

1. Add a Reminders second-level screen.
2. Show payment due reminders.
3. Show orders due today.
4. Show low inventory reminders.
5. Link the Dashboard reminder row and Areas list to the Reminders screen.

Out of scope:

1. Reminder snooze.
2. Editing orders or inventory directly from the reminder screen.
3. Push notification scheduling changes.
4. Backend or iCloud sync.

## Requirements Summary

The Reminder screen must contain three sections:

1. `Payment Due`: payment reminder message, WhatsApp reminder action, and Mark as Paid action for
   Ready or Completed orders with a positive balance.
2. `Orders For Today`: order name and customer name for active orders due today.
3. `Low Inventory`: inventory item name and current/minimum quantity.

Confirmed and In Progress orders must not appear in Payment Due. Completed orders may appear in
Payment Due when a balance remains. Cancelled orders must not appear in Payment Due or Orders For
Today.

Payment Due rows must say `{First Name} has {balance} balance due for {Cake Name}.`

The WhatsApp action must be visible only when WhatsApp is installed on the device. When visible, it
must open WhatsApp using the linked customer phone number and prefill:

```text
Hi {First Name}, this is a reminder for your CloudBake order.

Balance due: {balance}

Order: {Cake Name}

Due: {due date and time}

You can make the payment when convenient. Thank you!
```

Mark as Paid must reconfirm before setting the order paid and removing it from Payment Due.

Tapping an Orders For Today row must open that order detail without navigating away from Reminders.
Tapping a Low Inventory row must open that inventory item detail without navigating away from
Reminders. Payment Due rows also open the matching order detail in place.

The screen must use the shared CloudBake second-level screen and card styling.

## Test Strategy

Unit coverage verifies:

1. payment due reminders include only Ready or Completed orders with positive balance due,
2. today reminders include only active orders due on the current day,
3. low inventory reminders show current and minimum quantity text,
4. payment reminders build the WhatsApp message from linked customer contact details,
5. Mark as Paid updates the order and removes the reminder.
