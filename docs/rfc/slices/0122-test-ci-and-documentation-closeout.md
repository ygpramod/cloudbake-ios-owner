# Slice RFC-0122: Test, CI, And Documentation Closeout

## Status

Implemented in the owner app.

## Goal

Close the remaining test-registration, release-composition, CI-sharding, and documentation gaps so
that every acceptance journey is exercised intentionally, App Store builds remain free of
acceptance fixtures, and repository guidance matches implemented owner behavior.

## Requirements

1. Register every `CloudBakeOwnerUITests` acceptance selector in exactly one CI feature shard.
2. Add a repository-owned validation command that fails when an acceptance selector is missing,
   registered more than once, or no longer exists in the test target.
3. Run acceptance-registration validation in the existing unit/integration CI job without adding
   another runner.
4. Rebalance order acceptance journeys so inventory-deduction, checklist, costing, and photo
   workflows do not make the core order shard a recurring bottleneck.
5. Add a deterministic Release build verification command that proves the built app contains none
   of the acceptance environment keys prohibited by RFC-0120.
6. Run Release-composition verification in the existing unit/integration CI job with the Xcode
   version already pinned by the workflow.
7. Document the exact local validation commands and current CI lanes.
8. Correct owner-facing workflow documentation that still describes implemented recipe-driven
   inventory deduction as future work.
9. Keep all validation scripts dependency-free beyond macOS, Git, Python 3, and the pinned Xcode
   toolchain already used by CI.
10. Preserve the final-photo-to-design acceptance journey without automating Apple Photos. Use a
    Debug-only photo-library substitute during acceptance runs and prove through the Release
    composition gate that it cannot ship.

## Acceptance Shard Ownership

1. `core-recipes`: app shell, dashboard, reports, and recipe authoring.
2. `settings`: settings, import/export, backup, and restore.
3. `orders-core`: order creation, status, reminders, payments, calendar, and completed-order lists.
4. `order-workflows`: ingredient costing, recipe deduction, shortage decisions, checklist, and
   order photos.
5. `order-links`: customer, recipe, and design selection from an order.
6. `customers`: customer creation and maintenance.
7. `inventory`: inventory creation, editing, scrolling, swipe actions, import, voice, archive,
   disposal, and deletion.
8. `designs`: design and reference-photo workflows.

## Validation

1. The acceptance-registration command reports no missing, duplicate, or unknown selectors.
2. The Release-composition command builds the owner app with the Release configuration and scans
   the resulting app bundle for every prohibited acceptance key.
3. Unit and integration tests remain green.
4. Targeted acceptance tests moved or newly registered by this slice pass locally.
5. GitHub Actions passes the unit/integration lane and every acceptance shard.
6. `git diff --check` and changed-file Swift formatting remain clean.

Local closeout evidence:

1. all 77 acceptance selectors registered exactly once;
2. Release build and app-bundle scan passed;
3. 707 unit/integration tests passed with one intentional skip;
4. all 10 journeys that had previously been absent from CI passed, including focused reruns after
   correcting stale test assumptions;
5. final-photo promotion passed end to end with the Debug-only photo-library substitute, while a
   fresh Release bundle scan remained clean.

## Risks And Controls

1. Regex-only test discovery can silently miss valid XCTest declarations. Keep the accepted
   declaration and selector patterns explicit, fail on malformed CI selectors, and cover the
   validator with repository-state execution.
2. Adding missing journeys can increase CI duration. Assign workflows by responsibility and move
   the heavier order workflows out of the core order shard.
3. Release verification can inspect the wrong product. Build into a dedicated DerivedData
   directory and require exactly one `CloudBakeOwner.app` at the expected Release products path.
4. Documentation can drift again. Keep acceptance registration and Release composition executable
   as CI contracts rather than relying only on prose.

## Wiki Decision

`wiki/Owner-Workflows.md` must change because it currently tells owners that recipe-driven
inventory reduction is future work even though linked recipe usage, reservations, shortage
confirmation, and one-time deduction are implemented.
