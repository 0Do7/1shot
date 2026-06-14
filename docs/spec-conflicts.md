# Spec conflicts & deviations log

Per build guide §0: conflicts found during implementation are logged here, never
silently resolved. Format: date · where · what · resolution.

## 2026-06-09 · design D2 vs task 1.3 · package count
Design D2's tree lists **8** packages + app; task 1.3 says "**9** packages + app
target". Resolved by adding `OneShotInstruments` (os_signpost + performance-budget
harness, task 1.5) as the 9th package — the harness needed a home importable by both
app and tests, and it must not live in portable OneShotCore (imports `os`).

## 2026-06-09 · build guide §3 vs SwiftFormat · test naming
Build guide says name tests `test_chip_neverStealsFocus`; SwiftFormat (law per §2)
strips the redundant `test` prefix on swift-testing `@Test` functions. Resolution:
scenario-based names keep the `<surface>_<scenario>` shape without the prefix
(`chip_neverStealsFocus`). Formatter wins — it's the mechanically-enforced rule.

## 2026-06-13 · spec:capture-engine area vs freeze · area selection captures a snapshot on open
The "Area selection" requirement implies a live overlay (final pixels from the
live screen at confirm), while "Freeze-screen" is the explicit frozen mode.
Task 3.2 implements area selection by grabbing a per-display snapshot at
invocation, dimming it as the overlay backdrop, and **cropping the confirmed
region out of that snapshot** rather than re-capturing live. Rationale: exact
WYSIWYG with the backdrop, no one-frame race where the dimming leaks into the
shot, and the snapshot is needed anyway for the pixel-accurate magnifier. Output
is still at the source display's native density, satisfying the requirement
verbatim. Consequence: the screen is visually frozen for the brief selection
lifetime; freeze-screen (3.4) becomes the same mechanism surfaced deliberately
(persistent + signposted), not a separate capture path. No spec text changed.

## 2026-06-09 · design D9 · "Core Image inpainting" does not exist
D9 assumed CI ships an inpainting facility. Spike S1 census on macOS 26.3: 247
CIFilters, zero inpaint/heal/reconstruct candidates. Resolution per S1 findings
(`docs/spikes/s1-inpainting.md`): MVP content-aware removal = CI **diffusion fill**
(beats blur-fill baseline 2–4×); custom patch-match kernel deferred post-MVP.
Spec requirement text unchanged (already mandates honest-failure messaging).

## 2026-06-13 · spec:ocr-capture · automatic-language surfacing is approximate
`VNRecognizeTextRequest` does not report the per-run *detected* language. In
`.automatic` mode `RecognizedText.languages` is populated with the recognizer's
*supported* set (best-effort), not the detected one. Recognition correctness
(diacritics, mixed-script) is unaffected — only the surfaced language list is
imprecise. No spec text changed.

## 2026-06-13 · spec:ocr-capture / spec:utilities-settings · no AppSettings.ocrLayoutMode field
"Mode change persists" implies the OCR `LayoutMode` is a persisted setting, but
`AppSettings` (Core) has no such field. `LayoutMode` currently lives in OneShotOCR
and is `Codable`; wiring persistence requires either a Core field (`ocrLayoutMode`)
or moving `LayoutMode` to Core. Deferred to app-layer settings wiring (task 13.3);
flagged so the persistence half of the scenario isn't read as missing.

## 2026-06-13 · spec:licensing-updates · post-grace capture left enabled for previously-valid license
Spec says a license whose offline grace is exceeded SHALL degrade "no further than
the documented unlicensed-capture rules." `LicenseState.licensedOfflineGraceExceeded`
keeps capture enabled (single notice) rather than disabling it, reading "no further
than" generously for a *previously-valid* purchase. One-line change in
`LicenseState.captureEnabled` if stricter gating is wanted.

## 2026-06-13 · spec:output-destinations · intrinsic JPEG EXIF dimension keys not strippable
"Default export size sanity" requires no EXIF/GPS/serial/username metadata. ImageIO
unconditionally re-derives `PixelXDimension`/`PixelYDimension` into the JPEG EXIF
dict; these are intrinsic and non-identifying. Hardened export strips all GPS/TIFF/
IPTC and every other EXIF key — only the two benign dimension keys remain. Also:
WebP *encoding* availability is macOS-version dependent (unavailable on this build);
handled via a typed `formatUnsupportedOnThisOS` error, tests adapt at runtime.

## 2026-06-13 · spec:annotation-editor / spec:redaction · render-core redaction is a placeholder
OneShotRender 5.1 draws redaction annotations as opaque fills (gray for blur/pixelate,
black for blackout) — irreversible obscuring, but NOT true Gaussian/mosaic or the
OCR-defeat strength floor. Real content-defeating blur/pixelate is task 6.1 (redaction
lane, next batch), which the scout confirmed can use CoreImage inside Render (portability-
legal). Also logged: highlight uses a `.multiply` blend (visual choice, spec is silent on
blend mode); golden PNGs are AA-tolerance-compared and may need re-record on a different
macOS/font version (`ONESHOT_RECORD_GOLDENS=1`). Render goldens are DRAFT pending human
sign-off (build-guide DoD #3).

## 2026-06-13 · spec:library · FTS perf budget tested at a CI-safe ceiling
9.3's "<50ms at 10k items" is asserted at a generous 500ms CI-safe budget (debug
GRDB + CI variance); measured debug latency is ~1.7ms (printed via [perf]). The
50ms target is documented in-code as the release-build goal. FTS sync is explicit
delete-then-insert per write transaction (text denormalized from multiple columns +
the tags junction), not external-content triggers. ScrollDocument (7.1) lives in
OneShotScroll, not Core; Library round-trip persistence of scroll seams is deferred
to later integration.

## 2026-06-13 · ultracode adversarial review · 3 high-severity bugs found & fixed (0 deferred)
A per-package adversarial review pass (with attack reviewers on licensing + redaction)
caught three real spec/security defects the original green tests missed; all fixed:
(1) OCR preserve-layout indentation was normalized to image width, so narrow code
captures over-indented grossly — now derived from the recognized-text geometry;
(2) the signed license receipt was NOT bound to the running machine, so a valid
receipt could be copied to any Mac and still verify — now machine-bound;
(3) a magnifier callout re-decoded the ORIGINAL base image, leaking pixels a redaction
was meant to hide — now samples the already-redacted render layer. Plus 29 med/low
robustness + lint fixes. All packages remain swiftlint --strict clean.

## 2026-06-13 · batch 3 partials + headless-verify environment limits
- **6.3 text-aware redaction** — per-instance toggleable redactions + all-text one-click +
  blur/pixelate/blackout over OCR boxes are DONE; the "Text-aware erase blends" scenario is
  DEFERRED (left 6.3 unchecked): it needs a new Core `RedactionAnnotation.Style` (.erase =
  background-matching fill, no legible residue) and overlaps the demote-able 6.4 content-aware
  removal. The conversion stays OCR-free in Render's product target (takes geometry boxes).
- **7.6 restitch** — the MODEL is done (ScrollDocument Codable round-trip + re-seam/trim
  transforms with no recapture); the seam-dragging VIEW and the Library save/reopen wiring are
  app/integration-layer, deferred (left 7.6 unchecked).
- **Review-harden fixes:** library size-cap now counts kept/tagged bytes toward the cap (was
  over-cap-blind when excluded items held space); Today/Yesterday date-bucket midnight overlap.
- **Headless-verify caveat (NOT regressions):** the workspace verify ran OneShotCapture's
  Live*CaptureTests (need a real display + Screen Recording — self-hosted-runner only per design
  D8/D13) and the real-Vision OCR-defeat test, which stalled under concurrent sandbox load. Every
  batch-3 package passed `swift test` + `swiftlint --strict` in its own isolated harden run, and
  an earlier isolated verify had OneShotRender 40 ✓ / OneShotCapture 46 ✓.

## 2026-06-14 · spec:library §9.6/§9.7 · auto-import watcher + Core Spotlight (lane library-import)
- **Branch base.** The lane prompt said "branch off main", but `main` (351002b) does NOT yet
  contain the Library backend (LibraryStore/IndexingPipeline/etc.) my tasks must integrate with —
  that work lives on `lane/wave2-foundation` (= main + the Wave-2 commits; main is its ancestor).
  Branching off bare main was impossible (no store to integrate with), so `lane/library-import`
  is based on `lane/wave2-foundation`. When wave2 merges to main, this lane rebases cleanly (it
  only adds files + 3 additive edits). Flagged so the reviewer expects the wave2 delta in the diff.
- **New `contentHash` column (schema v1 → v2 forward-migration).** §9.6 "No duplicate entries"
  needs a content-identity field; `CaptureRecord` had only `originalPath` (path identity, fragile
  to move/rename). Per the lane brief ("add one only if absent"), added a nullable `contentHash`
  (SHA-256, streamed) via an ADDITIVE v2 migration — v1 DBs migrate with all items/names/tags/FTS
  preserved (existing "Migration path from v1" test updated to assert `["v1","v2"]`). Native
  captures leave it null (deduped by their unique path); auto-imports fill it. Dedup probe checks
  path OR hash, so a moved-but-identical file is still recognized. `CaptureRecord.contentHash` and
  `IndexingPipeline.CaptureInput.contentHash` are additive (defaulted nil) — no consumer breaks.
- **Opt-in gate stays in Core settings, not duplicated.** `AppSettings.autoImportEnabled` already
  exists (Core, default false); the app gates construction of `AutoImportController` on it. The
  library package carries only WHICH folders/types (`AutoImportConfig`) — no new Core field added.
- **Headless core vs. macOS-only edges (D8/D13 testing topology).** File-system watching
  (`DispatchSourceFolderWatcher`) and CoreSpotlight (`CoreSpotlightIndex`, `#if canImport`) are
  behind injectable protocols (`FileSystemWatching` / `SpotlightIndexing`); all import/dedup/
  backfill/donation/withdrawal LOGIC is unit-tested headlessly with in-memory fakes + a mock index
  (no real FSEvents, no permissions, no Spotlight). Real FSEvents delivery and real CSSearchableIndex
  donation are runner-verified like the other interactive surfaces. Spotlight withdrawal fires on
  delete + retention-eviction + integration-disable (`withdrawAll`), routed through a
  `SpotlightCoordinator` so the store stays Spotlight-free (no coupling). No spec text changed.
## 2026-06-14 · §4 post-capture chip · settings reconciliation + contract mechanism + partials
- **`chipTimeoutSeconds` default 8 → 0 (persistent).** spec:post-capture-chip "Chip persistence
  and timeout" says the chip is *persistent by default*; the prior default (8s) contradicted it.
  Spec wins (build-guide §0.5): `0` now means "no auto-dismiss"; a positive value opts into a
  timeout. New `AppSettings` fields (additive, codec-merged): `chipCorner` (default
  `.bottomTrailing`, matching the OS thumbnail) and `chipTimeoutAction` (`.discard`/`.copy`/`.save`,
  default `.discard` — an unattended timeout never silently writes a file). `ScreenCorner` +
  `ChipTimeoutAction` are portable OneShotCore enums. **Consumers note:** OneShotCore public API
  grew three additive members; existing settings files decode unchanged.
- **Keyboard contract uses a transient CGEventTap (D6 reconciliation).** D7 says "swallows only the
  contracted keys"; an `NSEvent` *global* monitor can observe but not swallow, so the only mechanism
  that satisfies the spec's "MUST swallow" is a `CGEventTap`. D6's "no CGEventTap" is scoped to
  *core capture*; the optional, disableable chip contract is not core capture. The tap is created
  ONLY while a chip is armed and torn down when the arm window ends; if it can't be created (app not
  trusted for Input Monitoring) the contract silently degrades to mouse-only — no proactive prompt,
  no nag (honest-failure). The contract *state machine* is unit-tested headlessly (`ChipStackModel`,
  `ChipKey`); live global key-swallowing is self-hosted-runner-verified like all interactive capture UI.
- **Partials (left unchecked in tasks.md):**
  - **4.3** per-chip hover affordances (copy/save/pin/edit/drag-handle) are built; the *stack-level*
    bulk-action UI control (copy-all/save-all/dismiss-all) is not yet surfaced — the model methods
    (`copyAll`/`saveAll`/`dismissAll`) exist and are unit-tested, but no header control triggers them.
  - **4.5** timeout behavior + chip-off pure-clipboard mode are done and tested; expand-in-place
    currently opens an honest *placeholder* editor window (AppDelegate `§5 seam`) — the real editor
    and the <400 ms p95 expand budget are §5 / perf-cert (4.6, 15.2).
  - **4.6** capture→chip <200 ms p95 perf assertion is deferred (needs the budget harness on real
    hardware / the self-hosted runner).
- **Infra:** `project.yml` now sets `GENERATE_INFOPLIST_FILE: YES` on `OneShotAppTests`/`OneShotUITests`
  so `xcodebuild … test` builds+signs the app test bundle locally and on the self-hosted runner
  (hosted CI stays build-only). No effect on the CI build step.

## 2026-06-14 · §13 automation (AppIntents + URL scheme) · decisions + deferrals
Lane `lane/automation` (tasks 13.4/13.5). New code lives in `OneShot/Sources/Automation/`
+ tests in `OneShot/Tests/Automation*.swift`. Notes:
- **Branched off `origin/main` (the real, up-to-date main), not local `main`.** Local `main`
  (`351002b`) was stale Wave-1 scaffold; `origin/main` (`2e27bc0`) has all merged Wave-2 work,
  which is what the orchestrator worktree (`lane/editor`) tracks and what carries the engines this
  lane wires to (OCRPipeline, LibrarySearch, LicenseState, CaptureCoordinator). Branching off stale
  local main would have lost every engine. No spec/code change — a base-ref correction.
- **Tests use swift-testing (`@Test`), not XCTest.** The lane instructions said "add XCTest
  coverage", but build-guide §0.5 / the "match existing test idioms exactly" rule wins: every
  existing `OneShot/Tests/*` file (ChipModelTests, AreaSelectionModelTests, …) is swift-testing.
  Following XCTest would have split the app test target across two frameworks. 57 new `@Test` cases.
- **One typed action catalog + one gate for BOTH surfaces.** AppIntents (§13.4) and the URL scheme
  (§13.5) share `AutomationAction` → `AutomationGate` → `AutomationDispatcher`, so there is exactly
  one place enforcing off-by-default / licensing / confirmation (spec "Public-surface parity"). The
  pure units (parser, gate, callback builder, dispatcher-with-fake-env) carry all the test coverage;
  the AppIntents runtime + the `kAEGetURL` Apple-Event handler are runner-only (matching prior lanes'
  treatment of interactive surfaces).
- **Scheme `oneshot://` chosen** (mirrors the bundle-id tail `com.sidequests.oneshot`). Registered
  via XcodeGen's `info:` block (new `OneShot/Resources/Info.plist`), which required dropping
  `GENERATE_INFOPLIST_FILE` for the OneShot app target ONLY (the test targets keep it); the menu-bar
  `LSUIElement`/`NSPrincipalClass` keys moved into the same explicit plist. The generated plist is a
  committed source file (only `OneShot.xcodeproj` is gitignored). Declaring the scheme is harmless
  while the API is OFF — the runtime gate ignores all calls until the user enables it.
- **Confirmation is scoped to the URL scheme, not AppIntents.** Spec says side-effecting actions
  "SHALL be confirmable"; AppIntents are already an explicit user gesture (Shortcuts/Spotlight), so
  applying a prompt there would double-confirm. The gate confirms only `source == .urlScheme`.
  Persisted per-action confirmation posture is a §13.3 Settings field that does not exist yet; the
  live env defaults to **always-confirm** (safe: any app can call the scheme). `AppSettings` was NOT
  modified — `urlSchemeEnabled` already existed; no new Core field was added.
- **Honest stubs for engines other lanes own (none invents an engine):**
  - **Pin (§10.5)** — `Pin Image` / `pins-toggle` intents + `oneshot://pin` are defined but the app
    seam throws/logs honestly ("pinning not available yet") per the lane instruction to guard/stub.
  - **Region OCR (§8.3)** — `ocr-region` / "Extract Text from Region" surface exists; the app seam
    throws "not available yet". OCR-on-file (`ocr-image`, headless via ImageIO + OCRPipeline) IS live.
  - **Library search window (§9) / Settings panes (§13.3)** — open-search / open-settings are logged
    no-ops; structured `Search Library` returns `[]` until the app instantiates a `LibraryStore`.
  - **Licensing (§14)** — no app-layer `LicenseManager` instance exists yet, so the live env supplies
    an interim in-trial default; the licensing GATE (expired → `capture-requires-license`, search
    still works) is fully unit-tested against injected `LicenseState`s, so only the app default is
    interim. When §14 wires a real manager, swap the one `automationLicenseState()` stub.
- **AppDelegate touched minimally** (another lane edits it concurrently): one additive line
  `installAutomation(coordinator:)`; all wiring lives in `AppDelegate+Automation.swift`. The extension
  takes `coordinator` as a parameter (passed from inside AppDelegate where the private property is
  visible) so it touches no private member.

## 2026-06-14 · §13 automation · review-fix pass (capture return / callback honesty / test gating)
Applied confirmed review findings on `lane/automation`. No spec change — these correct silently-faked
behavior and overstated claims:
- **(high) Capture intents now return the captured image, per §13.4.** The dispatcher's `.capture`
  case was returning `.ok` via a fire-and-forget `startCapture` seam; it now `await`s a
  `captureForAutomation(_:) async throws -> AutomationResult` seam that resolves to `.file(path:)`,
  which is threaded into the AppIntents `ReturnsValue<IntentFile>` output AND the URL `x-success`
  `filePath` callback. The seam is documented to **bypass the chip/editor** ("WITHOUT the app's own
  chip or editor blocking it"). Because the chip-free capture-and-return-to-file engine is owned by
  the capture/output lane and not yet wired in the app, the live seam (`automationCapture`) throws
  HONESTLY (`malformed-request`, "pending the capture/output lane") instead of popping the chip via
  `coordinator.perform` — the exact behavior §13.4 forbids and the review flagged. This matches the
  existing pin/region-OCR honest-stub pattern; the dispatcher CONTRACT is complete + unit-tested
  (capture → `.file` → `filePath`/`IntentFile`). `docs/automation.md` updated to show captures return
  a `File` with the app seam listed as pending (no longer silently faked).
- **(med) Malformed URL with a valid `x-error` now fires an error callback.** `AutomationURLParser`
  gained `callbacks(in:)` (best-effort callback extraction WITHOUT resolving the action), and
  `AutomationURLHandler.handle` now fires `AutomationCallbackBuilder.errorURL` on a parse failure
  using those callbacks. So `oneshot://teleport?x-error=myapp://fail` (unknown action, valid callback)
  now sends a descriptive error callback (spec §13.5/§13.6). Only a URL that `URLComponents` can't
  decompose at all still bails silently.
- **(med) Test-gating claim made honest.** The 60 automation `@Test` cases live in `OneShotAppTests`
  (Xcode app test target, `@testable import OneShot`), which is NOT an SPM package and is NOT run by
  `swift test` or hosted PR CI (build-only). `docs/automation.md` now has a "Testing & CI" section
  documenting the exact `xcodebuild test -only-testing:OneShotAppTests` command and stating that PR CI
  does not run these — so the green claim is no longer overstated. (Kept tests in the app target per
  build-guide §0.5 "match existing test idioms exactly"; all sibling `OneShot/Tests/*` are
  swift-testing in the app target.)
- **Cleanup:** removed unused `AppKit`/`OneShotCore` imports from `AutomationDispatcher.swift` (it uses
  only CoreGraphics/ImageIO + the engine packages).
