# Owner UI and Accessibility Conventions

This document records the reusable UI and accessibility conventions established by the Owner App
Experience Refresh slices. It applies to new or refreshed CloudBake owner iPhone screens.

## Shared UI

- Use `CloudBakeScreenScaffold` for top-level and second-level app sections.
- Use `CloudBakeDetailScaffold`, `CloudBakeDetailCard`, `CloudBakeDetailRow`, and
  `CloudBakeDetailDivider` for detail screens and settings rows.
- Use `cloudBakeFormScreenStyle()` for forms so keyboard, navigation, and grouped form behavior
  stays consistent.
- Prefer shared theme tokens from `CloudBakeTheme` and CloudBake color extensions instead of local
  font sizes, corner radii, shadows, or repeated spacing.
- Keep row/card actions compact. Use one primary inline action when needed and move lower-frequency
  actions into menus, sheets, detail screens, or confirmations.
- Use `cloudBakeCenteredPopup` for CloudBake-styled confirmation and preflight dialogs unless a
  slice explicitly calls for a native picker/list/sheet.

## Lists, Search, and Empty States

- Add search for owner-managed collections when there is more than one plausible lookup key.
- Search should cover the safe fields an owner would naturally remember, such as names, notes,
  public labels, contact fields, ingredient names, and design notes.
- List rows should show enough summary information to choose an item without opening every detail.
- Empty states should explain the next useful action and avoid exposing implementation details.
- No user-facing list or detail should show raw persistence paths, stable IDs, or private debug data.

## Forms

- Required fields should appear before optional or advanced fields.
- Save actions should be disabled or rejected with a nearby clear message until required fields are
  valid.
- Numeric fields must include unit or currency context where applicable.
- Multiline owner notes, preferences, allergies, and dietary fields must keep durable labels visible
  and must not rely only on pale placeholder text.

## Safety, Privacy, and Destructive Actions

- Allergies and dietary restrictions must be visually distinct from general preferences and notes.
- Customer details, allergies, private notes, recipes, costs, supplier details, and photo references
  must not be logged.
- Destructive actions require explicit confirmation with stable accessibility identifiers.
- Import/export and other broad data-management actions require preflight copy that explains merge,
  replace, or export behavior before the owner chooses a file or destination.

## Accessibility and Adaptivity

- Critical controls need stable accessibility identifiers for XCUITest and understandable labels for
  VoiceOver.
- Minimum tap targets should remain at least 44 by 44 points.
- Use text and symbols in addition to color for status, warning, and selected states.
- Check migrated screens on supported iPhone sizes in portrait and common landscape configurations.
- Check large Dynamic Type, increased contrast, Reduce Transparency, and VoiceOver for critical
  workflows before handing off broad UI changes.
- When a referenced photo asset is unavailable, show a clear accessible fallback state instead of a
  broken or blank image.

## Current QA Decision

Snapshot or image-based visual regression testing was not adopted in the refresh slices because it
has not yet been approved and the shared UI system is still stabilizing. Current regression proof is
provided through focused unit tests, repository-backed integration tests, targeted XCUITests, and
manual visual/accessibility review notes in handoffs.
