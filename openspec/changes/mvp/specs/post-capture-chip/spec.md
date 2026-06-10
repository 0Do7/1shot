# Post-Capture Chip

## ADDED Requirements

### Requirement: Chip appears fast in a configurable corner
After every completed capture (when chip mode is enabled), a preview chip SHALL appear in a user-configurable screen corner showing a thumbnail of the capture. The elapsed time from capture completion to the chip being visible MUST keep the end-to-end hotkey→chip latency under 200 ms at the 95th percentile. The chip SHALL appear on the display where the capture occurred.

#### Scenario: Chip appears after capture
- **WHEN** the user completes a capture with chip mode enabled
- **THEN** a chip with a thumbnail of the capture appears in the configured corner within the latency budget

#### Scenario: Corner is configurable
- **WHEN** the user changes the chip corner setting and takes a capture
- **THEN** the chip appears in the newly configured corner

#### Scenario: Chip appears on the capture's display
- **WHEN** the user captures a region on a secondary display
- **THEN** the chip appears on that secondary display

### Requirement: Chip never steals focus
The chip MUST be displayed without activating the app or taking key/keyboard focus away from the frontmost application. The user's current app SHALL remain frontmost and fully interactive while the chip is visible, including while multiple chips are stacked.

#### Scenario: Typing continues uninterrupted
- **WHEN** the user is typing in another application and a capture completes
- **THEN** the chip appears and every keystroke continues to be delivered to the user's app (excluding only the armed contract keys defined below)
- **AND** the frontmost application does not change

#### Scenario: Chip click does not activate before expand
- **WHEN** the chip is visible and the user continues working in another app
- **THEN** the app owning the chip never becomes the active application until the user explicitly expands or interacts with the chip

### Requirement: Keyboard contract
For a configurable arming window (default 8 seconds) after a capture, the chip SHALL respond to exactly three global keys without requiring focus: Esc discards the capture, ⌘C copies the image to the clipboard and dismisses the chip, and Enter expands the chip in place into the full editor. While armed, the system MUST swallow only these contracted keys; all other keystrokes MUST pass through to the frontmost app unmodified. A visible affordance on the chip MUST indicate that the contract keys are live, and MUST disappear when the arming window ends. The contract SHALL be disableable in settings.

#### Scenario: Esc discards
- **WHEN** the contract is armed and the user presses Esc
- **THEN** the most recent chip is dismissed and its capture is discarded
- **AND** nothing is written to disk and nothing is placed on the clipboard

#### Scenario: Cmd-C copies and dismisses
- **WHEN** the contract is armed and the user presses ⌘C
- **THEN** the capture image is placed on the system clipboard
- **AND** the chip dismisses

#### Scenario: Enter expands into editor
- **WHEN** the contract is armed and the user presses Enter
- **THEN** the chip expands in place into the full annotation editor window
- **AND** the editor window takes keyboard focus

#### Scenario: Contract expires and keys return to the user
- **WHEN** the arming window elapses without a contract key being pressed
- **THEN** the "keys live" affordance disappears
- **AND** subsequent presses of Esc, Enter, and ⌘C are delivered to the frontmost app normally while the chip remains visible per its timeout rules

### Requirement: Hover affordances
WHEN the pointer hovers over a chip, the chip SHALL reveal action affordances for: copy to clipboard, save to file, pin (float the capture), edit (open editor), and a drag handle. Each action MUST be operable with a single click and MUST have a VoiceOver-accessible label.

#### Scenario: Hover reveals actions
- **WHEN** the user hovers the pointer over a chip
- **THEN** copy, save, pin, edit, and drag-handle affordances become visible

#### Scenario: Save action prompts for destination behavior
- **WHEN** the user clicks the save affordance
- **THEN** the capture is written to the configured save location (or a save panel per settings) and the chip reflects the saved state

#### Scenario: Pin action floats the capture
- **WHEN** the user clicks the pin affordance
- **THEN** the capture opens as an always-on-top pinned float and the chip dismisses

### Requirement: Drag-out as file
The user SHALL be able to drag a chip (or its drag handle) into any drop-accepting application or Finder location, delivering the capture as an image file. The file MUST be materialized only when the drop is accepted (file-promise semantics); a cancelled drag MUST leave no file on disk.

#### Scenario: Drag into another app
- **WHEN** the user drags a chip into a Slack message composer
- **THEN** the capture is attached as an image file

#### Scenario: Cancelled drag leaves no file
- **WHEN** the user begins dragging a chip and releases it over a non-accepting area
- **THEN** no file is created anywhere on disk

### Requirement: Multi-capture stacking
WHEN additional captures complete while chips are visible, chips SHALL stack vertically in the configured corner rather than replacing each other. The keyboard contract SHALL apply to the most recent chip. The stack SHALL offer bulk actions: copy all, save all, and dismiss all. Each chip in the stack MUST remain individually actionable.

#### Scenario: Three rapid captures stack
- **WHEN** the user takes three captures in succession
- **THEN** three chips are visible, stacked vertically, each showing its own thumbnail

#### Scenario: Bulk dismiss
- **WHEN** the user invokes the stack's dismiss-all action
- **THEN** all chips dismiss and all undecided captures are discarded with nothing written to disk

#### Scenario: Individual action within a stack
- **WHEN** the user clicks the copy affordance on the middle chip of a three-chip stack
- **THEN** only that capture is copied to the clipboard and only that chip dismisses; the other two remain

### Requirement: Nothing written to disk until decided
The system MUST NOT create any user-facing file for a capture until the user takes an explicit persisting action (save, drag-out drop, an export from the editor, or a configured auto-save destination the user opted into). Discarding a chip (Esc, dismiss, timeout-with-discard configuration) MUST leave zero user-facing file artifacts. The Library's internal index-on-capture storage is exempt as internal app data and MUST NOT appear as a user-facing file in any save location.

#### Scenario: Capture then discard leaves no trace
- **WHEN** the user captures and presses Esc on the chip
- **THEN** no user-visible file exists in the save location, Desktop, or temp-visible directories attributable to that capture

#### Scenario: Copy does not save
- **WHEN** the user presses ⌘C on a chip
- **THEN** the image exists on the clipboard only, with no file written to any user-facing location

### Requirement: Chip persistence and timeout
The chip SHALL be persistent by default (remaining until acted on or dismissed). The user SHALL be able to configure an auto-dismiss timeout instead. The behavior of a timed-out chip (discard vs. configured default action such as copy or save) MUST be a documented, user-configurable setting.

#### Scenario: Persistent chip outlives the arming window
- **WHEN** the arming window elapses and the user takes no action with the default (persistent) configuration
- **THEN** the chip remains visible and actionable via mouse indefinitely

#### Scenario: Timeout dismisses per configuration
- **WHEN** the user configures a 10-second timeout with discard-on-timeout and a capture goes unhandled for 10 seconds
- **THEN** the chip dismisses and the capture is discarded

### Requirement: Chip-off (pure clipboard) mode
The system SHALL offer a mode that disables the chip entirely: every capture is copied directly to the clipboard with a minimal non-focus-stealing confirmation (e.g. a brief toast or sound per settings) and no chip is shown.

#### Scenario: Chip-off capture goes to clipboard
- **WHEN** chip-off mode is enabled and the user completes a capture
- **THEN** the image is placed on the clipboard
- **AND** no chip appears and no file is written

### Requirement: Expand in place into editor
Expanding a chip (Enter or clicking the edit affordance) SHALL open the full annotation editor seeded with that capture, animating from the chip's position. The editor window — unlike the chip — SHALL take focus. The chip for that capture SHALL be removed from the stack upon expansion. The editor MUST be interactive within 400 ms at the 95th percentile from the expand action.

#### Scenario: Expand opens editor with the capture
- **WHEN** the user presses Enter on an armed chip
- **THEN** the editor opens containing exactly that capture's image, focused and interactive within 400 ms (p95)
- **AND** that chip is no longer in the stack

#### Scenario: Expanding one chip leaves the rest of the stack
- **WHEN** three chips are stacked and the user expands the newest
- **THEN** the other two chips remain visible and actionable behind the editor

### Requirement: Chip accessibility
All chip controls (the chip itself, hover affordances, stack bulk actions) MUST expose VoiceOver labels and be reachable by accessibility APIs, and the keyboard contract MUST remain the keyboard-only path for discard/copy/expand.

#### Scenario: VoiceOver reads chip actions
- **WHEN** VoiceOver is enabled and the user navigates to a chip
- **THEN** the chip and each of its actions announce descriptive labels
