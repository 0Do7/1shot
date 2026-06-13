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
