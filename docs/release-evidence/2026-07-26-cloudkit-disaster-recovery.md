# CloudKit Disaster-Recovery Drill — 26 July 2026

This record intentionally contains no customer details, record identifiers, photo filenames,
CloudKit user identifiers, or other private bakery data.

## Release identity

- Result: PASS
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

## Local verification

On 26 July 2026, the exact Point 1 head passed:

- 189 selected backup/restore unit and integration tests, with 1 intentional CloudKit-account
  smoke-test skip and 0 failures;
- 6 targeted acceptance tests with 0 failures, covering unavailable-photo decisions, backup
  deletion failure, destructive/cellular/broken-asset restore decisions, rollback-required
  blocking, successful rollback reporting, and the manual destination picker.

## Restore phase

The installed TestFlight build retained an existing populated CloudBake database. The first restore
inspection stopped at the app's **Replace Local Data?** confirmation and selected **Cancel**.
After the owner explicitly authorized replacement, the drill repeated inspection and selected
**Replace and Restore**. CloudBake created its rollback copy, activated the downloaded snapshot,
and returned to the Home screen without an error.

Privacy-safe pre-restore expectations:

- customers: 2
- inventory items: 3
- recipes: 1
- active orders: 1
- completed orders: 4
- designs: 3
- recoverable photos reported by the manifest: 8
- custom logo: present

Restore evidence:

- full restore completed: 26 July 2026, approximately 9:25 PM SGT
- explicit replacement confirmation: completed
- restored customers: 2
- restored inventory items: 3
- restored recipes: 1
- restored active orders: 1
- restored completed orders: 4
- restored designs: 3
- restored custom logo: present and rendered
- representative inventory quantities and units: matched the pre-restore installation
- recipe linkage: restored recipe retained its inventory ingredient
- order linkage: active order retained its customer, recipe, extra ingredients, design source,
  design reference, and rendered design thumbnail
- image checks: restored design grid and linked order photo rendered; the manifest reported all
  8 photos with verified integrity
- force-quit and relaunch: passed at approximately 9:30 PM SGT
- reminder reconciliation: passed; payment-due, no-orders-today, and healthy-inventory categories
  matched the restored state
- fresh post-restore Back Up Now: completed at 9:31 PM SGT
- post-restore inspection: 9:31 PM creation time, 10.5 MB, 8 photos, integrity Verified
- current pointer freshness: resolved to the 9:31 PM post-restore generation
- unavailable-photo recovery: not exercised; all 8 manifest photos were available
- known issues: none observed during the production drill

Evidence reviewer and date are recorded in the Point 1 pull-request review.
