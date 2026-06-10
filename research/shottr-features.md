# Shottr — Exhaustive Feature Catalog & Pricing History

Research date: 2026-06-09. Current shipping version: **v1.9.1 (Dec 17, 2025), 2.3 MB DMG, macOS 10.15+ (Catalina and up), Intel + Apple Silicon** [OBSERVED — https://shottr.cc/ and https://shottr.cc/newversion.html].

Tagline on site: *"Screenshot tool for designers, front-end engineers, mobile developers, those who care about pixels."* Meta description: *"Shottr is a tiny and fast mac screenshot tool with annotations, beautiful backgrounds, scrolling screenshots and S3 upload capabilities. Built with love and optimized for Apple silicon."* [OBSERVED — https://shottr.cc/]

**Maker:** Pseudonymous indie developer, HN handle **ffitch** (bundle ID `cc.ffitch.shottr`); legal entity **Electric Endeavors LLC** (site footer); referred to as "Max" by Podfeet's review and "Evgenii" elsewhere — identity deliberately low-profile. He wrote on HN (2022): *"I'm not really anonymous, the app is signed with a certificate with my name on it… I just don't feel comfortable being a public figure"* (https://news.ycombinator.com/item?id=31787618). Contact: shottr.cc@gmail.com; X/Twitter @shottr_cc.

---

## 1. Capture modes

All [OBSERVED] from https://shottr.cc/, https://shottr.cc/newversion.html, and https://shottr.cc/kb/urlschemes unless noted.

| Mode | Details |
|---|---|
| **Area capture** | Marquee selection; Shift+drag = square selection; Esc during capture suppresses editor popup. |
| **Fullscreen capture** | Entire screen. |
| **Active window capture** | With configurable shadow handling modes (preferences); proportional padding; animated-wallpaper support added v1.7.2; fallback to active-window selection for edge cases (v1.9.1 era polish). |
| **"Capture Any Window"** | Separate hotkey-assignable action (added v1.6.1) — pick any window, not just the active one. |
| **Scrolling capture** | Vertical, auto-scrolled by the app: *"Take a screenshot of a long web page or capture conversation in a chat. Any app, any window."* Both directions: down and reverse/up (`shottr://grab/scrolling/reverse`). Max height default 20,000 px, configurable up to **200,000 px** (v1.6.1). Setting to reverse auto-scroll direction (for Scroll Reverser users, v1.7). Failure/max-height messaging (v1.7). Known limits [OBSERVED on FAQ]: *"Scrolling Capture doesn't work well with macOS Terminal, Visual Studio Code and Columns view in Finder"*; scroll-modifying apps (MOS, Scroll Reverser, Smooze) interfere; a **manual scrolling capture** fallback mode is documented (Notion guide linked from FAQ). macOS-level scrolling-capture breakage got an in-app workaround in v1.9. (https://shottr.cc/kb/faq) |
| **Repeat Area capture** | Re-captures the exact previous area; customizable shortcut (v1.6.0); URL scheme `shottr://grab/repeat`. |
| **Delayed capture** | 3-second delay default; arbitrary delay via URL scheme `shottr://grab/delayed=10`. |
| **Add Capture / append** | "Combine Screenshots — Take multiple screenshots and put them on the same canvas using the Add Capture button" (v1.7.2); `shottr://grab/append`. FAQ notes some tools don't work over appended captures. |
| **Load from clipboard / file** | Cmd+Shift+V clipboard, Cmd+Shift+O file; "Open With" for PNG/JPEG (v1.5.2); drag a file onto the canvas. |
| **Freeze screen** | FAQ entry "How do I freeze the screen?" exists — screen-freeze trick documented via KB. |

No video recording, no GIF *recording* (only 2-frame before/after GIF assembly — see §3). Video/GIF recording is a top entry on the public feature-request list (https://shottr.cc/request/) and on the homepage "what should I build next" survey ("Video or GIF recordings"). [OBSERVED]

## 2. Annotation & markup tools

v1.9 toolbar = **16 tools** ("All 16 tools are now shown in the toolbar if the window is large enough" — v1.9 notes). [OBSERVED]

- **Text labels** — multiple sizes/styles; pointy-arrow default for labels (v1.5.4); Tab-key adds picked color to label.
- **Arrows** — multiple styles incl. slim/super-slim, curved; CMD+drag reverses direction; since v1.9 *every* arrow type bendable into an arch.
- **Rectangles & Ovals** — fill + opacity controls (v1.6.2); classic and **hand-drawn style** (v1.9; Cmd+R randomizes the hand-drawn jitter).
- **Freehand drawing** (v1.7) — stroke variability via Cmd+Enter, smoothness via Opt+Up/Down; single-click point drawing.
- **Highlighter** (v1.7) — cap style via Cmd+Enter.
- **Spotlight** (v1.7) — dims everything but a region; background opacity via keys 1–9.
- **Step counter** (v1.5.4) — numbered badges; number editable by selecting and typing (FAQ).
- **Magnifier tool** (v1.9) — zoomed-in callout placed on the image.
- **Blur/pixelate** — area blur via key B; "text-only" pixelation mode that scrambles only glyphs (*"Text mode hides text without corrupting anything else"*); small-area scrambling hardened so it can't be reversed (v1.5.2); Chinese text accuracy work (v1.6.0).
- **Erase/remove objects** — content-aware-ish removal: *"remove sensitive information as if it was never there"*; text-only erase mode preserves background.
- **Image overlay** (v1.6.0) — paste images on top; semi-transparency via number keys; **before/after 2-frame GIF export** (press 5 for transparency, align, hit GIF icon).
- **Backdrop tool** (v1.8, Sep 2024) — gradient backgrounds, shadows (intensity-tuned in v1.8.1), rounded corners — the "beautiful screenshots" CleanShot-style feature.
- **Guides** (v1.5.2) — Opt+S vertical / Opt+D horizontal; click to imprint.
- Object plumbing: custom annotation colors (v1.8), color/thickness/line-style customization per object (v1.5.2), Opt+Drag duplicate, Cmd+C/Cmd+V objects, selected object jumps to front, configurable **object snapping** (v1.9, Draw menu), undo/redo (Cmd+Z / Cmd+Shift+Z + menu), Space+drag repositioning mid-draw, real-time size slider.
- **Expandable canvas** (v1.7.2) — draw outside the screenshot bounds; Edit → Rasterize Image; Reset Crop in Edit menu.
- **Crop/resize** — select + Enter to crop; image **resizer** by clicking the size readout upper-right (v1.7).
- **Print** (v1.7.2) — Cmd+Shift+P, orientation choice (v1.9.1).

## 3. OCR, QR, and text intelligence

[OBSERVED — homepage + changelog]
- Hotkey-triggered area OCR: *"Press a hotkey and select an area — Shottr will parse the text and copy it to the clipboard."* URL scheme `shottr://ocr`.
- **QR code detection/decoding** built into the OCR pass (v1.5.2).
- Chinese-language OCR support (v1.5.2); FAQ has "Support Other Languages" entry.
- Linebreak-removal button after recognition + default setting (v1.7); double-space prevention (v1.8.1).
- OCR toast lengthened 3s→5s (v1.7.2); custom confirmation toasts for OCR.
- Reviewer assessment [CLAIM, May 2023]: OCR is *"not only super accurate, but it's also really fast"* (https://www.podfeet.com/blog/2023/05/shottr/).

## 4. Pixel ruler, measurements, color tools (the app's stated raison d'être)

Author on HN [CLAIM by author, 2022]: *"I built Shottr to 'explore' pixels: zoom in, check rendering quality, select certain areas to measure sizes"* and *"I created Shottr first and foremost for measurements"* (https://news.ycombinator.com/item?id=31783606, ...31783789).

- **Screen ruler**: press ↑/↓ to measure vertical, ←/→ horizontal; hover between two objects and it snaps to edges; click to imprint measurement onto the screenshot; adjustable ruler sensitivity (v1.7.2); crisper rendering on non-retina (v1.5.2).
- **Selection-as-measuring-tool**: dimensions readout; arrow keys nudge 1 px, Shift+Arrows 10 px, Cmd+Arrows resize 1 px, Cmd+Shift+Arrows 10 px, [ / ] enlarge 1 px per side, Shift+[ ] 10 px; auto-padding button on marquee; click a marquee edge to auto-adjust that edge only (v1.6.1).
- **Smart selection**: press **A** to auto-adjust selection to object bounds; hold ⌥ while selecting for live preview of the snap; Cmd+click selects a monotone object (great for measuring buttons/elements).
- **Retina handling**: sizes reported in **logical (non-retina) pixels by default; click the dimension box to switch to physical retina pixels**; robust DPI detection in mixed Retina/non-Retina monitor setups (v1.6.0); retina images saved at 144 dpi when applicable (v1.6.1); optional retina-downscale-on-save setting (v1.5.1). [OBSERVED — homepage Tips]
- **Zoom**: "true zoom" digital magnifying glass — Z+click / Z+drag quick zoom, Cmd+2 zoom-to-selection, Q/W zoom to selection corners, Cmd+1 fit / Cmd+0 100%, "Default zoom level: Prefer 100%" setting; right-mouse-drag or Space+drag panning. KB: *"One of the key Shottr advantages is precision"* (https://shottr.cc/kb/precision).
- **Color picker**: TAB copies color under cursor; **Shift+TAB = "copy text color"** (darkest pixel of 20×20 area — no precision needed); select area + **C = copy average color**; multiple formats incl. HEX, HEX-without-#, **OKLCH** (v1.8.1).
- **Contrast checker**: WCAG 2.0 contrast ratio shown above selection marquee (v1.7.2); **APCA** added v1.8.1 (Opt+Click on the value toggles WCAG↔APCA).

## 5. Pinning & desktop utilities

- **Pin screenshots** (v1.6.0): floating, borderless, always-on-top windows; resize with scroll wheel; semi-transparent pins lose shadow for overlay comparisons (v1.7); marketed as "temporary screenshots storage / keep references."
- **Preview thumbnail** post-capture; option to keep it until used/dismissed (v1.6.1); shows above fullscreen & Stage Manager windows (v1.6.2); "preview instead of editor after area capture" setting (v1.5.3).
- Drag-and-drop the image out of the app/preview to anywhere (Yoink/Dropover compatibility maintained, v1.6.1).
- "Unclutter your desktop": dedicated save folder on ⌘S; auto-copy / auto-save after capture settings (v1.5.3); auto filename timecode that sorts chronologically by name (v1.6.2); FAQ Q on file name/location templating exists (limited).
- Background removal (subject cutout): **not present** — no mention anywhere on site/changelog. The Backdrop tool (gradients/shadows/rounded corners) is the closest "pretty screenshot" feature. [OBSERVED-absence]

## 6. Sharing & upload

- **Shottr Cloud upload** (Cmd+E / F2): uploads to shottr.cc, copies public URL. Requires a free **token** — instant for license holders, weeks-long email wait for free users. *"Tokens are free."* No expiration policy but *"I may take down any image without a warning"* and *"Shottr is not a secure image storage! All uploads are considered public."* Manage Uploads UI to view/delete. No Imgur/Dropbox/Drive/FTP/SFTP integrations (explicitly declined). [OBSERVED — https://shottr.cc/kb/upload/]
- **S3 upload** (v1.9, Nov 2025): any S3-compatible storage; third-party S3 services (Tencent, Yandex, Minio…) expanded in v1.9.1. Upload token ≠ license number (purchase FAQ).
- **Integrations/automation**: official **Raycast extension**, **Alfred workflow**, and a full **URL Schemes API** (v1.8): `shottr://grab/{fullscreen|area|window|scrolling|scrolling/reverse|repeat|delayed[=N]|append}`, `shottr://ocr`, `shottr://load/{clipboard|file}`, `shottr://{show|settings|uploads}`, plus `?then=copy,save,edit,pin,thumbnail` post-actions. [OBSERVED — https://shottr.cc/kb/urlschemes]

## 7. Performance claims & engineering posture

[OBSERVED — homepage, all current as of v1.9.1]
- *"Tiny (2.3mb dmg) native app optimized for Apple Silicon. It takes only 17ms to grab a screenshot, and ~165ms to show it to you."* (Historic sizes: 1.3 MB in 2021 → 2.3 MB in 2025 — the app grew but stayed minuscule.)
- Native low-level macOS APIs; FAQ: *"The Windows or Linux version doesn't seem likely. Shottr relies on low-level macOS api…its codebase is not portable."*
- Clipboard copies PNG (not TIFF) by default (v1.5.4); auto PNG/JPEG format selection based on content (v1.5.x).

## 8. Hotkeys & preferences depth

- Customizable global hotkeys for every capture mode (since v1.5), incl. Repeat Area (v1.6.0), Capture Any Window and "Reopen Shottr" (v1.6.1).
- In-editor: V select/crop; B blur area; A auto-adjust; Z zoom; Tab/Shift+Tab/C color picks; Enter crop; Cmd+E/F2 upload; Cmd+S save; Cmd+Shift+S Save As (works from thumbnail too); Esc behavior configurable (copy / save / nothing on Esc, v1.5.2); Cmd+C copies partial selection without closing window (v1.5.3).
- Preferences include: hotkeys; window-capture shadow modes; color format; default save folder; auto-copy/auto-save; preview-vs-editor; Esc behavior; notifications style (custom toasts vs system, per-action confirmations for OCR/Color/Save/Upload, fully off); telemetry toggle; max scrolling height; auto-scroll direction; retina downscale; default zoom; splash-screen hide (v1.8); window always-on-top; menubar icon hide (**license-only**, v1.7); dock-icon hide (**Friends Club experimental**, License tab) [OBSERVED — FAQ + changelog].
- Auto-update arrived v1.6.2 (Feb 2023); update check pings https://shottr.cc/api/version.json.

## 9. Privacy & telemetry

[OBSERVED — homepage FAQ] Telemetry (non-identifying: timings, error codes, feature-usage frequency) on by default, toggle in Preferences; *"never sold to third parties"*; Google Analytics removed in v1.5.1; license validation needs internet; app otherwise works offline. 2022 HN pushback on a `/telemetry.php` call after a blur action: *"when I blurred something it made a network request to its server… which is kind of creepy for a tool with privileged access that helps you hide data"* — VOC, https://news.ycombinator.com/item?id=31775459 (2022, pre-dates current disclosure).

## 10. Distribution

- **Direct download only** (DMG from shottr.cc) + **Homebrew cask** (`brew install shottr`, cask `shottr`, auto_updates true) [OBSERVED — homepage source + homebrew-cask repo].
- **Not on the Mac App Store** as of June 2026 (no apps.apple.com listing exists; author mused about MAS on HN in 2022 but never shipped it). So there is a single build — no MAS/website build split. [OBSERVED-absence]
- **Setapp: explicitly declined.** Purchase-page FAQ: *"I'll need to hike the app price significantly for it to make financial sense… I probably won't make it high enough to justify the hassle of the SetApp integration. Sorry."* [OBSERVED — https://shottr.cc/purchase.html]
- Launched on Product Hunt (Feb 2022; 4.9/5, 17 reviews as of 2026) and Show HN (Aug 2021; big thread Jun 2022, 184 pts).

## 11. Pricing — history and current model

**Timeline:**
1. **2021 – May 2023: free / donationware.** Author on HN, 2022: *"I don't plan on monetizing the app"* (https://news.ycombinator.com/item?id=31785511); Buy Me a Coffee page for tips; framed as a hobby project too costly to productize (Reddit post cited at https://news.ycombinator.com/item?id=31775965).
2. **May 24–28, 2023 (v1.7): paid tiers introduced** — Basic **$8**, Friends Club **$25** [CLAIM — https://www.podfeet.com/blog/2023/05/shottr/, corroborated by purchase-page cutoff date "if you have bought me a coffee before 5/24/2023, there's a free Friends Club license for you"]. Free tier retained. Nag: after a 30-day grace period, *"every 5-10 editor uses"* an animated character appears — *"Hi! I'm the world's most annoying salesperson. Do you want to buy Shottr?"* [CLAIM — Podfeet, May 2023].
3. **Oct 14, 2024: Basic raised $8 → $12** (announced on X: https://twitter.com/shottr_cc/status/1843260736958820471 — "Shottr license price will go up to $12 next Monday, October…"; existing licenses unaffected). Friends Club moved $25 → **$30** around the same period.
4. **Promos:** Black Friday sale dropping Basic to **$9** (markup still present, commented-out, on purchase page). Otherwise: *"There are no discount coupons available, and I'm not planning to issue promotional coupons in the future."*

**Current model [OBSERVED — https://shottr.cc/purchase.html, June 2026]:**
- **Free:** *"You can download and use Shottr for free. After 30 days it will start asking you to consider upgrading."* Homepage FAQ: *"Most of its features are available to free users; the main caveat is that the app will ask you to consider buying it every once in a while… I plan to add more features and raise its price in the future."* **License required for commercial use** (honor-system).
- **Basic — $12 one-time** (not subscription): removes nag, unlocks menubar-icon hiding, instant upload token, commercial use.
- **Friends Club — $30 one-time**: *"Bragging rights, access to experimental features, and better support"* (e.g., experimental dock-icon hide). Not upgradeable from Basic, never discounted.
- **License terms:** perpetual; *"One license covers one user and up to five computers"*; multi-license cart supported; no stated update-expiry (contrast CleanShot's 1-yr updates). Merchant of record **FastSpring** (card/PayPal/Alipay; no Bitcoin, no direct payment); EU VAT invoices; license retrieval portal; free Friends Club licenses for pre-5/24/2023 coffee-buyers and pre-Dec-2021 early supporters.

**Feature gating is minimal:** practically everything (scrolling capture, OCR, backdrop, S3, ruler) works free; paid = nag removal + menubar/dock icon hiding + instant upload token + experimental features + conscience. The model is "nagware with honor-system commercial clause," not a feature paywall. [OBSERVED]

## 12. Version history at a glance (dates [OBSERVED] from shottr.cc release notes)

| Ver | Date | Headliners |
|---|---|---|
| 1.5.1 | Oct 6, 2021 | v1.5 base: scrolling capture, area/window capture, OCR, object removal, hotkey prefs |
| 1.5.2 | Jan 9, 2022 | QR decoding, Chinese OCR, repeat-area, delayed shot, guides, object styling, telemetry toggle |
| 1.5.3 | Feb 10, 2022 | auto copy/save, preview-not-editor setting, Z+drag zoom |
| 1.5.4 | Jul 17, 2022 | step counter, text-only blur/erase, upload management |
| 1.6.0 | Sep 4, 2022 | pinning, image overlay, before/after GIF |
| 1.6.1 | Oct 22, 2022 | persistent thumbnail, 144dpi, 200k-px scroll limit |
| 1.6.2 | Feb 25, 2023 | auto-update, fill/opacity, scroll-resize pins |
| 1.7.0 | May 28, 2023 | **PAID TIERS**; freehand, highlighter, spotlight, resizer, OCR linebreak strip |
| 1.7.1 | Jul 27, 2023 | macOS 13.5 fixes |
| 1.7.2 | Nov 4, 2023 | expandable canvas, Add Capture, WCAG indicator, print |
| 1.8 | Sep 29, 2024 | **Backdrop tool**, Raycast/Alfred, URL schemes, custom colors |
| 1.8.1 | Nov 28, 2024 | OKLCH, APCA contrast |
| 1.9 | Nov 23, 2025 | **S3 upload**, magnifier callout, hand-drawn style, bendable arrows, snapping |
| 1.9.1 | Dec 17, 2025 | third-party S3, print orientation, stability |

Cadence note: ~1 feature release/year since going paid (1.7→1.8 was 16 months; 1.8→1.9 was 14 months) — slow but steady solo-dev pace. [OBSERVED]

## 13. Known gaps / weaknesses (for our add/cut analysis)

- **No video or GIF recording** (top community request; homepage survey lists "Video or GIF recordings"). [OBSERVED]
- **No real cloud product** — upload is a tokened, no-SLA, public-by-default convenience; *"no uptime guarantees… I may take down any image without a warning."* [OBSERVED — kb/upload]
- **No screenshot history/organizer** (feature-request list: "Screenshots organizer," "Screenshot history"), no filename templates, no multi-tab editor. [OBSERVED — https://shottr.cc/request/]
- **Scrolling capture fragility** in Terminal/VS Code/Finder-columns + scroll-utility conflicts. [OBSERVED — FAQ]
- **UI polish** [CLAIM — Setapp comparison, updated Jun 3 2026]: *"Basic UI: It's functional and won't be an issue for experts, but it lacks the polish and accessibility of CleanShot X"* (https://setapp.com/app-reviews/cleanshot-x-vs-shottr).
- No background-removal/AI features of any kind. [OBSERVED-absence]
- macOS-only forever (author's own words). Windows port off the table → open lane for us. [OBSERVED — FAQ]

## 14. VOC — verbatim user quotes

Product Hunt (https://www.producthunt.com/products/shottr/reviews, 4.9/5, 17 reviews):
- VOC: *"Even though this product launched on Product Hunt 4 years ago, Shottr is still one of my favorite tools today."* — Ilya Makarov, ~Jun 2026
- VOC: *"The workflow of quickly grabbing a screenshot, annotating it, and hitting Esc is incredibly efficient."* — Amit Jethani
- VOC: *"I now go out of my way to find opportunities to take a screenshot just so I can mark it up."* — John LaFoone
- VOC: *"Easily the best Screencapture app on Mac. Better than the original one…3 Minutes saved each time!"* — Edwin Masripan (~2025)
- VOC (nag friction): *"The features in the free plan are easily worth five stars to me...now its a bit annoying."* — Angelina Nguyen (~2025)
- VOC: *"tiny, easy, stable"* — Curly Brackets (~2024)

Hacker News (Jun 2022 thread, https://news.ycombinator.com/item?id=31773863 — pre-2024, possibly stale on specifics, emotionally evergreen):
- VOC: *"This is an amazing piece of software. Does all that's needed — simple screenshots, very convenient crop / blur tool, annotation, arrows. One question though — why is this free? I am ready to pay for this."* — bestest (...31775316)
- VOC: *"from the initial peek at it, i love it--especially the scrolling capture."* — _boffin_ (...31774799)
- VOC: *"I love the ability to remove icons from within screenshots and have the background fill in automagically."* — gnicholas (...31775153)
- VOC: *"The erase tool in addition to blur/mosaic is great. And non-destructive."* — sovok (...31785048)
- VOC (competitive frame): *"if you want to pay, get Cleanshot… The most ethical software license for a tool like this one."* — gingerlime (...31775916); *"https://cleanshot.com/ is also very good, IMO, much better than Shottr."* — guessmyname (...31775570)
- VOC (trust): *"when I blurred something it made a network request to its server… kind of creepy for a tool with privileged access that helps you hide data."* — mrtksn (...31775459)
- VOC (positioning): *"Looks like an improved and more independent (post Evernote acquisition) alternative to Skitch."* — micheljansen (...31775549)

MacUpdate (https://shottr.macupdate.com/, 4.7/5, 7 reviews):
- VOC: *"After many years using Snap-n-Drag, I discovered this little gem. Amazing tool."* — zlazkow, Mar 2024
- VOC: *"Really well done. Thoughtful details, precisely designed. Features like the color picker I haven't seen before."* — tobias_1, Mar 2023
- VOC: *"Nice free screenshot utility. I really like the quick and easy OCR option!"* — Johnny-K, Jul 2022

Press [CLAIM, May 2023]: *"Shottr is a gem… astonishingly good tool that I find delightful"*; on text-only erase: *"it's downright freaky!… I've never seen anything like it"* — Allison Sheridan, https://www.podfeet.com/blog/2023/05/shottr/

## 15. Source index

- https://shottr.cc/ (homepage: features, tips, FAQ, release notes)
- https://shottr.cc/newversion.html (full changelog)
- https://shottr.cc/purchase.html (pricing, license terms, FastSpring FAQ)
- https://shottr.cc/kb/faq ; https://shottr.cc/kb/upload/ ; https://shottr.cc/kb/urlschemes ; https://shottr.cc/kb/precision
- https://shottr.cc/request/ (feature requests = gap map)
- https://www.podfeet.com/blog/2023/05/shottr/ (paid-transition details)
- https://twitter.com/shottr_cc/status/1843260736958820471 (Oct 2024 price hike)
- https://news.ycombinator.com/item?id=31773863 (2022 HN thread, author Q&A + VOC)
- https://www.producthunt.com/products/shottr/reviews ; https://shottr.macupdate.com/
- https://setapp.com/app-reviews/cleanshot-x-vs-shottr (updated Jun 3, 2026)
- https://macupdater.net/app_updates/appinfo/cc.ffitch.shottr/index.html (v1.9.1 metadata)
