# Tier-2 Mac Screenshot Competitors: Deep Profiles + the Scrolling-Capture & Library Quality Bars

**Research date:** 2026-06-09. All MAS data pulled live from the iTunes Search/Lookup API and MAS review RSS on this date. Tags: **[OBSERVED]** = verified on official site/store/repo; **[CLAIM]** = vendor or third-party assertion not independently verified; **VOC:** = verbatim user quote. Pre-2024 evidence is flagged as possibly stale.

---

## 1. Executive Summary

1. **The scrolling-capture crown has moved.** Longshot (MAS-only, ~$12.99 lifetime, updated 3 days ago) is now the technical leader on scrolling capture — manual-scroll + real-time feature-recognition stitching, vertical/horizontal/360°, restitch-after-the-fact — while Xnip (the old "reliable" pick) has visibly slowed (last update Sep 2025) and still draws "scrolling doesn't work" 1-stars from paying users. Nobody, including CleanShot, is loved for scrolling capture; every app in the market has fresh 2024–2026 failure VOC.
2. **The fragility is structural, not incidental.** macOS has no system API for scrolling content. Every implementation is "synthesize/observe scroll + interval-capture + algorithmic stitching," and the failure modes are identical across apps: featureless/solid-color regions, sticky headers, lazy-loading, fast scrolling outrunning capture, apps with non-native scroll emulation (Terminal, VS Code, Finder column view), and scroll-modifier utilities (Mos, Scroll Reverser, Smooze). Shottr documents these failure cases explicitly; Longshot's dev confirms "without system-level API support [stitching] will always have some flaws."
3. **The library gap is real and the bar is now well-defined.** ScreenFloat 2 ($17.99 one-time, 5–8 releases/yr, rapturous MAS reviews) defines the capture-library bar: folders, smart folders (incl. "contains faces"/"contains text X"), tags/ratings, OCR + data detection, Spotlight indexing, iCloud sync, and — critically — **auto-import of screenshots taken with macOS' built-in tools** (v2.3.6, Mar 2026). Tidyshot (Mar 2026, $5.99-one-time Pro) defines the AI-organizer bar: on-device OCR renaming ("figma-dashboard-header.png"), semantic search, entity detection. **No app combines first-class capture (incl. scrolling) with a first-class library.** That is the open lane.
4. **Tier-2 pricing is uniformly hostile to subscriptions.** Lifetime $6–$18 is the norm (Longshot $12.99, iShot Pro $12.99, ScreenFloat $17.99, Snipaste Pro $8.99, Tidyshot $5.99); Xnip's $4.99/yr subscription is its single most repeated complaint. A fast-moving free/OSS tier (Capso 903★, macshot 1.9k★, both shipping scrolling capture in June 2026 releases) is compressing the bottom of the market.

---

## 2. SPECIAL FOCUS A — The Scrolling-Capture Quality Bar

### 2.1 How the implementations behave (comparison table)

| App | Scroll mode | Stitching UX | Directions | Documented limits / failure cases | Free-tier watermark | Source |
|---|---|---|---|---|---|---|
| **CleanShot X** (bar-setter) | **Auto-scroll** (button) + manual slow-scroll | Drag outline → "Start Capture" → "Auto-Scroll" → "Done"; stitched to one PNG | Vertical | VOC: long captures get downscaled ("the longer the area… the smaller the text in the output file"); "isn't as elegant as the rest of the app" | n/a (paid) | [scottwillsey.com](https://scottwillsey.com/cleanshotx-scrolling-screenshots/), [MPU Talk thread, May 2024](https://talk.macpowerusers.com/t/cleanshot-and-scrolling-capture/37142) |
| **Shottr** (bar-setter) | Auto-scroll default; **manual scrolling capture** as documented fallback | Auto-scrolls selection; shows a message if it fails to scroll or hits the **max-height limit**; setting to reverse auto-scroll direction | Vertical | Official FAQ: fails with **macOS Terminal, VS Code, Finder Columns view**, and scroll-modifying apps (**Mos, Scroll Reverser, Smooze**) because they "emulate scroll in a non-native way, the result is choppy"; "a percentage of systems don't work well with automatic capture" | n/a (free; $8 lifetime Pro) | [shottr.cc/kb/faq](https://shottr.cc/kb/faq) [OBSERVED] |
| **Xnip** | Manual scroll within selection (docs suggest **arrow keys** to avoid horizontal drift) | Scroll slowly; stitched on completion | **Downward only**; no horizontal | Strictest selection-area requirements of the three Chinese apps; worst on dynamic content & non-solid backgrounds, best on solid-color blocks; speed-sensitive | **Yes — watermark on free tier** (Pro removes) | [Longshot vendor test](https://longshot.chitaner.com/blog/scrollcapture_compare_with_other/) [CLAIM — competitor-published], [MAS desc](https://apps.apple.com/us/app/xnip-screenshot-annotation/id1221250572) [OBSERVED] |
| **Longshot** | **Manual scroll, any direction, any speed-within-reason**, with live stitched preview window | Real-time thumbnail preview while scrolling; can **drag selection edges after scrolling to restitch** missed content without restarting; hold Option = whole-window scroll capture; Shift+scroll = horizontal | **Vertical / horizontal / 360° panoramic**; mid-capture direction changes allowed | Official docs: solid-color backgrounds "can cause stitching failures due to the lack of distinctive features"; rapid scrolling can overwhelm processing and lose frames | Free tier exists in MAS app; **unlimited scrolling = Pro (~$12.99 one-time)** | [Scrolling capture guide](https://longshot.chitaner.com/blog/scrollingcapture_guide/) [OBSERVED] |
| **iShot** | Select area, press "S", slide upward; **auto-scrolling supported**; "length of the long screenshot is unlimited" | Stitch on completion | Downward only (per Longshot test) | Best scroll-speed tolerance of the three (Longshot's test); 2022 VOC of dropped content (stale) | Free tier limited; Pro features paid | [MAS desc](https://apps.apple.com/us/app/ishot-screenshot-recording-ocr/id1485844094) [OBSERVED] |
| **Capso (OSS)** | Scrolling capture in unified toolbar | — | — | v0.8.x, young | Free (BSL 1.1) | [github.com/lzhgus/Capso](https://github.com/lzhgus/Capso) [OBSERVED] |
| **macshot (OSS)** | "Auto-detects vertical or horizontal scrolling, **stitches with Apple Vision**" | — | Vertical + horizontal | — | Free (GPLv3) | [github.com/sw33tLie/macshot](https://github.com/sw33tLie/macshot) [OBSERVED] |
| **Snipaste** | **None.** Scrolling capture absent; planned for v3.0 | — | — | 8 years of forum requests unanswered (per Longshot dev) | Free (personal) | [Snipaste site/wiki](https://www.snipaste.com/), [Longshot dev blog](https://longshot.chitaner.com/blog/why_develop_longshot_alternate_snipaste/) |
| **Capto** | **None** for arbitrary apps — browser **webpage capture** (full-page via its own browser integration) only | — | — | — | n/a | [MAS desc](https://apps.apple.com/us/app/capto-screen-capture-recorder/id1078184147) [OBSERVED] |

### 2.2 The Longshot-published head-to-head (Longshot v1.2.0 vs iShot v1.7.7 vs Xnip v2.2.0)

[CLAIM — published by Longshot's developer; treat star ratings as directional, but the *axes of comparison* are the de-facto QA checklist for this feature.] Source: [longshot.chitaner.com/blog/scrollcapture_compare_with_other/](https://longshot.chitaner.com/blog/scrollcapture_compare_with_other/)

- **Scroll-area adaptability** (tolerance when selection exceeds scrollable bounds): Longshot 5/5, iShot 3/5, Xnip 1/5 — "Xnip has the strictest requirements for the selection area."
- **Horizontal-drift tolerance:** Longshot 5/5, iShot 3/5, Xnip 1/5 — Xnip's own docs recommend keyboard arrow keys to avoid horizontal misalignment.
- **Non-solid-color backgrounds:** Longshot ✅, iShot ❌, Xnip ❌. **Dynamic content blocks:** Longshot 4/5, iShot 3/5, Xnip 1/5. **Solid-color blocks (the inverse case):** Xnip 4/5, iShot 2/5, **Longshot 1/5** — feature-recognition stitching fails when there are no features.
- **Direction:** Longshot bi-directional + adjustable mid-capture; iShot and Xnip downward only. Only Longshot does horizontal/panoramic and whole-window-by-click.
- **Scroll-speed tolerance:** iShot best, Xnip second, Longshot needs slower scrolling.
- Money quote (their words): "stitching multiple images together through algorithms to achieve long screenshots **without system-level API support will always have some flaws**."

### 2.3 Why scrolling capture is fragile on macOS (engineering-spec notes)

- **No OS support.** macOS has no public API to render a scroll view's full content (unlike iOS's full-page Safari screenshots). Every Mac implementation is screenshots-over-time + stitching. [OBSERVED across all sources]
- **Two stitching families observed:**
  1. **Interval capture + pixel-overlap detection** — OSS ScrollSnap uses ScreenCaptureKit; its `StitchingManager` "combines multiple screenshots into a single image using overlap detection… It doesn't rely on accessibility APIs or scroll events. Instead, it captures at defined intervals while content scrolls, then algorithmically detects overlapping pixels between frames" ([github.com/Brkgng/ScrollSnap](https://github.com/Brkgng/ScrollSnap), MIT, v2.4.0 Apr 2026, 868★) [OBSERVED]. Xnip documents the same family: it "continuously captures the content of the area you selected, then find[s] the same portion of each capture and combine[s] them" — which is exactly why its docs forbid floating views/scrollbars inside the selection and "currently only support scroll down" ([xnipapp.com/scrolling-capture](https://xnipapp.com/scrolling-capture/)) [OBSERVED].
  2. **Image-feature-recognition stitching in real time** — Longshot's dev: "I implemented image stitching using image feature recognition algorithms. Through optimized performance, the stitching speed kept pace with gestures" ([dev blog](https://longshot.chitaner.com/blog/why_develop_longshot_alternate_snipaste/)) [CLAIM]. macshot stitches "with Apple Vision" (Vision-framework registration) [OBSERVED].
- **Auto-scroll adds a second fragile layer:** synthesized scroll events break in apps that "emulate scroll in a non-native way" — Shottr's FAQ names **Terminal, VS Code, Finder Columns view** — and in the presence of scroll-remapping utilities (**Mos, Scroll Reverser, Smooze**) and even Hot Corners (Shottr v1.9.1 fixed a Hot-Corners interaction bug, [shottr.cc/newversion.html](https://shottr.cc/newversion.html)) [OBSERVED].
- **Universal failure modes** (collated from Shottr FAQ, Longshot docs, ScreenSnap Pro's methods guide, ScrollSnap):
  - Solid-color / featureless stretches → no overlap anchors → stitch failure (Longshot admits this in its own guide).
  - Sticky headers / fixed elements / cookie banners → duplicated in every viewport frame.
  - Lazy-loading & infinite scroll → missing sections unless user pre-scrolls the page.
  - Fast scrolling → capture loop outrun → dropped frames / "eaten" content (also iShot VOC below).
  - Very long captures → output downscaling (CleanShot VOC: tiny text).
- **Mitigations the market has converged on** (our minimum bar): manual-scroll fallback mode (Shottr, CleanShot); real-time stitch preview so failure is visible *during* capture, not after (Longshot — best-in-class UX idea); explicit failure/max-height messaging (Shottr); reverse-scroll-direction setting (Shottr); post-capture area adjustment + restitch (Longshot only).

### 2.4 Scrolling-capture VOC (verbatim, dated)

From our own Reddit corpus (`research/raw/`):

- VOC: "still scrolling screenshot not fixed in this app, xnip works better in that way" — u/Spiritual_Show on the Shottr price-increase thread, r/macapps, 2024-10-09 ([comment](https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr4snx8/))
- VOC: "does the scrolling screenshot still broken? Like it skips fram[es], only reason I switched to xnip" — same user, same thread, 2024-10-09 ([comment](https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr4tijo/)) — the canonical "users churn off Shottr over scrolling frame-skips" evidence.
- VOC: "Wow. **LongShot!** … by far the best and most feature-rich one I've ever seen. And the lifetime $13 purchase sealed the deal for me even 10 minutes after playing with it. It's going to replace 3 other apps that I've been using for years." — u/operablesocks, r/macapps, 2025-04-30 ([comment](https://reddit.com/r/macapps/comments/1k9af1c/my_list_of_apps_id_pay_double_for/mpvl8lt/))
- VOC: "At the moment I use CleanShot but I am impressed with Longshot. CleanShot has subscription model. Longshot has lifetime option. Longshot also has OCR and other good features. I am impressed with Longshot despite being a long time user of CleanShot" — u/ZeroReader, r/macapps, 2024-04-04 ([comment](https://reddit.com/r/macapps/comments/1bvo3ms/seeking_advice_screenfloat_2_vs_snagit_vs/ky11w65/))
- VOC: "Xnip has to be the most polished FREE screenshot app I've ever used. Their basic features just work without forcing you to get the premium version." — r/macapps "What screenshot app do you use?", 2025 ([comment](https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdx85cf/))

From the open web:

- VOC: "The scrolling capture works fine. you just need to scroll a little bit slower and the application does the job fine… I bought the pro version for a very low price and I'm very happy" — Xnip MAS UK review, 5★, 2024-08-29 ([MAS reviews RSS](https://itunes.apple.com/gb/rss/customerreviews/id=1221250572/sortby=mostrecent/json))
- VOC: "I have tried, for over an hour and got the paid version and this app doesn't work. The highlighted scroll feature doesn't populate… I paid and even restarted my computer and it still doesn't work." — Xnip MAS US review, 1★, 2025-03-22 (same RSS)
- VOC: "Scrolling screenshot does not work it will cut off randomly halfway down the page. Poor quality app" — Xnip MAS UK, 1★, 2021-04-04 (**stale, pre-2024**)
- VOC: "I use xnipapp.com right now and this looks even better in terms of editing tools, except for one thing: scrolling capture. It allows me to capture scrolling portions of the screen and it's just so damn useful!" — HN comment, 2021-02-12, on a Shottr-adjacent launch (**stale but explains Xnip's moat**) ([news.ycombinator.com/item?id=26117021](https://news.ycombinator.com/item?id=26117021))
- VOC: "I primarily bought Longshot to use Scrolling Capture, which is a feature I have not found in other apps. Unfortunately, this feature does not work well. I have shared the following with the developer but never heard back" — Longshot MAS US, 2★, 2026-04-15 ([MAS reviews RSS](https://itunes.apple.com/us/rss/customerreviews/id=6450262949/sortby=mostrecent/json))
- VOC: "The long screenshot function is the app with the highest experience and success rate I have ever used." — Longshot MAS US, 5★, 2025-08-09 (same RSS)
- VOC: "滚动截图老吃内容… 考试答题滚动截图关键内容给我吃了" ("scrolling capture keeps eating content… it ate the key part of my exam answer") — iShot MAS UK, 1★, 2022-02-02 (**stale, pre-2024**, but the canonical dropped-frames failure)
- VOC: "The longer the area being captured, the smaller the text in the output file" and "unfortunately it isn't as elegant as the rest of the app's functionality" — robp on CleanShot X scrolling, MPU Talk, May 2024 ([thread](https://talk.macpowerusers.com/t/cleanshot-and-scrolling-capture/37142)). In the same thread BradG's workaround was "breaking very long grabs into sections, that I then stitched together after the fact" — i.e., a paying CleanShot user hand-stitching, which is the product failure in one sentence.
- VOC: "It's a little counterintuitive to get it to work initially, but once you get it, you'll use this all the time." — Scott Willsey on CleanShot X scrolling capture, blog, 2024-06-14 ([scottwillsey.com](https://scottwillsey.com/cleanshotx-scrolling-screenshots/)); same post flags non-scrolling elements (sticky menus, scrollbars) duplicating in output.
- VOC: "https://cleanshot.com/ is also very good, IMO, much better than Shottr." — HN, 2022-06-17, in a scrolling-screenshot context (**pre-2024**) ([item](https://news.ycombinator.com/item?id=31775570))

**Bar to beat (synthesis):** ship BOTH auto-scroll and manual mode; live stitch preview; post-capture restitch; horizontal support; explicit failure messaging; no output downscaling; and pass the "Shottr failure suite" (Terminal, VS Code, Finder columns, Mos/Scroll Reverser installed). No incumbent passes all of these today.

---

## 3. SPECIAL FOCUS B — The Library Gap

### 3.1 ScreenFloat 2 — the capture-library bar [OBSERVED]

Source: [screenfloatapp.com](https://screenfloatapp.com/), [MAS listing](https://apps.apple.com/us/app/screenfloat-pro-screen-capture/id414528154), [Eternal Storms blog](https://blog.eternalstorms.at/category/screenfloat/)

- **Shots Browser library:** name, **tag, rate, favorite**; **folders + Smart Folders** with criteria including *whether the shot contains faces, contains specific text, or which device captured it*; **extensive search with Spotlight indexing** (v2.3.5, Feb 2026, added word-level search in addition to exact phrase); **iCloud sync of the entire library across Macs**.
- **Data detection on every shot:** OCR text extraction, faces, barcodes/QR, links, emails, phone numbers, addresses — powering copy/open/redact actions ("quicksmart-redacting") and smart-folder criteria.
- **The killer 2026 feature: v2.3.6 (Mar 2026) auto-imports screenshots and recordings made with macOS' built-in tools** — i.e., ScreenFloat's library now works as an organizer even when capture happens elsewhere. ([blog post](https://blog.eternalstorms.at/2026/03/23/screenfloat-v2-3-6-adds-finder-auto-import-new-double-click-actions-and-improved-sharing/))
- Non-destructive annotation; recapture-same-area; Siri Shortcuts/AppleScript automation; widgets; share-as-link via iCloud/ImageKit/Cloudinary.
- **No scrolling capture. No OCR-free-tier games — single $17.99/€19.99 one-time price**, MAS + direct + Setapp, macOS 12.3+, native (Eternal Storms is a one-person Austrian native-Mac shop; SwiftUI/AppKit per dev journal).
- **Cadence 2024–26 [OBSERVED]:** v2.2.7 Feb 2025 → v2.2.9 May 2025 → v2.3.5 Feb 2026 → v2.3.6 Mar 2026 → v2.3.7 Apr 2026. Sustained, substantive monthly-ish releases.
- VOC (all 2025–2026, MAS): "I've used ScreenFloat every single day for 7+ years… a requirement for every Mac I own" (US 5★, 2026-05-19); "As an Interaction/Product Designer who has worked at Apple, Palm, and Yahoo!, this is my 'go-to' screenshot app. It puts the native macOS Screenshot utility to shame" (US 5★, 2026-05-19); "The best Screenshot app on the Mac and it keeps getting better. The app really needs more visibility" (UK 5★, 2026-02-24); "My 'CANNOT LIVE WITHOUT' app!… I would probably use it 50+ times a day" (AU 5★, 2025-09-05).
- VOC (friction): "it's far more complex than it needs to be… the latest update only allows for copying a LINK to the copied snap, not the image itself" (UK, 2026-04-27); HN 2025-11-28: floating shots cause "why don't these window controls work?" confusion ([item](https://news.ycombinator.com/item?id=46079145)). HN 2026-02-10 shows the power-use: overlaying two settings screenshots with transparency to diff GUIs ([item](https://news.ycombinator.com/item?id=46956319)).

### 3.2 Tidyshot — the on-device-AI organizer bar [OBSERVED]

Source: [MAS listing](https://apps.apple.com/us/app/tidyshot-screenshot-organizer/id6758950886) (v2.1.1, 2026-05-26; first release **2026-03-11**; macOS 14.6+), [poteam.pro/products/tidyshot](https://poteam.pro/products/tidyshot)

- Menu-bar organizer that watches the screenshot folder — **does not capture**; explicitly "works with built-in macOS tools, CleanShot, Shottr, and more."
- **On-device AI pipeline:** identifies source app + local OCR + keyword extraction → renames `Screenshot 2026-02-12…` to e.g. `figma-dashboard-header.png`; applies **native Finder tags by source app**; sorts into folders by app/date/custom rules.
- **Semantic search** ("type 'invoice' to find receipts"), entity detection (links, phone numbers, dates, names) — "powered by on-device language models — no cloud, no subscriptions, 100% privacy."
- **Floating Shelf:** hot-corner-activated grid of recent captures, drag straight into Slack/Mail; capture notifications with copy-text/copy-image actions; import preview with undo; auto-cleanup/retention rules.
- **Pricing:** Free = folder sorting, Finder tags, notifications, Quick Look, 20 quick actions/day (+20 throttled), 100-shelf-item cap. **Pro = one-time purchase ($5.99 per product site)** unlocks OCR renaming, semantic search, entities, templates, multi-folder watching, unlimited actions.
- ⚠️ **Namespace collision:** a *second*, unrelated "TidyShot: Screenshot Tool" (Pawel Komorkiewicz, [MAS id 6761196631](https://apps.apple.com/us/app/tidyshot-screenshot-tool/id6761196631), v1.7 released 2026-06-09, first release 2026-04-16) does capture+paste+searchable library with on-device OCR. Two brand-new apps with the same name in 3 months = independent confirmation this niche is heating up.

### 3.3 Snagit — the legacy library bar (comparison reference only)

Per TechSmith ([library tutorial](https://www.techsmith.com/learn/tutorials/snagit/snagit-library/), [features](https://www.techsmith.com/snagit/features/)): library stores full capture history (images, video, GIFs); **custom tags**; filter/sort by **date, application source, or website source**; filename search; recent versions made library search "up to 3x faster"; cloud library syncs captures across devices. This automatic app/website-source metadata is what ex-Snagit users miss most on Mac — only Tidyshot currently replicates it (via heuristics), and ScreenFloat via smart folders.

### 3.4 Other library-adjacent entrants

- **Pickle** ([pickleformac.app](https://pickleformac.app/)) [OBSERVED]: free forever, native Swift, macOS 14+, v1.1 (2025). Menu-bar **screenshot history grouped Today/Yesterday/weekdays**, one-click PII redaction (phones, emails, addresses), private share links auto-deleted after 7 days. Library-lite + privacy angle.
- **Capto** (below) has the oldest organizer: folder-based "smart collections" auto-sorting captures — but it's a 2016-era design with no OCR search, no tags-by-source, and the app is in maintenance mode.

**Gap statement:** CleanShot's "capture history" is a transient tray + paid cloud; Shottr has none. ScreenFloat proves an organized, OCR-searchable, synced library is worth $17.99 on its own; Tidyshot proves on-device-AI naming/search is worth $5.99 *without even capturing*. A capture tool with ScreenFloat-class library + Tidyshot-class auto-naming + Snagit-class source metadata has no direct competitor today.

---

## 4. Deep Profiles (priority order)

### 4.1 Xnip — the free+polished scrolling veteran

- **[OBSERVED] MAS:** v2.3.4 (2025-09-30), first release 2017-12-23, free + IAP, macOS 13.5+, 7 MB, dev 自达 张 (Zida Zhang, China). [Listing](https://apps.apple.com/us/app/xnip-screenshot-annotation/id1221250572). Distribution: MAS only (xnipapp.com links to MAS).
- **[OBSERVED] Monetization (from MAS IAP list):** "Xnip Pro Yearly Subscription **$4.99/yr**" + one-time "No watermark & Edit window" unlocks at **$9.99/$7.99**. Free tier puts a **watermark on screenshots**; "Subscribe Xnip Pro to remove the watermark… and gain access to all features in the future update."
- **[OBSERVED] Features:** scrolling capture; window capture with shadow incl. multi-window combined capture; color picker; physical-unit measurement; pin-to-screen; annotation suite (incl. numbered steps); "fully local app with **no network access permission**." **No OCR. No recording. No library.**
- **Cadence:** one release visible in the last 12 months (2.3.4, Sep 2025) — slowing vs Longshot/iShot. [OBSERVED]
- **Why users pick it [VOC]:** historically the only reliable scrolling capture at $0–5: "First app that ticks all my boxes… shadow, multiple windows, scrolling, and numbered steps put this screenshot app way above anything else I've tried" (MAS AU 5★, 2019-08-14, stale); UK 2024-08-29 5★ above ("tried all the screenshot apps. This is the best by far").
- **Top complaints [VOC]:** subscription resentment — "It gets really silly to the point that a snipping app has a yearly subscription (xnip)" (HN, 2020-11-25, stale but durable); upsell friction — "订阅了很多年了…能不能别把升级到专业版的菜单项放第一个！总是点错" ("subscribed for years… stop putting 'Upgrade to Pro' as the first menu item, I keep mis-clicking") (MAS US 1★, 2026-03-09); scrolling failures when paid (2025-03-22 1★ above); broken shortcut (2025-06-02 1★).

### 4.2 Longshot — the rising scrolling specialist (17 Reddit mentions)

- **[OBSERVED] MAS:** v1.5.3 (**2026-06-06 — three days before this research**), first release 2023-06-28, macOS 12+, 6 MB, dev 志泉 孔 (Kong Zhiquan). [Listing](https://apps.apple.com/us/app/longshot-screenshot-ocr/id6450262949). Free download + Pro unlock.
- **[OBSERVED] Pricing** ([pricing page](https://longshot.chitaner.com/pricing/)): Pro **one-time ≈$12.99**, perpetual individual license; "lifetime license… unlimited screenshot scrolling, step annotation, element measurement…, OCR…, custom hotkeys — unlocking all current pro features." MAS-only today; "a direct purchase option from our website is being prepared." Support via email/GitHub Issues. Free-tier limits not precisely documented [CLAIM: free tier covers basics; unlimited scrolling is the headline Pro gate].
- **[OBSERVED] Features:** the scrolling suite in §2.1; **offline OCR** + QR/barcode + text-to-speech; pin from clipboard (images/text/HTML; pinned images scrollable, flippable); screen element measurement with auto element-snap; step annotation; mosaic/blur; lightweight screen recording (full/region/window/app, system audio + mic).
- **Platform:** native (6 MB binary, custom AppKit-style UI; no Electron indicators) [OBSERVED size; INFERRED native].
- **Cadence:** very fast — multiple releases in H1 2026, dev writes detailed engineering blog posts. [OBSERVED]
- **Why users pick it [VOC]:** "Longshot可以说是截图类标杆应用了，开发者很用心" ("Longshot is the benchmark for screenshot apps; the developer is very dedicated") (MAS US 5★, 2026-05-12); highest-success-rate quote in §2.4.
- **Complaints [VOC]:** the 2026-04-15 2★ scrolling complaint incl. **developer not responding**; PNG-only clipboard output bloat (2026-05-12); occasional capture lag (2025-07-13).

### 4.3 iShot / iShot Pro — the Chinese freemium ten-in-one (better365)

- **[OBSERVED] MAS:** free app v2.6.7 (2026-03-21), first release 2019-11-06, macOS 10.13+, 46 MB, Ningbo Shangguan Technology (better365.cn). [Listing](https://apps.apple.com/us/app/ishot-screenshot-recording-ocr/id1485844094). Separate **iShot Pro** listing at **$12.99 up-front** (v2.6.7, 2026-02-24, first release 2022-03-02) ([listing](https://apps.apple.com/us/app/ishot-pro-screenshot-recording/id1611347086)).
- **[OBSERVED] Free-vs-Pro gating** (official comparison page, [better365.cn/ishot/difference.html](https://www.better365.cn/ishot/difference.html)): free iShot gives a **10-day full-feature trial**, after which exactly four premium features lock: (1) system-audio capture in recordings, (2) OCR, (3) **watermark-free long screenshots & shell screenshots** (i.e., scrolling capture stays usable but watermarked), (4) stickers/pin. In-app subscription: **¥6/month or ¥28/year (~$0.85/$3.90)**; iShot Pro is a **¥88 (~$12) lifetime buyout, ¥78 promo** — "iShot解锁高级功能后，与iShot Pro功能无区别" (once unlocked, free iShot is functionally identical to Pro). Both cover **5 devices per Apple ID**; Pro adds Family Sharing (6 members).
- **[OBSERVED] Features ("1 is equivalent to 10"):** area/window/multi-window capture; capture-window-under-cursor without activating it; delayed full-screen with countdown sound; repeat-last-area; long screenshot (press "S", slide up, **"length… is unlimited," auto-scroll supported**); "shell screenshot" (device-frame mockups); stickers/pin with a pinned-items library; annotation (incl. local highlight, serial numbers); color picker (R/G keys copy RGB/HEX); screen+audio recording; **OCR + screenshot translation**; rounded corners/shadow output. Native Apple Silicon + Intel.
- **Cadence:** steady — 2.6.x releases through Q1 2026. [OBSERVED]
- **Why users pick it [VOC]:** breadth-per-dollar: "ishot 一直使用多年，非常喜欢" (MAS US 5★, 2026-06-06); "So easy to set up and use. Price is good… Worth every penny" (MAS UK 5★, 2025-12-10).
- **Complaints [VOC]:** **English-market localization wall** — "when I try to look at the instruction video or FAQ, it takes me to a website where everything is in Chinese… for me, this app is worthless" (MAS US 1★, 2026-05-22); historic subscription rage and scrolling content-loss (2022, stale, §2.4); "听说可以免费使用…骗子" ("heard it's free… scam") (MAS AU 1★, 2024-10-23).

### 4.4 ScreenFloat 2 — floating + library specialist

Profiled in §3.1. Summary card: **$17.99 one-time**, MAS + direct + **Setapp**, native, macOS 12.3+, v2.3.7 (Apr 2026), 5–8 substantive releases/yr, 2011-vintage app rebuilt as v2 in 2023. Capture modes: selection/timed/recording/recapture/import — **no scrolling capture, no OCR-gating**. Differentiator: floats + Shots Browser library + iCloud sync + data detection. The single best-reviewed tier-2 app in this research.

### 4.5 Snipaste — free pin-centric cross-platform

- **[OBSERVED]** ([snipaste.com](https://www.snipaste.com/)): Snipaste 2 free for **personal** use; license required for business; **Pro: $8.99 single device (cross-platform) / $19.99 three devices / $19.99 MS-Store 10-device**. v1.x permanently free. Windows (x64/x86/ARM64), **macOS Universal — but the Mac build is officially Beta** with feature gaps vs Windows ([GitHub wiki](https://github.com/Snipaste/feedback/wiki/Beta-for-Mac)), Linux AppImage.
- **Features:** snip with UI-element auto-detect; pixel-level control; color picker; history playback; the signature **"paste as floating window"** (images, text, HTML, color swatches, GIF) with grouping, click-through, transparency, auto backup/restore; annotation incl. mosaic/Gaussian blur. **No scrolling capture (planned v3.0). No OCR library/organizer.**
- **VOC:** "There's also snipaste.com with very similar functionality. I dont understand how it's free." (HN, 2024-06-11, [item](https://news.ycombinator.com/item?id=40649806)); "I'll stick with Snipaste because of the 'pinning' feature — which is absolutely key for my workflow" (HN, 2024-04-26, [item](https://news.ycombinator.com/item?id=40169906)).
- **Takeaway:** validates pin-to-screen as a retention feature; weak as a Mac-native threat (beta, Qt cross-platform UI, no scrolling).

### 4.6 Capto — the Setapp also-ran

- **[OBSERVED] MAS:** v2.1.4 (2026-01-06, "Optimized for macOS 26. Minor defect fixes."), first MAS release 2016, macOS 10.14+, Global Delight. [Listing](https://apps.apple.com/us/app/capto-screen-capture-recorder/id1078184147). **Direct price $29.99 one-time / 2 Macs; $44.99 family / 5 Macs** [CLAIM via reviews]; on **Setapp**.
- **Setapp rating: 86% from 1,033 ratings** ([reviews page](https://setapp.com/apps/capto/customer-reviews)) [OBSERVED]. Third-party aggregate: 4.4/5 from 344 MAS ratings but only **3.2/5 from 160 MacUpdate reviews** [CLAIM, via [screensnap.pro roundup](https://www.screensnap.pro/blog/best-cleanshot-x-alternative-in-2026-plus-4-more-options-for-mac-users)].
- **2026 MAS VOC (fresh, mixed):** "In order to record system audio, you have to… buy the upgrade… you also CAN'T export without the upgrade" (US 2★); "latest update broke essential functionality… the video scrubber… now sloppy, unrestrained" (US 3★); offset by long-term loyalists ("Been using Capto for a few years now… Great app"). [OBSERVED via MAS review RSS, 2026-06-09]
- **Features:** fullscreen/selection capture; **URL-based full-webpage capture** (its substitute for scrolling capture); 60fps recording with webcam PiP; real video editing suite (cut/join/trim/annotate, per-track audio); image editor; **folder-based smart-collections organizer**; share to YouTube/Dropbox/FTP/SFTP.
- **Status: maintenance mode.** One trivial release in 12+ months; persistent 2025–2026 VOC: "'Capto Helper mandatory to proceed!' popup loops" (Andrew, 2026-05-26); "v2.1.3 keeps crashing repeatedly on Sequoia" (2025-08-21); "simple actions are made complicated" (2025-05-26); shortcut dies daily (2026-02-24). Lesson: a 2016-class organizer + recorder without maintenance bleeds trust even inside Setapp.

---

## 5. Quick Passes — 2024–2026 entrants

| App | What it is | Price/license | Scrolling? | Library? | Recency | Source |
|---|---|---|---|---|---|---|
| **Better Shot** (KartikLabhshetwar) | OSS "alternative to CleanShot X"; Swift 6/SwiftUI, macOS 14+, no deps; region/full/window via macOS `screencapture` CLI for "maximum reliability", OCR, color picker, pin-to-screen, MP4 recording + video editor (pad/radius/shadow/bg), annotations, Homebrew cask | Free, BSD-3 | **No** (not in README) | Capture-history tabs only | **1,972★; created 2026-01-11; v0.3.7 on 2026-06-07** | [github.com/KartikLabhshetwar/better-shot](https://github.com/KartikLabhshetwar/better-shot) [OBSERVED] |
| **Capso** (lzhgus) | OSS "free, native alternative to CleanShot X ($29) and Cap ($58)"; Swift 6/SwiftUI, macOS 15+, 12 SPM modules | **BSL 1.1** (→Apache 2.0 in 2029; bars competing derivatives) | **Yes** | **Yes** — persistent history library; pin; OCR+translate; R2 cloud share | **903★, v0.8.5 on 2026-06-07**, 35 releases | [github.com/lzhgus/Capso](https://github.com/lzhgus/Capso) [OBSERVED] |
| **macshot** (sw33tLie) | "Most feature-rich open-source screenshot tool on macOS"; Swift/AppKit, ~8 MB idle RAM; 18+ annotation tools, **PII auto-redact**, GIF recording, OCR+translate, beautify | Free, GPLv3 | **Yes — auto-detects vertical/horizontal, stitches with Apple Vision** | — | **1.9k★, v4.1.2 June 2026** | [github.com/sw33tLie/macshot](https://github.com/sw33tLie/macshot) [OBSERVED] |
| **Capso ≠ Capto** | Note the name collision with Setapp's Capto — expect user confusion | | | | | |
| **Pixera** | Screenshot *beautifier* (gradient/mesh backgrounds, shadows, rounded corners, **auto-redaction of emails/tokens**, batch export, watermark control), ⌘⇧8 capture-and-style | Free + premium | No | No | PH launch 2025–26 | [pixeratools.com](https://pixeratools.com/) [OBSERVED] |
| **Tidyshot** (Kozlovskyi) | On-device-AI screenshot organizer (§3.2) | Free + **$5.99 one-time Pro** | n/a (doesn't capture) | **Yes — its whole product** | First release 2026-03-11; v2.1.1 2026-05-26 | [MAS](https://apps.apple.com/us/app/tidyshot-screenshot-organizer/id6758950886) [OBSERVED] |
| **TidyShot** (Komorkiewicz) | Capture + instant-paste + OCR-searchable library; same name, different app | Free+IAP | — | Yes | First release 2026-04-16; **v1.7 on 2026-06-09 (today)** | [MAS](https://apps.apple.com/us/app/tidyshot-screenshot-tool/id6761196631) [OBSERVED] |
| **Pickle** | Free private screenshot manager: date-grouped history, 1-click PII redaction, 7-day self-deleting share links; native Swift, macOS 14+ | **Free forever** | No | Light | v1.1, 2025 | [pickleformac.app](https://pickleformac.app/) [OBSERVED] |
| **ScreenSnap Pro** | Mac+Windows screenshot styler/share tool: 15 annotation tools, 160+ gradients, cloud short links, recording, OCR, pin; **"website capture" via URL paste** instead of true scrolling capture; runs an aggressive SEO blog that *ranks for scrolling-screenshot queries it can't serve in-app* | **$29 one-time covering 2 Macs, lifetime updates, 30-day refund, "no subscriptions — ever"**; also on Setapp | **No** (URL-render only; its own guide concedes "scrolling capture is only available in Shottr and Snagit" among alternatives) | No | © 2026, active blog | [screensnap.pro/pricing](https://www.screensnap.pro/pricing) [OBSERVED] |

**Pattern:** the 2024–26 cohort splits into (a) OSS native CleanShot clones now shipping scrolling capture (Capso, macshot — both updated *this month*), (b) beautifier/share niches (Pixera, ScreenSnap Pro), and (c) library/organizer niches (Tidyshot ×2, Pickle). Nobody in the cohort is doing capture+library together either.

---

## 6. Implications for Our Product

1. **Scrolling-capture quality bar (PRD-ready):** auto-scroll AND manual; live stitching preview with visible failure state; post-capture re-stitch/extend; horizontal + whole-window modes; full-resolution output (no CleanShot-style downscale); pass-list = Terminal, VS Code, Finder column view, Slack threads, PDFs, with Mos/Scroll Reverser installed. Longshot is the app to beat on mechanics; CleanShot on polish; nobody on reliability messaging.
2. **Library is the open differentiator:** ScreenFloat-class (smart folders, OCR/data-detection search, sync, auto-import of *others'* screenshots) + Tidyshot-class on-device AI naming + Snagit-class source-app/website metadata. ScreenFloat's v2.3.6 auto-import shows the wedge: ingest everything, regardless of capture tool.
3. **Pricing gravity:** tier-2 lifetime band is **$5.99–$17.99**; Capto's $29.99 reads expensive for its quality; ScreenSnap Pro markets "$29 one-time, no subscriptions — ever" *as the product*. Xnip's $4.99/yr sub is its top complaint magnet. Direction (not a decision): one-time core + optional AI/cloud tier matches every signal in this corpus.
4. **Watch the OSS floor:** Capso and macshot (free, native, scrolling capture, OCR, recording, 1–2k stars, weekly releases) will commoditize baseline capture features within ~12 months; durable value sits in reliability engineering (scrolling), library/AI organization, and support quality — exactly the two veins above.
5. **Localization is a moat against the Chinese feature-leaders:** iShot/Longshot ship more features per dollar but bleed English-market trust on docs/support ("everything is in Chinese… worthless," 2026-05-22; "never heard back from the developer," 2026-04-15).

---

## 7. Source Index (primary)

- iTunes Search/Lookup API + MAS customer-review RSS, pulled 2026-06-09 (raw: `research/.raw/mas-lookups.txt`, `research/.raw/mas-reviews.txt`)
- Xnip: https://www.xnipapp.com/ · https://apps.apple.com/us/app/xnip-screenshot-annotation/id1221250572 · https://alternativeto.net/software/xnip/about/
- Longshot: https://longshot.chitaner.com/ · /pricing/ · /blog/scrollingcapture_guide/ · /blog/scrollcapture_compare_with_other/ · /blog/why_develop_longshot_alternate_snipaste/ · https://apps.apple.com/us/app/longshot-screenshot-ocr/id6450262949
- iShot: https://apps.apple.com/us/app/ishot-screenshot-recording-ocr/id1485844094 · https://apps.apple.com/us/app/ishot-pro-screenshot-recording/id1611347086
- ScreenFloat: https://screenfloatapp.com/ · https://blog.eternalstorms.at/category/screenfloat/ · https://apps.apple.com/us/app/screenfloat-pro-screen-capture/id414528154
- Snipaste: https://www.snipaste.com/ · https://github.com/Snipaste/feedback/wiki/Beta-for-Mac
- Capto: https://apps.apple.com/us/app/capto-screen-capture-recorder/id1078184147 · https://setapp.com/apps/capto/customer-reviews
- Shottr scrolling failure docs: https://shottr.cc/kb/faq · https://shottr.cc/newversion.html
- CleanShot scrolling: https://scottwillsey.com/cleanshotx-scrolling-screenshots/ · https://talk.macpowerusers.com/t/cleanshot-and-scrolling-capture/37142
- OSS/technical: https://github.com/Brkgng/ScrollSnap · https://github.com/sw33tLie/macshot · https://github.com/lzhgus/Capso · https://github.com/KartikLabhshetwar/better-shot
- New entrants: https://pickleformac.app/ · https://pixeratools.com/ · https://poteam.pro/products/tidyshot · https://www.screensnap.pro/ · TechSmith Snagit library: https://www.techsmith.com/learn/tutorials/snagit/snagit-library/
- HN VOC: items 26117021, 25214442, 40649806, 40169906, 46956319, 46079145, 31775570
