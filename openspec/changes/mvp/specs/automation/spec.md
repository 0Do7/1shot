# Automation Surface (E14)

## ADDED Requirements

### Requirement: AppIntents action catalog
The app SHALL expose its core actions as native AppIntents so they are available in Shortcuts and as Spotlight actions. The catalog MUST include at minimum: capture area (interactive), capture window (interactive), capture fullscreen, repeat last area, start scrolling capture, OCR region to text, OCR an input image to text, pin an image, hide/show all pins, and search the Library by text. Capture intents SHALL return the captured image as an output usable by subsequent Shortcuts steps; OCR intents SHALL return the recognized text.

#### Scenario: Capture intent feeds a shortcut
- **WHEN** a Shortcuts workflow runs "Capture Fullscreen" followed by a save-to-folder step
- **THEN** the intent returns the captured image to the workflow
- **AND** the workflow completes without the app's own chip or editor blocking it

#### Scenario: OCR intent returns text
- **WHEN** a workflow passes an image file to the "Extract Text" intent
- **THEN** the intent returns the recognized text as a string output
- **AND** recognition runs entirely on-device

#### Scenario: Spotlight action invocation
- **WHEN** the user invokes an app action surfaced in Spotlight (e.g. "Capture Area")
- **THEN** the corresponding capture flow starts exactly as if triggered by its hotkey

#### Scenario: Intent without required permission
- **WHEN** a capture intent runs while Screen Recording is not granted
- **THEN** the intent fails with an explicit error message naming the missing permission
- **AND** no blank image is returned to the workflow

### Requirement: Intent results respect app privacy posture
AppIntents SHALL operate within the app's local-first constraints: no intent SHALL transmit data over the network except via an explicitly user-configured destination, and intents SHALL respect the nothing-on-disk-until-decided rule by writing files only when the intent's contract is to produce a file.

#### Scenario: Clipboard intent leaves no file
- **WHEN** a workflow runs a capture intent whose output is consumed in-memory by the next step
- **THEN** no file is written to any user-visible location by the intent itself

### Requirement: URL-scheme API disabled by default
The app SHALL register a URL scheme exposing an automation API, and this API SHALL be OFF by default. Incoming scheme requests while disabled SHALL be ignored except for a single non-actionable notice telling the user where to enable the feature. Enabling SHALL require an explicit toggle in Settings accompanied by a plain-language explanation that other apps on the Mac will be able to trigger captures. Actions with side effects beyond the app (e.g. capture) SHALL be confirmable: the user SHALL be able to choose between always-confirm and silent operation per enabled scheme action.

#### Scenario: Scheme call while disabled
- **WHEN** another app opens a oneshot URL while the URL API is disabled
- **THEN** no capture or other action occurs
- **AND** the app shows a notice explaining the API is off and where to enable it

#### Scenario: Explicit enable
- **WHEN** the user enables the URL-scheme API in Settings
- **THEN** the toggle's explanation states that any app can invoke the enabled actions
- **AND** subsequent valid scheme calls perform their actions

#### Scenario: Confirmation mode
- **WHEN** the URL API is enabled with always-confirm mode
- **AND** a scheme call requests a fullscreen capture
- **THEN** the app asks the user to approve before capturing

### Requirement: Documented URL-scheme surface
The URL-scheme API surface SHALL be versioned and documented (parameters, defaults, return behavior, error behavior) in user-facing documentation shipped with the app or published on the product site. The scheme MUST cover at minimum: trigger each capture type, OCR region, pin image at path or pasteboard, open Library search with a query, and open Settings to a named pane. Malformed or unknown scheme requests SHALL fail safely with no action and no crash. Callbacks (x-callback-url style success/error returns) SHALL be supported so callers can receive results.

#### Scenario: Documented call works as documented
- **WHEN** a caller invokes the documented capture-area URL with a documented format parameter
- **THEN** the behavior matches the published documentation for that scheme version

#### Scenario: Malformed request fails safely
- **WHEN** a scheme call arrives with an unknown action or invalid parameters
- **THEN** the app performs no action and does not crash
- **AND** if a callback URL was supplied, the caller receives a descriptive error callback

#### Scenario: Caller receives results
- **WHEN** a scheme call requests OCR with an x-success callback
- **THEN** on completion the app invokes the callback with the recognized text (or the result reference as documented)

### Requirement: Raycast and Alfred extension support points
The app SHALL provide the integration surface required for Raycast and Alfred extensions at launch: every extension-relevant action SHALL be reachable headlessly via AppIntents and/or the URL scheme, including Library search returning results that can be displayed and opened from the launcher. The vendor SHALL publish a Raycast extension and an Alfred workflow at launch built solely on these public surfaces (no private hooks), so third parties can build equivalents.

#### Scenario: Launcher-driven capture
- **WHEN** the user triggers "Capture Area" from the Raycast extension
- **THEN** the area-selection overlay appears with the launcher window dismissed
- **AND** the resulting capture follows the user's normal chip/output configuration

#### Scenario: Launcher Library search
- **WHEN** the user searches "stripe webhook" from the Alfred workflow
- **THEN** matching Library items are returned for display in the launcher
- **AND** selecting one opens that item in the app

#### Scenario: Public-surface parity
- **WHEN** a third-party developer inspects the published extensions
- **THEN** every capability they use is available through the documented AppIntents or URL-scheme surface

### Requirement: Automation respects trial and license state
Automation entry points (intents, URL scheme, launcher extensions) SHALL enforce the same trial/license capture rules as interactive use. When capture is disabled by trial expiry, automation capture calls SHALL fail with an explicit licensing error rather than silently doing nothing; Library search and export automation SHALL continue to work after expiry.

#### Scenario: Expired trial blocks automated capture honestly
- **WHEN** the trial has fully expired and a Shortcuts workflow runs a capture intent
- **THEN** the intent fails with an error stating that capture requires a license
- **AND** a Library-search intent in the same workflow still returns results
