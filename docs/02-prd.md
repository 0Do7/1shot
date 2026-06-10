# PRD — 1shot (working codename)

**A Mac-native screenshot tool: fast like Shottr, beautiful like CleanShot, honest pricing — and it remembers everything you've captured.**

Date: 2026-06-09 · Status: Approved scope (per /grill-me sessions) · Owner: Cody
Evidence base: `research/00-research-report.md` (cited as §) · Strategy: `docs/01-feature-strategy.md` · Decisions log: `docs/00-decisions.md` · Deferred: `docs/deferred/`

---

## 1. Vision & summary

Mac users who care about screenshots currently choose between two compromises: CleanShot X (polished, $29 + renewal friction + cloud upsell, 1-Mac license) and Shottr (fast, $12, dated UI, solo-dev fragility, no library). The community's own words define the gap: *"fast and sleek as CleanShot, library like Snagit"* (§9 #48) — and the reviewers' vocabulary has an unclaimed slot: **"fast like Shottr, beautiful like CleanShot, honest pricing"** (§5).

1shot is a native Swift menu-bar app that wins the **post-capture 3 seconds** (the moment every reviewer narrates, §1.1) with a hybrid overlay→keyboard-first editor, takes the **scrolling-capture reliability crown** (the most-litigated comparison axis, §1.3), and opens the **largest unowned white space** — a local, OCR-searchable screenshot Library (§8.2) — under a pricing model that weaponizes every documented competitor wound (§6).

**Local-first, no cloud, no accounts, no AI, no telemetry by default, no subscriptions.**

## 2. Goals / Non-goals

### Goals (MVP = full v1 strategy, per decision 2026-06-09)
1. Win the capture→annotate→share loop on speed *and* polish simultaneously (neither incumbent does both).
2. Ship the category's most reliable scrolling capture (pass the failure suite, §8.3).
3. Ship the first capture+Library combination on any platform.
4. Launch with the trust kit: real trial, honest license, fast support, visible cadence.
5. Private beta → coordinated public paid launch.

### Non-goals (MVP) — all preserved in `docs/deferred/`
- ❌ Video/GIF recording (v2; #1-cited deferred feature — roadmap must show it publicly)
- ❌ Hosted cloud sharing/accounts (v2; S3/custom-endpoint BYO upload IS in scope)
- ❌ Any LLM/AI feature, on-device or server (post-PMF; no production costs until PMF)
- ❌ Windows (post-PMF; spec stays portable)
- ❌ Mac App Store build (sandbox kills scrolling capture + trial)
- ❌ Teams/SSO/admin anything

## 3. Personas (from §7 JTBD map)

| Persona | Job | Decisive features |
|---|---|---|
| **Dev bug-reporter** (primary) | "99% of bug tickets carry a screenshot" — make the issue obvious before anyone asks | Speed budget, keyboard-first editor, arrows/counters/blur, repeat-area, OCR |
| **Designer / pixel-pro** | Inspect, measure, spec, give feedback | Rulers, smart selection, color/contrast tools, pin/float, zoom navigation |
| **Doc writer / educator** | The six-step tutorial treadmill | Scrolling capture, stitch/combine, re-editable annotations, consistent beautify presets, Library |
| **Content creator / marketer** | Make it look professional for the feed | Backgrounds/beautify, platform export sizes, window shadows |
| **The organized knowledge-worker** | "Where's that screenshot from last month?" | Library: OCR search, auto-naming, provenance, auto-import |

## 4. Positioning & messaging (locked 2026-06-09)

- **Hero:** best-of-both-worlds — "Fast like Shottr. Beautiful like CleanShot. Honest pricing." (revisable later)
- **Supporting sections (landing page):** the Library that remembers · scrolling capture that never lies · local-first & private · the pricing pledge
- Frame any cleverness as built-in/native — never "AI-powered" (§8.5). Use "professional," not "beautiful," for beautify output (§8.8).
- Voice-of-customer copy bank: report §9 (58 sourced quotes).

## 5. Pricing & licensing (structure locked; price = launch-time variable)

- **One-time license, $19–29 corridor (final number at launch), 3 Macs, 1 year of feature updates.**
- **Public pledge: "Bug fixes are always free, forever."** (Strikes CleanShot's angriest wound, §4.1.)
- Agenda-style upgrades: features you bought are yours forever; pay only to add new feature-years. No deactivation, no renewal treadmill.
- **14-day full-featured trial**, dignified expiry (no nag mascot), 30-day refund.
- Merchant of record: **Paddle** (published 5% + $0.50; license-key + trial support; CleanShot precedent, §6.6).
- Subscriptions: none. Reserved exclusively for genuinely recurring-cost v2 services.

## 6. Scope — Epics & requirements

Acceptance criteria are summarized here; the OpenSpec change (`openspec/changes/mvp/`) carries the implementable detail.

### E1 — Capture engine
Area / window / fullscreen / repeat-previous-area / delayed / freeze-screen capture via ScreenCaptureKit + SCScreenshotManager (macOS 14+ only, zero deprecated-API usage, §8.9).
- Window capture with true transparent shadows (beats CleanShot, §2.1) and shadowless mode.
- Repeat-area shows region preview before recapture (fixes Shottr complaint).
- Delay customizable in UI. Multi-display + mixed-DPI correct. Cursor include/exclude.
- **Recording is a first-class capture *type* in the domain model from day one** (v2 hook).

### E2 — Post-capture surface ("the chip") — signature feature
Capture → preview chip in screen corner in <200ms p95.
- Chip is persistent + stackable (CleanShot model) AND fully keyboard-driven (Shottr model): `Esc` discard/retake, `⌘C` copy-and-dismiss, `Enter` expand in-place into full editor, drag-out as file into any app.
- Hover affordances: copy, save, pin, edit, drag handle. Multi-capture stacking with bulk actions.
- **Nothing is written to disk until the user decides** (universally loved behavior, §5) — except the Library's index-on-capture, which is internal, not a user-facing file.
- Configurable: corner, timeout, or chip-off (pure clipboard mode).

### E3 — Editor & annotation engine
Single-key tools (Shottr's soul) with CleanShot-grade output ("annotations just look so damn good").
- Tools: arrow (straight/curved), line, rect/ellipse, text (styles), highlight (smart text-following), spotlight/dim, auto-incrementing counter badges, freehand, magnifier callout, crop, expandable canvas, multi-image stitch/combine.
- **Re-editable document format** — annotations are objects forever; reopening from Library keeps them live (§9 #47/#52). Flatten only on export.
- Zoom/pan navigation (Z+drag class). Undo/redo unlimited.
- **The annotation document model is platform-agnostic pure-Swift (no AppKit types)** — the Windows-portability core.

### E4 — Redaction
- Blur AND pixelate AND black-out (Shottr regret-quote: "its blur tool doesn't blur", §4.5). Hardened (non-reversible on export).
- **Text-aware blur/erase**: Vision text detection → one click blurs/erases all text instances; per-instance toggle. (Shottr's #1 wow, §9 #16/#17 — not an LLM.)
- Content-aware object removal (inpainting via Core Image/custom — no network).

### E5 — Scrolling capture (the reliability crown)
Auto-scroll + manual modes, vertical + horizontal, live stitch preview alongside capture.
- **Post-capture restitch view**: drag seams to fix without recapturing (Longshot's best idea, §8.3).
- Full-resolution output — never downscale (CleanShot's documented failure).
- Explicit failure messaging when a surface can't be captured — never silently produce garbage.
- **Must pass the failure suite in CI rig:** Terminal, VS Code, Finder column view, Mos installed, Scroll Reverser installed, sticky headers, lazy-loading pages.
- Accessibility permission requested lazily at first use, with explainer (§8.9).

### E6 — OCR & QR (on-device, Apple Vision — not an LLM)
- Hotkey region-OCR → text on clipboard with toast preview; indentation/linebreak preservation modes; auto language detection (fixes Shottr gap); link + QR detection.
- The 3-keystroke loop must hold: hotkey → drag → ⌘V (§9 #50).

### E7 — Pin / float
Borderless always-on-top floats: opacity control, click-through lock, scroll-resize, hide/show-all hotkey, multi-pin. (The sleeper hit, §2.1 — we market it.)

### E8 — Pixel tools (free — never a paid add-on, §2.3)
Rulers with edge-snapping (stampable), distance measurement, smart object selection, logical-vs-retina toggle, color picker (hex/RGB/OKLCH, Tab-to-copy without Shottr's lost-work footgun), WCAG + APCA contrast checker.

### E9 — Beautify / backgrounds
Gradient/solid/image backdrops, padding, rounded corners, shadow, **brand presets** (saved gradient+padding+radius+size), per-platform export sizes, optional auto-apply preset. Target: "professional in 10 seconds" (§9 #22).

### E10 — The Library (white-space wedge)
Local SQLite (FTS5) index; no cloud, no account.
- Every capture OCR-indexed at save; **full-text search of pixels** with instant results.
- **Heuristic auto-naming** (no AI): source app + window title + top OCR tokens → `stripe-webhook-error.png`.
- **Provenance**: source app, window title, URL (browser captures) stored + searchable + filterable; reopen-source action.
- Smart folders/tags (auto: per-app, contains-code, this-week; manual tags).
- **Auto-import**: watch standard screenshot locations to index captures from any tool, incl. pre-install history (opt-in).
- Spotlight integration via Core Spotlight donation.
- Re-open any item with annotations still editable (E3 format).
- Retention controls (size cap, age rules). Schema includes nullable metadata/embedding columns (deferred-AI hook).

### E11 — Output & destinations
- Formats: PNG/JPEG/WebP/HEIC, Retina→1x option, file-size-conscious defaults (§2.1).
- Filename templates; save-location rules (per-preset).
- **Destination plugin architecture**: clipboard, file, app hand-off now; S3/custom-endpoint upload (BYO, zero cost to us) in MVP; hosted-cloud and LLM destinations are drop-ins later (deferred hooks).

### E12 — Onboarding, permissions & trust
- Guided install-to-/Applications check; pre-permission explainer screens; Screen Recording grant flow designed for the Sequoia/Tahoe re-auth regime; **permission-health screen** (§8.9).
- **Hotkey takeover wizard**: deep-link to System Settings + live read of `com.apple.symbolichotkeys` (IDs 28–31/184) → "⌘⇧3/4/5 freed ✓" live verification. Nobody does this (§8.9).
- First capture happens inside onboarding; user has annotated within 60 seconds of launch (Flow 8).
- Zero telemetry by default; opt-in crash reports only. No account, ever, in MVP.

### E13 — Utilities & settings
Hide desktop icons + widgets toggle (daily-retention utility, §2.2) · capture history tray (transient last-N strip, funnel into Library) · opinionated defaults with progressive disclosure ("all these options just clutter the interface" — §4.9) · launch-at-login · menu-bar icon (hideable).

### E14 — Automation surface
Native **AppIntents/Shortcuts/Spotlight actions** (neither incumbent has them, §2.4) · URL-scheme API (off by default) · Raycast + Alfred extensions at launch.

### E15 — Licensing, trial & updates
Paddle license keys: activate/deactivate self-serve, 3 seats, offline grace · 14-day trial with dignified expiry (24h capture grace, then capture disables — but Library browse/search/re-edit/export remain available forever; never hold user data hostage) · Sparkle 2 auto-updates · Homebrew cask at launch · public changelog.

## 7. Non-functional requirements

| Dimension | Budget / bar |
|---|---|
| Hotkey→chip latency | < 200 ms p95 (the "fast" word license, §1.7) |
| Editor open | < 400 ms p95 |
| App size | < 15 MB download (Shottr 2.3 MB is legend; CleanShot's 75 MB is grumbled at) |
| Idle footprint | < 100 MB RAM, ~0% CPU |
| Library search | < 50 ms for 10k items (FTS5) |
| Crash-free sessions | > 99.8% in beta before launch |
| Compatibility | macOS 14+ (Sonoma); Apple Silicon native + Intel; multi-display, mixed DPI |
| Privacy | Local-only data; no telemetry by default; notarized, hardened runtime |
| Accessibility | Full keyboard operability (inherent), VoiceOver labels on chip/editor controls |
| Portability | Domain model packages contain zero AppKit/SwiftUI imports (CI-enforced) |

## 8. User flows (acceptance flows — full versions in `docs/01-feature-strategy.md` §6)

1. **Bug report into Slack** — keyboard-only, mouse never required, nothing saved to disk unless asked.
2. ~~Screenshot→LLM~~ *(deferred — `docs/deferred/send-to-llm.md`; devs are served by flows 1+3)*
3. **OCR steal-the-text-back** — 3 keystrokes to pasted text with preserved indentation.
4. **Make it professional** — capture→brand preset→drag to tweet composer in ≤10s.
5. **Pin a reference** — float at 70% opacity, click-through, hide-all for screen share.
6. **Library recall** — "stripe webhook" → result → reopen with live annotations → re-copy.
7. **Scrolling capture that doesn't lie** — live preview, restitch view, honest failure.
8. **First run** — permissions explained before macOS asks, hotkeys verified freed, first annotated capture within 60s.

## 9. Launch plan (locked: private beta → public launch)

1. **M-beta:** closed beta, 50–200 users recruited from r/macapps + X waitlist. Focus: scrolling failure suite in the wild, Library comprehension, crash-free rate. Licensing infra may land mid-beta.
2. **Launch:** coordinated paid 1.0 — Product Hunt + r/macapps post (founder-voice, trust-kit forward) + the comparison-SEO page ("X vs CleanShot vs Shottr" is an active, AI-spam-polluted battleground an authentic page wins, §5).
3. Launch assets from VOC bank (§9): hero demo videos of the five gasp-moments (text-aware erase, scrolling+restitch, Library search, chip flow, beautify preset).
4. Public roadmap page showing video recording + cloud as "next" (defuses the #1 objection, §1.5).
5. Setapp Marketplace conversation post-launch (decision 00; rev-share unpublished — ask first, §10.2).

## 10. Success metrics

- **Beta:** capture-success rate ≥ 99.5% (excl. declared-unsupported surfaces); scrolling failure-suite pass; ≥ 40% of beta users perform a Library search by week 2 (wedge validation); crash-free ≥ 99.8%.
- **Launch (90 days):** trial→paid conversion ≥ 5% (category benchmark); ≥ 1,000 licenses; refund rate < 3%; r/macapps sentiment net-positive (qualitative audit).
- **PMF signal (gates deferred-feature work):** organic recommendation threads + D30 trial-cohort retention via opt-in update-check pings only (privacy-respecting proxy).

## 11. Risks & mitigations

| Risk | Mitigation |
|---|---|
| "Everything is MVP" scope vs ~12-month OSS commoditization clock (§8.6) | Multi-agent parallel build (build guide); milestone gates allow demoting E5-restitch-view or E14 to fast-follow if beta date slips — demote-able items are flagged in tasks |
| Scrolling capture is structurally hard | Dedicated engine module + CI failure-suite rig from week 1; restitch view is the safety net |
| Library demand is deep-but-niche (§10.8) | Hero stays best-of-both; Library is proof-point — beta metric (40% search) validates before launch messaging invests |
| Sequoia/Tahoe re-auth regime UX | 1-day API spike (does non-picker SCScreenshotManager trigger re-auth? §10.1) **before** spec freeze; permission-health screen |
| No-video objection at launch | Public roadmap + review-seeding focused on screenshot jobs |
| Solo-founder support black-hole risk (both incumbents' wound) | Support SLA on site; canned-response tooling; visible changelog cadence as marketing |

## 12. Open items

1. Final price point (launch-time decision; corridor $19–29).
2. ~~Product name~~ RESOLVED 2026-06-09: **1shot** (bundle ID `com.sidequests.oneshot`, modules `OneShot*`, document extension `.1shot`).
3. SCScreenshotManager re-auth spike result → may adjust permission UX spec.
4. Setapp Marketplace rev-share inquiry (post-launch decision).
