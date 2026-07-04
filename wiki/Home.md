# CloudBake Owner Wiki

This directory is the authored source for the CloudBake owner app GitHub Wiki.

Use these pages for owner-facing, operator-facing, and cross-repository guidance that should be easy
to browse outside the code tree. Keep durable engineering decisions in `docs/adr/`, implementation
proposals in `docs/rfc/slices/`, and repo-local quality rules in `docs/engineering-guardrails.md`.

## Pages

1. [Owner App Current State](Owner-App-Current-State.md)

## Source Of Truth

Repo-local `wiki/` is the source of truth. The GitHub Wiki is the publication target after changes
are merged to `main`.

For each future slice, update wiki source when the slice changes the current app state,
owner-facing behavior, operator-facing workflow, cross-repository guidance, or durable product
truth. If no wiki update is needed, record that decision in the PR or final handoff.
