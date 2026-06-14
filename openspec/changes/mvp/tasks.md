# Tasks — MVP (1shot)

Lanes: each `##` group is an independent agent lane unless its intro names a dependency.
Conventions for implementers: see `docs/03-build-guide.md`. Specs referenced as `spec:<capability>`.
Flagged `[demote-able]` = may slip to fast-follow if the beta date is at risk (PRD §11).

## 1. Spikes & Foundation (blocks everything; do first)

- [x] 1.1 S0 spike: empirically test whether non-picker SCScreenshotManager triggers Sequoia/Tahoe periodic re-auth on macOS 15.x and 26.x; write findings to `docs/spikes/s0-screencapture-reauth.md` (design D5; resolves design Open Q1) — 26.x empirics + sourced research done; 15.x empirical pass deferred to beta (no Sequoia hardware), tracked in findings doc
- [x] 1.2 S1 spike: Core Image inpainting quality test on 5 fixture screenshots; decide content-aware-removal approach vs blur-fill fallback; write `docs/spikes/s1-inpainting.md` (design D9)
- [x] 1.3 Scaffold repo: SPM workspace per design D2 (9 packages + app target), Xcode project, placeholder bundle ID `com.sidequests.oneshot`, SwiftLint/SwiftFormat configs
- [x] 1.4 CI pipeline (GitHub Actions): build + unit tests on hosted macOS runner; portability lint job that fails if OneShotCore/OneShotRender import AppKit/SwiftUI/UIKit (design D2)
- [x] 1.5 Performance-budget test harness: os_signpost + XCTest measure scaffolding for hotkey→chip <200ms p95 and editor-open <400ms budgets (PRD §7)
- [ ] 1.6 Self-hosted Mac runner: provision, script setup (Screen Recording + AX pre-granted), document restore procedure (design D8/D13)

## 2. OneShotCore — portable domain model (lane: core)

- [x] 2.1 AnnotationDocument value-type scene graph: all annotation types as enum cases with associated values, canvas extensions, schemaVersion + forward-migration (spec:annotation-editor, design D3)
- [x] 2.2 `.1shot` bundle format: base image + JSON + thumbnail, atomic read/write, versioned codec + golden fixture files
- [x] 2.3 Geometry/coordinate model: logical-vs-pixel spaces, multi-display mapping, mixed-DPI math + property tests (spec:capture-engine)
- [x] 2.4 Heuristic auto-naming engine: source app + window title + top OCR tokens → kebab filename; collision handling; unit-test corpus of 50 fixtures (spec:library, NO AI)
- [x] 2.5 Destination plugin protocol: payload model (image/document/text), destination descriptor, registration, error surface; clipboard + file built-ins (spec:output-destinations)
- [x] 2.6 Settings model: typed schema, defaults per PRD "opinionated defaults", migration, import/export excluding secrets (spec:utilities-settings)
- [x] 2.7 Filename template engine + save-location rules (spec:output-destinations)

## 3. OneShotCapture — capture engine (lane: capture; needs 2.3)

- [x] 3.1 ScreenCaptureKit wrapper: display/window enumeration, SCScreenshotManager still capture, capture-type enum with `.video` reserved (spec:capture-engine, design D5)
- [x] 3.2 Area selection overlay windows (per display, borderless): crosshair, magnifier, dimension readout, keyboard nudge, multi-display + mixed-DPI correct
- [x] 3.3 Window capture: alpha-preserving transparent shadow + shadowless mode; window picking UX (spec:capture-engine)
- [x] 3.4 Modes: fullscreen, repeat-previous-area (with region preview before recapture), delayed (UI-configurable), freeze-screen (spec:capture-engine)
- [x] 3.5 Global hotkeys: RegisterEventHotKey wrapper, conflict detection, rebinding UI model (design D6)
- [x] 3.6 Permission state machine: Screen Recording status detection, re-auth detection (per S0 findings), recovery flow hooks (spec:onboarding-permissions)

## 4. Post-capture chip (lane: chip; needs 3.1)

- [x] 4.1 Non-activating NSPanel chip: corner anchoring, never-steals-focus, stacking layout, VoiceOver labels (spec:post-capture-chip, design D7)
- [x] 4.2 Keyboard contract: arm-window event monitor for Esc/⌘C/Enter, swallow-scope rules, "keys live" affordance, configurable/disable (spec:post-capture-chip) — contract state machine unit-tested; live swallow via transient CGEventTap (D6 reconciliation, graceful-degrade), runner-verified
- [ ] 4.3 Hover affordances: copy/save/pin/edit/drag handle; bulk actions on stacks — per-chip hover affordances done; stack-level bulk-action UI trigger pending (model copyAll/saveAll/dismissAll done+tested) (see spec-conflicts 2026-06-14)
- [x] 4.4 Drag-out via NSFilePromiseProvider (file materialized on drop; nothing-on-disk preserved)
- [ ] 4.5 Chip lifecycle: timeout behavior, chip-off pure-clipboard mode, expand-in-place handoff to editor <400ms — timeout + chip-off done+tested; expand opens §5 placeholder editor; <400ms is perf-cert
- [ ] 4.6 Performance pass: capture→chip <200ms p95 on budget harness (1.5)

## 5. Editor & render (lane: editor; needs 2.1, 2.2)

- [x] 5.1 OneShotRender: rasterizer for every annotation type; flatten-on-export; golden snapshot test suite (the "annotations look so damn good" gate — goldens are design-reviewed assets) (spec:annotation-editor, design D13)
- [ ] 5.2 Editor canvas (AppKit + Core Animation): selection, drag/resize handles, Z+drag zoom/pan, 60fps manipulation
- [ ] 5.3 Single-key tool switching with text-editing suspension; full keyboard operability (spec:annotation-editor)
- [ ] 5.4 Tools wave 1: arrow (straight/curved), line, rect/ellipse, freehand, text with styles
- [ ] 5.5 Tools wave 2: smart text-following highlight, spotlight/dim, auto-incrementing counters, magnifier callout
- [ ] 5.6 Crop (non-destructive) + expandable canvas + multi-image stitch/combine (spec:annotation-editor)
- [ ] 5.7 Undo/redo via document snapshots, unlimited depth
- [ ] 5.8 Export panel: formats, Retina→1x, size readout, WYSIWYG guarantee tests (spec:output-destinations)

## 6. Redaction (lane: redaction; needs 5.1, 8.1)

- [x] 6.1 Blur + pixelate + black-out annotation types; OCR-defeat strength floor test (blur must defeat Vision OCR on 11–14pt text) (spec:redaction)
- [x] 6.2 Hardened export: redactions rasterized destructively on export across all formats + pasteboard types; metadata stripped; test that no pixel data survives
- [ ] 6.3 Text-aware blur/erase: Vision text boxes → per-instance toggleable redaction annotations; all-text one-click (spec:redaction)
- [ ] 6.4 Content-aware removal per S1 decision (inpaint or blend-fill fallback) [demote-able to fast-follow]

## 7. Scrolling capture (lane: scroll; needs 3.1; the reliability crown — protect this lane's time)

- [x] 7.1 Stitcher core: overlap estimation via normalized cross-correlation on luminance strips (vDSP), full-res refinement, ScrollDocument (tiles + seams) model + fixture-based unit tests (design D8)
- [x] 7.2 Sticky-chrome detection (static-row variance mask) + dedup-crop; fixture tests
- [ ] 7.3 Auto-scroll synthesis (AX scroll events) + manual mode + mid-session switch; lazy Accessibility request with explainer (spec:scrolling-capture)
- [ ] 7.4 Live stitch preview panel rendering the growing canvas; finish/cancel controls
- [x] 7.5 Honest-failure: confidence thresholds, explicit failure messaging, unsupported-surface detection (spec:scrolling-capture)
- [ ] 7.6 Restitch view: seam dragging, segment trimming, re-seam without recapture; ScrollDocument persists through Library save/reopen
- [x] 7.7 Horizontal scrolling capture
- [ ] 7.8 Failure-suite rig on self-hosted runner: scripted Terminal/VS Code/Finder-columns/Mos/Scroll-Reverser/sticky-header/lazy-load scenarios; wired as release gate (design D8/D13)
- [x] 7.9 Full-resolution guarantee: resource-limit behavior = honest partial, never downscale; tests

## 8. OCR (lane: ocr; small — combine with redaction agent if short-handed)

- [x] 8.1 OneShotOCR: Vision text recognition wrapper, language auto-detect, confidence surfacing (spec:ocr-capture)
- [x] 8.2 Layout post-processing: preserve-layout / merge-lines / raw-lines modes; indentation preservation tests on code screenshots
- [ ] 8.3 OCR capture flow: hotkey → region → clipboard + toast preview; 3-keystroke loop timing test; link + QR detection (QR never silently replaces text) (spec:ocr-capture)

## 9. Library (lane: library; needs 2.1, 2.4, 8.1; flagship wedge)

- [x] 9.1 GRDB store: captures table (provenance, media type + nullable duration, nullable metadata/embedding columns), FTS5 index, migrations, reference-not-vault file handling (spec:library, design D4)
- [x] 9.2 Index-on-capture pipeline: async OCR + auto-name + provenance (frontmost app, window title, browser URL via AX/scripting with graceful degradation) (spec:library)
- [x] 9.3 Search: FTS5 query layer, <50ms @ 10k items perf test, filters (app/date/tag/type)
- [ ] 9.4 Library browser UI (SwiftUI): grid, instant search, detail view, reopen-with-live-annotations, reopen-source action
- [x] 9.5 Smart folders (per-app, contains-code heuristic, date) + manual tags
- [x] 9.6 Auto-import watcher (opt-in): standard screenshot folders, any-tool captures, pre-install backfill, dedup, originals never modified (spec:library) — headless core done: AutoImporter (backfill + count-preview + live ingest through the existing IndexingPipeline, file-derived provenance only), content-hash dedup (new nullable `contentHash` column, schema v2 forward-migration), DispatchSource folder watcher behind an injectable `FileSystemWatching` protocol, AutoImportController (first-enable backfill / survive-launch resume / disable). App layer wires `AppSettings.autoImportEnabled` + the system screenshot folder (resolver provided). Real FSEvents delivery is runner-verified like all interactive paths
- [x] 9.7 Core Spotlight donation + withdrawal — donation/withdrawal logic behind an injectable `SpotlightIndexing` protocol (headless-tested with a mock); thin `CSSearchableIndex` adapter (`CoreSpotlightIndex`, `#if canImport(CoreSpotlight)`). SpotlightCoordinator donates on index/rename/re-index, withdraws on delete + retention-eviction, and `withdrawAll` on disable; deep-link identifier round-trips to the Library row id
- [x] 9.8 Retention controls (off by default): size cap, age rules, preview-before-delete

## 10. Pixel tools, pin, beautify (lane: visuals; needs 5.2)

- [ ] 10.1 Pixel rulers with edge snapping, stampable; distance measurement (spec:pixel-tools)
- [ ] 10.2 Smart object selection (monotone region + edge detect) with honest no-detection fallback
- [ ] 10.3 Color picker: hex/RGB/OKLCH, copy action distinct from any dismissal (anti-footgun requirement), logical-vs-retina toggle (spec:pixel-tools)
- [ ] 10.4 WCAG + APCA contrast checker
- [ ] 10.5 Pin windows: borderless always-on-top, per-pin opacity, click-through lock with guaranteed unlock, scroll-resize, hide/show-all hotkey, ≥10 pins (spec:pin-float)
- [ ] 10.6 Beautify: gradient/solid/image backdrops, padding/corners/shadow, non-destructive (spec:beautify)
- [ ] 10.7 Brand presets + per-platform exact-dimension exports + opt-in auto-apply with raw-clipboard guarantee; 500ms render budget

## 11. Destinations & output (lane: destinations; needs 2.5)

- [ ] 11.1 App hand-off destination (open-with / share to running app)
- [x] 11.2 S3/custom-endpoint destination: direct device→endpoint upload, Keychain-only credentials, excluded from settings export (spec:output-destinations) [demote-able] — EndpointDestination conforms to Core's CaptureDestination; injectable HTTPUploadClient (mock in tests, URLSessionUploadClient in prod) + injectable EndpointCredentialStore (in-memory fake in tests, Keychain in app layer). S3 SigV4-signed PUT (canonical request asserted against AWS worked example) + generic custom-HTTP PUT/POST (presigned-URL = no-credential PUT; bearer-token header injection). Connection test (signed HEAD), typed DestinationError surface (network/unauthorized/targetMissing/io with S3 `<Code>` detail), no partial-success URL on failure, shareableURL rendered from user URL pattern. Secrets live ONLY in the store → never in AppSettings/export. 32 destinations tests green, swiftlint --strict clean. App-layer wiring (real Keychain SecItem store + config/test UI) deferred to §13 settings/platform lane.
- [ ] 11.3 Format encoders: PNG/JPEG/WebP/HEIC with file-size-conscious defaults; size-comparison tests (spec:output-destinations)
- [ ] 11.2 S3/custom-endpoint destination: direct device→endpoint upload, Keychain-only credentials, excluded from settings export (spec:output-destinations) [demote-able]
- [x] 11.3 Format encoders: PNG/JPEG/WebP/HEIC with file-size-conscious defaults; size-comparison tests (spec:output-destinations)

## 12. Onboarding & permissions (lane: onboarding; needs 3.6; trust differentiator)

- [ ] 12.1 First-run flow: install-to-/Applications check, pre-permission explainers, first capture inside onboarding (60-second annotate bar, XCUITest-timed) (spec:onboarding-permissions)
- [ ] 12.2 Hotkey takeover wizard: System Settings deep-link + live read of com.apple.symbolichotkeys IDs 28–31/184 → "freed ✓" verification; never writes settings itself (spec:onboarding-permissions)
- [ ] 12.3 Permission-health screen: live status for Screen Recording/Accessibility/notifications, re-auth recovery per S0 findings
- [ ] 12.4 Onboarding XCUITest suite covering grant/deny/partial paths

## 13. Utilities, settings & automation (lane: platform)

- [ ] 13.1 Hide desktop icons + widgets toggle (spec:utilities-settings)
- [ ] 13.2 History tray: transient last-N strip, age-out discard, explicit funnel-into-Library action (spec:utilities-settings)
- [ ] 13.3 Settings UI: progressive disclosure, launch-at-login, hideable menu-bar icon
- [x] 13.4 AppIntents: capture/OCR/pin/search actions for Shortcuts + Spotlight (spec:automation) — full intent catalog (capture modes, region/file OCR, pin, hide/show pins, Library search entity) + AppShortcuts (Spotlight) built in `OneShot/Sources/Automation`, all funneling through one shared `AutomationDispatcher`+gate; pin is surface-only/stubbed (§10.5), region OCR pending the in-app flow (§8.3). AppIntents runtime is runner-only; dispatch/gate/parse are unit-tested (57 swift-testing cases). See spec-conflicts 2026-06-14.
- [x] 13.5 URL-scheme API (off by default) + docs page; trial-expiry error behavior (spec:automation) — `oneshot://` scheme registered in Info.plist; OFF by default behind `AppSettings.urlSchemeEnabled` with single disabled-notice + per-action confirm; pure parser/round-trip + x-callback-url + gate (expired-trial → contracted `capture-requires-license` error, search still works) fully unit-tested; `docs/automation.md` published. Apple-Event handler is runner-only.
- [ ] 13.6 Raycast + Alfred extensions (thin wrappers over 13.4/13.5) [demote-able]

## 14. Licensing, updates & distribution (lane: commerce; mock-first, real Paddle in beta)

- [x] 14.1 Local mock license server + OneShotLicensing package: key activation, 3-seat logic, Ed25519 receipt, 14-day offline grace (spec:licensing-updates, design D10)
- [x] 14.2 Trial state machine: 14-day full trial, 24h capture grace, capture-disable with Library-forever guarantee; dignified expiry UI (no nag mascot)
- [ ] 14.3 Paddle integration: product/price config, real activation/deactivation, refund webhook→deactivation [needs Paddle account; design Open Q4]
- [ ] 14.4 Sparkle 2: EdDSA keys, appcast pipeline, bug-fix-vs-feature-year gating logic ("bug fixes free forever" enforcement) (spec:licensing-updates)
- [ ] 14.5 Release pipeline: notarized DMG build, appcast publish, Homebrew cask, public changelog generation
- [ ] 14.6 Name remnant sweep at release: product name **1shot** applied repo-wide 2026-06-09 (modules OneShot*, bundle `com.sidequests.oneshot`, `.1shot` extension); remaining = verify appcast URL/cask/About strings when they exist

## 15. Beta & launch engineering (needs all lanes at integration level)

- [ ] 15.1 Integration QA pass: the 7 PRD acceptance flows as scripted end-to-end tests/checklists
- [ ] 15.2 Performance certification: all PRD §7 budgets measured on Intel + Apple Silicon, mixed-DPI multi-display
- [ ] 15.3 Beta build channel: Sparkle beta appcast, feedback command in-app (mailto/form, no analytics)
- [ ] 15.4 Beta exit gates: crash-free ≥99.8%, capture-success ≥99.5%, scrolling failure suite green, ≥40% beta users performed a Library search (PRD §10)
- [ ] 15.5 Launch artifacts engineering support: demo-asset capture builds (the 5 gasp-moment demos), comparison-page screenshots
- [ ] 15.6 1.0 release: final price set, Paddle live, notarized 1.0, Homebrew cask PR, changelog + roadmap page (video/cloud shown as next)
