# Utilities & Settings (E13)

## ADDED Requirements

### Requirement: Hide desktop icons and widgets toggle
The app SHALL provide a toggle that hides all desktop icons and desktop widgets, available from the menu bar, as a bindable hotkey, and as a pre-capture option. The toggle SHALL take effect within 1 second, SHALL persist across app restarts until toggled back, and SHALL restore the desktop to its exact prior state (icons and widgets) when disabled. If the app quits or crashes while the desktop is hidden, the next launch SHALL surface the hidden state so the user is never left with a mysteriously empty desktop.

#### Scenario: Toggle from menu bar
- **WHEN** the user enables "Hide desktop icons & widgets" from the menu bar
- **THEN** all desktop icons and widgets are hidden on all displays within 1 second
- **AND** disabling the toggle restores them to their prior arrangement

#### Scenario: State survives restart honestly
- **WHEN** the desktop is hidden and the app is quit and relaunched
- **THEN** the desktop remains hidden
- **AND** the menu-bar item clearly indicates the hidden state with a one-click restore

#### Scenario: Hide for a single capture
- **WHEN** the user enables the per-capture "hide desktop" option and takes a fullscreen capture
- **THEN** the captured image contains no desktop icons or widgets
- **AND** the desktop returns to its prior state after the capture completes

### Requirement: Transient capture history tray
The app SHALL maintain a transient history tray showing the last N captures of the current session as a visual strip (N user-configurable, with a documented default). Tray items SHALL support the same quick actions as the chip (copy, save, edit, pin, drag-out) and a "Save to Library" funnel action. The tray SHALL be transient: items it holds that were never saved or sent to the Library SHALL be discarded when they age out of the last-N window or when the app quits, consistent with the nothing-on-disk-until-decided principle. The tray SHALL be openable via menu bar and a bindable hotkey.

#### Scenario: Recent captures appear and act
- **WHEN** the user takes three captures and opens the history tray
- **THEN** the three captures appear newest-first as thumbnails
- **AND** pressing copy on any item places that image on the clipboard

#### Scenario: Funnel into Library
- **WHEN** the user clicks "Save to Library" on a tray item
- **THEN** the capture is persisted to the Library with full OCR indexing and provenance
- **AND** the item is marked in the tray as saved

#### Scenario: Transience respected
- **WHEN** the user takes more captures than the configured N without saving them
- **THEN** the oldest unsaved items disappear from the tray and their image data is discarded
- **AND** quitting the app discards all remaining unsaved tray items

### Requirement: Opinionated defaults with progressive disclosure
Settings SHALL ship with opinionated defaults such that a user who never opens Settings gets the full intended experience. The Settings UI SHALL be organized in two tiers: a primary tier exposing only the high-frequency choices (hotkeys, save location, default format, chip behavior, update cadence), and an "Advanced" disclosure per section for everything else. Every setting SHALL display its default and SHALL be individually resettable; a "Reset all to defaults" action SHALL exist and SHALL require confirmation.

#### Scenario: Zero-configuration usability
- **WHEN** a new user completes onboarding and never opens Settings
- **THEN** capture, chip, editor, Library, and export all function with the documented defaults

#### Scenario: Advanced options stay hidden until asked
- **WHEN** the user opens a Settings section
- **THEN** only the primary-tier options are visible
- **AND** the advanced options appear only after expanding that section's disclosure

#### Scenario: Reset to defaults
- **WHEN** the user invokes "Reset all to defaults" and confirms
- **THEN** every setting returns to its shipped default
- **AND** Library contents, license state, and capture history are NOT affected

### Requirement: Launch at login
The app SHALL offer a launch-at-login setting using the macOS service-management mechanism (visible to the user in System Settings > Login Items). Onboarding SHALL offer it once; it SHALL default to off until the user accepts. The in-app toggle SHALL reflect the true system state, including when the user changes it from System Settings directly.

#### Scenario: Enable launch at login
- **WHEN** the user enables launch-at-login in Settings
- **THEN** the app appears in System Settings Login Items
- **AND** the app launches automatically at the next login

#### Scenario: External change is reflected
- **WHEN** the user disables the app's login item from System Settings
- **THEN** the in-app toggle shows it as off the next time Settings is viewed

### Requirement: Hideable menu-bar icon
The app SHALL display a menu-bar icon as its primary surface, and SHALL allow the user to hide it. When hidden, the app SHALL remain fully operable via hotkeys, and the settings window SHALL be reachable by relaunching the app (opening the app while it is running SHALL bring up Settings/onboarding rather than a second instance). The hide control SHALL warn the user how to get back before applying.

#### Scenario: Hide and recover
- **WHEN** the user hides the menu-bar icon
- **THEN** a confirmation explains that relaunching the app from /Applications reopens Settings
- **AND** after hiding, hotkey captures continue to work
- **AND** opening the app again shows the Settings window with a control to restore the icon

#### Scenario: Single-instance guarantee
- **WHEN** the app is running with a hidden icon and the user opens it from Finder
- **THEN** no second instance starts
- **AND** the running instance presents its Settings window

### Requirement: Hotkey configuration
Settings SHALL provide a hotkey editor listing every bindable action (all capture types, OCR, pin, history tray, hide-desktop, hide/show-all-pins) with its current binding. The editor SHALL detect conflicts between the app's own bindings and refuse to save a duplicate, and SHALL allow clearing a binding. Hotkey registration SHALL NOT require Accessibility permission.

#### Scenario: Rebind an action
- **WHEN** the user records a new shortcut for area capture
- **THEN** the new shortcut triggers area capture immediately without app restart
- **AND** the old shortcut no longer does

#### Scenario: Internal conflict refused
- **WHEN** the user tries to assign a shortcut already bound to another app action
- **THEN** the editor identifies the conflicting action and does not save the duplicate binding

### Requirement: Settings persistence and portability
All settings SHALL persist across launches and app updates. The app SHALL provide export and import of settings (including output presets and hotkeys, excluding Keychain-held secrets and license state) as a single file, for migration to another Mac.

#### Scenario: Settings survive update
- **WHEN** the user updates the app via Sparkle
- **THEN** every customized setting retains its value after the update

#### Scenario: Export/import round trip
- **WHEN** the user exports settings on one Mac and imports the file on another
- **THEN** hotkeys, presets, and preferences match the source machine
- **AND** S3 credentials and license activation are not contained in the exported file
