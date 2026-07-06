# RFC-0045: Parallel Acceptance CI Shards

## Status

Accepted

## Authority and Scope

This slice applies to GitHub Actions acceptance test execution for the CloudBake owner iOS app.

It does not change product behavior, app architecture, test coverage expectations, or local
development requirements.

## Requirements Summary

- Reduce pull request feedback time as the acceptance suite grows.
- Keep acceptance tests mandatory and meaningful.
- Run owner workflow acceptance tests by feature area in parallel.
- Preserve failure artifacts so slow or failing shards can be inspected independently.

## Design

The `acceptance-tests` GitHub Actions job uses a matrix with feature shards:

- `core-recipes-customers`
- `orders-core`
- `orders-links`
- `inventory`

Each shard runs the `CloudBakeOwnerAcceptance` scheme with explicit `-only-testing` filters for the
tests owned by that feature area. Shards use `fail-fast: false` so multiple feature failures can be
reported in the same CI run.

The workflow keeps four acceptance jobs by combining core, recipe, and customer coverage into
`core-recipes-customers`, splitting order coverage into `orders-core` and `orders-links`, and
keeping inventory as its own shard. With the unit/integration job, this respects the five-runner
macOS concurrency limit.

Each failed shard uploads a feature-specific `.xcresult` artifact:

```text
acceptance-<feature>-xcresult
```

## Non-Functional Requirements

- The split must not weaken merge gates.
- Feature shards should remain small enough for fast feedback on GitHub-hosted macOS runners.
- New acceptance tests must be added to the appropriate shard when they are introduced.
- Test names should continue to make feature ownership obvious.

## Acceptance

- The CI workflow parses as valid YAML.
- Acceptance CI runs as parallel feature-sharded jobs.
- Failed shards publish feature-specific result bundles.
- Development documentation and testing ADRs describe the sharded CI contract.
