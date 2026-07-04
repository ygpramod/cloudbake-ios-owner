# Engineering Guardrails

These guardrails apply to the CloudBake owner app repository. They inherit from the CloudBake foundation guardrails and add iOS-specific expectations for SwiftUI development.

## Principles

- Correctness beats speed for inventory, orders, pricing, reminders, customer data, and recipes.
- Business rules should be explicit, testable, and kept out of UI glue code.
- Each slice should be small enough to review, test, and revert.
- Private owner data must stay private by default.
- Observability should be designed in before production complexity appears.

## Definition of Done

A slice is done only when:

- Scope matches an approved RFC slice or documented issue.
- Relevant ADRs are followed or a new ADR explains the deviation.
- Unit, integration, and acceptance tests are added or explicitly marked not applicable.
- CI passes.
- Code review has no unresolved required comments.
- User-facing or operational behavior is documented where needed.
- Security, privacy, and data migration impacts are considered.

## SwiftUI Code Quality

- SwiftUI views should stay thin and focus on rendering, layout, and user interaction.
- Domain logic should live outside views in domain services, application services, or view models as appropriate.
- View models should own presentation state and call domain/repository boundaries; they should not contain persistence-specific code.
- Avoid placing business rules in button handlers, computed view properties, or navigation glue.
- Use clear state ownership: prefer local `@State` for view-only state, observable models for screen state, and injected dependencies for services.
- Prefer simple, explicit code over clever abstractions.
- Avoid force unwraps, unchecked casts, broad exception swallowing, and silent failure paths.
- Do not add dependencies without a clear reason and review.

## Architecture Boundaries

- UI may depend on presentation models, but not directly on persistence details.
- Domain services should be testable without network, database, or UI runtime.
- Local persistence must be behind repository interfaces.
- Network or sync behavior must be behind integration boundaries and must not be required for offline owner workflows.
- Cross-repo communication should happen through versioned API contracts.

## Navigation and Accessibility

- Navigation should be explicit and testable.
- Accessibility identifiers are required for acceptance-testable navigation and critical workflows.
- Support Dynamic Type, VoiceOver-friendly labels, and sufficient contrast for critical information.
- iPhone-first layouts must not block iPad adaptation.
- Avoid fixed-size layouts that break on smaller iPhones, larger iPads, split view, or large text settings.
- Use previews for important screens and states when practical, including empty, loading, error, and populated states.

## Testing Guardrails

- TDD should be used where practical, especially for domain rules and persistence behavior.
- Unit tests cover pure logic and edge cases.
- Integration tests cover persistence, migrations, repositories, and framework wiring.
- XCUITest acceptance tests cover critical navigation and owner workflows as they are implemented.
- Tests should be deterministic and not depend on wall-clock time unless time is injected.
- Bugs should usually be fixed by first adding a failing test.
- Snapshot tests may be introduced later if visual regressions become hard to review manually.

## Observability

- Mobile app errors should be handled with user-safe messages and diagnostic context suitable for future crash reporting.
- API clients should preserve and forward backend correlation IDs when retrying or chaining calls.
- Correlation IDs are diagnostic metadata, not authentication or authorization credentials.
- Important future sync operations should be observable without exposing private owner data.

## Security and Privacy

- Treat customer details, allergies, preferences, private notes, costs, recipes, supplier data, and photos as private.
- Never log secrets, access tokens, private notes, full customer contact details, sensitive recipe/cost data, photos, allergies, or preferences.
- Public/customer-facing data must be explicitly published, not inferred from private owner data.
- Use least privilege for app permissions, CI credentials, and future service tokens.
- Secrets must not be committed to the repository.
- Dependency updates should be reviewed for security impact.

## Data and Migration Safety

- Database schema changes must use migrations once local persistence is introduced.
- Migrations should be forward-safe and tested from a fresh database.
- Destructive migrations require an RFC or ADR and a backup/rollback plan.
- Inventory and order state transitions must be auditable once implemented.
- Sync-related fields should be designed before sync behavior is implemented.

## Pull Request Guardrails

- Every PR should link the relevant RFC, ADR, or issue.
- PRs should be small and focused.
- PR descriptions must include a test plan.
- Documentation-only PRs may mark tests as not applicable.
- Implementation PRs must not skip tests without an explanation.
- CI failures must be fixed or explicitly justified before merge.
- `main` should be protected and should not accept direct commits.

## Commit Discipline

- Each commit should do one thing: one behavior, one refactor, one documentation update, or one test
  correction.
- Keep commits as small as practical while preserving a buildable and reviewable state.
- Split independent behavior changes into separate commits, even when they are delivered in the same
  PR. For example, expiry alerts and expiry editing should be separate commits.
- Commit messages must describe the behavior or repository truth that changed.
- Avoid vague messages such as `fix review comments`, `changes`, `updates`, or `misc`.
- Review-fix commits should name the actual change, such as `Preserve batch quantities when editing
  expiry`.
- Do not mix unrelated cleanup with feature behavior unless the cleanup is required for that behavior;
  when cleanup is useful but independent, commit it separately.

## Review And Merge Agent Guardrails

- Automated reviewer agents must follow `AGENTS.md`.
- Review agents must inspect the PR diff, tests, docs, CI status, and related RFC or ADR before approving.
- Review agents must request changes for blocking correctness, migration, privacy, testing, accessibility, documentation, or architecture issues.
- Review agents may approve only when no blocking findings remain and CI is green, unless the user explicitly accepts a documented CI exception.
- Merge agents must use rebase merge by default.
- Merge agents must pass the expected head SHA to the merge operation so moved PR heads are not merged accidentally.
- Merge agents must stop instead of merging when CI is failing, required review comments are unresolved, or the reviewed head SHA no longer matches.

## Evolution

These guardrails should evolve through ADRs. When a rule becomes too strict, too vague, or too weak, update it intentionally rather than bypassing it silently.
