# Design — MVP (Project Darkroom)

## Context

Greenfield native macOS app. Product scope and acceptance bars: `docs/02-prd.md` (E1–E15). Evidence: `research/00-research-report.md`. Hard constraints from decisions log: native Swift; local-first (no server, no accounts, no telemetry by default); no AI/LLM anywhere in MVP; one-time licensing via Paddle; direct distribution (notarized DMG + Sparkle + Homebrew cask); macOS 14+; future Windows port must be a spec-driven rewrite, so domain logic stays platform-agnostic; deferred features (`docs/deferred/`) must remain architectural drop-ins.

Implementation will be performed by multiple coding agents in parallel (model-agnostic). The design therefore optimizes for: clear module boundaries, low cross-module coupling, mechanically checkable conventions (CI lint over tribal knowledge).

## Goals / Non-Goals

**Goals:**
- Meet PRD performance budgets (hotkey→chip <200ms p95; <15MB download; <100MB idle RAM).
- Module boundaries that let 5–8 agents build concurrently without merge collisions.
- Domain core with zero UI-framework imports (CI-enforced) — the Windows-portable heart.
- Deferred-feature hooks present but dormant (capture-type enum, destination plugins, nullable library columns).

**Non-Goals:**
- Any server component. Any cross-platform abstraction layer beyond the domain core (we are not building the Windows app now, only refusing to foreclose it).
- Mac App Store sandbox compatibility.

## Decisions

### D1 — Language & UI framework: Swift 6 (strict concurrency), SwiftUI-first with AppKit at the edges
SwiftUI for settings, onboarding, Library browser, editor inspector panels. AppKit where SwiftUI can't deliver: the chip (non-activating `NSPanel`), capture overlays (borderless `NSWindow` per display), pin windows, the editor canvas (`NSView` + Core Animation for 60fps annotation manipulation). *Alternative considered:* pure AppKit (Shottr-style) — rejected: slower to build, SwiftUI is fine for non-latency-critical surfaces; pure SwiftUI — rejected: overlay/panel behavior and canvas performance need AppKit control.

### D2 — Package architecture: SPM workspace, layered, portability-linted
```
DarkroomKit/ (SPM workspace)
├─ DarkroomCore        # PORTABLE. Annotation document model, geometry, naming heuristics,
│                      # library domain types, destination protocol, settings model.
│                      # Imports: Foundation only. CI lint: no AppKit/SwiftUI/UIKit import.
├─ DarkroomRender      # Rendering/export of annotation documents (Core Image/Core Graphics).
├─ DarkroomCapture     # ScreenCaptureKit/SCScreenshotManager wrapper; capture-type enum
│                      # (.image now, .video reserved); display/window enumeration; permissions.
├─ DarkroomScroll      # Scrolling-capture engine: scroll synthesis, frame acquisition,
│                      # stitcher, seam model for restitch. Depends: DarkroomCapture, DarkroomRender.
├─ DarkroomOCR         # Vision text/QR recognition; indent/linebreak post-processing.
├─ DarkroomLibrary     # GRDB + FTS5 store, auto-import watcher, Spotlight donation,
│                      # retention. Depends: DarkroomCore, DarkroomOCR.
├─ DarkroomDestinations# Plugin implementations: clipboard, file, app hand-off, S3/custom.
├─ DarkroomLicensing   # Paddle REST verification, signed local receipt, trial state.
└─ Darkroom (app)      # AppKit/SwiftUI shells: chip, overlays, editor UI, Library UI,
                       # onboarding, settings, menu bar, hotkeys, AppIntents, URL scheme.
```
Each package = one agent lane. *Alternative:* monolithic app target — rejected: merge collisions, no portability enforcement.

### D3 — Annotation document: value-type scene graph, versioned, re-editable forever
`AnnotationDocument` = Codable struct: base image reference + ordered `[Annotation]` (enum with associated values: arrow, text, counter, blur-region, …) + canvas extensions. Persisted as `.darkroom` bundle (base image + JSON + thumbnail) with explicit `schemaVersion` and forward-migration. Editor mutates the model; `DarkroomRender` rasterizes for export (flatten), redactions rendered destructively only at export. This satisfies re-editability (PRD E3), Library reopen, and gives Windows a documented file format instead of code. *Alternative:* Core Data/SwiftData object graph — rejected: poor portability story, harder undo (we use value snapshots).

### D4 — Persistence: GRDB + SQLite FTS5
Library index = SQLite via GRDB: `captures` table (provenance, timestamps, media type + duration [nullable, video hook], metadata JSON column [nullable, AI hook]) + FTS5 virtual table over OCR text + name + tags. Files stay on disk (user-visible folder + `.darkroom` bundles); DB stores references — never hold images hostage inside an opaque store. *Alternatives:* SwiftData — too young, no FTS; Core Data — FTS via external index adds complexity; raw SQLite — GRDB gives migrations/observation cheaply. Schema documented in `specs/library/spec.md` as the portable contract.

### D5 — Capture: SCScreenshotManager only; permission posture designed up front
macOS 14+ floor removes all deprecated-API (`CGWindowListCreateImage`) liability. **Spike S0 (blocking, 1 day):** verify whether non-picker `SCScreenshotManager` triggers the Sequoia/Tahoe periodic re-auth (research §10.1) on 15.x and 26.x; permission-health UX adjusts on the result. Window capture composites alpha-preserving shadow (research: Shottr beats CleanShot here). Freeze-screen = fullscreen grab presented in an overlay window before region pick.

### D6 — Global hotkeys: Carbon `RegisterEventHotKey` wrapper (no Accessibility permission needed); `CGEventTap` is never required for core capture. Accessibility is requested lazily, only by DarkroomScroll at first scrolling capture (PRD E5/E12).

### D7 — The chip: non-activating `NSPanel`, focus-respecting keyboard contract
Chip panel never steals key focus from the user's app. Keyboard contract (Esc/Enter/⌘C) is armed for a configurable window (default 8s) after capture via a local+global event monitor that swallows only the contracted keys while the chip shows a subtle "keys live" affordance; clicking the chip or pressing Enter expands it in place into the editor window (which does take focus). Stacking = vertical accumulation, drag-out = `NSFilePromiseProvider` (file materialized on drop — preserves nothing-on-disk). *Alternative:* always-key floating window (Shottr preview) — rejected: steals focus, breaks "capture without leaving my app."

### D8 — Scrolling engine: synthesized smooth scroll + overlap-correlation stitcher + seam document
Loop: capture frame → synthesize scroll (AX scroll events; manual mode = user scrolls) → capture → estimate offset by normalized cross-correlation on downsampled luminance strips (vDSP), refine at full res → append tile. Sticky-header detection via per-row variance mask (rows static across frames = chrome → cropped). Output retains **source tiles + seam offsets** (`ScrollDocument`) so the restitch view can re-seam without recapture (PRD E5). Live preview renders the growing canvas. Honest-failure: correlation confidence below threshold → stop, explain, offer manual mode. **Failure suite** = scripted fixture scenarios (Terminal, VS Code, Finder columns, Mos/Scroll Reverser installed, sticky headers, lazy-load page) run on a dedicated self-hosted Mac runner (GitHub-hosted macOS runners can't grant Screen Recording/AX interactively).

### D9 — Text-aware redaction: Vision `VNRecognizeTextRequest` boxes → per-instance blur/erase annotations; content-aware removal via Core Image inpainting (custom patch-match kernel if CI's is insufficient — spike S1, 2 days, has graceful fallback to blur-fill). All on-device; "no AI" framing holds (Vision is OS-built-in).

### D10 — Licensing: Paddle Billing REST + Ed25519-signed local receipt
Activation: license key → Paddle API → signed receipt cached locally (3-seat counting server-side via Paddle activations API); 14-day offline grace; deactivation self-serve in-app. Trial: first-launch timestamp in receipt store + Keychain mirror (defeats casual reset; we accept determined resets — dignity over DRM). Expiry = capture still works for 24h grace, then capture disabled but **Library and export remain accessible forever** (never hostage data). *Alternative:* Lemon Squeezy — comparable; Paddle chosen for published pricing + category precedent (research §6.6).

### D11 — Updates & distribution: Sparkle 2 (EdDSA appcast), notarized DMG, Homebrew cask at launch, public changelog page generated from release notes.

### D12 — Privacy & diagnostics: zero network calls except Paddle activation, Sparkle appcast, and opt-in S3 destination. No analytics SDK. Crash reporting = opt-in submission of MetricKit/`.ips` payloads via a "Send diagnostics" action (mailto/manual), not automatic.

### D13 — Testing strategy
- DarkroomCore/Render: unit + snapshot tests (pointfree swift-snapshot-testing) — annotation render quality is a product feature ("annotations just look so damn good"), so goldens are reviewed assets.
- DarkroomScroll: stitcher unit tests on recorded fixture frame sequences (deterministic, runs on CI without permissions) + the live failure suite on the self-hosted runner.
- Performance: XCTest `measure` + os_signpost budget assertions for hotkey→chip and search latency.
- App flows: XCUITest for onboarding, capture→chip→editor→export, Library search.

## Risks / Trade-offs

- [Scroll stitching is structurally fragile] → seam document + restitch view as user-facing safety net; honest-failure UX; failure suite gates release.
- [Chip keyboard contract may surprise users (swallowed keys)] → short arm window, visible affordance, instantly configurable off; beta telemetry via feedback (not analytics).
- [Strict-concurrency Swift 6 + AppKit interop friction] → `@MainActor` app layer, Sendable domain values; isolate legacy-pattern code in thin wrappers.
- [Self-hosted CI runner is a single point of failure] → stitcher logic also covered by fixture-based tests on hosted runners; runner setup scripted/documented.
- [Paddle API/product setup is external dependency] → licensing package developed against a local mock server; real integration in M4.
- [15 capabilities, parallel agents, one app target] → app-target work split by surface (chip/editor/library/onboarding) with file-level ownership map in tasks.md; domain packages absorb most logic.

## Migration Plan

Greenfield — none. Rollback = Sparkle channel pinning (users can stay on previous version; appcast keeps last 3 releases).

## Open Questions

1. **S0 spike result** (SCScreenshotManager re-auth behavior) → may reshape permission-health UX copy.
2. **S1 spike result** (Core Image inpainting quality) → content-aware removal ships vs degrades to blur-fill.
3. Final product name → bundle ID, appcast URL, cask name (placeholder `com.sidequests.darkroom`; rename task is isolated in M4).
4. Paddle Billing vs Paddle Classic API surface for license activations (resolve when account is created, M0).
