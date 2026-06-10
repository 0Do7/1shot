# Scrolling Capture

## ADDED Requirements

### Requirement: Auto-scroll and manual capture modes
The system SHALL provide a scrolling-capture mode that captures content larger than the visible viewport by stitching successive frames. Two acquisition modes MUST be available: auto-scroll, where the system drives scrolling of the target surface, and manual, where the user scrolls at their own pace and the system stitches what it observes. The user SHALL be able to switch from auto to manual within a session (including when offered after an auto-mode failure) without losing already-captured content.

#### Scenario: Auto-scroll captures a long page
- **WHEN** the user starts an auto-scroll capture over a scrollable page taller than the viewport
- **THEN** the system scrolls the target, acquires frames, and produces a single stitched image of the traversed content

#### Scenario: Manual mode stitches user-driven scrolling
- **WHEN** the user starts a manual scrolling capture and scrolls the target themselves at varying speeds
- **THEN** the system stitches the observed content into a single image

#### Scenario: Mid-session switch preserves progress
- **WHEN** auto mode stalls and the user switches to manual mode
- **THEN** the content captured so far is retained and stitching continues from it

### Requirement: Vertical and horizontal capture
Scrolling capture MUST support both vertical and horizontal scroll directions. The direction SHALL be selectable at session start, and the stitched output MUST be correct for either axis.

#### Scenario: Horizontal capture of a wide surface
- **WHEN** the user runs a horizontal scrolling capture over a wide spreadsheet
- **THEN** the output is a single image of the traversed horizontal content with correct left-to-right continuity

#### Scenario: Vertical capture
- **WHEN** the user runs a vertical scrolling capture over a long document
- **THEN** the output is a single continuous vertical image

### Requirement: Live stitch preview
During capture, the system MUST display a live preview of the growing stitched canvas alongside the capture, updating as each new segment is stitched, so the user can see what has been captured and detect problems before finishing. The preview MUST reflect the actual stitch result (including any seam misalignment), not an idealized mock.

#### Scenario: Preview grows during capture
- **WHEN** a scrolling capture is in progress
- **THEN** a preview pane shows the stitched canvas extending in real time as segments are added

#### Scenario: Preview exposes a bad seam immediately
- **WHEN** a stitch step lands misaligned during capture
- **THEN** the misalignment is visible in the live preview at that moment

### Requirement: Session controls
A scrolling-capture session SHALL provide visible controls and keyboard equivalents to: finish (accept what is captured so far), cancel (Esc — discard everything, nothing written to disk), and pause/resume in manual mode. Finishing SHALL hand the result to the post-capture pipeline (chip/editor) like any other capture.

#### Scenario: Finish early keeps partial result
- **WHEN** the user finishes a scrolling capture before reaching the end of the content
- **THEN** the stitched image of everything captured so far is delivered to the post-capture pipeline

#### Scenario: Cancel discards everything
- **WHEN** the user presses Esc during a scrolling capture
- **THEN** the session ends, no image is produced, and no file is written to disk

### Requirement: Post-capture restitch without recapture
The result of a scrolling capture MUST retain its source segments and seam positions (not only the flattened pixels) for the lifetime of the capture's editable document. A restitch view SHALL let the user inspect each seam and drag/adjust seam offsets to correct misalignment, with the corrected result re-rendered from the original segments — no recapture required. Restitch MUST also allow trimming segments from either end. Restitch MUST remain available after the document is saved to the Library and reopened.

#### Scenario: Fix a misaligned seam after capture
- **WHEN** a finished scrolling capture has one misaligned seam and the user opens the restitch view and drags that seam to the correct offset
- **THEN** the output re-renders from the original segments with the seam corrected
- **AND** no recapture occurs

#### Scenario: Restitch after reopening from Library
- **WHEN** the user saves a scrolling capture to the Library, reopens it later, and opens the restitch view
- **THEN** all segments and seams are still present and adjustable

#### Scenario: Trim a bad trailing segment
- **WHEN** the final segment captured a popup and the user removes it in the restitch view
- **THEN** the output re-renders without that segment

### Requirement: Full-resolution output
The stitched output MUST be at the full native pixel density of the source display for its entire length. The system MUST NOT downscale the result regardless of total stitched size; if a hard resource limit would be exceeded, the system MUST stop with an explicit explanation and deliver the full-resolution content captured so far rather than silently delivering a downscaled image.

#### Scenario: Long Retina capture stays at 2x
- **WHEN** the user captures a 30-viewport-tall page on a 2x display
- **THEN** every region of the output is at 2x density, verified by comparing output pixel dimensions to the traversed logical content

#### Scenario: Resource limit reached honestly
- **WHEN** a capture grows beyond the supportable maximum size
- **THEN** the capture stops with a message explaining the limit
- **AND** the delivered partial result is full resolution, not a downscaled full-length image

### Requirement: Sticky chrome handling
The stitcher MUST detect viewport-fixed chrome (sticky headers, footers, floating toolbars/sidebars along the scroll axis) — regions that remain static across frames while content scrolls — and exclude repeated chrome from the stitched body so it does not appear duplicated at every seam. Fixed chrome from the first frame SHALL be preserved once at the corresponding edge of the output.

#### Scenario: Sticky header not repeated
- **WHEN** the user captures a page with a sticky header
- **THEN** the header appears exactly once at the top of the output and never inside the stitched body

#### Scenario: Floating element does not corrupt seams
- **WHEN** a page has a fixed floating button over scrolling content
- **THEN** the stitched body content is continuous and the button does not produce ghosting or duplicated bands

### Requirement: Honest failure messaging
WHEN the system cannot capture or stitch a surface reliably (stitch confidence below threshold, target does not scroll, content unscrollable or virtualized beyond tracking), it MUST stop and tell the user explicitly what went wrong and what to try (e.g. manual mode), and MUST offer to keep the validly stitched portion. The system MUST NEVER silently emit a corrupted, duplicated, gap-containing, or misordered result as if it were successful.

#### Scenario: Low-confidence stitch halts with explanation
- **WHEN** frame correlation confidence falls below the reliability threshold during auto capture
- **THEN** the capture stops, a message explains that the surface could not be stitched reliably and suggests manual mode
- **AND** the user is offered the option to keep the valid portion captured before the failure

#### Scenario: Unscrollable target
- **WHEN** the user starts a scrolling capture over a surface that does not respond to scrolling
- **THEN** the system reports that the target cannot be scrolled rather than producing a single-frame image presented as a scrolling capture

#### Scenario: No silent garbage
- **WHEN** any internal stitching step fails validation
- **THEN** the failure surfaces to the user; under no condition is a known-bad stitch delivered without warning

### Requirement: Lazy-loading content handling
In auto mode, the system MUST accommodate content that loads as it scrolls (lazy-loading pages): scroll pacing SHALL allow content to render before frame acquisition, and IF unrendered/placeholder regions are detected at a stitch boundary the system SHALL wait and retry before either succeeding or failing honestly per the failure-messaging requirement.

#### Scenario: Lazy-load page captured completely
- **WHEN** the user auto-captures a page whose images load on scroll
- **THEN** the output contains the fully loaded content with no placeholder/blank bands

#### Scenario: Content that never loads
- **WHEN** a lazy region fails to render within the retry budget
- **THEN** the capture stops with an honest failure message rather than stitching the placeholder

### Requirement: Failure suite compatibility
Scrolling capture MUST pass a defined failure suite, executed in CI on a dedicated rig before release: Terminal (scrollback), VS Code (editor and panel scrolling), Finder column view (horizontal), a system with Mos installed, a system with Scroll Reverser installed, sticky-header pages, and lazy-loading pages. Passing means: a correct full-resolution stitch, or an honest failure message — never silent garbage. Scroll-modifying utilities (Mos, Scroll Reverser) MUST NOT cause inverted, skipped, or duplicated stitching in auto mode.

#### Scenario: Terminal scrollback
- **WHEN** the suite captures a Terminal window with content in scrollback
- **THEN** the result is a correct continuous stitch of the scrollback or an explicit failure message

#### Scenario: Finder column view horizontal
- **WHEN** the suite runs a horizontal capture across Finder column view
- **THEN** the result is a correct horizontal stitch or an explicit failure message

#### Scenario: Scroll utilities installed
- **WHEN** the suite runs auto-scroll captures on machines with Mos and with Scroll Reverser active
- **THEN** stitch direction and continuity are correct, or the system fails honestly

#### Scenario: Suite gates release
- **WHEN** any failure-suite scenario produces silent garbage in CI
- **THEN** the build is marked failing and is not releasable

### Requirement: Lazy Accessibility permission with explainer
Auto-scroll mode requires the Accessibility permission; the system MUST NOT request it at app launch or onboarding. It SHALL be requested only at the first use of auto-scroll, preceded by an in-app explainer stating why it is needed and what it is used for. IF the permission is declined, manual mode MUST remain fully functional and the system SHALL offer it; the permission state SHALL be reflected in the app's permission-health surface.

#### Scenario: No Accessibility prompt before first use
- **WHEN** the user installs, onboards, and uses every non-scrolling feature
- **THEN** no Accessibility permission request occurs

#### Scenario: First auto-scroll shows explainer then prompt
- **WHEN** the user starts their first auto-scroll capture
- **THEN** an explainer describing the permission's purpose is shown before the system permission dialog

#### Scenario: Declined permission falls back to manual
- **WHEN** the user declines Accessibility
- **THEN** the system offers manual scrolling capture, which works without the permission

### Requirement: Multi-display and DPI correctness for scrolling capture
Scrolling capture MUST work on any connected display, including secondary and 1x displays, producing output at that display's native density with correct coordinate mapping for both scroll synthesis and frame acquisition.

#### Scenario: Scrolling capture on a 1x secondary display
- **WHEN** the user runs a scrolling capture of a window on a 1x external display
- **THEN** scrolling targets the correct window, frames are acquired from the correct display, and output is correct 1x-density content
