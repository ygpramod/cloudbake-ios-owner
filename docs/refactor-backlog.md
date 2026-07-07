# Refactor Backlog

This backlog captures maintainability smells found during the large guardrails refactor.

Use it as a starting point for future small refactor slices. Do not treat this as permission for
large rewrites; each item should still ship as small, tested commits.

## Recently Improved

- Split large inventory view-model tests into focused inventory list, batch editing, purchase bill,
  and stock operation test files.
- Split recipe import view-model tests and moved recipe test fakes into shared test support.
- Split order checklist tests and extracted shared order fixtures/fakes out of
  `OrderListViewModelTests`.
- Replaced `extension OrderListViewModelTests` test coupling with normal focused order test classes.
- Extracted recipe import, customer draft, order draft, order payment, inventory draft, purchase bill,
  and stock operation validation/planning helpers.

## Remaining Smells

1. `OrderListViewModel` is still broad.
   - It owns loading, add/edit draft handling, status changes, payment updates, checklist operations,
     photo operations, and detail hydration.
   - Next slice: extract one cohesive operation at a time only when tests already cover the behavior.

2. `InventoryListViewModel` is still broad.
   - Purchase bill import, stock batch editing, stock adjustments/usage, history, archive/restore, and
     add/edit item drafts remain in one type.
   - Next slice: avoid a full rewrite; extract one operation family into a helper or coordinator with
     focused tests.

3. `GRDBOrderRepository` is still large.
   - It contains order persistence, status transitions, recipe usage recording, checklist persistence,
     and photo persistence.
   - Next slice: split private mapping/persistence helpers by subdomain without changing repository
     protocol behavior.

4. Some view files remain large enough to hide logic.
   - `OrderDetailView`, `OrderListView`, `InventoryListView`, and `PurchaseBillImportView` should be
     watched for body logic, repeated modifiers, or state that belongs in view models.
   - Next slice: extract private subviews only where it makes behavior easier to read or test.

5. Some tests still have heavy fixture setup.
   - The largest remaining test files should be reviewed for fixture builders that can make the test
     intent clearer.
   - Next slice: prefer shared test support over inheritance or extension coupling.

6. Remaining force unwraps are mostly in older test fixtures.
   - Replace them opportunistically with `XCTUnwrap`, small fixture helpers, or explicit guard failures
     when touching those tests.
   - Do not churn unrelated test files only to remove harmless fixture unwraps.

## Out Of Scope For The Current Refactor PR

- Broad MVVM reshaping of `OrderListViewModel` or `InventoryListViewModel`.
- Rewriting persistence protocols.
- Reworking app navigation or owner workflows.
- Cosmetic UI-only changes.
