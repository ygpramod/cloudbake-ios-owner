# App Store and TestFlight Release Runbook

This runbook documents the CloudBake owner app release process from an accepted release candidate
through App Store Connect, TestFlight, and final App Store submission. It records the first real
release execution from July 2026, including the complications encountered and the checks that
prevent the same problems in later releases.

The runbook is operational documentation, not an Apple policy mirror. Apple can change App Store
Connect fields and review requirements. Follow the sequence here, but verify time-sensitive rules
against the linked Apple documentation before each release.

## Release Boundaries

CloudBake currently ships as:

- app name: `CloudBake`;
- Xcode scheme: `CloudBakeOwner`;
- bundle identifier: `com.cloudbake.owner`;
- Apple team identifier: `4H787CNDS2`;
- App Store Connect Apple ID: `6793108722`;
- platform: iPhone only (`TARGETED_DEVICE_FAMILY = 1`);
- CloudKit container: `iCloud.com.cloudbake.owner`;
- first version and build: `1.0 (1)`.

Do not commit signing certificates, private keys, App Store Connect credentials, reviewer phone
numbers, tester email addresses, or screenshots containing private bakery data. Reviewer and tester
contact details belong in App Store Connect only.

## First Release Evidence

The first release candidate used the following immutable evidence:

| Evidence | Value |
| --- | --- |
| Release PR | [#132: Prepare release build for App Store upload](https://github.com/ygpramod/cloudbake-ios-owner/pull/132) |
| Reviewed PR head | `f3567b2121b97eea0f24f403728ab543534b49dd` |
| Rebase-merge/main commit | `2895190744df90327e93084d0ca142d7ab31a033` |
| Version | `1.0` |
| Build | `1` |
| Archive creation | 22 July 2026 at 12:31 UTC |
| Upload completion | 22 July 2026 at 12:32 UTC |
| TestFlight state after setup | External build `Waiting for Review` |

PR #132 passed the unit/integration job and all seven acceptance shards then configured in CI:
`core-recipes`, `settings`, `orders-core`, `order-links`, `customers`, `inventory`, and `designs`.

The archive and export files were intentionally created under `/tmp`. They are transient evidence,
not source artifacts:

- `/tmp/CloudBakeOwner-RC-2895190.xcarchive`
- `/tmp/CloudBakeExportOptions.plist`
- `/tmp/CloudBakeOwnerUpload-2895190`

Later releases should write a short release-evidence record in the PR or release notes because
`/tmp` content can disappear at logout, restart, or system cleanup.

## Phase 1: Freeze the Release Candidate

### 1. Merge only a fully reviewed, green PR

Confirm that:

1. the release PR has no unresolved required review comments;
2. the exact reviewed head SHA matches the PR head;
3. unit/integration CI is green;
4. every required acceptance shard is green;
5. privacy, export-compliance, CloudKit, and owner-facing documentation changes are included;
6. the merge method follows repository rules.

For the first release, PR #132 was rebase-merged only after all eight required checks were green.

### 2. Synchronize a clean `main`

Run from the owner-app repository:

```sh
git switch main
git pull --ff-only origin main
git status --short --branch
git rev-parse HEAD
```

Expected properties:

- no modified or untracked release files;
- `main` matches `origin/main`;
- the recorded SHA is the SHA that will be archived.

Never archive an uncommitted working tree or a feature branch whose contents differ from the
reviewed commit.

### 3. Verify release configuration

Check the values before every archive:

```sh
rg -n "MARKETING_VERSION|CURRENT_PROJECT_VERSION|PRODUCT_BUNDLE_IDENTIFIER|TARGETED_DEVICE_FAMILY|DEVELOPMENT_TEAM" \
  CloudBakeOwner.xcodeproj/project.pbxproj

plutil -p CloudBakeOwner/Info.plist
plutil -p CloudBakeOwner/CloudBakeOwner.entitlements
```

The first release verified:

- `MARKETING_VERSION = 1.0`;
- `CURRENT_PROJECT_VERSION = 1`;
- `PRODUCT_BUNDLE_IDENTIFIER = com.cloudbake.owner`;
- `TARGETED_DEVICE_FAMILY = 1`;
- `DEVELOPMENT_TEAM = 4H787CNDS2`;
- `ITSAppUsesNonExemptEncryption = false`;
- the CloudKit service and `iCloud.com.cloudbake.owner` entitlement were present.

Increment `CURRENT_PROJECT_VERSION` for every replacement upload, even when
`MARKETING_VERSION` remains unchanged.

### 4. Confirm local Apple signing readiness

In Xcode:

1. open **Xcode > Settings > Accounts**;
2. confirm the Apple Developer account is signed in;
3. select the CloudBake team;
4. use **Manage Certificates** to confirm Xcode can access or create the required local signing
   certificate;
5. open the app target's **Signing & Capabilities** and confirm automatic signing resolves without
   errors;
6. confirm the iCloud/CloudKit capability uses the production app identifier and container.

A paid Apple Developer Program membership and a usable local signing identity are separate from
publishing an app record. App Store Connect membership alone does not make the Mac able to sign an
archive.

## Phase 2: Build and Inspect the Archive

### 1. Create the archive

Use a SHA-labelled path so the binary can be traced to source. This command is the reproducible
equivalent of the first archive invocation:

```sh
RELEASE_SHA="$(git rev-parse --short HEAD)"

xcodebuild archive \
  -project CloudBakeOwner.xcodeproj \
  -scheme CloudBakeOwner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "/tmp/CloudBakeOwner-RC-${RELEASE_SHA}.xcarchive" \
  -allowProvisioningUpdates
```

Require `** ARCHIVE SUCCEEDED **`. Preserve the full terminal log with the release evidence when a
future release is intended for production.

### 2. Inspect archive metadata

```sh
plutil -p "/tmp/CloudBakeOwner-RC-${RELEASE_SHA}.xcarchive/Info.plist"

codesign -d --entitlements :- \
  "/tmp/CloudBakeOwner-RC-${RELEASE_SHA}.xcarchive/Products/Applications/CloudBakeOwner.app" \
  2>/dev/null | plutil -p -
```

Confirm:

- application path and app name;
- `arm64` architecture;
- bundle ID, version, and build;
- expected team ID;
- CloudKit entitlements and container.

The first `.xcarchive` displayed an Apple Development identity and `get-task-allow = true` before
export. This did not block upload because Xcode's App Store Connect export prepared and re-signed
the distribution payload. Treat a successful distribution export/upload and App Store Connect
processing as the authoritative distribution-signing result; do not assume the raw archive's
embedded development signature is the final uploaded signature.

## Phase 3: Export and Upload

### 1. Prepare export options

The first upload used this property list:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>upload</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>4H787CNDS2</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

Save it to a temporary path such as `/tmp/CloudBakeExportOptions.plist`. Keeping
`manageAppVersionAndBuildNumber` false prevents Xcode from silently changing the repository's
reviewed version/build identity.

### 2. Upload the archive

```sh
xcodebuild -exportArchive \
  -archivePath "/tmp/CloudBakeOwner-RC-${RELEASE_SHA}.xcarchive" \
  -exportPath "/tmp/CloudBakeOwnerUpload-${RELEASE_SHA}" \
  -exportOptionsPlist /tmp/CloudBakeExportOptions.plist \
  -allowProvisioningUpdates
```

The first upload ended with:

```text
Upload succeeded. Uploaded CloudBakeOwner.
** EXPORT SUCCEEDED **
```

### 3. Wait for Apple processing

Upload success does not make the build immediately selectable. App Store Connect processes the
binary and sends an email when processing completes. Verify under **TestFlight > iOS** that the
version/build is present and has no blocking compliance warning.

If processing remains incomplete for more than 24 hours, use Apple's build-upload status guidance
and contact Apple Developer Support. Do not upload a duplicate build number while the original is
still processing.

Official references:

- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Build upload statuses](https://developer.apple.com/help/app-store-connect/reference/app-uploads/build-upload-statuses)

## Phase 4: Configure the App Store Record

The first app record used:

- app name: `CloudBake`;
- subtitle: `Bakery Orders & Inventory`;
- SKU: `cloudbake-owner-ios`;
- primary language: English (U.K.);
- primary category: Business;
- secondary category: Productivity;
- content rights: the app has the necessary rights to third-party content;
- licence: Apple's Standard License Agreement;
- age rating: 4+ with Apple's regional equivalents;
- price: free;
- availability: all 175 storefronts shown during setup;
- release: manual;
- compatibility: iPhone only; macOS “Designed for iPhone” and Apple Vision Pro compatibility were
  disabled for the initial release.

### Product-page metadata entered for version 1.0

Six iPhone screenshots were uploaded in this order:

1. `01-dashboard.jpg`
2. `02-orders.jpg`
3. `03-inventory.jpg`
4. `04-more.jpg`
5. `05-recipes.jpg`
6. `06-customers.jpg`

App Store Connect accepted the 6.9-inch set for the displayed 6.5-inch requirement. Keep the clean,
final upload files in durable release evidence for future versions; the original screenshots under
`~/Downloads` are not a reliable archive.

Promotional text:

> Run your handmade cake business from one private workspace for orders, inventory, recipes,
> customers, designs, payments, reminders, and recovery backups.

Description:

> CloudBake is a private bakery-management app designed for handmade cake businesses.
>
> Keep your day-to-day work organised in one place:
>
> - Plan active and completed orders with due dates, fulfilment details, status, pricing, payments,
>   checklists, photos, recipes, customers, and cake designs.
> - Track inventory quantities, purchase costs, expiry dates, projected order demand, adjustments,
>   usage history, and low-stock warnings.
> - Build reusable recipes from inventory ingredients and estimate ingredient costs while preparing
>   a quote.
> - Save customer contact details, preferences, allergies, important dates, and order history.
> - Organise cake designs and reference photos with searchable tags.
> - Import inventory from purchase bills or on-device voice recognition, and exchange inventory and
>   recipe data using CSV files.
> - Receive local reminders for upcoming orders, payments, inventory, and backups.
> - Create complete manual backups and optionally keep a private recovery backup in your own iCloud
>   account.
>
> CloudBake is local-first. Your bakery records remain in the app's private storage unless you
> choose to export a backup or enable private iCloud recovery backup. CloudBake contains no
> advertising, analytics, or tracking SDKs.

Keywords:

```text
bakery,cake,orders,inventory,recipes,customers,pricing,payments,reminders,designs
```

Other version metadata:

- version: `1.0`;
- copyright: `2026 Pramod Yellur Gururaj`;
- marketing URL: blank;
- routing coverage file: not applicable;
- Game Center: disabled;
- in-app purchases and subscriptions: none;
- release choice: manually release this version.

The support URL was temporarily set to the public privacy-policy source:

```text
https://github.com/ygpramod/cloudbake-ios-owner/blob/main/wiki/Privacy-Policy.md
```

This is accepted metadata but is not ideal support navigation. Before final App Store submission,
prefer a dedicated, public support/help page and keep the privacy policy as the privacy URL.

### Privacy and export compliance

The App Privacy declaration was published as:

- no tracking;
- no data collected by the developer;
- privacy policy URL pointing to `wiki/Privacy-Policy.md` on `main`.

This matches RFC-0116: CloudBake is local-first, has no advertising or analytics SDK, and optional
CloudKit backup uses the owner's private iCloud database. The binary declares
`ITSAppUsesNonExemptEncryption` as false, so CloudBake does not require export documentation for
non-exempt encryption under the current implementation.

Do not copy this privacy answer to a later version without re-auditing dependencies, network calls,
CloudKit behavior, analytics, tracking, and exported data.

### Digital Services Act remains an account-owner decision

Apple requires a DSA trader-status declaration even when the app is not distributed in the EU.
CloudBake's declaration is not complete at the time of this record. The account holder must decide
whether the app is distributed in connection with a trade, business, craft, or profession. This is
a legal self-assessment; an engineer or automated agent must not choose it on the owner's behalf.

If trader status is selected, Apple requires verified public contact information and may require
supporting documentation. Do not use a private contact value without understanding that Apple can
display it on the EU App Store product page.

Official reference:

- [EU Digital Services Act trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)

## Phase 5: Configure TestFlight

### 1. Complete Test Information

Under **TestFlight > Test Information**, the first release saved:

Beta description:

> CloudBake is a private bakery management app for orders, inventory, recipes, customers, designs,
> pricing, payments, reminders, backups, and optional private iCloud recovery.

Other fields:

- feedback email: `pramodyg@yahoo.in`;
- privacy policy URL: the public `wiki/Privacy-Policy.md` URL;
- reviewer first and last name: stored in App Store Connect;
- reviewer phone: stored in App Store Connect, never in source control;
- reviewer email: `pramodyg@yahoo.in`;
- sign-in required: off.

Review notes:

> CloudBake does not require an account or backend login. All primary bakery workflows work
> locally. Optional Cloud Backup uses the private CloudKit database of the iCloud account signed in
> on the test device. The reviewer can use the app without enabling Cloud Backup. Photo library,
> camera, Contacts, microphone, speech recognition, and notification permissions are requested only
> when the corresponding feature is chosen. Voice inventory recognition is performed on device.

The review phone is not merely informational. Apple may call if App Review needs clarification, so
provide a monitored number.

### 2. Create the internal testing group first

Apple requires an internal group before the first external group can be created.

The first release created:

- group: `CloudBake Internal Testers`;
- automatic distribution: enabled;
- build: `1.0 (1)` included automatically;
- tester count: one App Store Connect user;
- initial tester status: `Invited`.

Internal testers are App Store Connect users and can test without external Beta App Review. Do not
add a family tester as an App Store Connect user merely to bypass external review; that grants
persistent console access and is broader than TestFlight access.

### 3. Create the external testing group

The first release created:

- group: `CloudBake Family Testers`;
- tester count: two;
- public link: not created;
- tester identities: stored only in App Store Connect.

When testers were added before a build, their status correctly displayed `No Builds Available`.
Adding tester records is separate from attaching an approved or reviewable build.

### 4. Attach the build and submit Beta App Review

In the external group's **Builds** tab:

1. choose **Add Build to Group**;
2. select iOS, version `1.0`, build `1`;
3. continue to Test Information;
4. turn **Sign-in required** off because CloudBake has no login;
5. enter the “What to Test” text;
6. leave **Automatically notify testers** enabled;
7. click **Submit for Review**.

“What to Test” text used:

> Please test the main bakery workflows: creating and updating orders, customers, inventory,
> recipes and designs; recording payments; importing and exporting data; reminders; manual backup
> and restore; and optional private iCloud backup. Please report any confusing behavior, failed
> actions, missing data, or visual issues.

The verified result was:

- external group: two testers, one build;
- build: `1.0 (1)`;
- status: `Waiting for Review`;
- automatic tester notification: enabled.

The first external build requires Beta App Review. Later builds of the same version may not require
a full review, but never assume approval is automatic. TestFlight Beta App Review is separate from
the final App Store review.

Official reference:

- [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)

### 5. Understand the TestFlight window

Each uploaded build can be tested for 90 days from its upload date. Version `1.0 (1)` was uploaded
on 22 July 2026 and therefore expires around 20 October 2026. The app can remain in TestFlight over
a longer period by uploading a new, higher build number before the current build expires and moving
tester groups to that build.

Official reference:

- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)

## Phase 6: Release Smoke Test

After internal distribution, install TestFlight from the App Store, accept the invitation with the
invited Apple Account, and install the latest CloudBake build.

Perform at least this release smoke test on a real iPhone:

1. launch and complete or skip the first-run introduction;
2. create and edit a customer;
3. create inventory, adjust stock, and inspect history;
4. create a recipe using inventory;
5. create an order, link customer/recipe/design, change status, and record payment;
6. verify upcoming orders and reminders;
7. add a design/reference photo and reopen it;
8. export and import inventory and recipe CSV files through the Files picker;
9. create a manual full backup, choose a destination, and verify the file exists;
10. exercise manual restore only with disposable test data;
11. enable private Cloud Backup on a test iCloud account, run **Back Up Now**, and confirm status;
12. verify Wi-Fi/cellular confirmation behavior;
13. force-quit and relaunch to verify persistence;
14. submit a TestFlight feedback report for any failure or confusing behavior.

For any release-blocking defect:

1. fix through a focused branch and PR;
2. review and run required CI;
3. increment the build number;
4. archive the new exact `main` SHA;
5. upload and move tester groups to the new build;
6. never replace evidence for the previous build as if it were the same binary.

## Phase 7: Final App Store Submission

At the time this runbook was written, final App Store submission had not been completed. The
version page still showed **Prepare for Submission** and required these actions:

1. wait for and evaluate TestFlight feedback;
2. complete the DSA account/app declaration;
3. attach the correct processed build under the version's **Build** section;
4. turn **Sign-in required** off in App Review Information;
5. enter reviewer contact information without committing private contact data;
6. add the same no-login, local-first, CloudKit, and permission context used for Beta App Review;
7. replace the temporary support URL with a dedicated public support page if available;
8. recheck screenshots, description, keywords, age rating, category, price, storefronts, privacy,
   export compliance, and manual release;
9. click **Add for Review**;
10. open the draft submission and click **Submit for Review**.

`Add for Review` does not send the binary to Apple by itself; it adds the version to a draft
submission. The separate **Submit for Review** action sends the completed submission.

The first release intentionally selected manual release. After approval, the owner must still
choose when to release the version on the App Store.

Official reference:

- [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)

## Complications Observed and Recovery Guidance

### App Store Connect session and browser state

The in-app browser session expired and the expected browser view was no longer available. The work
continued in a signed-in Safari session. This did not change App Store Connect data, but it made UI
automation less predictable.

Recovery:

- use one signed-in browser tab for App Store Connect;
- verify the current URL, app, version, and group before editing;
- refresh accessibility/UI state after every navigation;
- do not infer success from a click—verify the resulting saved status.

### Apple processing delay after successful upload

The upload command succeeded before the build appeared as selectable. This is expected.

Recovery:

- wait for processing and the Apple email;
- inspect TestFlight build status;
- avoid unnecessary re-uploads;
- investigate only if processing remains stuck beyond Apple's published window.

### Review contact information blocked external setup

Beta review contact fields could not be saved without a phone number. The same contact requirement
appeared again while attaching the first external build.

Recovery:

- collect the monitored reviewer name, phone, and email before starting external setup;
- keep those values in App Store Connect, not repository documentation;
- explain that Apple may use the number to contact the reviewer.

### Sign-in was enabled by default

The external build flow and App Store version page displayed **Sign-in required** as enabled even
though CloudBake has no account system. Leaving it enabled disables continuation or creates invalid
username/password requirements.

Recovery:

- explicitly turn the checkbox off in every Beta App Review and App Review form;
- verify the saved value after closing and reopening the page.

### External testers existed before a build was available

The external testers were successfully added but showed `No Builds Available` until build `1` was
attached and submitted for Beta App Review.

Recovery:

- treat tester membership and build distribution as separate steps;
- verify the group header reports both tester and build counts;
- verify the build status is `Waiting for Review`, `Testing`, or another understood state.

### Safari Hide My Email/autofill interrupted tester entry

Safari displayed a Hide My Email suggestion while entering tester email addresses. Keyboard focus
could move to browser chrome instead of the intended table row.

Recovery:

- dismiss the suggestion with Escape;
- click the exact email field again;
- verify both complete addresses in the table before clicking Add;
- never include tester addresses in screenshots or committed logs.

### Long automated text entry could still be in progress

While entering review notes through browser automation, an immediate UI snapshot displayed only a
prefix even though typing later completed. Appending based on that premature snapshot temporarily
duplicated part of the notes.

Recovery:

- wait for long text entry to finish;
- re-read the complete field before saving;
- if duplicated, select all and replace the entire field once;
- visually verify the final saved notes and remaining-character count.

### TestFlight and App Store review are distinct

Submitting the external build produced `Waiting for Review` for Beta App Review. It did not attach
the build to version 1.0 or submit the app to the public App Store.

Recovery:

- track Beta App Review and App Store submission as separate checklist sections;
- do not describe TestFlight approval as App Store approval;
- repeat App Review contact and no-login information on the public version page.

### DSA status cannot be chosen by engineering

The App Information page still shows DSA setup as incomplete. The decision affects legal status and
potential public contact details.

Recovery:

- require the account holder's explicit trader/non-trader determination;
- consult legal advice if uncertain;
- verify any public contact information before confirmation.

### Temporary evidence and support URL are not durable

The archive, export plist, and upload directory live under `/tmp`, while the support URL currently
points to the privacy policy.

Recovery:

- store release evidence or checksums in a durable, access-controlled location;
- never store private signing material with that evidence;
- create a dedicated support/help wiki page before final submission.

## Repeat-Release Checklist

Use this abbreviated checklist only after reading the detailed sections above.

- [ ] Release PR approved; exact head and required CI green.
- [ ] Clean, synchronized `main`; release SHA recorded.
- [ ] Version/build values correct; build number incremented.
- [ ] Privacy, permissions, export compliance, and CloudKit entitlements re-audited.
- [ ] Local Apple account and signing certificates valid.
- [ ] CloudKit production schema compatible with the build.
- [ ] SHA-labelled archive succeeds and metadata is inspected.
- [ ] App Store Connect export/upload succeeds.
- [ ] Apple processing completes without blocking warnings.
- [ ] Product metadata, screenshots, support, privacy, pricing, and availability reviewed.
- [ ] Internal TestFlight smoke test passes on real iPhones.
- [ ] External group receives the intended build; review/test status verified.
- [ ] 90-day TestFlight expiry recorded.
- [ ] DSA declaration completed by the account holder.
- [ ] Correct build attached to the App Store version.
- [ ] App Review sign-in disabled and contact/review notes completed.
- [ ] Version added to a draft submission, then explicitly submitted for review.
- [ ] Manual release performed only after approval and owner confirmation.
- [ ] Repo-local wiki source published to the GitHub Wiki after merge.

## Release Evidence Template

Copy this into the release PR, release issue, or access-controlled release record:

```text
Version/build:
Release PR:
Reviewed head SHA:
Merged main SHA:
CI checks and result:
Xcode version:
macOS version:
Archive path:
Archive result:
Upload timestamp/result:
App Store Connect processing result:
TestFlight internal result:
TestFlight external status:
Real devices/iOS versions tested:
CloudKit production schema verification:
Privacy/export-compliance audit:
Known issues:
DSA status confirmed by account holder:
App Store submission status:
Release timestamp:
Wiki publication evidence:
```
