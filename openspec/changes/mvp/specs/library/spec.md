## ADDED Requirements

### Requirement: Local-only library with no cloud, account, or network dependency
The Library SHALL store its entire index in a local SQLite database (FTS5 full-text index) on the user's machine. All Library functionality — indexing, search, browsing, filtering, reopening — MUST work with zero network connectivity, MUST NOT require any account or sign-in, and the Library subsystem MUST NOT initiate any network request. No capture pixels, OCR text, names, or metadata SHALL ever leave the machine through this capability.

#### Scenario: Full functionality offline
- **WHEN** the machine has no network connectivity and the user searches, filters, and reopens Library items
- **THEN** every Library operation completes with full functionality

#### Scenario: No network traffic from the Library
- **WHEN** Library indexing and search activity is exercised while network traffic is monitored
- **THEN** the Library subsystem generates no outbound network requests

### Requirement: Transparent on-disk storage — references, never a vault
Library media SHALL be stored as user-visible files (image files and `.1shot` annotation bundles) in a user-browsable folder on disk; the database SHALL store references and index data, never the only copy of an image. A reveal-in-Finder action SHALL exist for every item. If the user moves or deletes a file externally, the Library SHALL detect the missing file and mark the item accordingly rather than crashing or showing stale thumbnails as live; deleting an item from the Library SHALL state what happens to the underlying file and behave accordingly.

#### Scenario: Files are user-visible
- **WHEN** the user opens the Library storage folder in Finder
- **THEN** each Library item's media exists as an ordinary file openable by other applications

#### Scenario: Reveal in Finder
- **WHEN** the user invokes reveal-in-Finder on a Library item
- **THEN** Finder opens with that item's file selected

#### Scenario: Externally deleted file
- **WHEN** a file referenced by the Library is deleted in Finder and the user later selects that item
- **THEN** the Library indicates the file is missing and offers to remove the dangling entry, without crashing

### Requirement: OCR indexing at save
Every capture saved to the Library SHALL have on-device OCR run over its pixels and the recognized text stored in the FTS5 index, automatically and without user action. Indexing SHALL be asynchronous and MUST NOT delay the capture flow or the chip; an item whose OCR is still pending SHALL already be present and findable by name/metadata, becoming text-searchable when indexing completes. Indexing failures on individual items MUST NOT block indexing of subsequent items.

#### Scenario: Capture text becomes searchable
- **WHEN** the user captures a window containing the text "stripe webhook error" and saves it to the Library
- **THEN** within a short background interval, searching "stripe webhook" returns that capture

#### Scenario: Indexing never blocks capture
- **WHEN** a capture is taken while previous items are still being OCR-indexed
- **THEN** the chip appears within its latency budget and the new capture queues for indexing

#### Scenario: One bad item does not poison the queue
- **WHEN** OCR fails on a corrupt or unreadable item
- **THEN** that item is marked as not-text-indexed and indexing continues for other items

### Requirement: Full-text search of pixels with instant results
The Library SHALL provide a search field querying the FTS5 index across OCR text, item names, tags, and provenance fields, returning ranked results as the user types. Search over a 10,000-item library SHALL return results in under 50 ms per query. Results SHALL show a thumbnail and indicate why each item matched (e.g. highlighted matching OCR snippet). Searches with no matches SHALL state so explicitly; prefix matching SHALL work so partial words return results while typing.

#### Scenario: Search by words that were only ever pixels
- **WHEN** the user types "stripe webhook" into Library search
- **THEN** captures whose image contains that text appear in the results with the matching snippet indicated

#### Scenario: 50 ms search budget at 10k items
- **WHEN** a search query runs against a library of 10,000 indexed items
- **THEN** results are returned in under 50 ms

#### Scenario: Live results while typing
- **WHEN** the user has typed only "webho"
- **THEN** items matching the prefix are already shown

#### Scenario: Empty result honesty
- **WHEN** a query matches nothing
- **THEN** an explicit no-results state is shown rather than a blank or stale list

### Requirement: Heuristic auto-naming without AI
Every capture saved to the Library SHALL receive an automatically generated, human-meaningful filename derived purely heuristically — combining source application, window title, and the highest-signal OCR tokens — sanitized into a filesystem-safe slug (e.g. `stripe-webhook-error.png`). The heuristic MUST NOT invoke any LLM or generative model, on-device or remote. Name collisions SHALL be resolved deterministically (e.g. numeric suffix). The user SHALL be able to rename any item, and a manual rename MUST never be overwritten by re-indexing. When no usable signal exists, the fallback name SHALL be timestamp-based, never empty.

#### Scenario: Meaningful name from app, title, and OCR
- **WHEN** the user captures a browser window titled "Webhooks – Stripe Dashboard" showing an error message
- **THEN** the saved item's filename is a readable slug built from those signals (such as `stripe-webhook-error.png`), not a generic `Screenshot 2026-…` name

#### Scenario: Collision handling
- **WHEN** two captures would produce the same auto-name
- **THEN** the second receives a deterministic disambiguating suffix and both remain retrievable

#### Scenario: Manual rename is sticky
- **WHEN** the user renames an item and the item is later re-indexed
- **THEN** the user's name is preserved

#### Scenario: Signal-free capture
- **WHEN** a capture has no detectable app, title, or OCR text
- **THEN** it receives a timestamp-based fallback name

### Requirement: Provenance captured with every screenshot
For every capture taken by the app, the Library SHALL record provenance: source application (bundle identifier and display name), frontmost window title, capture timestamp, display/region context, and — when the source is a supported browser — the active tab URL. Provenance fields SHALL be stored per-item and visible in the item's detail view. Unavailable fields SHALL be stored as absent (null), never fabricated, and provenance capture failure MUST NOT fail the capture itself.

#### Scenario: Browser capture records the URL
- **WHEN** the user captures a region of a Safari or Chrome window
- **THEN** the Library item records the browser as source app, the window title, and the page URL

#### Scenario: Provenance is null, not guessed
- **WHEN** the window title or URL cannot be determined for a capture
- **THEN** the corresponding field is empty in the item detail rather than populated with an incorrect value
- **AND** the capture itself completes normally

### Requirement: Provenance search, filtering, and reopen-source
Provenance fields SHALL be searchable through the main search field and exposed as filters (by source application, by domain/URL substring, by date range). Every item with recorded provenance SHALL offer a reopen-source action: reopening the recorded URL in the default browser for browser captures, or activating/launching the source application otherwise. When the source is no longer available (app uninstalled), the action SHALL fail with an explicit message.

#### Scenario: Filter by source app
- **WHEN** the user filters the Library by source application "Xcode"
- **THEN** only captures whose provenance records Xcode are shown

#### Scenario: Reopen the captured page
- **WHEN** the user invokes reopen-source on a capture taken from a browser tab
- **THEN** the recorded URL opens in the default browser

#### Scenario: Search hits a URL
- **WHEN** the user searches for "github.com"
- **THEN** captures whose provenance URL contains that domain appear in results

### Requirement: Smart folders and manual tags
The Library SHALL provide automatic smart folders that populate by rule with zero user setup, including at minimum: per-source-app folders, a contains-code folder (heuristic detection from OCR content — monospace layout / code-token density, no AI), and date-based folders (e.g. Today, This Week). Smart-folder membership SHALL update automatically as items are added or re-indexed. The user SHALL additionally be able to assign multiple manual tags per item, with tag-based filtering and tag terms included in search; deleting a tag SHALL remove it from all items without deleting any item.

#### Scenario: Per-app smart folder
- **WHEN** the user has captured from Xcode and Figma
- **THEN** smart folders for Xcode and Figma each contain exactly the captures from that app

#### Scenario: Contains-code folder
- **WHEN** a capture of a terminal session with source code is indexed
- **THEN** it appears in the contains-code smart folder

#### Scenario: Manual tagging and filter
- **WHEN** the user tags three items "bug-123" and filters by that tag
- **THEN** exactly those three items are shown

#### Scenario: Tag deletion is non-destructive
- **WHEN** the user deletes the tag "bug-123"
- **THEN** the previously tagged items remain in the Library without that tag

### Requirement: Opt-in auto-import of external screenshots
The Library SHALL offer an auto-import feature, disabled by default, that watches standard macOS screenshot locations (the configured system screenshot folder, Desktop default) plus user-added folders, and indexes new image files appearing there — including captures produced by any other tool. On first enablement, the user SHALL be offered a one-time backfill that imports and indexes the pre-existing screenshot history found in the watched folders, with a count shown before confirmation. Imported items SHALL receive OCR indexing and heuristic naming metadata like native captures (file-derived provenance only); the original files MUST NOT be moved, renamed, or modified by import unless the user explicitly opts into a relocation behavior. Duplicate detection SHALL prevent re-importing an already-indexed file.

#### Scenario: Disabled by default
- **WHEN** the app is freshly installed
- **THEN** no folder watching or importing occurs until the user enables auto-import

#### Scenario: Screenshot from another tool gets indexed
- **WHEN** auto-import is enabled and the user takes a screenshot with macOS ⌘⇧4 into the watched folder
- **THEN** the file appears in the Library and becomes text-searchable after background OCR

#### Scenario: Pre-install history backfill
- **WHEN** the user enables auto-import on a folder containing 500 existing screenshots and confirms the backfill
- **THEN** all 500 are indexed and searchable, and their files remain in place, unmodified

#### Scenario: No duplicate entries
- **WHEN** a watched file that is already indexed is touched or re-scanned
- **THEN** no second Library entry is created

### Requirement: Core Spotlight integration
The Library SHALL donate searchable items to Core Spotlight so captures are findable from system Spotlight by name, OCR text, and provenance keywords. Activating a Spotlight result SHALL open the item in the app's Library. Donations SHALL be updated on rename/re-index and removed when the item is deleted from the Library, and the donation SHALL be withdrawn entirely if the user disables Spotlight integration in settings.

#### Scenario: Find a capture from system Spotlight
- **WHEN** the user searches macOS Spotlight for text that appears in a Library capture
- **THEN** the capture appears as a Spotlight result and selecting it opens that item in the Library

#### Scenario: Deletion removes the donation
- **WHEN** the user deletes an item from the Library
- **THEN** it no longer appears in Spotlight results

### Requirement: Reopen with annotations still editable
Items saved with annotations SHALL be stored in the re-editable document format, and reopening such an item from the Library (including via search results and Spotlight) SHALL restore every annotation as a live, individually editable object — not a flattened bitmap. Edits made after reopening SHALL be re-saveable to the same Library item, and re-export SHALL be possible at any time. Items imported as plain images (auto-import) SHALL open in the editor with a fresh annotation layer over the unmodified original.

#### Scenario: Month-old annotations remain objects
- **WHEN** the user reopens a capture annotated a month ago
- **THEN** each arrow, text, and blur annotation is selectable, movable, and deletable

#### Scenario: Edit, re-save, re-copy
- **WHEN** the user reopens a Library item, moves an annotation, saves, and copies the result
- **THEN** the Library item reflects the edit and the clipboard holds the updated render

### Requirement: Retention controls
The Library SHALL provide user-configurable retention rules: a maximum total size cap and age-based rules (e.g. delete or archive items older than N days), each individually optional and all disabled by default. Before any rule deletes items, the app SHALL make the policy's effect visible (what will be removed and when) and apply rules predictably (oldest-first for the size cap). Manually tagged or explicitly kept items SHALL be excludable from automatic deletion. Retention actions SHALL be logged/visible so deletions are never mysterious.

#### Scenario: Retention off by default
- **WHEN** the app is freshly installed
- **THEN** no automatic deletion of Library items ever occurs until the user configures a rule

#### Scenario: Size cap evicts oldest first
- **WHEN** a 5 GB size cap is configured and the Library exceeds it
- **THEN** the oldest non-excluded items are removed until the Library is under the cap

#### Scenario: Kept items survive age rules
- **WHEN** an age rule would delete an item the user marked as kept
- **THEN** the item is not deleted

### Requirement: Library access survives trial expiry forever
After trial expiry on an unlicensed install, the Library SHALL remain fully accessible forever: browsing, searching, filtering, opening items, and exporting/copying any item MUST continue to work without a license. Expiry SHALL never delete, encrypt, watermark, or otherwise degrade Library data or exports. Gating of new-capture functionality is governed by the licensing capability, but no path to the user's existing data SHALL ever be gated.

#### Scenario: Expired trial, full data access
- **WHEN** the trial has expired and the app is unlicensed
- **THEN** the user can open the Library, run searches, open any item, and export it at full quality

#### Scenario: No degradation of existing data
- **WHEN** trial expiry occurs
- **THEN** no Library item is deleted, watermarked, downscaled, or made read-protected

### Requirement: Forward-compatible schema with reserved extension columns
The Library schema SHALL be versioned with forward migrations and SHALL reserve, from v1: a media-type field with nullable duration (video hook), and nullable metadata and embedding columns (deferred-AI hook). These reserved columns MUST remain unpopulated and unread by all MVP code paths, and their presence MUST NOT affect MVP behavior or search performance. The schema SHALL be documented in this capability's spec area as the portable contract for future platforms.

#### Scenario: Reserved columns exist and stay null
- **WHEN** the v1 database schema is inspected after normal MVP use
- **THEN** the media-duration, metadata, and embedding columns exist and contain only null values for image captures

#### Scenario: Migration path from v1
- **WHEN** a future schema version opens a v1 database
- **THEN** existing items, names, tags, and OCR index entries are preserved through migration
