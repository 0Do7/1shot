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
