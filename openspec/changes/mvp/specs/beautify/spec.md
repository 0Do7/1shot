## ADDED Requirements

### Requirement: Backdrop types
The beautify surface SHALL offer three backdrop types behind the capture: gradient (with a curated built-in set plus user-defined color stops and angle), solid color (any color, including picked from the image), and user-supplied image (fitted with fill/fit options). Changing backdrop type SHALL preview live on the actual capture without committing.

#### Scenario: Apply a gradient backdrop
- **WHEN** the user selects a gradient backdrop
- **THEN** the capture is rendered centered over the gradient in a live preview

#### Scenario: Custom solid from picked color
- **WHEN** the user picks a color from the capture itself as a solid backdrop
- **THEN** the backdrop becomes that exact color

#### Scenario: Image backdrop
- **WHEN** the user chooses a local image file as the backdrop
- **THEN** the capture renders over that image with the selected fill/fit mode

### Requirement: Padding, rounded corners, and shadow controls
The beautify surface SHALL provide independently adjustable padding (backdrop margin around the capture), corner radius applied to the capture, and a drop shadow with adjustable intensity. All three SHALL update the live preview immediately, SHALL be keyboard-adjustable, and each SHALL be settable to zero/off.

#### Scenario: Adjust all three properties
- **WHEN** the user sets padding, corner radius, and shadow values
- **THEN** the preview reflects each change immediately and independently

#### Scenario: Everything off equals plain capture
- **WHEN** padding, radius, and shadow are all zero and no backdrop is set
- **THEN** the output is pixel-identical to the unbeautified capture

### Requirement: Beautify is non-destructive
Beautify settings SHALL be stored as part of the re-editable annotation document, never burned into the source pixels before export. Reopening a beautified document from the Library SHALL restore all beautify parameters for further adjustment, and removing beautify SHALL recover the original capture pixels exactly.

#### Scenario: Reopen and change the backdrop
- **WHEN** the user reopens a previously beautified capture from the Library and selects a different gradient
- **THEN** the new gradient replaces the old one with the original capture pixels intact

#### Scenario: Remove beautify entirely
- **WHEN** the user disables beautify on a saved beautified document
- **THEN** the document renders the original, unmodified capture

### Requirement: Brand presets
The app SHALL let the user save the complete current beautify configuration (backdrop, padding, corner radius, shadow, export size) as a named preset, support multiple presets, and apply any preset to a capture with a single action. Presets SHALL be editable, deletable, reorderable, and persisted locally across launches; applying a preset SHALL replace all beautify parameters atomically.

#### Scenario: Save and apply a brand preset
- **WHEN** the user saves the current configuration as "Acme blog" and later applies it to a new capture
- **THEN** the new capture receives the identical backdrop, padding, radius, shadow, and export size in one action

#### Scenario: Edit a preset
- **WHEN** the user edits a preset's padding and saves
- **THEN** subsequent applications of the preset use the new padding while captures already exported are unaffected

#### Scenario: Presets survive relaunch
- **WHEN** the app is quit and relaunched
- **THEN** all saved presets are present unchanged

### Requirement: Per-platform export sizes
The beautify surface SHALL offer named export-size targets for common platforms (at minimum: X/Twitter post, Open Graph 1200×630, Dribbble shot, App Store screenshot, plus square and 16:9 generic) and custom width×height. Selecting a target SHALL set the output canvas to those exact dimensions with the capture composed inside (scaled to fit, never distorted or cropped without indication), and the exported file dimensions MUST match the selected target exactly.

#### Scenario: Export at Open Graph size
- **WHEN** the user selects the Open Graph target and exports
- **THEN** the exported image is exactly 1200×630 pixels with the beautified capture composed undistorted within it

#### Scenario: Custom dimensions
- **WHEN** the user enters a custom size of 1080×1080
- **THEN** the preview and export use exactly 1080×1080

### Requirement: Optional auto-apply preset
The app SHALL offer an opt-in setting that automatically applies a chosen preset to new captures when they enter the editor/beautify flow. The setting MUST default to off; when on, the auto-applied result SHALL remain fully adjustable and removable per capture, and the underlying capture (clipboard/chip copy actions) SHALL remain the raw, unbeautified image unless the user exports the beautified version.

#### Scenario: Auto-apply on
- **WHEN** auto-apply is enabled with preset "Acme blog" and the user opens a new capture in the editor
- **THEN** the capture appears with the preset already applied and editable

#### Scenario: Auto-apply default off
- **WHEN** the app is freshly installed
- **THEN** new captures open without any beautify applied

#### Scenario: Chip copy stays raw under auto-apply
- **WHEN** auto-apply is enabled and the user copies a capture directly from the chip
- **THEN** the clipboard receives the unbeautified capture

### Requirement: Professional in ten seconds
The capture-to-shareable flow — capture, apply a saved preset, drag or export the result into a destination app — SHALL be completable in 10 seconds or less by a user with a preset already saved, with no mandatory dialog between preset application and drag-out. Preset application on a typical capture SHALL render in under 500 ms.

#### Scenario: Ten-second flow
- **WHEN** a user with a saved preset captures a window, applies the preset via its one-step action, and drags the result into a tweet composer
- **THEN** the entire flow completes within 10 seconds and the dropped image is the beautified, platform-sized output

#### Scenario: Preset render latency
- **WHEN** a preset is applied to a typical full-screen capture
- **THEN** the beautified preview renders in under 500 ms

### Requirement: Beautified export fidelity
Exports of beautified captures SHALL render backdrop, shadow, and corner masking at full output resolution with correct alpha (no banding from downscaled gradients, no opaque box around shadows on transparent-capable formats). When exporting to a format without alpha (e.g. JPEG), corner-rounded output SHALL composite onto the backdrop rather than producing black corners.

#### Scenario: Rounded corners on JPEG
- **WHEN** a beautified capture with rounded corners is exported as JPEG
- **THEN** the corner regions show the backdrop, not black or artifact pixels

#### Scenario: Gradient quality at large sizes
- **WHEN** a gradient backdrop is exported at 2x platform size
- **THEN** the gradient is rendered at full output resolution without visible upscaling artifacts
