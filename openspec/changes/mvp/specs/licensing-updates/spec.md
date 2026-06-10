# Licensing, Trial & Updates (E15)

## ADDED Requirements

### Requirement: Paddle license activation
The app SHALL activate licenses by validating a Paddle license key against the Paddle API and caching a cryptographically signed local receipt. Activation SHALL require only the license key — no account, no email login inside the app. The signed receipt SHALL be verified locally on each launch; a receipt that fails signature verification SHALL be treated as absent, not as a crash.

#### Scenario: Successful activation
- **WHEN** the user enters a valid Paddle license key with a seat available
- **THEN** the app validates it against Paddle, stores a signed local receipt, and shows the license as active
- **AND** no further network call is required for normal use

#### Scenario: Invalid key
- **WHEN** the user enters an invalid or revoked key
- **THEN** activation fails with a human-readable reason
- **AND** the app's current trial/license state is unchanged

#### Scenario: Tampered receipt
- **WHEN** the local receipt file has been modified
- **THEN** signature verification fails and the app behaves as unlicensed
- **AND** the user is prompted to re-activate rather than shown an error crash

### Requirement: Three-seat management with self-serve activate/deactivate
Each license SHALL permit activation on up to 3 Macs, with seat counting performed server-side via the Paddle activations records. The app SHALL provide in-app self-serve deactivation that frees the seat immediately. When activation fails because all seats are used, the app SHALL display which activations exist (machine names/dates as available) and how to free a seat, including a path that works when an old machine is no longer accessible.

#### Scenario: Activate within seat limit
- **WHEN** a key with 1 of 3 seats used is activated on a second Mac
- **THEN** activation succeeds and the seat count becomes 2 of 3

#### Scenario: Seat limit reached
- **WHEN** activation is attempted on a fourth Mac
- **THEN** activation is refused with a message listing existing activations
- **AND** instructions are shown for freeing a seat, including for an inaccessible machine

#### Scenario: Self-serve deactivation
- **WHEN** the user deactivates the license in-app
- **THEN** the seat is released server-side and the local receipt is removed
- **AND** the app returns to its appropriate trial/expired state

### Requirement: Fourteen-day offline grace
A licensed app SHALL function fully offline. Periodic receipt revalidation SHALL be tolerant: if the app cannot reach Paddle, the license SHALL remain fully valid for at least 14 days from the last successful validation before showing any warning. After the grace period without contact, the app SHALL warn but SHALL degrade no further than the documented unlicensed-capture rules, and SHALL recover to fully-licensed automatically on the next successful validation.

#### Scenario: Two weeks offline
- **WHEN** a licensed Mac is offline for 13 days
- **THEN** all features work with no warnings or nags

#### Scenario: Grace exceeded then restored
- **WHEN** validation has been impossible for more than 14 days
- **THEN** the app shows a single clear notice about the validation lapse
- **AND** the first successful revalidation clears the notice and restores normal state without user action beyond connectivity

### Requirement: Fourteen-day full-featured trial
A new install SHALL begin a 14-day trial with every feature enabled — no watermarks, no capability locks, no nag interstitials during the trial. Remaining trial days SHALL be visible on demand (menu bar/about/settings), not via interruptive pop-ups. The trial start SHALL be recorded redundantly (receipt store plus Keychain) to defeat casual resets; the app SHALL NOT employ invasive fingerprinting beyond this.

#### Scenario: Trial is the full product
- **WHEN** a user exercises capture, editor, scrolling capture, Library, and exports during the trial
- **THEN** no feature is restricted and no watermark appears on any output

#### Scenario: Trial status discoverable not intrusive
- **WHEN** 5 trial days remain
- **THEN** the remaining days are visible in the menu-bar/about surface
- **AND** no modal or capture-interrupting reminder has been shown

#### Scenario: Casual reset defeated
- **WHEN** the user deletes the app's preference files and relaunches during or after the trial
- **THEN** the trial clock is restored from the Keychain mirror rather than restarting

### Requirement: Dignified trial expiry
On trial expiry, the app SHALL enter a 24-hour capture grace period during which capture continues to work and the user is informed once. After the grace period, capture functionality SHALL be disabled until a license is activated; however the Library, viewing, search, annotation editing of existing items, and export of all existing data SHALL remain accessible forever. Expiry messaging SHALL be respectful: factual copy, a purchase link, and a dismiss — no mascots, no guilt copy, no repeated interruptions, and the user's data SHALL never be held hostage.

#### Scenario: 24-hour grace
- **WHEN** the trial expires while a user is mid-workday
- **THEN** capture continues to work for 24 more hours
- **AND** the user sees one clear notice that the trial has ended and capture stops after the grace period

#### Scenario: Post-grace state
- **WHEN** the grace period has elapsed without activation
- **THEN** capture hotkeys and capture entry points show a single licensing notice when invoked
- **AND** Library search, item viewing, re-editing, and export all still function

#### Scenario: Data never hostage
- **WHEN** a user with an expired trial exports their entire Library
- **THEN** every capture exports at full quality with no watermark or restriction
- **AND** this remains true indefinitely after expiry

### Requirement: Feature-year license model with free bug fixes forever
A license SHALL include all feature updates released within its covered feature window (1 year from purchase). Releases SHALL distinguish bug-fix updates from feature releases: bug-fix releases (patch-level, including security and OS-compatibility fixes) SHALL install on every license regardless of the license's update window — "bug fixes are always free, forever." Only releases introducing new feature-years SHALL be gated. A license outside its update window SHALL continue running its owned versions and receiving bug fixes for them indefinitely; features already owned SHALL never deactivate.

#### Scenario: Bug fix after window lapses
- **WHEN** a user's 1-year update window ended 6 months ago
- **AND** a bug-fix release is published for their owned feature version
- **THEN** Sparkle offers and installs the update normally

#### Scenario: Feature release gated honestly
- **WHEN** a feature-year release outside the user's window is published
- **THEN** the update UI shows it as available with upgrade pricing
- **AND** declining leaves the current version fully functional with no nagging

#### Scenario: Owned features never deactivate
- **WHEN** a license's update window expires
- **THEN** every feature present in the user's installed version continues to work permanently
- **AND** no deactivation, re-validation downgrade, or renewal prompt blocks usage

### Requirement: Sparkle 2 auto-updates with user-controlled cadence
The app SHALL use Sparkle 2 with an EdDSA-signed appcast for updates. The user SHALL control the cadence: automatic check-and-install, check-and-notify, or manual-only, plus a "Check now" action. Update checks SHALL transmit no identifying data beyond what Sparkle requires for appcast retrieval. The appcast SHALL retain at least the last 3 releases so users can remain on a prior version, and every update SHALL display its release notes before install in notify/manual modes.

#### Scenario: Cadence respected
- **WHEN** the user selects manual-only updates
- **THEN** the app performs no scheduled update checks
- **AND** "Check now" still works on demand

#### Scenario: Signed updates only
- **WHEN** an appcast item fails EdDSA signature verification
- **THEN** the update is rejected and not installed
- **AND** the user is not silently left on a partially-applied update

#### Scenario: Release notes before install
- **WHEN** an update is found in check-and-notify mode
- **THEN** the release notes for the new version are shown before the user confirms installation

### Requirement: Homebrew cask distribution
The app SHALL be installable via a Homebrew cask at public launch. The cask SHALL install the same notarized build as the direct download, and new releases SHALL be reflected in the cask within the release process (automated version/checksum bump). An app installed via Homebrew SHALL update cleanly via either Sparkle or `brew upgrade` without state loss.

#### Scenario: Cask install parity
- **WHEN** a user installs via `brew install --cask`
- **THEN** the installed app is the identical notarized bundle offered for direct download
- **AND** onboarding, licensing, and updates behave identically

#### Scenario: Brew upgrade preserves state
- **WHEN** a Homebrew-installed user upgrades via `brew upgrade`
- **THEN** settings, license activation, and the Library are intact after upgrade

### Requirement: Public changelog
Every release SHALL be accompanied by an entry on a public changelog page, generated from the release notes, clearly marking each release as bug-fix or feature release with its date and version. The in-app update UI SHALL link to the public changelog.

#### Scenario: Changelog entry per release
- **WHEN** any release is published
- **THEN** the public changelog page lists it with version, date, type (bug-fix or feature), and notes matching the Sparkle release notes

### Requirement: Licensing network surface is minimal and explicit
The licensing subsystem SHALL contact only the Paddle API, and only on: user-initiated activation/deactivation, and background receipt revalidation no more often than the documented interval. Licensing calls SHALL contain no usage analytics, capture metadata, or Library information. All licensing functionality SHALL be testable against a mock server (no hard-coded production-only behavior).

#### Scenario: Payload audit
- **WHEN** licensing network traffic is inspected during activation and revalidation
- **THEN** requests contain only the license key, activation/seat identifiers, and app version
- **AND** no usage, capture, or device-profiling data is present
