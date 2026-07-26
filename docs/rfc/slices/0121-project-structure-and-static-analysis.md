# Slice RFC-0121: Project Structure And Static Analysis

## Status

Implemented in the owner app.

## Goal

Reduce the largest owner-app and acceptance-test files without changing product behavior, make
feature workflows easier to review in isolation, and add a deterministic formatting and static
analysis gate to pull-request CI.

This numbered improvement point ships through one reviewed pull request. Each independent
reorganization remains a separate, buildable commit.

## Requirements

1. Split the shared UI foundation by responsibility while preserving the existing CloudBake visual
   API and rendering behavior.
2. Split the broad acceptance suite into feature-focused files while preserving test names, shard
   registration, launch configuration, and shared journey helpers.
3. Extract order view-model behavior one workflow at a time. Keep UI state and orchestration in the
   view model while moving workflow rules, persistence coordination, and error mapping behind
   focused collaborators.
4. Extract inventory view-model behavior one workflow at a time, beginning with the duplicated
   purchase-bill and voice-draft persistence workflow.
5. Do not move business rules into SwiftUI views, expose persistence details to views, or create a
   generic framework around feature-specific behavior.
6. Preserve public behavior, accessibility identifiers, database schema, migrations, and owner
   data.
7. Add repository-owned formatting configuration and a CI check that uses the Swift toolchain
   already supplied by Xcode.
8. Static analysis must be deterministic, must not download an unpinned executable during CI, and
   must provide actionable file-and-line output.
9. Keep each extracted file focused enough that an engineer can understand and test its workflow
   without reading the entire screen implementation.

## Implementation Order

1. Shared UI primitives: theme, scaffolds, cards and fields, actions, and app chrome.
2. Acceptance journeys: app/settings, orders, and designs, retaining the existing dedicated
   customer, inventory, and recipe suites.
3. Order workflows: payments, checklist, and photo/design handling.
4. Inventory workflows: imported-draft planning and persistence shared by purchase-bill and voice
   entry.
5. Formatting/static-analysis configuration, local verification, and CI enforcement.

## Validation

1. The owner-app target builds after every structural commit.
2. Existing order and inventory view-model unit tests remain green after each workflow extraction.
3. Acceptance tests keep the same XCTest selectors and remain registered in their existing CI
   shards.
4. Targeted owner journeys remain green after the acceptance-suite split.
5. The formatter/static-analysis command passes locally and in CI.
6. `git diff --check` remains clean and the Xcode project contains every extracted source file in
   exactly one intended target.

## Risks And Controls

1. Structural moves can accidentally change access control. Prefer focused collaborators with
   explicit inputs and results over widening mutable view-model state.
2. Test-file moves can silently remove tests from a target. Verify Xcode target membership and run
   representative selectors from every moved suite.
3. Formatter adoption can create an unreadable whole-repository rewrite. Establish configuration,
   format only files changed by this slice, and enforce the same configuration in CI.
4. Workflow extraction can hide behavior changes inside refactoring. Preserve existing tests first,
   add focused collaborator coverage where rules move, and keep behavior changes out of this slice.

## Wiki Decision

No wiki change is required. This slice changes source organization, test organization, and CI
quality gates only; it does not change an owner-visible workflow or product capability.
