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

## 2026-06-14 · §6.3/6.4 redaction finish · `.erase` blend-fill + content-aware removal
- **New `RedactionAnnotation.Style.erase` (OneShotCore, strictly additive).** Added ONE enum case to the
  existing `blur/pixelate/blackout` set — no renames/reorders of Core types (the editor-canvas lane edits
  Core in parallel; this minimizes the merge). Wire token is the literal `"erase"`, pinned by a Core test;
  existing documents decode unchanged. `RedactionAnnotation.strength` is unused by erase (it carries no
  radius/cell) — left as-is rather than making it optional, to avoid a non-additive model change.
- **Erase == content-aware removal == the S1 diffusion-fill fallback.** Per `docs/spikes/s1-inpainting.md`:
  macOS 26.3 Core Image ships ZERO inpaint/heal filters, so MVP content-aware removal is CI **diffusion
  fill** (the spike's winning technique, 2–4× better RMSE than blur-fill). The spec has two requirements
  that both reduce to the same primitive — "Text-aware blur and erase" (erase = "fill to match the
  surrounding background … no legible residue") and "Content-aware object removal" (inpaint, else "fall
  back to a blended fill"). One renderer (`RedactionRenderer.erasedPatch`) satisfies both: seed the region
  with the surrounding-ring average colour, then 7 blur-and-reblend passes with shrinking sigma so border
  colours diffuse inward. **No custom patch-match / ML kernel** (spike decision #3: post-MVP only, ML banned).
- **OCR-defeat by construction.** The fill is synthesized ONLY from pixels OUTSIDE the region — the region's
  original pixels are masked out before any blur, so nothing legible can bleed through. Verified like 6.1
  with the REAL `VisionTextRecognizer` (`textAwareEraseBlends`, `eraseHardensDestructivelyAcrossFormats`)
  PLUS a background-continuity floor (`meanDiffFromColor` < 24 over a flat fixture) and a direct
  "no near-black residue survives" check (`eraseFillIgnoresOriginalRegionContent`). Erase reuses the
  existing destructive `.copy` redraw path in `AnnotationDrawing.drawRedaction`, so it hardens on export
  across every format and z-orders correctly — no new export plumbing.
- **Honest-failure scope (spike decision #2) is app-layer, not regressed here.** The spike asks for a
  variance/structured-content warning before applying erase ("never claim magic"); that live-preview UX is
  an editor-canvas (§5) concern. The render core's contract is correct-and-destructive: on structured
  backgrounds the fill is an honest smudge that still leaks no legible text (the floor), not a corrupted
  result. Undo is the editor's document-snapshot stack (§5.7), already specced — the erase object is
  re-editable in the document like every redaction and only flattened at export.
