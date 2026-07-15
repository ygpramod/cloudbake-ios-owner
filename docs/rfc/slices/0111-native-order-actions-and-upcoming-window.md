# Slice RFC-0111: Native Order Actions And Upcoming Window

## Status

Implemented.

## Parent Decisions

- Foundation RFC-0001: Owner App Experience Refresh
- Slice RFC-0008: Orders And Reminders Experience

## Goal

Make common order choices feel native and keep the Home dashboard focused on near-term work.

## Scope

1. Present order status and payment choices in compact native iOS menus.
2. Keep partial-payment entry and inventory-deduction confirmation explicit because they collect
   input or protect a stock mutation.
3. Limit Home Upcoming Orders to active orders due from today through the end of the thirtieth day.
4. Keep orders outside that window available in Orders and Calendar.

## Design

Order rows and order detail use the same native menu semantics, including a checkmark for the current
status and stable accessibility identifiers. The existing view-model and repository commands remain
the only mutation path.

The upcoming-order window is calculated in `OrderListPresentation` with an injected calendar and
clock. It includes the owner's local calendar day today and day 30, while excluding past, completed,
cancelled, and day-31 orders.

## Test Plan

- Unit: exact date-window boundaries and active-state filtering.
- Acceptance: native status selection, inventory-deduction protection, and native payment action.
- CI: unit/integration and all acceptance shards.

## Documentation Decision

Update the owner workflow, current capabilities, README, and repository operating contract because
the native-choice pattern and dashboard window are durable owner-facing behavior.
