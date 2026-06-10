# Capture Engine

## ADDED Requirements

### Requirement: Capture modes
The system SHALL provide six still-image capture modes, each invocable via a configurable global hotkey and via the menu-bar menu: area selection, window, fullscreen, repeat-previous-area, delayed, and freeze-screen. All capture acquisition MUST use ScreenCaptureKit / SCScreenshotManager exclusively; the system MUST NOT call any deprecated capture API (e.g. `CGWindowListCreateImage`).

#### Scenario: Each mode is invocable by hotkey
- **WHEN** the user presses the configured hotkey for any of the six capture modes
- **THEN** the corresponding capture flow begins within the hotkey latency budget
- **AND** the resulting image is delivered to the post-capture pipeline

#### Scenario: Each mode is invocable from the menu bar
- **WHEN** the user selects a capture mode from the menu-bar menu
- **THEN** the same capture flow begins as if the hotkey had been pressed

#### Scenario: No deprecated APIs in the binary
- **WHEN** the shipped binary is inspected for symbol references
- **THEN** no references to deprecated capture APIs (e.g. `CGWindowListCreateImage`) are present

### Requirement: Area selection capture
Area capture SHALL present a crosshair selection overlay on every connected display. The overlay SHALL display live pixel dimensions of the selection, SHALL support adjusting the selection edges/corners before confirming, and SHALL be cancellable with Esc. Confirming the selection SHALL produce an image of exactly the selected region at the display's native (Retina) resolution.

#### Scenario: User drags a region and confirms
- **WHEN** the user invokes area capture, drags a region, and confirms
- **THEN** the captured image matches the selected region's bounds exactly
- **AND** the image is at the native pixel density of the display the region was on

#### Scenario: User cancels the selection
- **WHEN** the user presses Esc during area selection
- **THEN** the overlay dismisses without producing any capture
- **AND** no file is written and no chip appears

#### Scenario: Selection shows live dimensions
- **WHEN** the user is dragging or adjusting a selection
- **THEN** the overlay displays the selection's current width and height in pixels, updating live

### Requirement: Window capture with true transparent shadows
Window capture SHALL highlight the window under the cursor and capture the chosen window on click. The default output MUST include the window's drop shadow composited with a true alpha channel (transparent background, not a flattened backdrop). The system SHALL also provide a shadowless mode (selectable at capture time via modifier key and as a persistent setting) that captures the window with no shadow and tight bounds.

#### Scenario: Window captured with transparent shadow
- **WHEN** the user captures a window with shadow mode active
- **THEN** the output image contains the window plus its shadow
- **AND** the area outside the window and shadow is fully transparent (alpha 0), with the shadow itself partially transparent

#### Scenario: Shadowless window capture
- **WHEN** the user captures a window with shadowless mode active
- **THEN** the output image contains only the window content with no shadow pixels
- **AND** the image bounds are tight to the window frame

#### Scenario: Window highlighting during pick
- **WHEN** the user moves the cursor over candidate windows during window-capture mode
- **THEN** the window under the cursor is visually highlighted before any capture occurs

### Requirement: Repeat-previous-area with region preview
Repeat-area capture SHALL recapture the most recently used area-selection region. Before capturing, the system MUST briefly display a visual preview of the stored region's bounds on screen so the user can see what will be captured; the user SHALL be able to cancel (Esc) during the preview. If no previous region exists, the system SHALL fall back to area-selection mode instead of failing.

#### Scenario: Repeat shows preview before recapture
- **WHEN** the user invokes repeat-area capture and a previous region exists
- **THEN** the previous region's bounds are displayed as an on-screen preview before the capture is taken
- **AND** the capture proceeds with the exact same region (same display, same coordinates) after the preview

#### Scenario: Cancel during repeat preview
- **WHEN** the user presses Esc while the repeat-area preview is showing
- **THEN** no capture is taken

#### Scenario: Repeat with no prior region
- **WHEN** the user invokes repeat-area capture and no previous area selection exists in this session or persisted state
- **THEN** the system opens normal area-selection mode instead of producing an error or empty capture

### Requirement: Delayed capture
Delayed capture SHALL capture after a user-configurable delay. The delay value MUST be editable in the settings UI (not hard-coded), and the system SHALL show a visible countdown indicator during the delay. The user SHALL be able to cancel the pending capture during the countdown.

#### Scenario: Delay fires after configured interval
- **WHEN** the user sets the delay to N seconds and invokes delayed capture
- **THEN** a countdown indicator is shown
- **AND** the capture is taken N seconds (±0.5s) after invocation

#### Scenario: Cancel during countdown
- **WHEN** the user cancels (Esc or clicking the countdown indicator's cancel affordance) during the countdown
- **THEN** no capture is taken and the countdown indicator dismisses

### Requirement: Freeze-screen capture
Freeze-screen capture SHALL grab the full content of all displays at invocation time and present the frozen image(s) in overlay windows, allowing the user to select a region from the frozen state while live screen content continues to change underneath. The selected region MUST be extracted from the frozen image, not from the live screen at confirmation time.

#### Scenario: Selection from frozen content
- **WHEN** the user invokes freeze-screen, screen content changes (e.g. a tooltip disappears), and the user then selects a region
- **THEN** the output reflects the screen state at the moment of invocation, not the state at confirmation

#### Scenario: Freeze across multiple displays
- **WHEN** freeze-screen is invoked on a multi-display setup
- **THEN** every connected display is frozen simultaneously and the user can select a region on any display

### Requirement: Multi-display and mixed-DPI correctness
All capture modes SHALL behave correctly on multi-display setups with mixed scale factors (e.g. one Retina and one 1x display). Selection overlays MUST appear on every display; coordinates MUST map correctly per display; captured output MUST be at the native pixel density of the source display with no scaling artifacts; an area selection MUST NOT be capturable across a boundary in a way that mixes scale factors incorrectly (a cross-display selection SHALL produce a single correct image or be constrained to one display, never a corrupted result).

#### Scenario: Capture on a 1x display attached to a Retina Mac
- **WHEN** the user area-captures a 100x100-point region on a 1x external display
- **THEN** the output image is 100x100 pixels (1x density) with correct content

#### Scenario: Capture on the Retina display of the same setup
- **WHEN** the user area-captures a 100x100-point region on the 2x internal display
- **THEN** the output image is 200x200 pixels with correct content

#### Scenario: Window capture of a window on a secondary display
- **WHEN** the user captures a window located entirely on a secondary display
- **THEN** the output contains that window at the secondary display's native density with correct bounds

### Requirement: Cursor inclusion control
The system SHALL provide a setting controlling whether the mouse cursor is included in captures. When enabled, the cursor MUST appear in fullscreen and area captures at its on-screen position; when disabled, no cursor pixels appear in any capture.

#### Scenario: Cursor included
- **WHEN** cursor inclusion is enabled and the user takes a fullscreen capture
- **THEN** the cursor is rendered in the output at its on-screen position

#### Scenario: Cursor excluded
- **WHEN** cursor inclusion is disabled and the user takes any capture
- **THEN** the output contains no cursor pixels

### Requirement: Hotkey-to-result latency budget
For area, window, fullscreen, and repeat captures, the elapsed time from global hotkey press to either (a) the selection overlay being visible and interactive, or (b) for non-interactive modes, the post-capture chip being visible, MUST be under 200 ms at the 95th percentile on supported hardware. This budget SHALL be asserted by automated performance tests.

#### Scenario: Fullscreen hotkey to chip
- **WHEN** the user presses the fullscreen-capture hotkey
- **THEN** the post-capture chip is visible within 200 ms (p95 across repeated runs)

#### Scenario: Area hotkey to overlay
- **WHEN** the user presses the area-capture hotkey
- **THEN** the selection overlay is visible and accepting input within 200 ms (p95 across repeated runs)

### Requirement: Global hotkeys without Accessibility permission
Global capture hotkeys MUST function with only the Screen Recording permission granted; the system MUST NOT require Accessibility permission for any core still-capture flow. Hotkey registration SHALL not depend on event taps that require Accessibility.

#### Scenario: Capture works without Accessibility
- **WHEN** Screen Recording is granted, Accessibility is not granted, and the user presses any capture hotkey
- **THEN** the capture flow executes normally with no Accessibility prompt

### Requirement: Screen Recording permission failure behavior
WHEN Screen Recording permission is missing or has been revoked, a capture attempt SHALL NOT fail silently or produce a black/empty image. The system MUST detect the missing permission, present an explanation with a direct link to the relevant System Settings pane, and reflect the state in the app's permission-health surface.

#### Scenario: Capture attempted without permission
- **WHEN** the user invokes any capture mode and Screen Recording permission is not granted
- **THEN** no garbage/black capture is produced
- **AND** the user is shown a message explaining the missing permission with a one-click path to System Settings

#### Scenario: Permission revoked mid-session
- **WHEN** Screen Recording permission is revoked while the app is running and the user invokes a capture
- **THEN** the system detects the revocation and shows the same guided recovery, not a corrupted capture

### Requirement: In-memory capture results
A completed capture SHALL be delivered to the post-capture pipeline as an in-memory image. The capture engine itself MUST NOT write any user-facing file to disk; persistence decisions belong to downstream surfaces (chip, editor, destinations).

#### Scenario: Capture produces no file
- **WHEN** the user completes any capture and takes no further action
- **THEN** no new user-visible file exists in any save location

### Requirement: Capture type extensibility
The capture domain model MUST represent the kind of capture as an extensible capture-type concept in which still image is one case and video recording is a reserved, presently inert case. All pipeline interfaces (capture result, chip input, library record) MUST be typed against this concept so that adding recording in v2 requires no change to existing still-image contracts.

#### Scenario: Domain model carries capture type
- **WHEN** a still capture flows through the pipeline
- **THEN** its result is tagged with the image capture type
- **AND** the type system admits a video case without modification of consumer interfaces (verified by a compile-time test instantiating the reserved case)

### Requirement: Portable domain core
Capture domain types (capture type, capture result metadata, geometry) MUST reside in the platform-agnostic core package and MUST NOT import AppKit, SwiftUI, or UIKit. This constraint SHALL be enforced by an automated CI check.

#### Scenario: CI rejects UI imports in domain package
- **WHEN** a change introduces an AppKit/SwiftUI/UIKit import into the capture domain types package
- **THEN** the CI lint fails the build
