# App Store Release

CloudBake releases move through three separate gates:

1. a reviewed and fully green release candidate on `main`;
2. TestFlight distribution and real-iPhone validation;
3. a separate public App Store submission and manual release.

TestFlight approval is not App Store approval. An external TestFlight build may require Beta App
Review, and every uploaded build expires for testers after 90 days. A new build number starts a new
testing window.

The complete operator runbook lives in the repository at
[`docs/app-store-release-runbook.md`](https://github.com/ygpramod/cloudbake-ios-owner/blob/main/docs/app-store-release-runbook.md).
It includes:

- release-candidate evidence and CI gates;
- Apple signing prerequisites;
- reproducible archive and upload commands;
- App Store Connect product, privacy, pricing, and release settings;
- internal and external TestFlight groups;
- Beta App Review and App Store Review information;
- the real-device smoke-test checklist;
- complications and recovery guidance from the first release;
- the final submission checklist and release-evidence template.

## Owner Decisions

The Apple account holder must make or confirm decisions that engineering cannot safely infer:

- EU Digital Services Act trader or non-trader status;
- the public contact details Apple may display for a trader;
- the monitored private contact details Apple App Review may use;
- whether the tested version is ready for public submission;
- when an approved manually released version should become public.

Private reviewer phone numbers, tester email addresses, certificates, and credentials must remain in
App Store Connect or another access-controlled system and must not be committed to this repository.

## Current First-Release State

Version `1.0 (1)` was uploaded on 22 July 2026. The first external TestFlight group has two testers
and the build was submitted for Beta App Review with automatic tester notification enabled. At the
time this page was authored, its status was **Waiting for Review** and final App Store submission had
not yet occurred.
