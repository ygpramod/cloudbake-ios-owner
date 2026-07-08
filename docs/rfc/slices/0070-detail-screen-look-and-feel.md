# Slice RFC-0070: Detail Screen Look And Feel

## Authority And Scope

This slice applies the CloudBake visual language to owner-facing detail screens and centered action
popups.

In scope:

1. shared detail-screen styling primitives,
2. order detail styling,
3. order centered popup styling,
4. inventory item, stock history, and archived inventory detail styling,
5. recipe detail styling,
6. customer detail styling,
7. acceptance-test selector updates required by the custom detail chrome.

Out of scope:

1. changing domain behavior,
2. changing form layouts,
3. redesigning selection screens,
4. dark mode support.

## Requirements Summary

Detail screens should feel consistent with the CloudBake home and second-level screens:

1. warm light background,
2. compact detail controls without repeating the detail title in a header,
3. hero summary cards,
4. titled detail sections,
5. white rounded cards for key-value information,
6. visible row actions instead of hidden swipe-only actions inside custom scroll views,
7. centered confirmation popups for owner actions.

## Implementation Notes

The slice introduces reusable detail UI primitives in `CloudBakeScreenStyle.swift`:

1. `CloudBakeDetailScaffold`,
2. `CloudBakeDetailAction`,
3. `CloudBakeHeroCard`,
4. `CloudBakeDetailCard`,
5. `CloudBakeDetailRow`,
6. `CloudBakeDetailDivider`.

Order detail now uses the same detail scaffold for:

1. hero order summary,
2. order overview,
3. customer, recipe, design, fulfillment, notes, payment, checklist, reminders, and photos.

Inventory detail now uses card-based sections for item attributes and stock batches. Adjust, Use,
and History are visible detail action chips below the hero card.

Recipe detail now uses card-based notes and ingredient rows. Ingredient deletion is a visible row
action.

Customer detail now uses card-based contact, important date, preference, and linked order sections.

Centered popups now use the CloudBake modal treatment with dimmed backdrop, icon, title, subtitle,
option card, and pink cancel button. Order status and payment actions, customer add-mode choice,
and inventory archive confirmation use the shared treatment.

## Test Strategy

Run:

1. `xcodebuild build -project CloudBakeOwner.xcodeproj -scheme CloudBakeOwner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
2. `xcodebuild test -project CloudBakeOwner.xcodeproj -scheme CloudBakeOwnerUnitIntegration -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
3. targeted acceptance tests for affected order, inventory, recipe, and customer detail flows.

Acceptance tests that previously asserted native detail navigation bars should assert stable custom
detail content or controls instead.

## Non-Functional Requirements

1. Keep detail views readable and card sections small.
2. Keep business behavior outside SwiftUI styling helpers.
3. Keep existing accessibility identifiers where workflows depend on them.
4. Avoid hidden swipe-only actions inside custom scroll-view cards.
5. Preserve iPad split-view detail behavior by hiding the dismiss control when the detail pane is
   not presented as a sheet.

## Open Questions

1. Whether selection screens should receive the same custom detail-style chrome in a later slice.
2. Form screens now receive a separate native-form CloudBake style in Slice RFC-0071.
