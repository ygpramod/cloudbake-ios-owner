# CloudKit Disaster-Recovery Drill — 26 July 2026

This record intentionally contains no customer details, record identifiers, photo filenames,
CloudKit user identifiers, or other private bakery data.

## Release identity

- Result: restore phase pending explicit approval to replace the populated installation
- Time zone: Asia/Singapore
- Git SHA represented by the binary: `1d7f4ab`
- Marketing version/build: `1.0 (3)`
- Distribution source: TestFlight
- CloudKit environment: Production
- Device: iPhone 16 Pro Max, iOS 26.5.2
- Xcode: 26.6 (17F113)

The subsequent branch commits are documentation-only and do not change the tested binary.

## Preconditions

- Signed entitlement: `iCloud.com.cloudbake.owner`
- Production schema verified in CloudKit Console: yes
- Production record types:
  - `CBBackupFile`, 13 total fields
  - `CBBackupGeneration`, 15 total fields
  - `CBBackupPointer`, 8 total fields
- Production schema promotion: 26 July 2026

## Publication and inspection

- Back Up Now started: 26 July 2026, approximately 9:10 PM SGT
- Back Up Now completed: 26 July 2026, 9:11 PM SGT
- Settings result: Up to Date
- Settings estimated upload size: 10.5 MB
- Restore inspection creation time: 26 July 2026, 9:10 PM SGT
- Restore inspection payload size: 10.5 MB
- Restore inspection photo count: 8
- Restore inspection integrity: Verified
- Compatibility: accepted by Build 3; replacement confirmation was presented
- Current pointer freshness: restore inspection resolved to the manifest created within the
  recorded backup-attempt window
- Previous local data: unchanged after inspection was cancelled

## Restore phase

The installed TestFlight build retained an existing populated CloudBake database. The drill stopped
at the app's **Replace Local Data?** confirmation and selected **Cancel**. A full restore must not
continue until the owner explicitly authorizes replacing this installation or provides a clean
disposable device/account.

Still required:

1. capture privacy-safe expected counts and representative link/value categories;
2. explicitly confirm **Replace and Restore**;
3. verify restored counts, representative values and links, eight recoverable photos, and the
   custom logo;
4. force-quit and relaunch;
5. verify reminder reconciliation;
6. publish a fresh post-restore backup;
7. record the final result and reviewer.
