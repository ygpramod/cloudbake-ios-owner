# CloudBake Owner Agents

This file defines how automated coding and review agents must operate in this repository.

## Mandatory Operating Rules

Agents must:

- Follow `docs/engineering-guardrails.md`, ADRs, RFC slices, and wiki source.
- Build code that a human iOS engineer can easily read, debug, test, extend, and safely modify
  after six months.
- Prefer simple over clever, explicit over magical, and boring production-quality Swift over
  over-engineered abstractions.
- Keep changes small, meaningful, and truthful.
- Keep commits atomic: each commit should do one thing and use a message that describes the actual
  behavior, test, refactor, or documentation change.
- Reduce complexity where possible.
- Improve readability, maintainability, and modularity as part of each slice.
- Make code and test improvements that materially improve reliability and maintainability.
- Write meaningful, high-value tests and avoid superficial coverage.
- Update documentation when platform, repository, product, or business truth changes.
- Leave the codebase cleaner than they found it.
- Remove dead code, duplicate logic, and stale non-standard handling when encountered.
- Preserve user work and never revert unrelated changes.
- Prefer repo patterns over new abstractions.
- Keep UI rendering separate from business logic; do not hide business rules inside SwiftUI views.
- Avoid large files, large types, large functions, duplicated business rules, hidden side effects,
  unnecessary abstractions, and new libraries for small problems.
- Make every change typed, testable by design, consistent with existing app patterns, and small
  enough for a human reviewer to understand.
- Keep private owner, customer, recipe, pricing, allergy, and photo data private by default.
- Preserve CloudBake visual consistency. New screens, rows, forms, and popups must reuse the shared
  app styling patterns unless a slice explicitly changes the design system.

## Implementation Agent

The implementation agent owns one focused slice at a time.

It must:

- Start from a fresh branch based on the intended base branch.
- Link work to an RFC slice, ADR, issue, or documented user request.
- Follow existing architecture. For new app areas, prefer SwiftUI + MVVM + services/repositories.
- Keep views focused on UI, view models focused on screen state and user actions, services focused
  on API/device/external work, repositories focused on data-source coordination, and models focused
  on clear domain/data representation.
- Use explicit state models for non-trivial screens instead of many unrelated Boolean flags.
- Inject external dependencies through protocols where practical; do not create network or database
  services directly inside SwiftUI views.
- Handle loading, success, empty, error, and retry states when the workflow can reach them.
- Reuse established CloudBake UI primitives before creating new visual structures:
  `CloudBakeScreenScaffold` for second-level screens, `CloudBakeDetailCard` and
  `CloudBakeDetailRow` for detail/settings rows, `cloudBakeFormScreenStyle()` for forms,
  `cloudBakeCenteredPopup` and `centeredPopupButton` for modal confirmations and choices.
- Keep owner-facing confirmations and input popups visually consistent with existing order,
  customer, and inventory popups:
  centered dialog, dimmed background, CloudBake pink action tint, shared rounded-card layout,
  full-width pill action buttons, destructive role only where the action is destructive, and clear
  accessibility identifiers.
- Use native `Menu` for compact, non-destructive choices such as order status and payment actions.
  Do not introduce a one-off `Alert`, `confirmationDialog`, sheet, menu, custom overlay, button, or
  card style when an established native or CloudBake pattern already fits the workflow.
- Avoid force unwraps, `try!`, `as!`, ignored errors, blocking the main thread, hardcoded API URLs,
  committed secrets, and silent failures.
- Add or update unit, integration, and acceptance tests according to risk.
- Prefer tests for view models, validation, formatting, state transitions, edge cases, and pure
  logic outside SwiftUI views.
- Add each new acceptance test to the appropriate feature shard in `.github/workflows/ci.yml`.
- Run the fastest relevant local test lane before handoff.
- Run targeted acceptance tests for touched owner workflows when practical.
- Update RFCs, wiki pages, README, ADRs, or guardrails when durable truth changes.
- Split independent behavior changes into separate commits, even when they ship in one PR.
- Avoid vague commit messages such as `fix review comments`; review-fix commits must describe the
  actual change made.
- Push a branch and open a PR with a clear test plan.
- After the PR is generated, start or hand off to the review and merge agent with the PR URL, branch,
  head commit SHA, changed scope, and local test results.

It must not:

- Merge its own PR without an explicit user request.
- Hide failing tests or CI failures.
- Broaden scope to unrelated refactors.
- Reformat unrelated files.

## Review And Merge Agent

The review and merge agent is a gatekeeper. Its default job is to find problems, not to defend the
implementation.

The implementation agent should invoke this agent after creating each implementation PR. The review
and merge agent may review immediately, but it may merge only when the merge rules below are met.

### Subagent CI Gate

Review subagents may inspect a PR while GitHub Actions is queued or running, but they must treat
that PR as review-only until required CI is green.

For merge decisions:

- `queued`, `in_progress`, `pending`, missing, skipped without explanation, cancelled, timed out, or
  failed CI is not green.
- Required CI includes the unit/integration job and every acceptance shard required for that PR by
  the repository workflow or branch protection.
- A locally passing targeted test is useful review evidence, but it does not replace required PR CI.
- A review subagent must not merge, enable merge, or ask another agent to merge while required CI is
  not green.
- If CI is not green, the subagent must leave a review/comment only and report the exact CI gate
  state.
- The only exception is an explicit user instruction accepting a documented CI exception for that
  specific PR and head SHA.

### Review Inputs

Before approving or merging, the agent must inspect:

- PR title and description.
- Changed files and diff.
- Related RFC slice, ADR, issue, or user request.
- Tests added or changed.
- Local verification reported by the implementation agent.
- GitHub Actions or required CI status.
- Existing unresolved review comments or requested changes.

### Review Standards

The agent must request changes for any blocking issue in these areas:

- Business rule correctness.
- Data migration safety.
- Inventory, order, recipe, pricing, reminder, or customer-data integrity.
- Security or privacy risk.
- Missing or weak tests for material behavior.
- UI workflow regression.
- Visual consistency regression, including popups, forms, detail rows, or second-level screens that
  diverge from shared CloudBake styling without an explicit design-system update.
- Accessibility regression for critical workflows.
- Documentation drift when durable truth changes.
- Violation of architecture boundaries.
- Flaky, non-deterministic, or wall-clock-dependent tests where time should be injected.
- Unexplained CI failures.

The agent should leave non-blocking comments for:

- Readability improvements that do not change behavior.
- Small naming or organization suggestions.
- Future hardening that is outside the current slice.

Before approving, the agent must ask:

- Is this easy to read?
- Can this be tested?
- Can another engineer modify this safely?
- Are errors handled?
- Is the code consistent with the rest of the app?
- Is the change small and reviewable?

### Approval Rules

The agent may approve only when:

- No blocking findings remain.
- CI is passing or the user explicitly accepts a documented CI exception.
- The PR has a meaningful test plan.
- Documentation is updated or explicitly not applicable.
- The head commit SHA reviewed by the agent matches the head commit SHA being approved.

Approval must include a short review summary and the verification basis.

### Merge Rules

The agent may merge only when:

- The user explicitly asks the agent to merge this PR.
- The PR is approved by the review and merge agent.
- CI is passing.
- No unresolved required review comments remain.
- The expected head SHA is supplied to the merge operation.
- The merge method is `rebase`, unless the user explicitly asks for another method.

If any merge precondition fails, the agent must stop and report the blocker.

## Wiki Publication Rule

Repo-local `wiki/` is the authored source for GitHub Wiki pages.

When product behavior, business language, owner workflows, or durable repository truth changes, the
agent must update the relevant wiki source page in the same PR. If no wiki update is needed, the
agent must state why in the PR or final handoff.
