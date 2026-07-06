# Slice RFC-0061: Order Photo Camera Capture

## Status

Implemented

## Parent RFC

- `docs/rfc/slices/0057-order-photos.md`

## Context

Order detail can already show saved order photos and import customer reference or final cake photos
from the photo library. The owner also needs to capture photos directly from the device camera,
especially final cake photos taken during handmade cake preparation and delivery.

## Scope

In scope:

- camera capture action for customer reference photos,
- camera capture action for final cake photos,
- routing captured camera images through the existing order photo storage path,
- disabling camera actions when camera hardware is unavailable,
- updating camera privacy copy,
- focused acceptance coverage that the camera actions are visible.

Out of scope:

- automating physical camera capture in CI,
- retaking or replacing a saved order photo,
- image crop/edit tools,
- full-screen image preview,
- promoting final cake photos into the design library.

## Requirements

- Order detail must expose a camera action for customer reference photos.
- Order detail must expose a camera action for final cake photos.
- Camera actions must use the iOS camera when hardware is available.
- Camera actions must be disabled when camera hardware is unavailable.
- Captured photos must save through the same local-first order photo path as library imports.
- Camera permission copy must include order photos.
- CI must not depend on physical camera hardware.

## Design

`OrderDetail` presents `OrderPhotoCameraView` as a full-screen camera cover for the selected photo
kind. `OrderPhotoCameraView` wraps `UIImagePickerController` with `.camera` source type and `.photo`
capture mode, matching the existing purchase bill and recipe camera patterns.

When the owner captures an image, the detail view converts it to JPEG data and calls
`OrderListViewModel.addOrderPhoto(kind:imageData:)`. The view model continues to own local file
storage and metadata persistence.

The camera buttons remain visible but disabled when `UIImagePickerController.isSourceTypeAvailable`
reports no camera. This keeps the UI predictable in simulators and on unsupported devices.

## Testing

Focused tests cover:

- existing order photo view-model tests for the save path used by camera capture,
- the saved-photo acceptance fixture,
- the acceptance test verifying that reference and final photo camera actions are present.

Manual device testing is required to exercise actual camera hardware because CI simulators do not
reliably provide camera capture.

## Follow-Up

- Add optional caption editing.
- Add full-screen photo preview.
- Add a promote-to-design-library flow for final cake photos.
