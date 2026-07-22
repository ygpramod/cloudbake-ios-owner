# Slice RFC-0117: Order Inventory Shortage Override And Fallback Cost

## Status

In progress.

## Goal

Allow the owner to finish a real order when CloudBake's usable inventory record is short, while
keeping the shortage explicit, inventory non-negative, and ingredient costing useful.

## Scope

1. Replace the hard insufficient-stock failure for Ready and Completed transitions with an
   owner-confirmed warning.
2. Consume every available non-expired quantity without making usable inventory or stock batches
   negative.
3. Record the undeducted quantity as an order ingredient shortfall for later audit.
4. Calculate estimated and actual cost for the full required quantity.
5. Price quantity beyond usable stock with the newest historically known purchase unit price.
6. Keep missing-price warnings when no historical price exists.

Manual inventory consumption remains strict and continues to reject consumption above usable
stock. This override applies only to the one-time order recipe and extra-ingredient usage workflow.

## Business Rules

1. Ready and Completed still require explicit confirmation before the first recipe usage.
2. If usable inventory is short, CloudBake must show the affected ingredients and require a second
   explicit confirmation before continuing.
3. Cancelling the shortage warning leaves order status, inventory, costs, and usage unchanged.
4. Continuing consumes only usable, non-expired stock in earliest-expiry-first order.
5. Inventory and batch quantities never become negative. Expired quantities remain untouched until
   corrected or disposed.
6. The usage record remains one-time even when part of its required quantity is a shortfall.
7. Estimated cost allocates usable batches first. Any quantity beyond usable stock uses the newest
   known priced purchase for that inventory item, including depleted or expired historical batches.
   Historical batches provide only a price reference and are never consumed.
8. Actual cost uses the same fallback for the recorded shortfall and is frozen with the usage.
9. If no historical unit price exists, CloudBake preserves the calculable partial total and warns
   that the remaining quantity has no price.
10. The actual cost breakdown records and displays the shortfall quantity separately from missing
    price quantity.

## Persistence

Add a non-negative `shortfall_quantity` value to each persisted order ingredient cost row. The
order status, partial inventory deduction, consumption transactions, cost snapshot, shortfall, and
one-time usage record remain one atomic database operation.

Consumption transactions record only the quantity actually removed from inventory. The persisted
ingredient cost row records the full required quantity and its shortfall.

## Validation

1. Domain tests cover fallback pricing with partially available, depleted, expired, and entirely
   unpriced stock.
2. Persistence tests prove strict mode rolls back, override mode floors usable stock, preserves
   expired batches, records only actual consumption, and stores the shortfall and full cost.
3. View-model tests cover warning presentation, cancellation, confirmation, and successful status
   change from both Ready and Completed entry paths.
4. Targeted order acceptance coverage verifies the owner-visible shortage confirmation when
   practical; detailed arithmetic remains in deterministic unit and integration tests.

## Documentation Decision

Order, inventory, costing, and owner workflow documentation must be updated because this changes a
durable business rule.
