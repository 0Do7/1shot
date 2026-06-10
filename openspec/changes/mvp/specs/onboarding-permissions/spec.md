# Onboarding, Permissions & Trust (E12)

## ADDED Requirements

### Requirement: Guided install-location check
On launch, the app SHALL detect whether it is running from /Applications. If it is running from a Downloads folder, a mounted DMG, or any translocated path, onboarding SHALL offer a one-click "Move to Applications" action that moves the bundle and relaunches. The app SHALL NOT request any macOS permission until it is running from a stable install location, so that granted permissions are not invalidated by a later move.

#### Scenario: First launch from mounted DMG
- **WHEN** the user launches the app directly from the mounted DMG
- **THEN** onboarding explains why /Applications matters (permissions stick to the app's location)
- **AND** offers a single "Move to Applications" button that installs and relaunches
- **AND** no permission prompt has been triggered before the move completes

#### Scenario: Already correctly installed
- **WHEN** the app is launched from /Applications
- **THEN** the install-check step is skipped entirely and onboarding proceeds to the next step

#### Scenario: Move fails
- **WHEN** the move to /Applications fails (e.g. insufficient privileges, existing copy running)
- **THEN** the user sees the specific cause and manual instructions
- **AND** onboarding does not proceed to permission steps until resolved or explicitly skipped by the user

### Requirement: Pre-permission explainer screens
For every macOS permission the app uses (Screen Recording, Accessibility, and any future addition), onboarding SHALL show an in-app explainer screen BEFORE the corresponding macOS system prompt can appear. Each explainer SHALL state in plain language: what the permission enables, exactly what the app does and does not do with it (local-only, no telemetry, no uploads), and what happens if the user declines. The system prompt SHALL only be triggered by an explicit user action on the explainer (e.g. a "Continue" button). The app SHALL never trigger a macOS permission dialog as a side effect of an unrelated action.

#### Scenario: Screen Recording explainer precedes the system prompt
- **WHEN** onboarding reaches the Screen Recording step
- **THEN** the explainer screen is shown stating that captures stay on this Mac and nothing is uploaded
- **AND** the macOS prompt appears only after the user clicks the explicit continue action

#### Scenario: User declines a permission
- **WHEN** the user declines Screen Recording at the system prompt
- **THEN** the app shows what is now unavailable and how to grant it later via the permission-health screen
- **AND** the app remains usable for permission-independent features without crashing or re-prompting in a loop

#### Scenario: No surprise prompts
- **WHEN** the user performs any action in the app that would require a not-yet-granted permission
- **THEN** the in-app explainer for that permission is shown first
- **AND** the macOS dialog never appears without a preceding explainer in the same flow

### Requirement: Screen Recording grant flow for the Sequoia/Tahoe re-auth regime
The Screen Recording flow SHALL be designed for macOS versions that periodically re-confirm screen-capture access. The app SHALL detect when its authorization has lapsed or entered a pending re-confirmation state, and SHALL handle the re-auth moment gracefully: a capture attempted during a lapsed state SHALL produce a clear in-app explanation and a one-click path to re-confirm, never a black/empty capture or a silent failure. After the user grants or re-confirms in System Settings, the app SHALL detect the change without requiring the user to hunt for what to do next (including relaunching itself automatically if the OS requires a relaunch for the grant to take effect).

#### Scenario: Periodic re-confirmation lapse
- **WHEN** macOS has expired the app's screen-capture confirmation
- **AND** the user presses a capture hotkey
- **THEN** the app shows a message explaining the OS re-confirmation requirement with a button deep-linking to the relevant System Settings pane
- **AND** no blank or partial capture is produced

#### Scenario: Grant detected live
- **WHEN** the user grants Screen Recording in System Settings while the app's explainer is on screen
- **THEN** the explainer updates to a granted state without manual refresh
- **AND** if the OS requires an app relaunch, the app offers/performs the relaunch and returns the user to where they were in onboarding

#### Scenario: Re-auth never corrupts output
- **WHEN** authorization lapses between two captures in a session
- **THEN** the second capture attempt is blocked with the re-auth explanation
- **AND** nothing is written to the clipboard, disk, or Library for the blocked attempt

### Requirement: Permission-health screen
The app SHALL provide a permission-health screen, reachable from the menu bar and from Settings, showing the live status of every permission the app can use: Screen Recording, Accessibility, and Launch-at-Login state. Each row SHALL show: granted / not granted / needs re-confirmation, what features depend on it, and a deep-link action to the exact System Settings pane. Status SHALL refresh automatically while the screen is visible. The screen SHALL also surface the install-location check result.

#### Scenario: All-green state
- **WHEN** all permissions are granted and the app is in /Applications
- **THEN** every row on the permission-health screen shows a granted indicator
- **AND** no action buttons demand attention

#### Scenario: Lapsed permission surfaces with a fix path
- **WHEN** Screen Recording has entered the needs-re-confirmation state
- **THEN** the permission-health screen shows that row in a warning state naming the affected features (all capture types)
- **AND** its action button opens System Settings directly to Screen Recording

#### Scenario: Live refresh
- **WHEN** the user grants Accessibility in System Settings while the permission-health screen is open
- **THEN** the Accessibility row updates to granted without the user reopening the screen

### Requirement: Hotkey takeover wizard
Onboarding SHALL include a hotkey takeover step that lets the user transfer ⌘⇧3, ⌘⇧4, and ⌘⇧5 from the macOS built-in screenshot tools to the app. The wizard SHALL: (1) read the live state of `com.apple.symbolichotkeys` entries with IDs 28, 29, 30, 31, and 184 to determine which system shortcuts are currently enabled; (2) deep-link the user to the System Settings keyboard-shortcuts pane with instructions for disabling them (the app SHALL NOT silently modify system preference files); (3) re-read the state and display per-shortcut verification such as "⌘⇧3 freed ✓ · ⌘⇧4 freed ✓ · ⌘⇧5 freed ✓"; (4) only register the app's own bindings on a shortcut once it is verified free or the user explicitly accepts a conflict. Skipping the wizard SHALL leave the app on non-conflicting default hotkeys.

#### Scenario: Full takeover happy path
- **WHEN** the user follows the wizard and disables the system shortcuts in System Settings
- **AND** returns to the wizard
- **THEN** each freed shortcut shows a live "freed ✓" verification read from `com.apple.symbolichotkeys`
- **AND** the app binds ⌘⇧3/4/5 to its own capture actions only after verification

#### Scenario: Partial takeover
- **WHEN** the user frees ⌘⇧4 but leaves ⌘⇧5 enabled in the system
- **THEN** the wizard shows ⌘⇧4 as freed and ⌘⇧5 as still taken by macOS
- **AND** the app binds only the freed shortcut and keeps its default binding for the other

#### Scenario: User skips takeover
- **WHEN** the user chooses "keep the system shortcuts" or skips the step
- **THEN** the app uses its own default hotkeys that do not conflict with ⌘⇧3/4/5
- **AND** the wizard remains re-runnable later from Settings

#### Scenario: System state changes after onboarding
- **WHEN** a macOS update or the user re-enables a system screenshot shortcut that the app has bound
- **THEN** the permission-health/hotkey area reports the conflict the next time it is checked
- **AND** offers to re-run the takeover wizard

### Requirement: Lazy Accessibility permission
The app SHALL NOT request Accessibility permission during onboarding or at launch. Accessibility SHALL be requested only at the moment the user first starts a scrolling capture, preceded by its pre-permission explainer (stating it is used solely to synthesize scroll events during scrolling capture). Global hotkeys and all non-scrolling capture types SHALL function without Accessibility. If the user declines, scrolling capture SHALL offer manual-scroll mode, which works without the permission.

#### Scenario: No Accessibility prompt at onboarding
- **WHEN** the user completes the entire onboarding flow without using scrolling capture
- **THEN** macOS has never shown an Accessibility prompt for the app
- **AND** the app does not appear in the Accessibility list in System Settings

#### Scenario: First scrolling capture triggers explainer then prompt
- **WHEN** the user invokes scrolling capture for the first time
- **THEN** the Accessibility explainer is shown first
- **AND** the macOS Accessibility prompt appears only after the user continues

#### Scenario: Decline degrades to manual mode
- **WHEN** the user declines Accessibility
- **THEN** scrolling capture offers manual-scroll mode immediately
- **AND** auto-scroll remains available later via the permission-health screen once granted

### Requirement: First capture inside onboarding
Onboarding SHALL culminate in a guided first capture: immediately after Screen Recording is granted, the flow SHALL prompt the user to take a real capture and SHALL open the result in the editor with a short guided annotation step. The flow MUST be completable — launch to first annotated capture — within 60 seconds for a user who accepts defaults. Onboarding SHALL be skippable at every step, and a skipped onboarding SHALL be resumable from the menu bar.

#### Scenario: Sixty-second first annotation
- **WHEN** a new user launches the app and accepts default choices at each onboarding step
- **THEN** the user has taken a capture and placed at least one annotation on it within 60 seconds of first launch
- **AND** the guided capture used the app's real capture and editor surfaces, not a simulation

#### Scenario: Skip and resume
- **WHEN** the user skips onboarding at the hotkey step
- **THEN** the app is immediately usable with default settings
- **AND** "Finish setup" is available from the menu bar and reopens onboarding at the first incomplete step

#### Scenario: First capture fails
- **WHEN** the guided first capture fails (e.g. permission lapsed mid-flow)
- **THEN** onboarding returns the user to the relevant permission step with an explanation
- **AND** does not mark onboarding complete

### Requirement: Zero telemetry by default
The app SHALL make no analytics, telemetry, tracking, or phone-home network calls by default. The only permitted default network calls are the Sparkle update check (per the user's chosen cadence) and Paddle license activation when the user initiates it. Crash reporting SHALL be strictly opt-in and user-initiated per incident: the app SHALL collect crash payloads locally and offer a "Send diagnostics" action the user explicitly triggers; nothing is auto-submitted. Onboarding SHALL state this privacy posture explicitly. No account creation SHALL exist anywhere in the app.

#### Scenario: Network silence in default configuration
- **WHEN** a fresh install runs through onboarding, captures, edits, and Library use with default settings
- **AND** network traffic from the app is monitored
- **THEN** the only outbound connections observed are Sparkle appcast checks
- **AND** no analytics or telemetry endpoint is ever contacted

#### Scenario: Crash data requires explicit send
- **WHEN** the app crashes and is relaunched
- **THEN** the user is offered a review-and-send diagnostics action showing what would be submitted
- **AND** declining or ignoring it results in no transmission

#### Scenario: No account surface
- **WHEN** the user explores all onboarding screens and settings
- **THEN** no sign-up, sign-in, or account-creation UI exists anywhere

### Requirement: Re-runnable onboarding components
Each onboarding component (install check, permission explainers, hotkey takeover wizard, guided first capture) SHALL be individually re-runnable after onboarding from Settings or the permission-health screen, and SHALL behave correctly when run in an already-configured state.

#### Scenario: Re-run wizard post-setup
- **WHEN** the user re-runs the hotkey takeover wizard weeks after install
- **THEN** it reflects the current live system shortcut state
- **AND** completing or cancelling it leaves existing unrelated settings untouched
