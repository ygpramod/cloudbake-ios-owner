# Slice RFC-0071: Form Screen Look And Feel

## Authority And Scope

This slice applies the CloudBake visual language to owner-facing form screens where the owner
creates, edits, imports, or corrects app data.

In scope:

1. shared form-screen styling primitive,
2. inventory item, stock adjustment, stock usage, and batch edit forms,
3. recipe, recipe ingredient, and recipe import forms,
4. customer add/edit forms,
5. order add/edit forms,
6. order checklist edit, photo caption, and design-promotion forms,
7. purchase bill import form.

Out of scope:

1. changing form field behavior,
2. changing validation rules,
3. replacing every native control with a custom control,
4. redesigning selection screens,
5. dark mode support.

## Requirements Summary

Form screens should feel consistent with CloudBake second-level and detail screens while preserving
the native iOS form affordances that keep data entry reliable.

Requirements:

1. use the warm CloudBake screen background behind forms,
2. preserve native form layout, keyboard behavior, pickers, date pickers, and toolbar save/cancel
   actions,
3. use the CloudBake pink tint for owner actions and controls,
4. keep existing accessibility identifiers for acceptance-tested workflows,
5. keep the change visual-only unless a specific workflow bug is found.

## Implementation Notes

The slice introduces `cloudBakeFormScreenStyle()` in `CloudBakeScreenStyle.swift`.

The modifier:

1. hides the native scroll background,
2. applies `CloudBakeScreenBackground`,
3. applies the CloudBake pink tint,
4. keeps existing navigation titles and toolbar actions intact.

This is intentionally lighter than the detail-screen rewrite. Forms still use native `Form`,
`Section`, `TextField`, `Picker`, and `DatePicker` controls so owner data entry remains predictable.

## Test Strategy

Run:

1. `xcodebuild build -project CloudBakeOwner.xcodeproj -scheme CloudBakeOwner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
2. targeted acceptance tests that open and save representative inventory, order, customer, and
   recipe forms.

## Non-Functional Requirements

1. Preserve form accessibility identifiers.
2. Avoid custom controls for standard data-entry behavior.
3. Keep the shared styling primitive small and readable.
4. Do not introduce business logic into SwiftUI styling.
5. Keep form behavior compatible with native iOS expectations on supported iPhones.

## Open Questions

1. Whether selection screens should receive a separate CloudBake visual treatment.
2. Whether larger import forms should later move from native `Form` to custom card sections if the
   native layout proves too visually constrained.
