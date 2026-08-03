# RFC Slice 0123: Native iOS Dialogs

Status: Implemented

## Problem

CloudBake used a custom centered overlay for confirmations, choices, warnings, and short input.
The overlay duplicated system presentation behavior, could grow beyond its content, and required
feature-specific sizing and button styling.

## Decision

Replace the custom popup system across the owner app with native iOS presentation:

1. use `Menu` for anchored compact choices,
2. use `confirmationDialog` for action lists, confirmations, and destructive decisions,
3. use `Alert` for acknowledgements and short text input supported by the system,
4. use a native sheet only when the workflow requires richer controls than an alert can host,
5. preserve destructive button roles, explicit cancel paths, concise explanatory messages, and
   stable accessibility identifiers,
6. remove the custom dimmed overlay, rounded popup card, custom action rows, and popup-specific
   icon/color logic,
7. route system-driven interactive dismissal through the same cancellation cleanup exactly once,
   without treating a selected dialog action as cancellation.

The scope includes order status and payment decisions, inventory archive/delete/disposal,
customer and recipe deletion, design tags/removal, reminder payment confirmation, voice-import
mapping choices, backup/restore decisions, and Settings data-management preflight.

Photo and file pickers, cameras, full editors, and navigation destinations are not popups and keep
their existing native presentations.

## Subsequent Presentation Boundary

Later product direction keeps native `Menu` presentation for compact choices attached to cards or
form fields, including status, payment, report filters, inventory units, and cake specifications.
These menus use the shared CloudBake native-menu style so selected checkmarks retain the primary
pink accent in every screen.
Main screen and workflow action lists such as report selection, More Actions, and template
management use the shared CloudBake-styled action popover while retaining native popover
presentation and dismissal behavior.

## Validation

1. The owner-app Debug build succeeds for a generic iPhone Simulator.
2. Acceptance journeys locate native dialog actions through stable accessibility identifiers and
   verify system-owned titles, messages, and dismissal through their user-visible presentation.
3. Targeted order, inventory, customer, recipe, design, Settings, backup, and restore acceptance
   journeys pass.
4. Search confirms the retired custom popup APIs and custom overlay implementation are absent.
5. The final build is installed on the connected iPhone for owner validation.
