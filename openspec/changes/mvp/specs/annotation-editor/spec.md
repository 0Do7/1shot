# Annotation Editor

## ADDED Requirements

### Requirement: Re-editable annotation document
Annotations MUST be stored as discrete objects layered over an untouched base image, never painted into the pixels, for the entire lifetime of the document. Saving to the Library and reopening — at any later time, across app restarts and app updates — MUST restore every annotation as a live, selectable, editable object. Rasterization (flattening) SHALL occur only when producing an export artifact (file, clipboard, drag-out) and MUST NOT alter the stored document.

#### Scenario: Reopen from Library with live annotations
- **WHEN** the user annotates a capture with an arrow and a text label, saves it to the Library, quits and relaunches the app, and reopens the item
- **THEN** the arrow and text are individually selectable, movable, restylable, and deletable
- **AND** the base image pixels are unchanged from the original capture

#### Scenario: Export flattens without mutating the document
- **WHEN** the user exports an annotated document to PNG and then continues editing
- **THEN** the exported file contains the flattened result
- **AND** the in-app document still has all annotations as live objects

#### Scenario: Old documents open in newer app versions
- **WHEN** a document saved with an earlier document schema version is opened by a newer app version
- **THEN** the document opens with all annotations intact via forward migration, never refusing or rasterizing

### Requirement: Platform-agnostic document model
The annotation document model (document, annotation types, geometry, styles) MUST be expressed in portable pure-Swift value types with no AppKit, SwiftUI, or UIKit imports, and MUST be serializable to a documented format with an explicit schema version. An automated CI check SHALL fail any change that introduces a UI-framework import into the document model package.

#### Scenario: CI enforces portability
- **WHEN** a change adds `import AppKit` (or SwiftUI/UIKit) to the annotation document model package
- **THEN** the CI lint fails the build

#### Scenario: Document round-trips through serialization
- **WHEN** any annotation document is serialized and deserialized
- **THEN** the resulting document is value-equal to the original, including annotation order, styles, and canvas extensions

### Requirement: Single-key tool selection
Every annotation tool SHALL be activatable by a single unmodified key press (e.g. A for arrow, T for text) while the editor is focused, in addition to toolbar clicks. The active tool MUST be visibly indicated. Single-key shortcuts MUST be suspended while the user is entering text in a text annotation. The complete key map SHALL be discoverable in the UI.

#### Scenario: Key press switches tool
- **WHEN** the editor is focused, no text is being edited, and the user presses a tool's key
- **THEN** that tool becomes active and the toolbar indicates it

#### Scenario: Tool keys do not fire during text editing
- **WHEN** the user is typing inside a text annotation and presses a letter that is also a tool shortcut
- **THEN** the letter is inserted into the text and the active tool does not change

### Requirement: Annotation tool set
The editor SHALL provide the following annotation tools, each producing a styled, re-editable object: arrow (straight and curved), line, rectangle, ellipse, text (with selectable styles), highlight, spotlight/dim (darken everything outside a chosen region), auto-incrementing counter badges, freehand draw, and magnifier callout (an enlarged inset of a chosen source region). Every object SHALL support selection, move, resize/reshape, restyle (color, stroke weight, and tool-appropriate attributes), reorder, duplicate, and delete after creation.

#### Scenario: Curved arrow is created and reshaped
- **WHEN** the user draws an arrow and switches it to curved
- **THEN** the arrow renders as a curve with an adjustable control point
- **AND** dragging the control point reshapes the existing arrow object

#### Scenario: Counter badges auto-increment
- **WHEN** the user places three counter badges in sequence
- **THEN** they are numbered 1, 2, 3 automatically
- **AND** deleting badge 2 renumbers the remaining badges to 1, 2

#### Scenario: Spotlight dims outside the region
- **WHEN** the user applies the spotlight tool to a region
- **THEN** everything outside the region is dimmed and the region remains at full brightness
- **AND** the spotlight region can be moved and resized afterward as an object

#### Scenario: Magnifier callout tracks its source
- **WHEN** the user creates a magnifier callout over a source region
- **THEN** an enlarged rendering of that region appears as a movable callout object
- **AND** moving the source region updates the callout content

### Requirement: Smart text-following highlight
The highlight tool SHALL detect text lines in the base image (on-device) and, when dragged across text, snap the highlight to the detected line geometry so it reads as marker-over-text rather than a free rectangle. A non-snapping free highlight MUST remain available when no text is detected or when the user overrides snapping.

#### Scenario: Highlight snaps to a text line
- **WHEN** the user drags the highlight tool across a line of text in the capture
- **THEN** the highlight aligns to the detected text line's bounds

#### Scenario: Highlight over non-text content
- **WHEN** the user drags the highlight over a region with no detected text
- **THEN** a free rectangular highlight is created at the dragged bounds

### Requirement: Crop and expandable canvas
The editor SHALL support cropping the document and expanding the canvas beyond the base image bounds (adding margin space on any side, filled with a chosen background) so annotations and additional images can sit outside the original pixels. Crop MUST be non-destructive: the cropped-out content is retained in the document and the crop can be re-adjusted or removed later.

#### Scenario: Crop is re-adjustable
- **WHEN** the user crops a document, saves it to the Library, reopens it, and enlarges the crop
- **THEN** the previously cropped-out content reappears

#### Scenario: Canvas expansion adds space
- **WHEN** the user expands the canvas below the image
- **THEN** new canvas space appears with the chosen fill
- **AND** annotations can be placed in the expanded region
- **AND** exports include the expanded canvas

### Requirement: Multi-image stitch and combine
The editor SHALL allow placing multiple captures into one document and combining them: side-by-side / vertical stitch arrangements and free placement on the expanded canvas. Each placed image SHALL remain an independent, repositionable object until export.

#### Scenario: Two captures stitched vertically
- **WHEN** the user adds a second capture to a document and chooses vertical stitch
- **THEN** the two images render stacked with the canvas sized to fit
- **AND** each image can still be selected and reordered afterward

### Requirement: Zoom and pan navigation
The editor SHALL support zooming (keyboard, scroll/pinch gestures, and fit/100% commands) and panning, including a momentary pan/zoom mode held from the keyboard (Z-plus-drag class) that returns to the prior tool on release. Annotation geometry MUST remain anchored to image coordinates across all zoom levels.

#### Scenario: Momentary zoom-drag
- **WHEN** the user holds the zoom modifier key and drags, then releases
- **THEN** the view zooms per the drag and the previously active tool is restored on release

#### Scenario: Annotations stay anchored under zoom
- **WHEN** the user places an arrow at 100% zoom and then zooms to 400%
- **THEN** the arrow points at the same image pixels at every zoom level

### Requirement: Unlimited undo and redo
Every document-mutating action (create, move, restyle, delete, crop, canvas change, redaction edit, stitch) MUST be undoable and redoable with no fixed depth limit within an editing session, via standard shortcuts (⌘Z / ⇧⌘Z). Undo MUST restore the exact prior document state.

#### Scenario: Deep undo chain
- **WHEN** the user performs 100 distinct annotation edits and presses ⌘Z 100 times
- **THEN** the document returns to its initial state, with each step visibly reverting one action

#### Scenario: Redo after undo
- **WHEN** the user undoes three actions and presses ⇧⌘Z three times
- **THEN** the document returns to the state before the undos

### Requirement: Rendering quality and export fidelity
Exported renders MUST be visually identical to the on-canvas presentation (WYSIWYG) and MUST be produced at the document's full native pixel density — never downscaled by default. Annotation rendering (anti-aliasing, shadows, arrowheads, text) SHALL be regression-guarded by reviewed golden-image snapshot tests.

#### Scenario: Export matches canvas
- **WHEN** the user exports a document containing each annotation type
- **THEN** the exported pixels match the canvas rendering within snapshot tolerance

#### Scenario: Retina capture exports at full resolution
- **WHEN** a 2x-density capture is annotated and exported with default settings
- **THEN** the export retains the full 2x pixel dimensions

### Requirement: Keyboard-first editor operation
The complete annotate-and-ship loop MUST be operable without a mouse for at least: tool selection, ⌘C copy flattened result to clipboard (and close per settings), ⌘S save/export, Esc to close (prompting only if there are unexported changes per settings), Delete to remove the selected annotation, arrow keys to nudge the selected annotation, and Tab/⇧Tab to cycle annotation selection.

#### Scenario: Keyboard-only annotate-and-copy
- **WHEN** the user opens the editor from the chip, selects a tool by key, places an annotation, and presses ⌘C
- **THEN** the flattened annotated image is on the clipboard without any pointer interaction having been required

#### Scenario: Nudge selected annotation
- **WHEN** an annotation is selected and the user presses an arrow key
- **THEN** the annotation moves by one logical unit in that direction (larger step with Shift)

### Requirement: Editor open latency
Opening the editor — from chip expansion or from a Library item — MUST present an interactive canvas within 400 ms at the 95th percentile on supported hardware, asserted by automated performance tests.

#### Scenario: Editor open within budget
- **WHEN** the user expands a chip into the editor
- **THEN** the canvas is rendered and accepting input within 400 ms (p95 across repeated runs)
