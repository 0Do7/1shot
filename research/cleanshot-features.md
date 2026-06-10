# CleanShot X — Exhaustive Feature Catalog

**Researched:** 2026-06-09 · **Vein:** CleanShot X (cleanshot.com, MakeTheWeb / Wojtek Kowalski)
**Current shipping version:** 4.8.8 (23 March 2026) · **Min OS:** macOS 10.15+ · **App size:** ~74.9 MB (per Setapp listing)

Tags: `[OBSERVED]` = seen on official site/changelog/docs · `[CLAIM]` = reviewer/third-party said it · `VOC:` = verbatim user quote for landing-page copy.

---

## 0. Positioning snapshot

- Tagline: **"Capture your Mac's screen like a pro."** Marketing claims **"over 50 features"** and **"It feels like 7 apps in one."** [OBSERVED] (https://cleanshot.com/)
- Social proof on site: "4.9" stars "Based on user reviews", "350+ tweets" of testimonials. [OBSERVED] (https://cleanshot.com/, https://cleanshot.com/testimonials)
- Cloud is explicitly optional: "Cloud account is not required to use the app." [OBSERVED] (https://cleanshot.com/faq)
- **No Windows version and "no planned release currently."** [OBSERVED] (https://cleanshot.com/faq) — directly relevant to our future Windows-port goal: CleanShot has formally ceded that ground.

---

## 1. Capture modes [OBSERVED] (https://cleanshot.com/features unless noted)

| Mode | Details |
|---|---|
| **Capture Area** | Custom region selection; edge snapping; remembers previous area ("Capture Previous Area" is a separate command/shortcut) |
| **Capture Window** | Individual app windows; optional window shadow disable; rounded corners preserved (sharp-corner bug fixed in 4.8.8); **Editable Window Screenshots** added in 4.8 (May 2025) |
| **Capture Fullscreen** | Whole display; auto-crop of the MacBook notch from fullscreen-app screenshots (4.6, Sep 2023) |
| **Scrolling Capture** | "Capture something that doesn't fit on your screen"; Auto-Scroll option (4.4, Aug 2022); **Horizontal scrolling capture** (4.8, May 2025); multi-page printing of scrolling captures (4.8); length warning; improved stitching with drag-drop positioning (4.8) |
| **Self-Timer** | Delayed capture for setting up hover states / menus |
| **All-In-One mode** | Single shortcut opens a unified capture UI for all modes (4.2, Mar 2022); size specification by typed dimensions; aspect-ratio locking; saves last selection; per-mode keyboard shortcuts inside All-In-One (4.8); works with Freeze Screen |
| **OCR capture** ("Capture Text") | Region-select OCR — see §7 |

**Capture-time aids** [OBSERVED]:
- **Crosshair mode** with precision targeting (hold ⌘, or always-on preference)
- **Magnifier** — zoomed loupe during crosshair selection
- **Freeze Screen** — freezes moving content before selecting (works with All-In-One; hover states captured correctly as of 4.8.5)
- **Hide desktop icons** while capturing/recording — a signature feature since v1.0 (the app's namesake "clean" shot); also hides widgets (4.7, May 2024); you can still drop files on the hidden-icon desktop; standalone toggle + URL-scheme endpoints
- **Do Not Disturb auto-enable** / notification hiding during capture & recording
- **Self-Timer cursor handling**, shutter-sound mute preference, screen-dimming disable option

**After-capture actions** (configurable defaults, separate for screenshots vs video) [OBSERVED, changelog]: copy / save / annotate / upload / pin / open video trimming tool; multiple default actions at once (2.4, 2019); **auto-apply a Background-tool preset to all screenshots** (4.7, May 2024) with Shift-hold to temporarily bypass (4.8.4, Oct 2025); "Ask for name" (and tags) dialog before save/upload with Discard button.

---

## 2. Annotation editor ("Annotate") — tool-by-tool [OBSERVED] (https://cleanshot.com/features + changelog)

Editor shell: native macOS design, dark/light mode, resizable window, canvas zoom, move canvas with spacebar, lock canvas, undo/redo (⌘Z/⇧⌘Z), copy/paste & duplicate objects (⌘D, alt-drag), Shift for perfect shapes / locked-axis moves, emoji support (rendering fixed 4.8.8), object size hotkeys (1–6), per-tool letter hotkeys (R rectangle, A arrow, etc.), **"Copy without closing"** (Alt+copy, 4.8), Share button, print, drag image straight out of the editor.

1. **Crop / Resize** — crop with aspect-ratio selection and edge snapping; crop tool recognizes background color; **Resize Tool** (4.7, May 2024); "Scale Retina to 1x"; rotate & flip images (4.8, May 2025).
2. **Arrow** — four styles including curved arrows (4.2).
3. **Line** — straight lines.
4. **Rectangle** (outline) and **Filled rectangle**.
5. **Ellipse**.
6. **Pencil / freehand** — with auto-smoothing.
7. **Highlighter** — opacity slider; **Smart Highlighter with automatic word detection** (4.7, May 2024).
8. **Highlight tool** (area emphasis; rounded-corner & ellipse shapes, 3.4).
9. **Spotlight** — dims everything except the chosen area.
10. **Pixelate** — randomized pixelation (deliberately hardened against de-pixelation recovery, 4.2); adjustable intensity; Gaussian-blur variant.
11. **Blur** — "secure and smooth blur" options.
12. **Black Out** — solid redaction tool (4.2) — explicitly security-positioned alongside the hardened Pixelate/Blur.
13. **Counter** — auto-incrementing numbered step badges; custom styles & starting number; counters always render on top (4.7.5).
14. **Text** — seven predefined text styles incl. rounded; custom colors; opacity; larger sizes; **auto-format long text into left-aligned paragraphs** (4.7); easy resize handles.
15. **Color picker** — in-editor color picker tool (new in 4.8, May 2025) + custom colors with opacity slider.
16. **Image stitching / combine** — drag-drop multiple screenshots into one canvas (3.9, 2021), improved positioning (4.8).
17. **Canvas auto-expand** — annotations drawn past the edge expand the canvas with transparent background. VOC: "With CleanShot X you can literally color outside the lines! … This might be my single favorite thing about CleanShot X." (https://www.podfeet.com/blog/2022/04/cleanshot-x/, Apr 2022 — possibly stale but feature still present)
18. **Background tool** — see §5.
19. **.cleanshot project file format** — re-editable annotation projects (4.0, Dec 2021); screenshots reopened from the overlay stay editable.
20. Misc: disable object shadows, sRGB auto-conversion (4.8), QR-code reading via OCR tool (4.6).

---

## 3. Quick Access Overlay [OBSERVED] (https://cleanshot.com/features)

The post-capture floating thumbnail (their signature interaction since v1):
- Immediate actions: copy, save ("Save All" for batches), annotate, upload, trash, system Share menu, open-in-Mail, rotate image, pin, OCR.
- Drag & drop the thumbnail into any app; multi-display support; choose position & size; show-on-active-display.
- Auto-close timer (configurable, incl. 5/10-min options); swipe gestures (two-finger swipe to delete, slide down to dismiss); spacebar Quick Look preview; middle-click to close pins.
- File-info display; newest-screenshot indicator (4.7); subtle animation (4.7); "Restore Recently Closed" recovery; "Save as…" context menu; keyboard shortcuts for overlay actions, plus global Save/Close-overlay shortcuts.
- VOC: "The workflow of CleanShot X to simply hit Command-C and move on works much better for me." (https://www.podfeet.com/blog/2022/04/cleanshot-x/)

## 4. Pinning (floating screenshots) [OBSERVED]

- "Pin to screen": screenshot floats always-on-top; adjust size & opacity (two-finger scroll for opacity); arrow-key nudging; **Lock Mode** to click through to apps beneath (4.3); "Drag me" handle; shadow/corner-radius toggle; border removal; pin via shortcut, after-capture action, from Capture History, or QuickLook; context menu: copy, save, OCR, annotate, flip horizontally, scale Retina to 1x; **hide/show all pinned** shortcut and Close All (4.7); pin any PNG/JPEG via URL scheme.

## 5. Background tool (beautification) [OBSERVED]

- Added 4.5 (Dec 2022): wrap screenshots in backgrounds — **10 built-in backgrounds** plus **ten more added 4.7 (May 2024)**; custom background upload; padding, alignment, aspect-ratio controls; manual value entry; **Auto Balance** auto-spacing; **save settings as Presets** (4.6) and **auto-apply preset to every screenshot** (4.7) — i.e., one-time setup, every capture comes out "marketing-ready."

## 6. Capture History / restore [OBSERVED]

- Capture History (4.4, Aug 2022): browse recent captures, filter by type, selective delete, clear all, restore multiple files, double-click opens Annotate, annotate & pin from history, includes externally added files (4.7), **retention up to 1 month** (4.7, May 2024).
- "Restore Recently Closed File" (since 3.4.1) — undo for an accidentally dismissed capture.

## 7. OCR / Text Recognition [OBSERVED]

- "Capture Text" tool since 3.8 (Jun 2021). **"Text recognition is performed completely on-device"** — privacy-positioned. (https://cleanshot.com/features)
- Auto language detection (4.8, May 2025); language coverage grew steadily — Thai/Vietnamese (4.6.1), Korean/Japanese/Russian/Ukrainian (4.4, needs newer macOS), Arabic (4.8), then **+10 languages in 4.8.4 (Oct 2025): Czech, Danish, Dutch, Indonesian, Malay, Norwegian, Polish, Romanian, Swedish, Turkish**.
- Extras: link detection in recognized text, **QR-code reader** (4.6), line-break control via API, separate OCR shortcuts, OCR from pinned screenshot, distinct recognition sound.
- Note: no translation, no table reconstruction, no "search history by text" — (Shottr-style extras absent; gap worth noting).

## 8. Screen recording & GIF [OBSERVED] — *our v1 defers this; cataloged for parity table*

- **MP4 (H.264)** and **GIF** recording; quality/FPS/resolution controls incl. max-resolution cap and low-FPS options; lock aspect ratio; remember last area; uniform area selection (Option); area move/resize with arrow keys.
- **Audio:** microphone + computer/system audio with **own audio engine, no driver install** (4.6, Sep 2023); mono option; stereo-to-mono; mic-muted notification; mic volume visualization; improved bitrate; 4.8.8 fixed Focusrite-interface left-channel bug.
- **Camera:** webcam picture-in-picture (3.4, 2020); click overlay to fullscreen; square/rectangle/circle shapes; flip; virtual-camera support (Snap Camera, Logi Capture…); macOS **Presenter Overlay** support (4.6.2, Dec 2023).
- **Presentation aids:** Capture Clicks (color/size/style), Capture Keystrokes (customizable position, press animations, modifier-display duration), hide cursor option, hide desktop clutter, auto-DND, countdown, pause/resume, restart recording, menu-bar timer, recorder-controls repositioning, prevent display sleep, screen-dimming control, crash recovery, fullscreen controls visible-but-not-recorded.
- **Video Editor** (3.6, Mar 2021): trim, change quality/resolution to shrink file size, stereo→mono, mute/volume, playback preview; GIF trimming; GIF optimization preference; opens any external video file; open MP4 from clipboard.
- Recording upload to Cloud with auto-upload option.

## 9. Desktop icon hiding [OBSERVED]

Standalone utility feature (not just during capture): toggle desktop icons (+ widgets since 4.7) via menu bar, shortcut, or URL scheme (`/toggle-desktop-icons`, `/hide-desktop-icons`, `/show-desktop-icons`); desktop-stacks compatible; can still drop files onto the hidden desktop.

## 10. Settings & customization depth [OBSERVED]

- Settings tabs (from URL-scheme docs): **general, wallpaper, shortcuts, quickaccess, recording, screenshots, annotate, cloud, advanced, about** — 10 panes. (https://cleanshot.com/docs-api)
- File-name templating: app name or window title in names, auto-increment with custom start, month/AM-PM/UTC tokens, illegal-character cleanup, disable "@2x" suffix, PixelSnap naming parity.
- Output: format choice in Save-as, sRGB conversion, WebP & HEIC support (4.8, May 2025), Retina-to-1x scaling, remember last save location, default destination picker on Save button, auto temp-file deletion.
- Behavior: warning-dialog resets, silent updates / disable auto-update check, sound mutes, "Hide uploaded media," disable URL-scheme API, per-action After-Capture matrices.
- Macworld: the app "rewards study with greater control and efficiency." [CLAIM] (https://www.macworld.com/article/617854/cleanshot-x-review.html, Mar 2022 — stale but directionally valid)

## 11. Hotkey system [OBSERVED]

Every command globally bindable (incl. F1–F12), with many granular extras: Capture Area & Save, Capture Previous Area, Pin, Annotate Last Screenshot, Open From Clipboard, Hide/Show Overlays, Restore Recently Closed, separate OCR shortcuts, hide-pinned shortcut, in-editor tool/size keys, overlay action keys. VOC: "If you're a shortcut junkie, CleanShot X is filled with them." (podfeet.com, 2022)

## 12. Integrations & automation [OBSERVED]

- **URL Scheme API** (documented at https://cleanshot.com/docs-api): 18 endpoints — capture-area / capture-previous-area / capture-fullscreen / capture-window / self-timer / scrolling-capture / pin / record-screen / capture-text / open-annotate / open-from-clipboard / all-in-one / toggle-, hide-, show-desktop-icons / add-quick-access-overlay / open-history / restore-recently-closed / open-settings — most take x/y/width/height/display and an `action` param (copy|save|annotate|upload|pin). Permission handling fixed 4.8.6 (Dec 2025).
- **Raycast**: official extension (fixed 4.8.6), Raycast AI Chat integration (4.7.2, Jun 2024), ⌘R send-to-Raycast in Annotate (4.7.3). This is the closest thing they have to an "AI feature" — notable that core app has **no native AI** beyond OCR; Cloud adds **automatic video transcription + autogenerated captions** (https://cleanshot.com/product/cloud).
- **PixelSnap 2** integration (same developer's measurement tool) — measurement overlay during capture; PixelSnap owners get a 20% discount.
- System Share-menu extensions; "Open With CleanShot" in Finder; QuickLook interplay; TopNotch compatibility; GoPro-webcam utility compatibility.
- No public REST/cloud API, no Zapier, no Slack/Jira integrations found. [OBSERVED-absence]

## 13. CleanShot Cloud [OBSERVED] (https://cleanshot.com/pricing, https://cleanshot.com/product/cloud)

- **Cloud Basic** (bundled free with every license): **1 GB storage**; instant share links copied to clipboard during upload; drag-drop while uploading; GIF/video upload.
- **Cloud Pro** ($8/user/mo annual, $10 monthly): **unlimited storage**, **custom domain + branded links/logo**, **self-destruct control** (expiring links), **password protection** (settable pre-upload, 4.3), full-quality uploads, **tags**, name-before-upload, direct-download links, **team management**, **SSO** (since 3.8.1, 2021) and **SCIM**, auto-upload of recordings.
- Web dashboard: delete shares, see **view counts**, organize with tags/folders; **custom video player**; **automatic video transcription** and **autogenerated captions**; **Push notifications for comments/views on shared media** (4.8.4, Oct 2025 — implies a commenting feature on shares).
- Security claims: "ISO 27001 certification," "external security testing." [OBSERVED] (https://cleanshot.com/product/cloud)
- **Sharp edge (VOC goldmine):** by default, videos uploaded to Cloud **self-destruct after 24 hours** unless changed in settings. [CLAIM] VOC: "Your videos get deleted automatically and nobody tells you" … "A ton of people on Reddit complained about the same thing." (https://klicktrust.com/cleanshot-x-review/, 2025)

## 14. Pricing, licensing, trial — exact [OBSERVED] (https://cleanshot.com/pricing, /buy, /faq)

- **App + Cloud Basic — $29 one-time** (1 Mac): perpetual license, **1 year of updates**, optional **$19/year** renewal for continued updates, 1 GB cloud.
- **Multi-seat one-time:** 2 Macs $49 · 5 Macs $119 · 10 Macs $229 · >10 seats email hello@cleanshot.com.
- **App + Cloud Pro — $8/user/mo billed annually ($96/yr) or $10/mo monthly:** always-latest app version, unlimited cloud, custom domain/branding, self-destruct + password protection, team management + SSO.
- License terms: one activation per seat; moving to a new Mac auto-deactivates the old one; keys delivered via **Paddle**; License Manager portal (licenses.cleanshot.com) for re-download & extra seats.
- **Trial: none** directly — "we do have a 30-day money-back guarantee so feel free to give the app a try"; **7-day free trial only via Setapp**.
- Discounts: **30% student** (edu email), **20% PixelSnap 2 owners**.
- **Setapp:** included from $9.99/mo; Setapp members get the **Cloud Pro version included**; listing shows **99% rating, 14,013 ratings**, v4.8.8. [OBSERVED] (https://setapp.com/apps/cleanshot)
- Third-party 3-year cost math [CLAIM] (screensnap.pro, Feb 2026, a competitor's blog — bias noted): Shottr $12 vs CleanShot-no-cloud $87 vs CleanShot+Cloud $317 vs Setapp $360.

## 15. Shipping direction 2024–2026 (changelog read) [OBSERVED] (https://cleanshot.com/changelog)

- **4.7 (May 2024):** Resize tool, Smart Highlighter (auto word detection), auto-apply background presets, 10 new backgrounds, hide widgets, 1-month history, new URL-scheme endpoints. → doubling down on **annotation polish + beautification-by-default**.
- **4.7.2–4.7.5 (Jun 2024–Feb 2025):** Raycast AI integration, Sequoia compatibility, large bug-fix batches.
- **4.8 (May 2025) — biggest recent drop:** color picker, editable window screenshots, **horizontal scrolling capture**, rotate/flip, OCR auto-language + Arabic, **WebP/HEIC**, stitching improvements, multi-page printing, sRGB, copy-without-closing, advanced upload options, All-In-One sub-shortcuts.
- **4.8.1–4.8.5 (Jul–Dec 2025):** macOS **Tahoe** UI overhaul + icon, new aspect ratios, **push notifications for comments/views** (Cloud engagement loop), **+10 OCR languages**, preset-bypass modifier.
- **4.8.6–4.8.8 (Dec 2025–Mar 2026):** Raycast/URL-scheme and recording fixes.
- **Strategic read:** cadence is steady but incremental — refinement, OS-compat, OCR breadth, Cloud collaboration (comments/notifications/transcription). **No native AI features, no Windows, no redesign of pricing** in 2024–2026. The innovation pace has visibly slowed vs 2020–2022 feature explosions — an opening.

## 16. Voice of customer (verbatim)

Curated (official testimonials page — positive by construction, https://cleanshot.com/testimonials):
- VOC: "I didn't realize how broken native screenshots on macOS were until I started using CleanShot." — Kushal Byatnal
- VOC: "The UX of CleanShot is amazing — I've never been able to capture, annotate, and share visuals so quickly." — Steve Boak
- VOC: "Cleanshot does something macOS already does, taking screenshots, but 1000X better 🔥" — Fabrizio Rinaldi
- VOC: "I use it easily 10 times a day. It's incredibly good." — Andrew German
- VOC: "I use it almost every 10 minutes. Not sure what I'd do without it." — Jonno Riekwel
- VOC: "One of the best gifts I've ever received was a CleanShot license" — Melissa Eshaghbeigi
- VOC: "CleanShot is one of the best Mac apps out there." — Cabel [Sasser, Panic]
- VOC: "Probably the best screen capture app I've ever seen 🔥" — Daniel Korpai
- VOC: "The essential swiss army knife for screenshots, markups, and GIFs." (homepage testimonial)
- VOC: "One of my most used 'invisible' apps that just fits into my workflow." (homepage testimonial)

Independent (reviews; emotional language):
- VOC: "Screenshots appear instantly. This is genuinely 'I didn't even realize it was done' fast" (https://klicktrust.com/cleanshot-x-review/, 2025)
- VOC: "It's all there and it works how your brain expects it to work" (klicktrust, on editing)
- VOC (negative): "Your videos get deleted automatically and nobody tells you" (klicktrust quoting Reddit sentiment on 24h cloud video expiry)
- VOC (negative): "All these options just clutter the interface" (klicktrust, feature overload)
- VOC (negative): "Sometimes you see old versions of screenshots pop up… it's definitely weird and confusing" (klicktrust)
- VOC: "With CleanShot X you can literally color outside the lines!" / "I'm besotted with CleanShot X." (https://www.podfeet.com/blog/2022/04/cleanshot-x/, Apr 2022 — pre-2024, flag stale)
- VOC: "This is such a handy app for taking screen shots! I use this often as I put together articles and newsletters." (Setapp review, https://setapp.com/apps/cleanshot)
- [CLAIM] Macworld Editors' Choice: "CleanShot X truly shines in its Annotate feature, a super-powered bump above Apple's Markup." (Mar 2022 — stale)
- Note: direct Reddit harvesting was blocked (reddit.com unfetchable + API 403); Reddit-sourced sentiment here comes via secondary citations.

## 17. Observed gaps & friction (ammo for our positioning)

1. **No trial** outside Setapp — Macworld and others flag it; relies on money-back guarantee. [OBSERVED]
2. **Cloud Pro paywall** for self-destruct/password/custom domain; sharing beyond 1 GB needs $96/yr on top of $29. [OBSERVED]
3. **24h default video self-destruct** burned users (trust issue). [CLAIM]
4. **No screen ruler / pixel-measurement** in-app (sold separately as PixelSnap, $) — Shottr includes it free. [CLAIM] (screensnap.pro, 2026)
5. **No native AI** (no AI naming, no smart redaction, no summarize/translate OCR) — only Raycast hand-off + Cloud transcription. [OBSERVED-absence]
6. **No Windows**, explicitly. [OBSERVED]
7. Feature breadth ↔ "clutter the interface" complaints; 45–75 MB footprint vs Shottr's ~2 MB. [CLAIM]
8. Update cadence 2024–2026 is mostly maintenance — perceived stagnation risk for them.

## 18. Sources

- https://cleanshot.com/ · https://cleanshot.com/features · https://cleanshot.com/pricing · https://cleanshot.com/buy · https://cleanshot.com/faq · https://cleanshot.com/changelog · https://cleanshot.com/testimonials · https://cleanshot.com/docs-api · https://cleanshot.com/product/cloud
- https://setapp.com/apps/cleanshot
- https://klicktrust.com/cleanshot-x-review/ (2025)
- https://www.screensnap.pro/blog/cleanshot-x-vs-shottr (Feb 2026; competitor blog — bias)
- https://www.macworld.com/article/617854/cleanshot-x-review.html (Mar 2022 — stale)
- https://www.podfeet.com/blog/2022/04/cleanshot-x/ (Apr 2022 — stale)
