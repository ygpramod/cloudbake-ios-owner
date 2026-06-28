# Development Workflow

CloudBake owner app changes must go through a branch and pull request before merging into `main`.

## Branches

- `main` is the protected integration branch.
- Feature branches should use the `codex/` prefix unless a different prefix is explicitly requested.
- Each branch should map to one focused RFC slice, ADR update, bug fix, or documentation change.

## Pull Requests

Every pull request should include:

- A short summary.
- Links to related RFCs or ADRs.
- A test plan.
- Notes for any behavior, migration, or follow-up risk.

Implementation pull requests must include relevant unit, integration, and acceptance test evidence.

## Main Branch Protection

`main` should be protected in GitHub with these rules:

- Require a pull request before merging.
- Require at least one approval.
- Require review from code owners.
- Require status checks to pass before merging once CI exists.
- Block force pushes.
- Block branch deletion.
