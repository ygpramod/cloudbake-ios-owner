# Slice RFC-0097: Expired Inventory Exclusion And Disposal

## Status

Implemented.

## Goal

Prevent expired stock from being consumed and give the owner an explicit, audited way to dispose
of it.

## Scope

1. Exclude expired batches from manual stock consumption.
2. Exclude expired batches from order recipe and extra-ingredient consumption.
3. Fail consumption when usable, non-expired stock cannot cover the requested quantity.
4. Show an expired-stock disposal action on inventory item details when expired stock remains.
5. Dispose all expired remaining batches atomically while preserving usable batches.
6. Record disposal as an `expiredDisposal` inventory transaction.

## Business Rules

1. A batch is expired when its expiry timestamp is earlier than the consumption or disposal time.
2. A batch without an expiry date remains usable.
3. Normal consumption uses only usable batches in earliest-expiry-first order.
4. Expired quantity remains part of current stock until the owner disposes of it or corrects the
   saved batch.
5. Expired disposal is not order consumption and is excluded from ingredient-cost calculations.
6. Inventory quantity, batches, and the disposal transaction are saved atomically.

## Validation

1. Unit tests cover skipping expired batches and rejecting insufficient usable stock.
2. Unit tests cover disposal preserving usable batches and recording history.
3. Persistence integration tests cover order consumption with expired stock present.
4. Acceptance coverage verifies disposal from inventory item details.
5. The full unit and integration lane and targeted inventory acceptance test pass locally.

## Documentation Decision

The Inventory Guide and Business Concepts wiki sources are updated because expiry handling and the
new transaction type are durable owner-facing behavior.
