# ADR-0009: Establish Engineering Guardrails

## Status

Accepted

## Context

The CloudBake owner app is one implementation repository within the larger CloudBake system. It
needs local engineering expectations that match the foundation guardrails while being specific
enough for SwiftUI, supported iPhone layouts, accessibility, testing, privacy, and future sync/API
behavior.

## Decision

Adopt repo-local engineering guardrails for the owner app.

The owner app guardrails inherit from the CloudBake foundation guardrails and add iOS-specific expectations for SwiftUI view structure, state ownership, navigation, accessibility, previews, UI testing, privacy, and offline-first boundaries.

## Alternatives Considered

- Rely only on the foundation repo guardrails: too easy for app contributors to miss local expectations.
- Keep guardrails informal in PR review: too easy to drift as the app grows.
- Wait until more features exist: cheaper now, more expensive later.

## Consequences

Owner app pull requests will have a clearer quality bar. Some implementation work may take longer, but SwiftUI architecture, accessibility, testing, and privacy concerns should be caught earlier.

## Related

- Foundation guardrails: `ygpramod/CloudBake` `docs/engineering-guardrails.md`
- Local guardrails: `docs/engineering-guardrails.md`
- ADR: `docs/adr/0001-owner-app-swiftui.md`
- ADR: `docs/adr/0007-testing-strategy.md`
- ADR: `docs/adr/0008-github-actions-ci-cd.md`
