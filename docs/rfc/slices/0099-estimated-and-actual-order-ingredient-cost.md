# Slice RFC-0099: Estimated And Actual Order Ingredient Cost

## Status

Implemented.

## Goal

Help the owner quote an order using known ingredient costs and preserve the actual cost of the
inventory batches consumed for the order.

## Scope

1. Calculate estimated cost from the order's scaled recipe and extra ingredients.
2. Allocate cost from usable batches in earliest-expiry-first order.
3. Treat an inventory batch amount as the purchase amount for that batch and derive its unit cost.
4. Show the known partial total while warning about ingredients with missing prices.
5. Persist actual per-ingredient cost atomically with order inventory deduction.
6. Show the cost breakdown only after the owner opens the ingredient-cost row.

## Business Rules

1. Expired batches do not contribute quantity or cost.
2. A missing price is never assumed to be zero.
3. Priced portions remain included when another batch or ingredient lacks a price.
4. Estimated cost recalculates from current order recipe, multiplier, extras, and inventory batches.
5. Actual cost records the precise usable batches allocated by the deduction workflow.
6. Actual cost does not change when inventory prices are edited later.
7. Historical deductions created before this slice are not backfilled or estimated after the fact.
8. Ingredient cost is private owner data and does not affect the quoted price automatically.

## Persistence

Migration `0027_add_order_ingredient_costs` leaves pre-slice batches unpriced because their original
quantity cannot be reconstructed safely, and creates one actual cost snapshot per order and
inventory item. New stock calculates unit cost from purchase amount divided by batch quantity.
Consumption preserves that unit cost. Priced purchases remain separate batches even when their
expiry date and total amount match, because combining their quantities would corrupt unit cost.

## Validation

1. Unit tests cover partial known cost, missing price warnings, and expired-batch exclusion.
2. View-model tests cover estimated, actual, and pre-slice historical states.
3. Persistence integration verifies actual cost is stored with FEFO deduction.
4. Acceptance coverage expands the breakdown and verifies its partial total and missing-price warning.
5. The full unit and integration lane and targeted acceptance test pass locally.

## Documentation Decision

Business Concepts and Owner Workflows are updated because ingredient-cost semantics and the order
pricing workflow are durable owner-facing behavior.
