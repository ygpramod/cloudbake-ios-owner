# Slice RFC-0116: App Store Privacy Readiness

## Status

Accepted.

## Goal

Make CloudBake's privacy behavior transparent to the owner and provide the bundle metadata required
for App Store submission.

## Scope

1. Add an app privacy manifest that declares no tracking or developer data collection.
2. Declare the approved reasons for CloudBake's use of app-only preferences, app-container file
   metadata, and disk-capacity checks.
3. Add an offline privacy policy reachable from Settings.
4. Publish the matching policy as repo-local wiki source and provide its public `main` URL for App
   Store Connect.
5. Cover policy content and Settings navigation with automated tests.
6. Declare that CloudBake does not use non-exempt encryption so App Store Connect can apply the
   correct export-compliance path to each uploaded build.

## Privacy Classification

CloudBake has no advertising, analytics, tracking, or developer-operated server. Owner data remains
local unless Cloud Backup is enabled or the owner explicitly exports a manual backup. Cloud Backup
uses the current user's private CloudKit database; Apple documents this database as user-owned,
accessible only to that user by default, and invisible in the developer portal. CloudKit data stored
solely on Apple's behalf is therefore not declared as data collected by the CloudBake developer.

The manifest declares:

1. `CA92.1` for app-only `UserDefaults` preferences.
2. `C617.1` for metadata of files in the app and CloudKit containers.
3. `E174.1` for user-observable backup eligibility based on sufficient working disk space.

## Test Plan

- Unit: policy sections and stable public policy URL.
- Acceptance: Settings opens the privacy policy.
- Build: validate the manifest is copied into the application bundle.

## Acceptance Criteria

- The built app contains `PrivacyInfo.xcprivacy` with the three audited required-reason categories.
- The manifest declares no tracking, tracking domains, or collected data types.
- Settings exposes the complete privacy policy without requiring network access.
- The policy accurately explains local storage, private CloudKit backup, device permissions,
  retention, deletion, and sharing.
- The public policy source is ready to use as the App Store Connect Privacy Policy URL after merge.
- The app bundle declares `ITSAppUsesNonExemptEncryption` as false.

## Wiki Decision

Add `wiki/Privacy-Policy.md` and link it from the wiki home page because privacy and data-retention
behavior are owner-facing and required for App Store release.
