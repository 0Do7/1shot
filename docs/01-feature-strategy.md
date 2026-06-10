# Feature Strategy — Add / Cut / Defer + User Flows

Date: 2026-06-09 · Derived from `research/00-research-report.md` (citations are § references into it)
Status: proposal for review → feeds the PRD

---

## 1. Positioning hypothesis (the one-sentence product)

> **"Fast like Shottr, beautiful like CleanShot, honest pricing — and it remembers everything you've ever captured."**

The first three clauses are the reviewers' own unclaimed vocabulary slot (§5). The fourth is the largest unowned white space: capture + a searchable local library in one app has literally zero occupants (§8.1–8.2), and the community wrote the spec as a thread title: *"fast and sleek as CleanShot, library like Snagit"* (§9 #48).

Pillars, in priority order:
1. **The post-capture 3 seconds** — hybrid overlay-that-expands-into-keyboard-first-editor. Nobody ships this (§1.1).
2. **Reliability as a feature** — win the scrolling-capture crown (the most-litigated comparison axis, #1 switching trigger both directions, §1.3).
3. **The library** — local, OCR-indexed, auto-named, source-metadata-stamped memory (§8.2).
4. **Honest pricing** — weaponize every documented competitor wound: bug-fixes-behind-renewal, 1-Mac seats, forced cloud, subscriptions, nagware (§6).
5. **Local-first & native** — "native Swift" is now an explicit purchase criterion; "You had me at 'AI: none'" (§1.7, §8.5). Frame intelligence as *on-device*, never "AI-powered."

---

## 2. ADD — v1 feature set

### Tier A — the signature innovations (demo-able, nobody has them)

| Feature | What it is | Evidence |
|---|---|---|
| **Hybrid post-capture surface** | Capture → Shottr-speed preview chip in the corner (CleanShot-style persistent, stackable, drag-as-file) that is *fully keyboard-driven*: Esc retake, ⌘C copy-and-dismiss, Enter expands in-place into the full editor, single-key tools. Nothing written to disk until the user decides. | §1.1, §5 — the two loved models, merged |
| **Scrolling capture built to the reliability bar** | Auto + manual modes, live stitch preview, **post-capture restitch**, horizontal, full-res output (no downscaling), explicit failure messaging; must pass the failure suite: Terminal, VS Code, Finder columns, Mos/Scroll Reverser installed. | §1.3, §8.3 — "the winnable engineering crown" |
| **The Library** | Every capture auto-indexed locally: OCR-text search, heuristic auto-naming from provenance + OCR keywords ("figma-dashboard-header.png" — no LLM/AI), source app + URL/window-title provenance, smart folders/tags, auto-import of screenshots taken with *any* tool (ScreenFloat's killer move). Spotlight-searchable. | §7 job 10, §8.2, §9 #43/#48/#51/#53 |
| **Text-aware blur / erase / content-aware removal** | Shottr's single biggest on-camera wow ("That's some Next Level AI"), absent from CleanShot. Ours must blur *and* pixelate (Shottr regret-quote: "its blur tool doesn't blur"). Vision-framework text detection — no LLM. | §2.1, §9 #16/#17 |

### Tier B — best-of-both essentials (table-stakes done at differentiator quality)

- **Capture modes:** area / window (with proper transparent shadows — Shottr does this better, §2.1) / fullscreen / repeat-previous-area (with region preview, fixing Shottr's complaint) / delayed (customizable in UI) / freeze-screen.
- **Annotation suite:** arrows, shapes, text, highlight (smart text-following), spotlight, auto-incrementing counters, freehand, magnifier callout — **re-editable project format** (CleanShot's `.cleanshot` is loved; Shottr's burnt-in annotations are an explicit complaint and wishlist item, §9 #47/#52). Keyboard-first single-key tool switching (Shottr's soul) with CleanShot-grade visual output ("annotations just look so damn good").
- **Backgrounds/beautify:** gradient/solid/image backdrops, padding, rounded corners, shadow, device-frame-free "professional" presets, auto-apply preset option, per-platform export sizes. Users say "professional," not "beautiful" (§8.8).
- **OCR + QR:** hotkey OCR-to-clipboard, auto language detection (fixes Shottr's gap), linebreak handling, link/QR detection. All on Apple Vision, on-device.
- **Pin/float:** the under-marketed sleeper hit (§2.1) — borderless, opacity, click-through lock, resize, hide-all, multi-pin.
- **Pixel tools (free, not a $ add-on like PixelSnap):** rulers with edge snapping, measurements, smart object selection, color picker with hex/OKLCH + WCAG/APCA contrast check, logical-vs-retina toggle.
- **Canvas:** crop/resize/rotate, expandable canvas ("color outside the lines"), multi-shot stitch/combine (doc-writer differentiator, §2.1).
- **Output discipline:** WebP/HEIC/PNG/JPEG, Retina→1x, file-size-conscious defaults ("I hate these screenshots that are >2MB", §2.1).
- **Hide desktop icons** — cheap to build, appears in nearly every CleanShot review as daily-retention utility (§2.2).
- **Capture history tray** — the transient last-N strip (distinct from, and a funnel into, the Library).

### Tier C — platform & trust plumbing (cheap, differentiating)

- **Guided hotkey-takeover onboarding:** deep-link to System Settings + live read of `com.apple.symbolichotkeys` → "⌘⇧3/4/5 freed ✓". Nobody does this; it's everyone's ugly first 2 minutes (§5, §8.9).
- **Permission health screen** + lazy Accessibility request at first scrolling capture; designed Sequoia/Tahoe re-auth moment (§8.9).
- **Native AppIntents/Shortcuts/Spotlight actions** (neither incumbent has them) + URL-scheme API + Raycast/Alfred extensions (§2.4).
- **macOS 14+, ScreenCaptureKit/SCScreenshotManager only**; Developer ID + notarized, Sparkle 2, Homebrew cask at launch (§8.9).
- **Speed budget as a spec:** hotkey→preview p95 < 200ms, app < 10 MB, idle RAM minimal — Shottr's 2.3 MB / 17 ms numbers are "quoted as legend" (§1.7); we must be in that class to use the "fast" word.
- **Trust kit:** real identity, real support SLA, public changelog cadence, trial with dignified expiry (no nag mascot), zero telemetry by default (a privacy-sensitive blur tool got pushback over telemetry, §shottr-features).

---

## 3. CUT — features the evidence says not to build (v1)

| Cut | Why (evidence) |
|---|---|
| **Cloud anything** (accounts, hosted links, sync) | Locked decision + the angriest CleanShot VOC is the forced cloud (§9 #28/#36); got Shottr banned at a company. Local-first is the marketable wedge. v2 must then match "link copied before upload finishes." |
| **Video/GIF recording** | Locked deferral — but treat as the #1-cited roadmap item (see §4 below). |
| **All-In-One capture UI** | [rarely-used] by reviewers (§2.2); adds chrome, contradicts the keyboard-first identity. |
| **Self-destruct/expiring shares, SSO/SCIM, team admin** | Business-cloud surface; v2+ at the earliest. CleanShot's 24h video self-destruct default is a documented trust wound — never replicate. |
| **Nag mascot / aggressive trial mechanics** | Shottr's "humongous paper clip creature" annoys even fans (§4); we monetize on a real trial instead. |
| **Separate paid measurement app** | CleanShot sells PixelSnap separately; Shottr includes rulers free and wins goodwill. Bundle pixel tools (§2.3). |
| **Server-side AI in v1** | "You had me at 'AI: none'" (§9 #54); vibe-coded AI apps get torched in r/macapps. On-device intelligence only (auto-name, redaction-detect, search). Server AI, if ever, is the v2+ subscription tier. |
| **Translation OCR, table reconstruction, before/after GIF assembly** | Niche/rarely-used (§2.3/§2.4); roadmap candidates, not v1. |
| **Mac App Store build** | Sandbox kills scrolling-capture AX + trials (§6.6); direct + Homebrew only, Setapp Marketplace as a later storefront. |
| **Dozens-of-settings sprawl** | "All these options just clutter the interface" (§4.9). Opinionated defaults, progressive disclosure. |

---

## 4. DEFER — v2 commitments the v1 architecture must not foreclose

1. **Video/GIF recording** — spec already cataloged (§2.2): webcam PiP, system audio *without drivers*, pause/restart, click/keystroke overlays, trim with live file size. Architectural hook: the capture engine and post-capture surface must treat "recording" as a first-class capture type from day one.
2. **Cloud link-sharing** — the bar is CleanShot's "link is copied before upload even finishes" (§3.6). Hook: the share/destination system is a plugin surface (clipboard, file, LLM, S3/BYO now; hosted cloud later). Shottr's v1.9 S3/self-hosted upload shows BYO-cloud satisfies power users in the meantime — include S3/custom endpoint in v1 if cheap.
3. **Windows port** — both incumbents have formally ceded it (§1.10). Hook: the OpenSpec domain spec (annotation model, library schema, editing operations, file pipeline) stays platform-agnostic; UI/capture layers are explicitly platform modules. Windows expectation-setting: ShareX/Snipping Tool set the free floor — the port sells polish + library, not capture mechanics (§8.4).
4. **Send-to-LLM destination** — moved to deferred per 2026-06-09 decision (no LLM-flavored features until PMF). Full spec preserved in `docs/deferred/send-to-llm.md`; the destination-plugin surface in MVP keeps it a drop-in.
5. **Premium on-device AI tier** — semantic library search, AI auto-naming, auto-redaction of PII/API keys (BlurData proves the job), smart cropping. Full spec in `docs/deferred/ai-features.md`. One-time higher tier if on-device; subscription only if server-side and well under the $96–120/yr rage line (§6).

> All deferred features live in `docs/deferred/` with evidence, architectural hooks, and revisit triggers.

---

## 5. Pricing proposal (adopting the research recommendation, §6)

- **Core license: $24 one-time, 3 Macs**, 1 year of feature updates.
- **Public pledge, on the pricing page: "Bug fixes are always free, forever."** (Community-stated ideal verbatim: "bug updates to be lifetime… only new features paid. Much like Agenda.") This is the direct strike at CleanShot's angriest wound.
- **Feature-version upgrades** (Agenda-style: keep what you bought forever; pay to add the new year's features) — no renewal treadmill, no license deactivation, ever.
- **Real 14-day trial**, full-featured, dignified expiry. 30-day refund.
- Launch discount + Black Friday as the community's tracked conversion events.
- Subscriptions reserved exclusively for v2 recurring-cost services (cloud ~$4–6/mo if ever).
- Positioning guardrail: do **not** price-fight Shottr at $12 (§6.5) — we sell a bigger job (the library + reliability), not a cheaper capture.

---

## 6. User flows (the flows people already love, with our fixes)

### Flow 1 — Bug report into Slack/Jira (highest-frequency job, §7.1)
⌘⇧4 (taken over) → drag region → preview chip lands in corner (< 200ms) → **Enter** → editor: `A` arrow, `C` counter ×3, `B` blur the token → **⌘C** → ⌘V in Slack. Mouse never required; nothing saved to disk unless asked. *Our fix vs today: CleanShot needs the mouse, Shottr's output looks rough — this is both, plus provenance (app/URL) embeddable as a caption.*

### Flow 2 — Screenshot → LLM *(DEFERRED — see `docs/deferred/send-to-llm.md`)*
The dev pasting into Claude Code/Cursor is still served in MVP by Flow 1 + Flow 3 (instant copy, OCR-to-clipboard); the dedicated destination/payload/burst features ship post-PMF.

### Flow 3 — "Steal the text back" (OCR daily driver, §7.3)
⌘⇧2 → drag over a Slack code screenshot → text on clipboard with indentation preserved, toast shows first line → ⌘V in VS Code. Three keystrokes, matching the HN-praised loop (§9 #50), plus auto language detect.

### Flow 4 — Make it professional (social/marketing, §7.6)
Capture window (true transparent shadow) → chip → **K** backdrop → brand preset (saved gradient + padding + corner radius + platform size) → drag the chip straight into the tweet composer. "YouTube thumbnail in 30 seconds" (§9 #22) becomes 10.

### Flow 5 — Pin a reference (sleeper hit, §7.8)
Capture the spec table → **P** → borderless always-on-top float at 70% opacity, click-through locked → work in Figma underneath → ⌘⇧P hides all pins for the Zoom share. (§9 #23)

### Flow 6 — "Where's that screenshot from last month?" (the wedge, §7.10)
⌘⇧L → Library → type "stripe webhook" → OCR-indexed results instantly, filtered to "from: Chrome" → hover shows source URL → Enter reopens it **with annotations still editable** → re-copy. Also surfaces screenshots taken with macOS native capture (auto-import).

### Flow 7 — Scrolling capture that doesn't lie (the crown, §8.3)
Hotkey → pick "auto" → live stitch preview scrolls alongside → hits a sticky header glitch → **post-capture restitch view**: drag the seam, fix it without recapturing → full-res export. If a surface can't be captured (Terminal), the app *says so* instead of producing garbage.

### Flow 8 — First run (trust onboarding, §5 friction list)
Install to /Applications (checked & guided) → one screen explains the two permission moments before macOS asks → Screen Recording grant → "Take over ⌘⇧3/4/5?" → deep-link + **live verification: "shortcuts freed ✓"** → first capture happens inside the onboarding → chip → "press Enter" → user has annotated within 60 seconds of launch.

---

## 7. Risks to carry into the PRD

1. **Deferring video** is the locked scope's biggest risk (§1.5) — v1 must win the screenshot jobs *decisively*, and marketing must show the recording roadmap.
2. **OSS commoditization clock**: macshot/Capso make baseline capture free within ~12 months (§8.6) — durable value lives in reliability, library, polish, support. Ship before the window closes.
3. **Library demand is deep but possibly narrow** (§10.8) — de-risk with the landing-page smoke test: "searchable screenshot library" vs "flawless scrolling capture" as the hero-message A/B.
4. **Platform spike needed before spec freeze**: does non-picker `SCScreenshotManager` trigger Sequoia/Tahoe re-auth? (§10.1, 1-day spike.)
5. **Scrolling reliability is hard** — it's the crown *because* it's structurally fragile; budget real engineering time and the failure-suite CI rig.
