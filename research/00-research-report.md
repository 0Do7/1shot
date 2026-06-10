# Consolidated Research Report — Mac Screenshot Tool ("Best of CleanShot X + Shottr")

**Date:** 2026-06-09 · **Synthesized from:** `cleanshot-features.md`, `shottr-features.md`, `demo-videos.md`, `market-landscape.md`, `reddit-voc.md`, `reviews-mining.md`, `use-cases-jtbd.md`, `gap-fresh-voc-2025-2026.md`, `gap-macos-platform-constraints.md`, `gap-naming-brand.md`, `gap-tier2-competitors.md`
**Tags carried through:** [OBSERVED] = official page/changelog/store/registry seen directly · [CLAIM] = reviewer/commenter assertion · VOC: = verbatim user quote. Pre-2024 evidence flagged where used.

---

## 1. Executive Summary — the 10 findings that should drive product decisions

1. **The post-capture 3 seconds IS the product.** Capture itself is a commodity; every reviewer narrates what happens immediately after the shutter. CleanShot's persistent corner overlay (copy/save/pin/upload/edit/drag) and Shottr's instant keyboard-first preview (Esc/Enter/⌘C/drag) are the two loved models. A hybrid — overlay that expands into a keyboard-first editor — is the literal "best of both worlds" no one ships. (demo-videos §8.1; reviews-mining §8 "Screenshots and recordings sit at the corner of your monitor until you're ready to use them.")

2. **Pricing: one-time ~$19–29 with a public "bug fixes are always free" pledge and a 2–3 Mac license is the evidence-backed choice.** Subscription is a slur in this market — Snagit's 2025 subscription pivot and Screen Studio's 2025 one-time kill both produced loud, quotable backlash (founder VOC: "I deeply regret doing that"). CleanShot's single most attackable wound is bug fixes gated behind the $19/yr renewal (documented via support-email screenshots); its second is one-Mac licensing. Shottr's $12/5-devices sets the value anchor. Cloud/server-AI is the only legitimately subscription-shaped piece, and even fans call CleanShot Cloud "overpriced."

3. **Scrolling capture reliability is the single biggest head-to-head differentiator and the #1 switching trigger in both directions — and nobody is actually reliable.** It is structurally fragile on macOS (no system API; all implementations are scroll-synthesis + stitching). The quality bar is now PRD-ready: auto + manual modes, live stitch preview, post-capture restitch, horizontal, no output downscaling, and passing the failure suite (Terminal, VS Code, Finder columns, Mos/Scroll Reverser installed). Longshot leads on mechanics; CleanShot on polish; no one on reliability.

4. **The screenshot library/organized-memory job is the largest unowned white space.** The community has literally written the spec as a thread title: "fast and sleek as CleanShot, library like Snagit." CleanShot has declined to build it for years [CLAIM, repeated]; Shottr has nothing; ScreenFloat ($17.99, rapturous reviews) and Tidyshot ($5.99 on-device AI renamer) prove standalone willingness-to-pay; the iOS AI-organizer wave proves demand at scale. Capture + library in one app has no occupant.

5. **Video/GIF recording is CleanShot's #1 retention lever and Shottr's loudest wishlist scream ("why oh why can it not do video capture please I'm begging you").** Deferring video to v2 is the locked decision's biggest scope risk: v1 must win the screenshot jobs decisively (scrolling, library, speed, redaction) and the roadmap must treat recording as the most-cited deferred feature, with the spec already cataloged (webcam PiP, system audio without drivers, pause/restart, click/keystroke overlays, trim with live file size).

6. **Screenshot→LLM is the fastest-growing new job (2024→2026) and no incumbent owns it.** Devs paste UI bugs into Claude Code/Cursor daily, OCR Slack screenshots into VS Code in 3 keystrokes, and new micro-tools (LazyScreenshots, Vibeshots) exist purely for "people who paste into AI all day." Concrete features: burst-capture → bulk paste, auto-blur secrets before paste, OCR+image+source-metadata as one payload, configurable AI destination.

7. **"Native Swift" is now an explicit purchase criterion and trust filter.** Vibe-coded Electron clones get destroyed in r/macapps ("vibe coded electron slop"); "feels like Apple built it" is the top CleanShot compliment; Shottr's 2.3 MB / 17 ms numbers are quoted as legend. Meanwhile free native OSS clones (macshot 1.9k★, Capso 903★ — both shipping scrolling capture, updated this month) are commoditizing baseline capture within ~12 months. Durable value = reliability engineering, library/AI organization, polish, support.

8. **The hero demos that make reviewers gasp on camera are known:** text-aware blur/erase ("That's some Next Level AI"), scrolling capture that just works ("what the actual heck… 12 out of 10"), one-click beautify backgrounds ("a YouTube thumbnail in 30 seconds"), OCR from impossible places (playing GIFs, QR codes), and pin/float (the sleeper hit users "stumbled into"). These plus a keyboard-first editor with CleanShot polish are the launch-review playbook.

9. **Local-first is a marketable wedge — the angriest CleanShot VOC anywhere is "Forcing your own cloud should be illegal" — but cloud link-sharing is simultaneously the single feature business users call "crucial."** Both constituencies are real and loud (~38 mentions each way). v1 local-first matches a vocal segment and a corporate-trust angle (Shottr was banned at a company over its upload feature); v2 must match the "link in clipboard before upload even finishes" spec.

10. **Both incumbents are showing stagnation/abandonment anxiety, and both have formally ceded Windows.** CleanShot shipped one feature release in 13 months ("is the renewal worth it this year?" is now a recurring thread); Shottr had zero releases in 2026 H1 ("Thought it was abandoned"), and both have documented support-black-hole complaints. Fast, human, visible dev responsiveness is cheap differentiation — Shottr's "decent dev" halo and macshot's ship-in-hours cadence earn outsized loyalty. CleanShot's FAQ: no Windows version "and no planned release currently"; Shottr's: "doesn't seem likely… codebase is not portable." The future Windows port has no native premium competitor waiting.

---

## 2. Feature Matrix: CleanShot X vs Shottr

Classification: **[table-stakes]** = free tools already do it / absence disqualifies · **[differentiator]** = evidence people pay/rave/switch for it · **[rarely-used]** = present but low-evidence usage.

### 2.1 Overlap (both have it)

| Feature | CleanShot X | Shottr | Quality notes & classification |
|---|---|---|---|
| Area / window / fullscreen capture | ✅ + All-In-One mode, editable window shots (4.8) | ✅ + "Capture Any Window", shadow modes | **[table-stakes]**. Shottr wins raw speed (17ms/165ms claim, "demonstrably faster" VOC); CleanShot wins polish. Shottr does transparent-shadow window shots better — VOC: "CleanShotx can't accurately produce shadow" (reddit 1j87ewh). |
| Repeat/previous-area capture | ✅ separate shortcut | ✅ (v1.6) | **[differentiator]** for repetitive feedback workflows ("Best for repetitive region screenshot"). Shottr friction: region not previewed before recapture (explicit complaint). |
| Scrolling capture | ✅ vertical + horizontal (4.8), auto-scroll | ✅ vertical ±reverse, up to 200k px | **[differentiator]** — the most-litigated feature in every comparison. Majority verdict: CleanShot "leaps and bounds better"; minority prefers Shottr's. Both have 2024–26 failure VOC (CleanShot: downscaled output, "refuses to go to the end"; Shottr: skipped frames, broke on macOS 26). See §8 quality bar. |
| Delayed/self-timer capture | ✅ | ✅ (3s, arbitrary via URL scheme) | **[table-stakes]**. Shottr complaint: delay not customizable in UI. |
| Freeze screen | ✅ | KB-documented trick | **[rarely-used]** but fixes the Figma dotted-line class of bugs (Shottr regression thread 1joxuu7). |
| Annotation suite (arrows, shapes, text, highlight, spotlight, counter, freehand) | ✅ 19+ tools, re-editable .cleanshot projects | ✅ 16 tools, hand-drawn style, magnifier callout | **[table-stakes]** to have; **[differentiator]** to be *fast and good-looking*: "annotations just look so damn good" (CSX) vs Shottr's "burnt-in" annotations complaint (no re-edit after save — explicit wishlist). Auto-incrementing counters loved on both. |
| Blur / pixelate / redact | ✅ hardened pixelate, Gaussian, Black Out | ✅ + **text-only blur/erase + content-aware object removal** | **[differentiator]** — Shottr's text-aware blur/erase is THE wow moment in every Shottr video ("downright freaky", "blew my mind"). CleanShot has no object removal. One Shottr regret-purchase: "its blur tool doesn't blur (it only pixelates)". |
| OCR (on-device) + QR | ✅ 24+ languages on Tahoe, auto-detect, link detection | ✅ fast, linebreak strip, CJK setting | **[differentiator]** in daily-driver usage (devs OCR Slack screenshots into VS Code); both on Apple Vision so language coverage tracks macOS version. Shottr gap: no auto multi-language (drives TextSniper pairing). Neither does translation (iShot/macshot do) or OCR-history search. |
| Pin/float screenshots | ✅ opacity, click-through Lock Mode, hide-all | ✅ borderless, scroll-resize, transparency | **[differentiator]** — the sleeper hit ("It's a lifesaver for visual references… haven't looked back"); ~38 Reddit mentions, under-marketed by both. |
| Color picker | ✅ in-editor (4.8) | ✅ Tab-to-copy hex, OKLCH, average-color, **WCAG/APCA contrast checker** | Shottr's is **[differentiator]** for designers (replaced standalone apps); CleanShot's is parity. Shottr friction: Tab doubles as close-without-save (lost-work-on-camera moment). |
| Background/beautify tool | ✅ 20 backgrounds, presets, auto-apply-to-every-shot | ✅ Backdrop (v1.8): gradients, shadows, corners | **[differentiator]** for the social/marketing job ("pops a lot better in the feed"). CleanShot's preset auto-apply is the deeper implementation; Shottr's is basic and (per one 2025 thread) paywalled in free tier. |
| Image stitching/combine | ✅ drag-drop multi-shot canvas | ✅ Add Capture / append | CleanShot's cited as "not found elsewhere" (TidBITS); Shottr's has tool-compat caveats. **[differentiator]** for doc writers; CleanShot also criticized: "completely falls down… combining multiple images" (ex-Snagit user). |
| Expandable canvas (draw outside bounds) | ✅ | ✅ (v1.7.2) | **[rarely-used]** but a delight quote generator ("you can literally color outside the lines!"). |
| Hotkeys for everything | ✅ | ✅ single-key editor tools | **[table-stakes]**; Shottr's keyboard-first editor is its soul, CleanShot's editor is mouse-first. |
| URL-scheme automation + Raycast | ✅ 18 endpoints, official Raycast ext | ✅ schemes (off by default), Raycast + Alfred | **[differentiator]** for the power-user ecosystem; neither ships native AppIntents/Shortcuts actions — open Tahoe-era gap. |
| Crop/resize/rotate, format options | ✅ WebP/HEIC, sRGB, Retina→1x | ✅ resizer, 144dpi, auto PNG/JPEG | **[table-stakes]**. File-size-conscious output is a real VOC job ("I hate these screenshots that are >2MB"). |
| Capture history | ✅ 1-month history, filters, restore | ❌ (none) | CleanShot's is "limited" / transient tray — **[differentiator] half-built**; the full library job is unserved (§8). |

### 2.2 Unique to CleanShot X

| Feature | Classification | Evidence |
|---|---|---|
| **Screen recording (MP4/GIF), system audio w/o drivers, webcam PiP, pause/restart, click/keystroke overlays, trim editor** | **[differentiator — #1 retention feature]** | "screen recording to gif worth the price alone"; Loom-replacement workflow; "this feature alone is worth the price" (system audio). Deferred to our v2. |
| **Cloud sharing (1 GB free; Pro: unlimited, custom domain, password, self-destruct, SSO/SCIM, transcription)** | **[differentiator] for business minority; [rarely-used]/bloat for prosumers** | "I use the image hosting for my business… crucial" vs "everything except cloud upload"; "you do not need to waste $8 a month." 24h default video self-destruct is a trust wound. Deferred to our v2. |
| Hide desktop icons + widgets (standalone toggle) | **[differentiator]** — daily-retention utility used during Zoom shares; the app's namesake | demo-videos §2.10 |
| Quick Access Overlay (persistent corner hub, stacking, swipe gestures) | **[differentiator]** — the signature interaction | But also: "quick access takes important place of screen, blocking whatever is behind." |
| All-In-One capture UI | [rarely-used] by reviewers; convenience | |
| Smart Highlighter (word detection), curved arrows, 7 text styles | [differentiator-polish] | "highlight text and it keeps it on the text" |
| Re-editable .cleanshot project format | **[differentiator]** for doc maintenance | Shottr's burnt-in annotations are an explicit complaint. |
| Self-timer cursor handling, DND auto-enable, notch auto-crop | [table-stakes-polish] | |
| Horizontal scrolling capture | [differentiator] (only CleanShot + Longshot/macshot) | |
| PixelSnap integration (measurement sold separately, $) | n/a — Shottr includes rulers free | |

### 2.3 Unique to Shottr

| Feature | Classification | Evidence |
|---|---|---|
| **Pixel rulers (snap-to-edges, stampable), measurements, smart object selection (A-key, ⌘-click monotone)** | **[differentiator]** — its editorial identity | "the best measuring tool in mother-friggin macOS" |
| **Text-only blur / text-only erase / content-aware removal** | **[differentiator]** — the single biggest wow across all Shottr coverage | "I push delete and they're all gone and you would never know" |
| WCAG/APCA contrast checker, OKLCH | [differentiator-niche] designers | |
| True zoom/pan editor navigation (Z+drag, ⌘2 into selection) | [differentiator] "precise screenshots: Shottr 5+" | |
| 2.3 MB size / 17 ms capture / Apple-Silicon-optimized | **[differentiator]** — speed is a feature | "crazy fast and never lags"; "1 to 2 seconds is… almost like lunch break" |
| S3/self-hosted upload (v1.9) | [differentiator-niche] BYO-cloud power users | Partially defused "no cloud"; "one-shortcut shareable link" still missed. |
| Before/after 2-frame GIF assembly | [rarely-used] | |
| Free tier (full-featured nagware) + $12/5 devices | **[differentiator]** — the funnel | "the WinRAR of macOS" |
| Guides (Opt+S/D), scrolling capture up to 200k px, reverse scroll | [niche] | |

### 2.4 Neither has (gaps both share — our openings)

- **Screenshot library**: smart folders, tags, OCR-indexed search, source-app/URL metadata, auto-import (ScreenFloat/Tidyshot/Snagit define the bar). **The white space.**
- **AI features of any kind** (CleanShot: only Raycast hand-off + Cloud transcription; Shottr: none): auto-redaction of PII/API keys, auto-naming, semantic search, smart cropping — all already monetized by micro-tools (BlurData, Tidyshot, Pixera).
- **Native AppIntents/Shortcuts/Spotlight actions** (both URL-scheme-only).
- **Send-to-LLM destination** (paste-payload of image+OCR+metadata).
- **Provenance metadata** (source URL/window title — Screenotate's long-praised idea; fresh VOC asks for it).
- **Guided hotkey-takeover onboarding** (live detection of freed ⌘⇧3/4/5 — nobody does it).
- **Windows version** (both formally declined).
- **Translation OCR, table reconstruction**, project-scoped capture presets, batch doc consistency, stale-screenshot re-take.

---

## 3. What Users LOVE (evidence-ranked, with VOC)

### CleanShot X (rank by frequency/intensity across veins)

1. **Polish / "feels native"** — the most repeated praise family everywhere. VOC: "it feels like Apple built it" (r/macapps 2026); "feels native to the point I can forget it's not part of the Mac experience" (2026); "I didn't realize how broken native screenshots on macOS were until I started using CleanShot" (testimonials).
2. **Workflow speed via the overlay** — VOC: "The UX of CleanShot is amazing — I've never been able to capture, annotate, and share visuals so quickly"; "Screenshots and recordings sit at the corner of your monitor until you're ready to use them" (Matt Galligan); "about 99% of bug tickets I enter… have a CleanShotX screenshot attached" (HN 2025).
3. **All-in-one consolidation** — "It feels like 7 apps in one" (official, echoed); "saves me a lot of money from not needing Loom"; G2: "three different tools… in one place."
4. **Annotation quality** — "The fact that the annotations just look so damn good… Most other tools produce ugly annotations" (r/macapps).
5. **Scrolling capture** — "leaps and bounds better [than Shottr] and I use it a lot"; "what the actual heck… It's a 12 out of 10 experience" (YouTube).
6. **Recording + instant cloud link** — "link is copied before upload even finishes… my video could still be uploading" (MinorCo); recipients: "wow, thank you for the video."
7. **Backgrounds/beautify** — "a pretty nice looking YouTube thumbnail for about 30 seconds of work"; "It just looks so pretty."
8. **Value once bought** — "Me: I dunno, $29 for CleanShot seems steep... Also me, 10 minutes after buying it: 😍" (Josh Puetz); "$29 price tag is well justified and you will realize this yourself once you pay."
9. **Hide desktop icons** — appears in nearly every review as a daily utility.
10. Social proof scale: **99% positive across 14,013 Setapp ratings** [OBSERVED] — the strongest datapoint in the category.

### Shottr

1. **Speed & tininess** — "crazy fast and never lags my system. The fact that this app is basically free is insane to me. I'd literally throw money at the developer" (r/macapps, 59↑ thread); "tiny, easy, stable" (PH); "shottr is literally (literally) noticeably faster… than the native animated corner pop out thing."
2. **Text-aware blur/erase/object removal** — "It's crazy how well this works… That's some Next Level AI" (Bog); "downright freaky!… I've never seen anything like it" (Podfeet 2023).
3. **OCR** — "the OCR, the pinning, the rulers, everything" ; "I use Shottr on my MacBook to immediately OCR my screenshots" (HN 2025); "whether someone shares code or error log as screenshot on slack, it's 3 steps" (HN 2025).
4. **Price/value & dev goodwill** — "$12 is a fair price" (28 pts); "Shottr dev seems like a good person… I'll support devs like that"; "Why would you use anything but Shottr on macOS?… on a whole different level. They deserve all the fame" (HN 2026).
5. **Pixel tools** — "fwiw shottr has colour picker (press tab) and distance (hold 1… 2…)"; the maker's own positioning: "a workhorse for pixel-professionals."
6. **Keyboard-first loop** — "The workflow of quickly grabbing a screenshot, annotating it, and hitting Esc is incredibly efficient" (PH); "less steps to copy the screenshot you just took."
7. **"Does 90% of CleanShot"** — the recommendation-ladder logic: "Shottr will still do 90% of CleanshotX, and do it with style."
8. **Delight conversion** — "I now go out of my way to find opportunities to take a screenshot just so I can mark it up" (PH).

---

## 4. What Users COMPLAIN About / Don't Use (evidence-ranked, with VOC)

### CleanShot X complaints (by heat × frequency)

1. **License model — bug fixes behind renewal** (angriest theme, sustained 2024→2026, documented with support screenshots): "your only option is to renew your license to fix the bug"; "I had to repurchase my license to get some bugs fixed"; "so it's a one-time-payment subscription..that's. insane."; "a dressed up sub model." Third-party articles now (mis)frame it as "$29/year" — perception damage done.
2. **One-Mac licensing**: "it's gonna disable one if you try to activate it on the other"; "I still use Shottr at work because I don't want to pay for a second license."
3. **Forced/upsold cloud**: "Forcing your own cloud should be illegal... no way to hide it" (PH — angriest single quote found); "I don't want to pay anymore to have their TRASH CLOUD PRODUCT shoved in my face" (2026); 24h default video self-destruct: "Your videos get deleted automatically and nobody tells you."
4. **Price as gatekeeper**: "$29… just too much for a lot of people who just need simple screenshots"; "a hard pill to swallow."
5. **No library**: "cleanshot doesn't have a library… [Snagit] I can share screenshots between all my devices"; "They have no intention of picking up that area."
6. **Scrolling capture edges**: non-adjustable max height, output downscaling ("the longer the area… the smaller the text"), "refuses to go to the end of the document" (Setapp review).
7. **Perceived stagnation** (2025–26): "it seems that the development of the app has stalled… is the developer even still motivated?"; "Love the app, maybe it makes sense to renew every 2-3 years?"
8. **Support latency**: "I emailed support about this 7 months ago. Not a priority..."
9. **Overkill/clutter for casual users**: "All these options just clutter the interface"; learning-curve notes (G2); overlay "blocking whatever is behind."
10. **No trial** outside Setapp; reliability bugs (recording stops after 12–18 min; DisplayPort reset "Infuriating"; ~75 MB app vs Shottr 2.3 MB grumbles).
11. **Don't use:** Cloud is the #1 "everything except…" answer; All-In-One and many of the "50 features" go unmentioned in usage censuses.

### Shottr complaints

1. **Scrolling capture unreliability** — most-repeated single defect in the corpus: "the scrolling screenshot messes up quite a bit. Never happened to me when trying CleanShot X"; "it cut out some portion"; macOS 26 broke it outright (error citing "macOS 13.5" while on 26.0.1). The #1 reason people upgrade to CleanShot.
2. **No video/GIF recording** — now the loudest wishlist item: "why oh why can it not do video capture please I'm begging you"; "No screen recording kills Shottr for me."
3. **Slow/opaque solo-dev cadence & abandonment anxiety**: "Thought it was abandoned"; "barely gets any updates (0 so far in 2026)"; macOS-beta breakage cycles; "I do not know how to reach him… he has kept no option to reach him!!!!!!"
4. **Dated/non-native-feeling UI**: "it just looks a little dated"; "I would like the developer to make the UI feel more minimalistic and similar to Apple's UI"; "Cleanshot seems to have better UI" (PH).
5. **Annotation/editing gaps**: burnt-in (non-re-editable) annotations; "it only zooms at 100% increments, its blur tool doesn't blur… worse at annotations than Preview. I really regret buying it"; transparent-background annotation workflow "clunky frustrating" vs CleanShot; weak text styling.
6. **Nag mascot** post-paid pivot: "The humongous paper clip creature... now it's a bit annoying" — though the community largely defends the $12 ask.
7. **Upload/cloud friction**: token-by-email for free users ("Haven't done this"); "Shottr is not a secure image storage! All uploads are considered public" [OBSERVED]; got Shottr **banned at a company** (corporate-trust ceiling).
8. **OCR edges**: no auto multi-language (TextSniper pairing), no Hindi, occasional typos on camera.
9. **Quality confusion**: "less sharp" output, no dpi/quality setting, "cannot capture white #fff"; Tab-key data-loss footgun; splash-screen-on-login annoyance; notification-permission hack needed.
10. **No history/library/organizer** (top items on its own public request list [OBSERVED]).

---

## 5. As-Used Flow Comparison (video vein)

### CleanShot X capture-to-done
DMG → license/Cloud activation → wizard offers to take over ⌘⇧3/4 but **user must manually uncheck Apple's defaults in System Settings** (the ugly first 2 minutes of every user's life) → capture → **Quick Access Overlay** slides into corner and persists → hover hotkeys (⌘E edit, copy, save, pin, upload, drag-as-file into Slack/Docs) → editor with mouse-first tools, objects stay editable, B = Background tool → done. Key behavior: **nothing is written to disk until you decide** — universally loved. Most common reviewer loop: capture → ⌘E → arrow/blur → drag into Slack. Recording loop: select region → mic/system-audio/webcam toggles → pause/resume/restart → trim → auto-upload with **link copied before upload finishes**.

### Shottr capture-to-done
DMG → menu-bar icon → set hotkeys (same manual System Settings surrender; plus a second Accessibility prompt for scrolling capture) → capture → **preview window** (editor-lite): Esc = throw away and retake, ⌘C = copy-and-close without saving a file, Enter = full editor, drag-out = save anywhere → editor driven by single keys (B blur, H highlighter, C counter, M magnifier, K backdrop, 1/2 rulers, Tab hex, A smart-select, Enter crop). Feel: "throwaway-fast," keyboard-first, transient.

### Magic moments (gasps on camera)
- CleanShot: scrolling capture working first time ("12 out of 10"); backgrounds → social-ready in 30s; OCR from a playing GIF; pause/restart mid-recording; link-before-upload-finishes; drag-anywhere overlay.
- Shottr: text-only blur/erase/content-aware delete (the cold-open of multiple videos); Tab-to-copy hex; pixel rulers; Esc-to-retake speed; "it's basically free."

### Friction moments (the fix list)
- **Both:** manual hotkey surrender in System Settings (nobody automates or even live-verifies it — see §8/platform).
- CleanShot: no trial; 1-device license; Cloud Pro value confusion on camera ("not exactly sure what's all in there"); manual scroll outrunning the stitcher; background auto-extend only clean on solid colors; shallow video editor.
- Shottr: notification-permission hack; Tab-key lost-work footgun; email-the-dev upload token; double permission prompts; OCR typos; no recording.

### The unclaimed positioning slot in reviewers' existing vocabulary
CleanShot = "versatile all-in-one," Shottr = "lightning fast, lightweight, pixel-perfect, free," Screen Studio = "polished video." Open: **"fast like Shottr, beautiful like CleanShot, honest pricing."** The comparison frame ("CleanShot vs Shottr vs …") is an active, AI-spam-polluted SEO battleground an authentic comparison page would win.

---

## 6. Pricing Landscape + Sentiment → Recommendation

### The map (June 2026, all [OBSERVED] unless noted)

| Product | Model | Price | Sentiment |
|---|---|---|---|
| macOS built-in / Win Snipping Tool | free | $0 | The rising free floor (Snipping Tool now: OCR, recording+audio, trim, color picker, redaction, GIF) |
| Shottr | freemium nagware → one-time | $12 Basic (1 user/**5 Macs**), $30 Friends Club; BF $9 | Beloved; price hike produced FOMO purchases, not anger; "underpriced" per fans |
| CleanShot X | one-time + optional update renewal; cloud sub separate | $29 (1 Mac, 1 yr updates) + $19/yr optional; Cloud Pro $8–10/mo; BF 30% off | "Worth every penny" AND "dressed up sub model" — the renewal/bug-fix gate is the wound |
| Xnapper | one-time + 1yr updates (renew −40%) | $29.99 | Fair; $5 AppSumo LTDs are an anchoring hazard |
| Tier-2 lifetime band | one-time | $5.99–$17.99 (Tidyshot, Snipaste, Longshot, iShot, ScreenFloat) | The norm; Xnip's $4.99/yr sub is its top complaint magnet |
| Snagit | **subscription-only since Jan 2025** | $39/yr | "a licensing 'gotcha' and a pretty disgusting greed move"; visible exodus |
| Screen Studio | **subscription-only since Sep 2025** | $108/yr | Founder: "I deeply regret" the prior $229 one-time; pricing is its "most consistent point of friction" |
| Zight/Droplr/Monosnap | freemium subs | ~$3–10/mo | Stagnating/harvest mode — cloud-sharing-as-subscription is a dying standalone category |
| Cap (template) | OSS + one-time desktop OR cloud sub | $58 once / $8.16/mo | The hybrid model working in adjacent recording space |
| Setapp (channel) | $9.99/mo bundle; since Mar 2026 single-app sales | — | Community cynicism ("a middleman"); CleanShot is the #1 "buy outright instead" app |

### Sentiment laws (from ~2,000 community datapoints)
1. **Subscription is a slur** for utility apps; $120/yr-class pricing is "waaay overpriced"; the two 2025 subscription pivots are the category's cautionary tales and active churn events (Snagit refugees explicitly told to go to CleanShot/ShareX).
2. **One-time $12–35 is the praised corridor.** $29 clears WTP *after* value demo (Josh Puetz arc) but is "a hard pill" top-of-funnel — hence Shottr's free funnel wins volume.
3. **The renewal gotchas are the real rage triggers**, not price level: bug-fixes-behind-renewal (CleanShot), license revocation (Snagit), one-Mac seats (CleanShot). Community-stated ideal, verbatim: "bug updates to be lifetime… and only new features to be paid. Much like Agenda."
4. **Cloud/recurring-cost services are the only tolerated subscription** — and even there CleanShot Cloud is called "overpriced" by superfans who coach skipping it.
5. **Don't price-fight Shottr**: "Shottr has those 4 features + a lot more for $12… you'd have to price even lower" — community veterans explicitly warn entrants off pure-cheaper plays; the slots at $0/$12/$29 are taken. Differentiate on use case.
6. **Channel economics** [OBSERVED]: Paddle MoR = 5% + $0.50 published (CleanShot's choice; FastSpring opaque ~5–8.9%); Setapp's pool model dilutes low-priced utilities (Shottr declined it for exactly this) but the Mar 2026 Setapp Marketplace (single-app lifetime sales, rev-share unpublished) reopens it as a secondary storefront. MAS structurally excluded for the full product (sandbox kills scrolling-capture AX + trials).

### Data-backed recommendation
**One-time core license ~$19–29, covering 2–3 Macs, with a public "bug fixes are always free, forever" pledge; optional paid feature-version upgrades (Agenda-style) or discounted update-year renewals for new features only; 30-day refund + real trial (dignified expiry, no mascot-nag); launch/BF discounts as the conversion events the community already tracks.** Reserve subscription pricing exclusively for genuinely recurring-cost v2 services (cloud sharing, server-side AI) priced well under the $96–120/yr rage line (~$4–6/mo) — and if AI is on-device, put it in a higher one-time tier instead. This simultaneously matches every praised model in the corpus and weaponizes every documented competitor wound (CleanShot's renewal gate + 1-Mac seat, Snagit's subscription, Xnip's sub, Shottr's nag).

---

## 7. Jobs-to-be-Done Map (jobs → workflows → underserved friction)

| # | Job | Workflow today | Underserved friction (opportunity) |
|---|---|---|---|
| 1 | **Bug reporting/QA** ("make the issue obvious before anyone asks") — highest frequency; "99% of bug tickets" carry a screenshot | hotkey → annotate (arrows/steps/blur) → paste into Jira/Slack/GitHub | Env metadata (URL, app, OS) lost; multi-shot bugs need manual stitching; cloud links cost extra |
| 2 | **Screenshot→LLM** (fastest-growing, 2024+) | capture → clipboard → ⌘V into Claude Code/Cursor/ChatGPT | No first-class AI destination; no burst→bulk-paste; no auto-blur-secrets-before-paste; no image+OCR+metadata payload |
| 3 | **OCR/knowledge capture** ("steal the text back") — daily driver | hotkey → region → text on clipboard → VS Code/Obsidian | Formatting lost (code indent, tables); no provenance (source URL/window); no note-app routing; multi-language auto-detect |
| 4 | **Documentation/tutorials** ("the six-step treadmill") | capture clean window → numbered steps → consistent padding → export/rename/move/insert ×20 | Per-project presets (naming+folder+style); re-editable annotations; batch consistency; stale-screenshot re-take |
| 5 | **Design QA/pixel inspection** | capture → zoom → ruler/measure → color-pick → compare | Measured values don't flow anywhere (retyped); no Figma destination |
| 6 | **Social/marketing beautification** | capture → backdrop/padding/frame → platform-sized export | Brand presets; per-platform export sizes; (video beautify = v2) |
| 7 | **Customer support** | capture → annotate + blur PII → hosted link in Zendesk macro | Needs cloud links (v2); image reuse library |
| 8 | **Reference-while-working (pin/float)** | capture → pin always-on-top → work → discard | Near-solved; multi-pin composition + per-app/Space pinning are the polish edge |
| 9 | **Compliance/receipts/evidence** (thin) | scrolling capture → timestamped file | Long-tail; retention + timestamps suffice |
| 10 | **Organization/recall (meta-job, unsolved)** | Hazel rules, Dropbox folders, hand-rolled S3 pipelines; iOS AI-organizer app wave | **The white space**: OCR/semantic-searchable local library, auto-naming, source metadata, auto-import of others' screenshots |

Cross-cutting: speed is the product (nothing may slow hotkey→clipboard); power users glue tools via Raycast/Alfred/Hazel/URL schemes — automation surface is cheap leverage; the multi-tool reality (CleanShot + Shottr + ScreenFloat + TextSniper simultaneously, per TidBITS 2026) is the literal evidence that "best of both worlds" is bought today as four apps.

---

## 8. Market White Space & Positioning (incl. Windows)

1. **"Power + Pretty + Private (+ Organized)" in one app has no occupant.** Shottr = power/no polish; Xnapper = pretty/no power; CleanShot = both-ish with cloud-flavored upsell and no library. A native, local-first, one-time-priced app spanning capture → annotate → beautify → OCR → **organize/search** is the unfilled composite.
2. **The library is the deepest single wedge** (§7 job 10). Bar to meet, fully specified by tier-2 leaders [OBSERVED]: ScreenFloat-class smart folders/tags/Spotlight/iCloud-sync + **auto-import of screenshots taken with any tool** (its killer v2.3.6 move) + Tidyshot-class on-device-AI renaming ("figma-dashboard-header.png") and semantic search + Snagit-class source-app/website metadata. Two different apps named "TidyShot" launched within 3 months of each other — the niche is heating up *now*.
3. **Scrolling-capture reliability is a winnable engineering crown** (structural fragility means whoever passes the failure suite owns the most-litigated comparison axis). PRD bar: auto + manual modes, live stitch preview, post-capture restitch (Longshot's best idea), horizontal, full-res output, explicit failure messaging, pass Terminal/VS Code/Finder-columns/Mos/Scroll Reverser.
4. **The orphaned Snagit individual** (Mac+Windows, corporate-grade needs, subscription-hating) is actively told to split across ShareX + CleanShot. A future one-time Mac+Windows app is the only clean answer — **and both incumbents have publicly ceded Windows** [OBSERVED: cleanshot.com/faq "no planned release"; shottr.cc FAQ "doesn't seem likely… codebase is not portable"]. Windows demand signals exist on camera ("if this was a Windows app I would be baffled"; "insane that mac doesn't have sharex and you gotta pay for the 'equivalent'" — reverse direction; Reddit asks for "Shottr for Windows"). Caveat: ShareX + the upgraded Snipping Tool set Windows expectations at "everything free" — a Windows port must sell polish/UX/library, not capture mechanics.
5. **Local-first AI is the unclaimed premium tier**: on-device auto-redaction (BlurData/PageRedact prove the job), auto-naming/semantic search (Tidyshot), smart cropping. Critical community constraint: AI is welcome **only** if local and useful — "You had me at 'AI: none'" gets upvotes; vibe-coded AI apps get torched. Frame as "on-device intelligence," never "AI-powered."
6. **The OSS floor is rising fast** (macshot 1.9k★, Capso, Better Shot — native, free, shipping scrolling capture and PII redaction in June 2026 releases). 12-month window before baseline capture is fully commoditized; durable moats = reliability, library, polish, support, trust.
7. **Trust/identity/support is cheap differentiation**: both incumbents have support-black-hole VOC; Shottr's pseudonymous dev caused a corporate ban; community filters demand real identity, trial, transparent (or absent) cloud, native Swift, visible cadence.
8. **Naming/brand** (from gap-naming-brand): `shot/snap/snip/screen` roots are saturated (~25+ live "shot" products) and polluted (sniper-game SEO noise; MAS clone farms squat phonetic spellings — "Shotter" already squats Shottr). Winners encode ONE hero benefit in plain words ≤3 syllables (Snipaste, Longshot, TextSniper). **Unclaimed name territories matching our wedge: memory/library/recall and local-first/private** — used in copy by micro-apps, encoded in a name by no one. Any successful name will be squatted on MAS/GitHub within months — occupy keywords, org names, and misspellings at launch. Users reach for "professional," not "beautiful," to describe beautified output.
9. **Platform constraints that shape the spec** (gap-macos-platform-constraints): target **macOS 14+** on SCScreenshotManager/ScreenCaptureKit only (zero deprecated-API nag liability); screenshots-only does NOT dodge the Sequoia/Tahoe re-auth regime — design the permission moment (install to /Applications first; explain the monthly dialog; permission-health screen); Accessibility requested lazily at first scrolling capture; hotkey takeover can't be automated but can be 10× better-guided (deep link + live read of `com.apple.symbolichotkeys` IDs 28–31/184 → "shortcuts freed ✓" — nobody does this); Developer ID + notarization + Sparkle 2 + Homebrew cask at launch; ship URL scheme (off by default) **and** native AppIntents (Spotlight actions on Tahoe — neither incumbent has them).

---

## 9. VOC Language Bank (best verbatims by theme)

### LOVE — speed & flow
1. "Screenshots appear instantly. This is genuinely 'I didn't even realize it was done' fast" (https://klicktrust.com/cleanshot-x-review/)
2. "The workflow of quickly grabbing a screenshot, annotating it, and hitting Esc is incredibly efficient" (https://www.producthunt.com/products/shottr/reviews)
3. "It takes 2 clicks, to capture anything... Yes, no copy-paste, straight Paste. Super Deluxe!" (https://shottr.macupdate.com/)
4. "shottr is literally (literally) noticeably faster… than the native animated corner pop out thing" (https://reddit.com/r/macapps/comments/1bvo3ms/.../ky1hus0/)
5. "CleanShotX's tools are about 1 billion times faster/easier to use… about 99% of bug tickets I enter… have a CleanShotX screenshot attached" (https://news.ycombinator.com/item?id=45826010)
6. "Also using it on a Mac, yes 1 to 2 seconds is a no go these days. That's almost like lunch break" (https://reddit.com/r/macapps/comments/1hl3cmh/.../m3l1ygt)
7. "I use it easily 10 times a day. It's incredibly good." (https://cleanshot.com/testimonials)
8. "I bought Shottr because… I use it hundreds of times per day and I save a tremendous amount of time and clicks" (https://news.ycombinator.com/item?id=41699263)

### LOVE — polish & native feel
9. "it feels like Apple built it… there is no pressure to renew the license" (https://www.reddit.com/r/macapps/comments/1rfyugm/.../o81izl6/)
10. "feels native to the point I can forget it's not part of the Mac experience." (https://www.reddit.com/r/macapps/comments/1rfyugm/.../o7pvx7q/)
11. "I didn't realize how broken native screenshots on macOS were until I started using CleanShot." (https://cleanshot.com/testimonials)
12. "Cleanshot does something macOS already does, taking screenshots, but 1000X better 🔥" (https://cleanshot.com/testimonials)
13. "Cleanshot should be bundled with osx." (https://www.reddit.com/r/macapps/comments/1rfyugm/.../o7s4rhv/)
14. "The fact that the annotations just look so damn good… Most other tools like this produce ugly annotations." (https://reddit.com/r/macapps/comments/1jur1n1/.../mm61axu/)
15. "Oh my gosh, this is the best screenshot app that has ever existed." (Sara Dietschy, https://www.youtube.com/watch?v=nuVRVoUeLPc)

### LOVE — magic features
16. "I push delete and they're all gone and you would never know. Look at that. Isn't that freaking awesome?" (Snazzy Labs, https://www.youtube.com/watch?v=FxUk8gxzHI8)
17. "It's crazy how well this works… That's some Next Level AI." (Bog, https://www.youtube.com/watch?v=GcbDQfeSzlM)
18. "yeah what the actual heck — are you serious right now… It's a 12 out of 10 experience." (scrolling capture, https://www.youtube.com/watch?v=-AReQV86cw8)
19. "It's the best measuring tool in mother-friggin macOS." (https://www.youtube.com/watch?v=npxlJdxSv4A)
20. "astonishingly good tool that I find delightful... downright freaky" (https://www.podfeet.com/blog/2023/05/shottr/, 2023)
21. "I can't tell you how much time I've spent trying to draw rectangles over text... With Shottr, it's instant" (same)
22. "that's a pretty nice looking YouTube thumbnail for about 30 seconds of work." (https://www.youtube.com/watch?v=DzISx8XDJj4)
23. "It's a lifesaver for visual references while working in Photoshop or Illustrator." (pin/float, https://reddit.com/r/macapps/comments/1jur1n1/.../mm4pzzf/)
24. "Scrolling capture is OP — not something I have to use often but is something that would be noticeably painful if gone!" (…/mm57zz9)
25. "the OCR text grab is surprisingly accurate, and the scrolling capture works without fussing around… try shottr first and only buy cleanShot if you hit a wall." (https://www.reddit.com/r/macapps/comments/1rfyugm/.../o8m0wtv/)
26. "I now go out of my way to find opportunities to take a screenshot just so I can mark it up" (https://www.producthunt.com/products/shottr/reviews)
27. "I've had multiple people ask me what I use after I send them a screen shot and to me, that's the hallmark of a great app." (https://www.reddit.com/r/macapps/comments/1p82arx/.../nr2thuz/)

### HATE — pricing & licensing
28. "Forcing your own cloud should be illegal... no way to hide it" (https://www.producthunt.com/products/cleanshot/reviews)
29. "so it's a one-time-payment subscription..that's. insane. i'd never support a product with such exploitative practices." (https://www.reddit.com/r/macapps/comments/1p6nijk/.../nuef307/)
30. "sucks you have to renew license all the time… it's just a dressed up sub model" (https://www.reddit.com/r/macapps/comments/1kxdox3/.../muofypz/)
31. "if your version gets a bug that is fixed on a newer version, your only option is to renew your license to fix the bug..." (https://reddit.com/r/macapps/comments/1jur1n1/.../mm72jl3/)
32. "charge me once or I won't pay the 'just 10$/month' == 120$/year for a screenshot app is waaay overpriced." (HN 2025, via https://hn.algolia.com/api/v1/search?query=%22screenshot%22%20%22subscription%22&tags=comment)
33. "I still use Shottr at work because I don't want to pay for a second license." (https://reddit.com/r/macapps/comments/1iu8s5o/.../mdvgr12/)
34. "it's gone subscription, so hell no." (Snagit, https://reddit.com/r/macapps/comments/1iaysxg/.../m9lhqsv/)
35. "you do not need to waste $8 a month on this product. It's awesome just as it is." (https://www.youtube.com/watch?v=-AReQV86cw8)
36. "I don't want to pay anymore to have their TRASH CLOUD PRODUCT shoved in my face." (https://www.reddit.com/r/macapps/comments/1p6nijk/.../nyusvet/)
37. "the most important part, and something I wish everyone did, is the option to just pay a one-time fee." (https://www.youtube.com/watch?v=Te-6PhYamrY)
38. "$12 is a fair price for what Shottr brings to the table...." (https://www.reddit.com/r/macapps/comments/1nz52c4/.../nhznw0t/)
39. "Me: I dunno, $29 for CleanShot seems steep... Also me, 10 minutes after buying it: 😍" (https://cleanshot.com/testimonials)

### HATE — product gaps & fragility
40. "love shottr but why oh why can it not do video capture please I'm begging you" (https://www.reddit.com/r/macapps/comments/1p82arx/.../nr2vbd1/)
41. "The only issue i have with Shottr… is that the scrolling screenshot messes up quite a bit. Never happened to me when trying CleanShot X" (https://reddit.com/r/macapps/comments/1kdcjl3/.../mqgn1un/)
42. "Scrolling capture is the exception... refuses to go to the end of the document." (https://setapp.com/apps/cleanshot/customer-reviews)
43. "One of the biggest issues for me is that cleanshot doesn't have a library." (https://reddit.com/r/macapps/comments/1bvo3ms/.../ky68pzc/)
44. "I emailed support about this 7 months ago. Not a priority..." (https://setapp.com/apps/cleanshot/customer-reviews)
45. "taking a screenshot with CleanShot somehow resets the DisplayPort driver and everything flips out for a minute… Infuriating." (https://news.ycombinator.com/item?id=47224675)
46. "Thought it was abandoned." (Shottr, https://www.reddit.com/r/macapps/comments/1p5ayxb/.../nqihyjt/)
47. "we were using it to draw annotations on a map and then needed to re-open the file and move these around but they were burnt in?" (https://reddit.com/r/macapps/comments/1jwlubd/)

### WISH — the jobs to claim
48. "Imagine you use the screenshot tool, and immediately have access to all other screenshots… then maybe you merge them. It's all within the app… SnagIt did that part right" (https://reddit.com/r/macapps/comments/1hl3cmh/.../m3kp7e2/) — and the thread title itself: "fast and sleek as Cleanshot, library like Snagit."
49. "Paste UI on a GitHub PR. Paste Figma into a LLM. Paste bugs into Slack or a support tool." (https://news.ycombinator.com/item?id=44795542)
50. "whether someone shares code or error log as screenshot on slack, it's 3 steps: 1. cmd+opt+control+o 2. select the area 3. cmd+v in vscode" (https://news.ycombinator.com/item?id=45883631)
51. "always looked for a screenshot [app] that saves the website link from which the screenshot was taken" (https://www.reddit.com/r/macapps/comments/1s27jjc/.../oc7jz5b/)
52. "I wish I could edit the annotations after I saved the image. It would be awesome." (https://www.reddit.com/r/macapps/comments/1p5ayxb/.../nqoc9tz/)
53. "Can it automatically tag keywords based on image content? …screenshot on Safari of a cat drinking milk → keywords: safari browser, cat, milk…" (https://www.reddit.com/r/macapps/comments/1mzxv63/.../nao021n/)
54. "You had me at 'AI: none'." (https://www.reddit.com/r/macapps/comments/1s27jjc/.../oc6uv8u/)
55. "Plain screenshots don't tell the user where to look, in what order, or why… That's exactly what these tools are there to fix." (https://reddit.com/r/macapps/comments/1jxlau1/.../mmtjrcz/)
56. "Working with computers + people = the need to explain things with little arrows or even videos a hell of a lot of the time." (…/mmw2zpp/)
57. "what extras do other apps bring to the table that I didn't even realise I couldn't live without? ;)" (the skeptic to convert, https://reddit.com/r/macapps/comments/1iu8s5o/.../mdydp0t/)
58. "I find my friends and colleagues rarely open links or download PDFs I send; an image gets looked at almost instantly." (…/mmtbtxt/)

---

## 10. Contradictions Resolved, Open Questions & Low-Confidence Areas

### Contradictions between veins (resolution + reasoning)

1. **"Which app is faster?"** Jeff Su [CLAIM]: CleanShot "slightly more responsive." Everyone else (Reddit corpus ~10 mentions, HN, MacUpdate, Shottr's own benchmarks): Shottr is the lighter/faster one. **Resolution: Shottr wins** — overwhelming multi-source consensus vs one reviewer; treat Su's line as cloud-workflow halo.
2. **"Whose scrolling capture is better?"** Reddit majority (~8 explicit) + switching stories: CleanShot; vocal minority + 2026 thread comments: Shottr ("auto scrolls for you", "far superior"). Tier-2 vein: **Longshot now leads on mechanics**; CleanShot has its own downscaling/end-of-document failures. **Resolution: CleanShot wins reliability head-to-head with Shottr (it's the #1 stated upgrade reason), but the absolute crown is vacant** — both have fresh failure VOC, and the engineering vein shows the fragility is structural. Build to the §8 bar.
3. **"Is CleanShot a subscription?"** No [OBSERVED — $29 perpetual + optional $19/yr updates], but 2026 SEO articles and many users *perceive/describe* it as "$29/year" or "full subscription." **Resolution: report the fact, exploit the perception** — the bug-fix-behind-renewal mechanic (documented via support screenshots) makes the "dressed up sub" framing fair game in positioning.
4. **"Is cloud a killer feature or bloat?"** Both, cleanly split: business/client-facing users call it "crucial"; prosumers call it the one feature they never touch and resent the upsell. **Resolution: both are real constituencies (~38 mentions each)** — local-first v1 serves one loudly; v2's instant-link must match the "copied before upload finishes" spec for the other. Don't average them.
5. **Shottr free-tier gating.** Older veins: "practically everything works free"; 2025 nag-thread OP: backgrounds/menu-bar-hide/splash gated; reddit-voc: watermark on free scrolling captures. **Resolution: gating tightened over 2024–25**; current best estimate = core capture/OCR/rulers free, backdrop + cosmetic/cloud conveniences gated, nag persistent. Low confidence on exact watermark scope — verify in-app before citing externally.
6. **Shottr pricing description.** market-landscape: "pay what you want / name your price"; shottr-features & fresh VOC: fixed $12/$30 via FastSpring. **Resolution: purchase page offers name-your-price framing on top of $12 reference pricing; treat $12 Basic (1 user/5 Macs) / $30 Friends Club as the operative facts** [OBSERVED purchase.html].
7. **CleanShot dev pace.** Changelog shows steady maintenance [OBSERVED]; community says "stalled." **Resolution: both true — cadence is maintenance-heavy (one feature release in 13 months), which *feels* stalled to renewal payers.** That's the strategically relevant reading.
8. **Snagit pricing date.** One vein says "fall 2024 announcement," another "subscription-only starting Jan 2025." **Resolution: announced 2024, effective with Snagit 2025 (Jan 2025)** — consistent.

### Open questions / low-confidence
1. **Does non-picker `SCScreenshotManager` trigger the Sequoia/Tahoe periodic re-auth?** Conflicting 2024 reports; must be empirically tested on 15.7/26.x before the engineering spec freezes (1-day spike).
2. **Setapp Marketplace developer rev-share %** — unpublished; ask Setapp directly before committing to the channel.
3. **Reddit score data** in the PullPush-era corpus is unreliable (all comments show score 1); frequency counts are ordinal only. Arctic Shift filled mid-2025→2026 but r/macapps skews power-user — casual-user sentiment is under-sampled everywhere except Setapp's 14k ratings (which lack text granularity).
4. **Shottr-dev Setapp quote** ("hike the app price significantly") — present on purchase-page FAQ per one vein but not re-located in the platform pass; pin the primary source before quoting externally.
5. **Exact current Shottr free-tier watermark/gating matrix** (see contradiction 5) — verify in-app.
6. **Name shortlist legal clearance** — no TESS/EUIPO class 9/42 sweep done; only directional findings (TECHSMITH SNAGIT registered; CLEANSHOT coexists cross-class; shotlib.com was the lone unregistered .com among checked directions, status volatile).
7. **G2 page content** for CleanShot was 403-blocked (snippet-sourced only); B2B review sentiment is thin by nature of the category, not by gap.
8. **How big is the library job really?** Volume of complaints is NICHE (~6 threads) but depth/persistence is high and adjacent products monetize it; sizing rests on inference from ScreenFloat/Tidyshot traction + iOS analogues, not direct demand measurement. A landing-page smoke test of "searchable screenshot library" vs "flawless scrolling capture" messaging would de-risk the lead positioning choice.
9. **Windows port economics** — demand signals are real but anecdotal; ShareX/Snipping Tool free-floor implies polish-led pricing power is unproven. Revisit with dedicated research before committing.
10. **macOS 26.x scrolling-capture API changes** — ScreenCaptureKit "updates" page didn't render in research pass; check Xcode 26 SDK diffs (any new system support would reshape the scrolling-capture moat).
