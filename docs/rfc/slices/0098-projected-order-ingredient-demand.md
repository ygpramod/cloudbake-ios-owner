# Slice RFC-0098: Projected Order Ingredient Demand

## Status

Implemented.

## Goal

Warn the owner before usable inventory becomes insufficient for all active orders.

## Scope

1. Aggregate linked recipe ingredients and order-specific extra ingredients across active orders.
2. Apply each order's recipe multiplier and compatible unit conversion.
3. Compare aggregate demand with usable, non-expired inventory.
4. Show each shortage on every active order that contributes demand for the item.
5. Include projected shortages in Dashboard and Reminders low-inventory alerts.
6. Stop projecting an order after inventory usage is recorded or the order is completed or cancelled.

## Business Rules

1. Projection is a warning only; it does not reserve or deduct stock.
2. Draft, Confirmed, In Progress, and Ready orders contribute until usage is recorded.
3. Completed, Cancelled, and already-deducted orders do not contribute.
4. Expired batches are excluded from usable availability.
5. Legacy inventory without saved batches uses its current quantity as usable availability.
6. Warnings are calculated from current app state and are not stored historically.

## Validation

1. Unit tests cover multi-order aggregation, recipe scaling, extras, order-state exclusion, recorded
   usage exclusion, and expired-batch exclusion.
2. View-model tests cover order warnings, Dashboard alerts, and Reminders alerts.
3. Acceptance coverage verifies an order warning created by aggregate demand from two orders.
4. The full unit and integration lane and targeted acceptance test pass locally.

## Documentation Decision

Business Concepts and Owner Workflows are updated because projected shortage behavior is durable
owner-facing product truth.
