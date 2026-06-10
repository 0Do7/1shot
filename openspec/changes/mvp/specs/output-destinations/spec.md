# Output & Destinations (E11)

## ADDED Requirements

### Requirement: Export format support
The app SHALL export captures in PNG, JPEG, WebP, and HEIC formats. The user SHALL be able to set a default export format globally, and SHALL be able to override the format at the point of any individual export. JPEG, WebP, and HEIC exports SHALL expose a quality setting; PNG SHALL be exported lossless.

#### Scenario: Default format applied on save
- **WHEN** the user has set the default format to WebP
- **AND** the user saves a capture from the chip without choosing a format
- **THEN** the file is written as WebP using the configured quality setting
- **AND** the file extension matches the actual encoded format

#### Scenario: Per-export format override
- **WHEN** the user invokes "Save As" from the editor and selects HEIC
- **THEN** that single export is encoded as HEIC
- **AND** the global default format setting is unchanged

#### Scenario: Format unsupported by destination falls back explicitly
- **WHEN** the user copies an export to the clipboard in a format the pasteboard cannot represent natively (e.g. WebP)
- **THEN** the clipboard receives a PNG representation
- **AND** no silent quality degradation occurs beyond the documented fallback

### Requirement: Retina downscale option
The app SHALL provide a Retina→1x option that exports captures at logical (1x) resolution instead of native backing-store resolution. The option SHALL be settable as a global default and overridable per export. The downscale SHALL use high-quality resampling and SHALL preserve the logical pixel dimensions of the captured region exactly.

#### Scenario: 1x export from a 2x display
- **WHEN** the user captures a 400×300 point region on a 2x Retina display
- **AND** the Retina→1x option is enabled
- **THEN** the exported image is exactly 400×300 pixels
- **AND** the full-resolution original remains available in the Library unchanged

#### Scenario: Mixed-DPI multi-display capture
- **WHEN** a capture spans displays with different scale factors
- **AND** Retina→1x is enabled
- **THEN** the export is rendered at uniform 1x logical resolution with no visible scaling seams at the display boundary

### Requirement: File-size-conscious defaults
Out of the box, the app SHALL ship export defaults tuned for small file size without visible quality loss: PNG output SHALL be optimized (e.g. palette reduction where lossless-safe is not required is NOT permitted — PNG remains lossless, but metadata SHALL be stripped), and lossy formats SHALL default to a quality level documented in settings. Exported files SHALL NOT embed EXIF location data, hardware identifiers, or any user-identifying metadata.

#### Scenario: Default export size sanity
- **WHEN** the user exports a typical full-screen capture with default settings
- **THEN** the resulting file contains no EXIF GPS, serial-number, or username metadata
- **AND** the encoded size is not larger than a baseline unoptimized encode of the same pixels

#### Scenario: Quality default is visible and adjustable
- **WHEN** the user opens export settings
- **THEN** the current default quality value for each lossy format is displayed
- **AND** changing it takes effect on the next export without restart

### Requirement: Filename templates
The app SHALL generate filenames from a user-editable template supporting at minimum these tokens: date, time, capture type, source application name, window title, sequential counter, and Library auto-name. The settings UI SHALL show a live preview of the rendered template. Rendered filenames SHALL be sanitized of characters invalid on macOS and on Windows-portable filesystems (`/ \ : * ? " < > |`), and the app SHALL never overwrite an existing file silently — collisions SHALL be resolved by appending a numeric suffix.

#### Scenario: Template renders with capture context
- **WHEN** the template is `{app}-{date}-{counter}` and the user captures a Safari window on 2026-06-09 as the third capture of the day
- **THEN** the saved filename is `Safari-2026-06-09-3` plus the format extension

#### Scenario: Invalid characters sanitized
- **WHEN** the window title contains `Bug: crash / restart?`
- **AND** the template includes the window-title token
- **THEN** the rendered filename contains no path-separator or reserved characters
- **AND** the file saves successfully

#### Scenario: Collision never overwrites
- **WHEN** a rendered filename already exists in the destination folder
- **THEN** the new file is saved with a numeric suffix (e.g. `name-2.png`)
- **AND** the existing file is untouched

### Requirement: Per-preset save-location rules
The app SHALL support named output presets, each binding a save location, format, Retina→1x setting, and filename template. The user SHALL be able to assign a default preset globally and assign distinct presets per capture type (e.g. scrolling captures to one folder, OCR-source captures to another). When a preset's save location becomes unavailable (deleted folder, unmounted volume), the app SHALL fall back to the default save location and notify the user rather than failing the save.

#### Scenario: Capture type routes to its preset
- **WHEN** the user has assigned a "Docs" preset (folder `~/Docs/shots`, PNG, 1x) to scrolling captures
- **AND** the user completes a scrolling capture and saves it
- **THEN** the file lands in `~/Docs/shots` as a 1x PNG named by the preset's template

#### Scenario: Missing destination folder falls back
- **WHEN** the preset's target folder has been deleted
- **AND** the user saves a capture using that preset
- **THEN** the file is saved to the default save location
- **AND** the user sees a non-blocking notification identifying the unavailable preset location

### Requirement: Destination plugin contract
All output targets SHALL be implemented against a single destination protocol defined in the portable domain core (DarkroomCore). The contract SHALL define: a stable destination identifier, display name and icon reference, accepted payload types (image data, file URL, text), an asynchronous deliver operation returning success or a typed error, optional per-destination configuration schema, and a capability declaration (e.g. returns-a-shareable-URL: yes/no). Registering a new destination SHALL require no changes to capture, chip, or editor code — destinations SHALL be discovered from a registry. The contract MUST be sufficient to host future hosted-cloud and LLM destinations as drop-ins without protocol changes.

#### Scenario: Registry-driven destination menus
- **WHEN** a new destination is registered with the destination registry
- **THEN** it appears in the chip and editor share menus without any modification to chip or editor code
- **AND** its display name and icon come from the plugin's own declaration

#### Scenario: Typed failure surfaces to the user
- **WHEN** any destination's deliver operation fails
- **THEN** the user sees an error message containing the destination name and the typed failure reason
- **AND** the source capture remains intact and re-sendable

#### Scenario: Future destination kinds fit the contract
- **WHEN** a destination declaring the returns-a-shareable-URL capability completes delivery
- **THEN** the returned URL is placed on the clipboard and shown in a confirmation toast
- **AND** this behavior requires no special-casing for that specific destination

### Requirement: Clipboard destination
The app SHALL provide a clipboard destination that places the exported image on the system pasteboard. Copying SHALL respect the active format/Retina settings. Clipboard delivery SHALL complete without writing any file to disk.

#### Scenario: Copy writes nothing to disk
- **WHEN** the user presses ⌘C on the chip
- **THEN** the image is on the pasteboard and immediately pastable into another app
- **AND** no file has been created in any user-visible folder

### Requirement: File destination
The app SHALL provide a file destination that saves the export according to the active output preset (location, format, template). After a save, the user SHALL be able to reveal the file in Finder from the confirmation surface.

#### Scenario: Save then reveal
- **WHEN** the user saves a capture via the file destination
- **THEN** the file exists at the preset's location with the templated name
- **AND** a "Reveal in Finder" action is offered and opens the enclosing folder with the file selected

### Requirement: App hand-off destination
The app SHALL provide an app hand-off destination that opens the exported capture in a user-chosen application (e.g. Preview, an image editor, a chat client) via the standard open-with mechanism, materializing a file only at hand-off time. The user SHALL be able to pin favorite hand-off apps for one-click access.

#### Scenario: Hand off to a pinned app
- **WHEN** the user has pinned an image editor as a hand-off target
- **AND** the user invokes hand-off from the chip
- **THEN** the capture opens in that application
- **AND** the file passed to it reflects the active format and Retina settings

#### Scenario: Hand-off target missing
- **WHEN** a pinned hand-off application has been uninstalled
- **THEN** invoking it shows an explicit error naming the missing app
- **AND** the user is offered the picker to choose a replacement

### Requirement: S3 / custom-endpoint upload destination
The app SHALL provide an upload destination targeting S3-compatible storage using credentials supplied entirely by the user (endpoint URL, region, bucket, access key, secret, optional path prefix, optional public-URL pattern). The app vendor SHALL bear zero hosting cost: no vendor-operated relay, proxy, or storage is involved; uploads go directly from the user's machine to the user's endpoint. Credentials SHALL be stored in the macOS Keychain and SHALL never leave the device except in the upload request itself. The destination SHALL provide a connection test, and after a successful upload SHALL copy the resulting object URL (per the user's URL pattern) to the clipboard.

#### Scenario: Configure and test connection
- **WHEN** the user enters endpoint, bucket, and credentials and runs the connection test
- **THEN** the app performs a minimal authenticated request against the endpoint
- **AND** reports success or the specific failure (DNS, auth, bucket access, TLS) without storing an unverified "working" state

#### Scenario: Upload returns a usable URL
- **WHEN** the user sends a capture to a configured S3 destination
- **THEN** the object is uploaded directly to the user's endpoint under the configured prefix
- **AND** the rendered public URL is placed on the clipboard and shown in a toast

#### Scenario: Upload failure is honest and recoverable
- **WHEN** the upload fails mid-transfer (network drop, 403, quota)
- **THEN** the user sees the failure cause and a retry action
- **AND** the capture is not lost and no partial-success URL is copied

#### Scenario: Credentials live in Keychain only
- **WHEN** the user inspects the app's settings files on disk
- **THEN** no S3 secret key material appears in any preferences or support file
- **AND** removing the destination deletes its Keychain items

### Requirement: Deferred destination hooks remain dormant
The destination registry SHALL ship with only clipboard, file, app hand-off, and S3/custom-endpoint destinations enabled. Hosted-cloud and LLM destination kinds SHALL NOT appear in any UI, SHALL initiate no network calls, and SHALL exist only as protocol capacity. No destination SHALL perform network access except the explicitly user-configured S3/custom-endpoint destination.

#### Scenario: No dormant destinations in UI
- **WHEN** the user opens every share/output menu in the app
- **THEN** only clipboard, file, app hand-off, and configured S3/custom destinations are listed

#### Scenario: Network surface is limited to configured uploads
- **WHEN** the user has not configured an S3/custom destination
- **AND** the user exercises every output path
- **THEN** the destination subsystem makes zero network connections
