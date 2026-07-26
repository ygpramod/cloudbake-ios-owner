# CloudBake Privacy Policy

Effective 21 July 2026.

CloudBake is a private, local-first bakery management app. This policy explains what information
CloudBake stores, where it is stored, and the controls available to you.

## Data CloudBake Stores

CloudBake stores the bakery information you enter, including inventory, recipes, designs, photos,
customers, orders, pricing, payments, reminders, and app preferences. This information is stored
locally in CloudBake's private app storage on your iPhone.

CloudBake does not include advertising, analytics, or tracking SDKs. The CloudBake developer does
not operate a server that receives your bakery data.

## Cloud Backup

When Cloud Backup is enabled, CloudBake stores one complete recovery backup in the private CloudKit
database belonging to the iCloud account signed in on the iPhone. Apple states that private CloudKit
data is accessible only to the current user by default and is not visible in the developer portal.
Private CloudKit data counts against the user's iCloud storage allowance.

You can disable Cloud Backup or permanently delete its stored backup from CloudBake Settings. Local
data remains on the iPhone when the cloud backup is deleted.

If a linked Photos-library image is no longer available, CloudBake asks before creating a recovery
backup without it or removing its broken CloudBake reference. An omission approval is stored locally
as an opaque digest; the raw Photos identifier, customer information, and original filename are not
uploaded as omission metadata. Removing a broken reference never deletes an item from the Photos
library. Cancelling or failing a replacement backup leaves the latest successful cloud backup
unchanged.

## Device Access

CloudBake accesses protected iPhone resources only for features you choose to use and after iOS
permission is granted:

- Photos and camera access save bakery and reference images in the iPhone Photos library and let
  CloudBake retain their app references. The custom in-app logo uses CloudBake-managed storage.
- Contacts access imports a contact you select into a customer draft.
- Microphone and speech recognition create inventory drafts using on-device recognition. CloudBake
  does not retain microphone audio.
- Notifications provide local order, inventory, and backup reminders.

Original Photos-library items remain under your control after CloudBake creates its working copy.

## Retention and Deletion

Local records remain until you delete them or remove CloudBake. Deleting the app removes its local
app storage but does not delete original Photos-library items or manual backup files exported to a
location you selected.

Delete the Cloud Backup from Settings before removing the app if you also want its recovery copy
removed from iCloud. Manual backup files remain until you delete them from their exported location.

## Sharing

CloudBake does not sell personal information and does not share bakery information with advertisers,
data brokers, or analytics providers. Information is sent to Apple only when you use Apple services
such as private CloudKit backup or protected device features governed by Apple's permissions and
privacy terms.

## Privacy Questions

For privacy or support questions, email [pramodyg@yahoo.in](mailto:pramodyg@yahoo.in). Do not include
customer details, recipes, photos, or other private bakery information unless needed to resolve your
request.
