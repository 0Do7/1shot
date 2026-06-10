# Redaction

## ADDED Requirements

### Requirement: Three redaction styles
The editor SHALL provide three region redaction styles as annotation tools: blur, pixelate, and black-out (solid fill). Each SHALL be applied by dragging a region and SHALL produce a re-editable redaction object whose region can be moved, resized, restyled (e.g. blur radius, pixel size, fill color), switched between the three styles, and deleted prior to export. Each style's on-canvas preview MUST visually match the exported result.

#### Scenario: Apply each style
- **WHEN** the user drags a blur, a pixelate, and a black-out region over three areas of a capture
- **THEN** each area renders with its respective effect on canvas
- **AND** each redaction is selectable and adjustable as an object

#### Scenario: Switch style on an existing redaction
- **WHEN** the user selects an existing blur redaction and changes its style to pixelate
- **THEN** the same region re-renders as pixelated without re-dragging

#### Scenario: Preview matches export
- **WHEN** the user exports a document containing each redaction style
- **THEN** the exported pixels in each region match the on-canvas preview within snapshot tolerance

### Requirement: Effective obscuring strength
Blur and pixelate MUST actually destroy legibility at their default strengths: text of typical UI size (11–14 pt at capture density) under a default-strength blur or pixelate region MUST NOT be machine-readable by on-device OCR in the exported image. Minimum permitted strengths SHALL be floored such that the user cannot configure a redaction labeled blur/pixelate that leaves such text OCR-readable.

#### Scenario: Default blur defeats OCR
- **WHEN** a capture containing 12 pt text is redacted with default blur and exported
- **THEN** running text recognition over the redacted region of the export yields none of the original strings

#### Scenario: Strength cannot be lowered below the floor
- **WHEN** the user drags the blur strength control to its minimum
- **THEN** the resulting strength still satisfies the OCR-defeat criterion above

### Requirement: Hardened, non-reversible export
On export (file, clipboard, drag-out, and any destination), every redaction MUST be rendered destructively into the output pixels: the output artifact MUST contain no original pixel data for redacted regions in any layer, channel, metadata, embedded thumbnail, or recoverable form, for all three styles and for all supported export formats. The exported blur MUST be computed such that the underlying content is not reconstructible from the output (no reversible/weak transforms).

#### Scenario: Exported file contains no hidden original pixels
- **WHEN** the user exports a redacted document to each supported format
- **THEN** byte-level and metadata inspection of the output finds no embedded original image, alternate representation, or thumbnail revealing the redacted content

#### Scenario: Clipboard copy is hardened
- **WHEN** the user copies a redacted document with ⌘C
- **THEN** every clipboard representation placed (all pasteboard types) carries only the flattened, redacted pixels

### Requirement: Re-editable in the document, hardened only at export
Within the stored annotation document, redactions SHALL remain non-destructive objects over the untouched base image so the user can adjust or remove them later from the Library. The unflattened document format is internal; any user-facing sharing of the document content MUST pass through the hardened export path.

#### Scenario: Redaction adjusted after reopening
- **WHEN** the user saves a redacted document to the Library, reopens it, and enlarges the blur region
- **THEN** the blur region resizes over the intact base image and a subsequent export hardens the new region

### Requirement: Text-aware blur and erase
The system SHALL offer a text-aware redaction action that detects all text instances in the base image using on-device text recognition (no network) and, in one action, creates a redaction (user's choice of blur or erase) over every detected instance. Erase SHALL remove the text by filling its region to blend with the surrounding background rather than leaving a visible patch where possible.

#### Scenario: One click redacts all text
- **WHEN** the user invokes text-aware blur on a capture containing multiple text regions
- **THEN** every detected text instance receives its own blur redaction object in a single action

#### Scenario: Text-aware erase blends
- **WHEN** the user invokes text-aware erase on text over a flat background
- **THEN** the text regions are filled to match the surrounding background with no legible residue

#### Scenario: Works offline
- **WHEN** the machine has no network connectivity and the user invokes text-aware redaction
- **THEN** detection and redaction complete normally

### Requirement: Per-instance toggles
After a text-aware detection pass, each detected text instance MUST be individually toggleable: the user SHALL be able to include or exclude any instance from redaction (e.g. keep the heading visible, redact the email addresses) before and after the bulk action, via direct interaction with each instance's region.

#### Scenario: Exclude one instance
- **WHEN** text-aware blur has covered five detected instances and the user toggles one instance off
- **THEN** that instance's redaction is removed and the original text is visible again, while the other four remain redacted

#### Scenario: Re-include a toggled-off instance
- **WHEN** the user toggles a previously excluded instance back on
- **THEN** the redaction reappears over exactly that instance's region

### Requirement: No-text and partial-detection behavior
WHEN text-aware redaction is invoked and no text is detected, the system MUST say so explicitly rather than silently doing nothing. Detection results are advisory: the user MUST be able to add manual redaction regions alongside text-aware ones, and the UI SHALL communicate that detection can miss text (the user remains responsible for review).

#### Scenario: No text found
- **WHEN** the user invokes text-aware redaction on an image with no recognizable text
- **THEN** a message states that no text was detected and no redactions are created

#### Scenario: Manual region supplements detection
- **WHEN** detection misses a stylized word and the user drags a manual blur over it
- **THEN** the manual redaction coexists with the text-aware redactions and hardens identically on export

### Requirement: Content-aware object removal
The editor SHALL provide a content-aware removal tool: the user marks a region and the system fills it by synthesizing plausible surrounding content (inpainting), entirely on-device with no network calls. The removal SHALL be a re-editable object until export and hardened at export like other redactions. IF the inpainting result quality is unacceptable for a given region, the system SHALL fall back to a blended fill rather than producing a corrupted result, and the user MUST always be able to undo.

#### Scenario: Remove an object from a uniform background
- **WHEN** the user marks an icon sitting on a flat background for content-aware removal
- **THEN** the region is filled to be visually continuous with the background

#### Scenario: Removal is undoable and re-editable
- **WHEN** the user applies content-aware removal, then presses ⌘Z
- **THEN** the document returns to its prior state with the object visible again

#### Scenario: Offline operation
- **WHEN** the machine has no network connectivity
- **THEN** content-aware removal functions identically

### Requirement: Redaction performance
Applying a region redaction (blur/pixelate/black-out) MUST render its on-canvas preview interactively (region follows the drag without visible lag) on a full-screen Retina capture. A text-aware detection pass over a full-screen Retina capture MUST complete and present its instances within 3 seconds at the 95th percentile on supported hardware.

#### Scenario: Interactive blur drag
- **WHEN** the user drags a blur region across a 5K capture
- **THEN** the blurred preview tracks the drag without dropped interaction

#### Scenario: Detection pass within budget
- **WHEN** the user invokes text-aware redaction on a full-screen Retina capture
- **THEN** detected instances are presented within 3 seconds (p95)

### Requirement: Redaction model portability
Redaction annotation types (region, style, parameters, per-instance toggle state) MUST live in the platform-agnostic document model with no UI-framework imports, serialized with the document, so redacted documents round-trip through the Library and the future portable format.

#### Scenario: Redactions survive serialization
- **WHEN** a document containing all redaction styles and a text-aware set with mixed toggles is serialized and deserialized
- **THEN** every redaction's region, style, parameters, and toggle state is restored exactly
