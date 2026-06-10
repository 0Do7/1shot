## ADDED Requirements

### Requirement: Rulers with edge snapping
The editor SHALL provide horizontal and vertical ruler guides that can be placed anywhere on the image and that snap to detected high-contrast edges in the underlying pixels when dragged near them. Snapping SHALL be visibly indicated and SHALL be temporarily disabled while a documented modifier key is held. Each ruler SHALL display its position, and the gap between adjacent parallel rulers SHALL display as a pixel distance.

#### Scenario: Ruler snaps to a UI edge
- **WHEN** the user drags a vertical ruler to within a few pixels of a button's edge in the image
- **THEN** the ruler snaps precisely onto the detected edge
- **AND** a visual snap indication is shown

#### Scenario: Modifier bypasses snapping
- **WHEN** the user drags a ruler with the snap-override modifier held
- **THEN** the ruler follows the cursor exactly without snapping

#### Scenario: Distance between rulers
- **WHEN** two parallel rulers are placed
- **THEN** the pixel distance between them is displayed

### Requirement: Stampable rulers
The app SHALL allow stamping placed rulers and their measurement labels into the image as annotation objects, so they survive export and are visible to recipients. Stamped rulers SHALL be ordinary annotations: re-editable, movable, and deletable until export flattening; non-stamped rulers MUST NOT appear in exported output.

#### Scenario: Stamp a ruler into the export
- **WHEN** the user stamps a ruler and exports the image
- **THEN** the exported image contains the ruler line and its measurement label

#### Scenario: Unstamped rulers excluded from export
- **WHEN** the user exports with un-stamped guide rulers present
- **THEN** the exported image contains no ruler graphics

#### Scenario: Stamped ruler stays editable
- **WHEN** the user reopens the document from the Library
- **THEN** previously stamped rulers can still be moved or deleted

### Requirement: Distance measurement tool
The editor SHALL provide a measurement tool that reports the pixel distance between two points (drag-defined), displaying width, height, and diagonal length of the dragged span. Measurement endpoints SHALL participate in edge snapping. Measurements SHALL be stampable as annotations under the same rules as rulers.

#### Scenario: Measure a drag span
- **WHEN** the user drags the measurement tool from one point to another
- **THEN** the live readout shows Δx, Δy, and the diagonal distance in pixels

### Requirement: Smart object selection measurement
The app SHALL detect rectangular UI objects (buttons, cards, images, text blocks) under the cursor in the captured pixels and, in smart-selection mode, highlight the hovered object's bounds with its width × height; a click SHALL lock the measurement, and measuring between two detected objects SHALL report the gap between their edges. When no object is detected under the cursor, the tool SHALL indicate this and fall back to manual drag measurement — it MUST NOT report a guessed bounding box as confident.

#### Scenario: Hover measures a button
- **WHEN** the user hovers a button in the screenshot with smart selection active
- **THEN** the button's detected bounds are highlighted with its width × height in pixels

#### Scenario: Gap between two objects
- **WHEN** the user selects one detected object and then a second
- **THEN** the edge-to-edge spacing between them is displayed

#### Scenario: No object detected
- **WHEN** the cursor is over a region with no detectable object
- **THEN** no object highlight is shown and drag-measurement remains available

### Requirement: Logical vs retina pixel toggle
All pixel readouts (rulers, measurements, object sizes, coordinates) SHALL be displayable in either physical (retina) pixels or logical points, with a single toggle that switches every readout consistently and persists across sessions. The active unit SHALL be visibly labeled wherever values are shown, and on a 2x capture the two modes MUST differ by exactly the capture's scale factor.

#### Scenario: Toggle from retina to logical
- **WHEN** a measurement reads 200 px on a 2x-scale capture and the user toggles to logical units
- **THEN** the same measurement reads 100 pt
- **AND** all other visible readouts switch units simultaneously

#### Scenario: Unit choice persists
- **WHEN** the user relaunches the app after selecting logical units
- **THEN** new measurements display in logical units

### Requirement: Color picker with hex, RGB, and OKLCH
The editor SHALL provide an eyedropper color picker with a magnified loupe that reports the pixel under the cursor in hex, RGB, and OKLCH simultaneously, with a persistent setting for which format the copy action uses. Copying SHALL place exactly the formatted color string on the clipboard and confirm with non-blocking feedback. Sampled colors SHALL accumulate in a session history from which any prior sample can be re-copied.

#### Scenario: Pick and copy a color as hex
- **WHEN** the user picks a pixel with copy-format set to hex and invokes copy
- **THEN** the clipboard contains the color as a hex string (e.g. `#1A73E8`)
- **AND** a confirmation is shown without stealing focus

#### Scenario: All three formats visible
- **WHEN** the loupe is over a pixel
- **THEN** hex, RGB, and OKLCH values for that pixel are all displayed

#### Scenario: Re-copy from history
- **WHEN** the user has sampled three colors and selects an earlier one from the history
- **THEN** that color is copied in the active format

### Requirement: Copy never doubles as destructive dismissal
No keystroke in the pixel tools SHALL be overloaded to both copy a value and close or dismiss the window/document (explicitly avoiding Shottr's Tab-copies-and-closes lost-work footgun). Copy actions MUST leave the window open and the document state untouched; window-closing keystrokes MUST be distinct from copy keystrokes; and closing a window with unexported annotation changes SHALL follow the editor's unsaved-changes behavior rather than discarding silently.

#### Scenario: Copy keeps the window open
- **WHEN** the user copies a color or measurement via its keyboard shortcut
- **THEN** the value is on the clipboard
- **AND** the window remains open with all annotations and tool state intact

#### Scenario: No shared copy/close keystroke
- **WHEN** the keyboard shortcut map is inspected
- **THEN** no single unmodified keystroke is bound to both a copy action and a close/dismiss action in any pixel-tool context

### Requirement: WCAG and APCA contrast checker
The app SHALL provide a contrast checker that takes two sampled colors (foreground and background, pickable from the image or entered manually) and reports: the WCAG 2.x contrast ratio with AA/AAA pass-fail badges for normal and large text, and the APCA Lc value with its associated usage guidance. Swapping foreground and background SHALL be a one-action operation, and the full result SHALL be copyable as text.

#### Scenario: Check two picked colors
- **WHEN** the user picks a text color and its background color from a screenshot
- **THEN** the WCAG ratio (e.g. 4.6:1) with AA/AAA pass-fail indicators and the APCA Lc value are displayed

#### Scenario: Swap foreground and background
- **WHEN** the user invokes swap
- **THEN** the WCAG ratio is unchanged and the APCA value updates to reflect the reversed polarity

#### Scenario: Copy the contrast report
- **WHEN** the user invokes copy on the contrast result
- **THEN** the clipboard contains both colors, the WCAG ratio with pass levels, and the APCA value as text

### Requirement: Pixel tools available without a paid tier
All pixel tools in this capability SHALL be available in the free/trial-expired state on the same terms as the rest of the app's post-expiry behavior and MUST NOT be gated as a separate paid add-on within any license tier.

#### Scenario: No upsell gate on pixel tools
- **WHEN** a licensed user opens any pixel tool
- **THEN** the tool functions fully with no additional purchase prompt
