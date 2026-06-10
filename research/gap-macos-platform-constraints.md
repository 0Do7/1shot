# macOS Platform Constraints & Channel Mechanics (as of mid-2026)

**Research date:** 2026-06-09. Scope: macOS 15 Sequoia → macOS 26 Tahoe platform constraints that bound a v1, local-first, screenshots-only Mac capture tool, plus distribution/channel mechanics. Tags: **[OBSERVED]** = Apple docs / official changelog / directly verified artifact; **[CLAIM]** = dev blog, press, or commenter report. All claims version- and date-stamped. Pre-2024 items flagged.

---

## 1. Screen-Capture Permission Regime (TCC "Screen & System Audio Recording")

### 1.1 Timeline of the permission, version by version

| macOS | Behavior | Status |
|---|---|---|
| 10.15 Catalina (2019, **pre-2024, stable since**) | Screen Recording TCC permission introduced; one-time grant, app must be relaunched after grant. | [OBSERVED] — Apple Support: https://support.apple.com/guide/mac-help/control-access-screen-system-audio-recording-mchld6aa7d23/mac |
| 15.0 Sequoia betas (Jul–Aug 2024) | **Weekly** re-authorization prompt for third-party screen capture apps ("…can access your screen and audio. Do you want to continue to allow access?"). Announced Aug 6–8, 2024. | [OBSERVED via press] MacRumors: https://www.macrumors.com/2024/08/15/macos-sequoia-screen-recording-app-permissions/ ; AppleInsider: https://appleinsider.com/articles/24/08/07/users-have-to-confirm-screen-recording-permission-every-week-in-macos-sequoia |
| 15.0 Sequoia beta 6 (Aug 14, 2024) → 15.0 release (Sep 2024) | Backlash forced Apple to soften: prompt became **monthly** and additionally on reboot in early builds; dialog offers "**Allow For One Month**" / "Open System Settings". | [OBSERVED via press] 9to5Mac: https://9to5mac.com/2024/08/14/macos-sequoia-screen-recording-prompt-monthly/ ; Daring Fireball (Aug 17, 2024): https://daringfireball.net/linked/2024/08/17/macos-15-beta-6-monthly-screen-recording-prompts |
| 15.1 (Oct 2024) | Frequency reduced again. Apple's official statement: *"Applications using our deprecated content capture technologies now have enhanced user awareness policies. Users will see fewer dialogs if they regularly use apps in which they have already acknowledged and accepted the risks."* Named beneficiaries in press coverage included **CleanShot X and PixelSnap**. | [OBSERVED — Apple statement quoted] MacRumors: https://www.macrumors.com/2024/10/07/apple-screen-recording-popup-update/ ; 9to5Mac: https://9to5mac.com/2024/10/07/macos-sequoia-screen-recording-popups/ ; iDownloadBlog: https://www.idownloadblog.com/2024/10/09/macos-sequoia-15-1-macos-screen-recording-prompts-frequency-reduced/ |
| 15.1 gotcha | 15.1 also began **overwriting the approval timestamp on each app invocation** — i.e., the 30-day clock resets while you keep using the app, but an app unused for >30 days re-nags, even if the user had "disabled" the nag via the plist hack. | [CLAIM — tinyapps.org analysis, Sep–Oct 2024] https://tinyapps.org/blog/202409180700_disable_sequoia_nag.html |
| 26 Tahoe (Sep 2025) | Permission pane reorganized: "Screen & System Audio Recording" plus a new **"System Monitoring"** grouping under Privacy & Security. TCC now evaluates the **responsible process** (not parent process) — permissions don't inherit to child processes; raw command-line binaries are no longer prompted at all and don't appear in the pane (26.1 requires an app **bundle** to appear in the Screen Recording UI). Periodic re-prompts still reported for some apps in Tahoe (e.g., Teams permission loops on 26.4), but the routine monthly nag for regularly-used GUI apps appears to have stayed at the relaxed 15.1 policy rather than reverting. | [CLAIM — community/vendor reports, 2025–2026] Apple Community: https://discussions.apple.com/thread/256188161 ; OpenClaw issue (Tahoe TCC, 2026): https://github.com/openclaw/openclaw/issues/14138 ; MS Q&A (26.4 Teams loop): https://learn.microsoft.com/en-us/answers/questions/5848423/teams-for-mac-screen-sharing-permission-loop-on-ma |

**Net for spec:** Assume the user will see, at minimum: (a) the initial Screen Recording grant (with app relaunch *not* required since Sequoia for ScreenCaptureKit apps, but commonly still messaged), and (b) a periodic "still allow?" dialog if our capture path counts as "deprecated content capture technologies" or non-picker ScreenCaptureKit. Design onboarding copy for both, and a recovery flow for the "app moved after grant" failure mode (§1.4).

### 1.2 What exactly triggers the recurring nag — screenshots vs. video

- **[OBSERVED]** The nag is keyed to *capture technology*, not screenshot-vs-video intent. Deprecated CoreGraphics capture APIs (`CGWindowListCreateImage`, `CGDisplayStream`, etc.) trigger the recurring confirmation. Michael Tsai's roundup (Aug 8, 2024): https://mjtsai.com/blog/2024/08/08/sequoia-screen-recording-prompts-and-the-persistent-content-capture-entitlement/
- **[OBSERVED]** Apps that adopt **`SCContentSharingPicker`** (the system-drawn content picker, macOS 14+) are **exempt** from the recurring prompt, because the user picks content per-session through system UI — analogous to the iOS photo picker model. Same Tsai roundup; HN discussion: https://news.ycombinator.com/item?id=41598112
- **[CLAIM]** Programmatic ScreenCaptureKit calls that enumerate content (`SCShareableContent`) or capture without the picker — **including `SCScreenshotManager` in at least some configurations** — were reported to still generate the alert in Sequoia. (HN 41598112 commenters; Tsai roundup.) **Do not assume a screenshots-only app dodges the nag just by using ScreenCaptureKit.** The only documented full exemption is the picker UX, which is hostile to hotkey-driven instant capture.
- **[OBSERVED]** The **`com.apple.developer.persistent-content-capture`** entitlement suppresses recurring prompts but Apple's docs scope it to **VNC/remote-desktop apps** with a request form (doc updated Aug 21, 2024): https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.persistent-content-capture — a screenshot utility almost certainly won't get it. (Jump Desktop got it: https://support.jumpdesktop.com/hc/en-us/articles/29070118000781-macOS-Sequoia-Screen-Recording-Policies-and-Jump-Desktop-Connect )
- **Sequoia-era visual tell [OBSERVED via press/vendor docs]:** a purple/orange **menu-bar capture indicator** shows whenever any app captures the screen; it's system-drawn and non-suppressible. (Screenify guide, Apr 2026: https://www.screenify.studio/blog/2026-04-23-macos-screen-recording-permissions )

**Verdict on "screenshot apps dodge nags that recorders suffer":** **Not supported.** The TCC permission and the periodic re-auth treat still capture and video capture identically; what matters is (1) which API family, (2) picker vs. programmatic, (3) regular use (post-15.1). A v1 screenshots-only app benefits indirectly — no microphone/system-audio permissions, no long-lived capture sessions feeding the indicator — but it gets the same Screen Recording grant and the same periodic re-auth as recorders.

### 1.3 The plist mechanism & community workarounds (useful for support docs, not product)

- **[OBSERVED]** Approvals live in `~/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist`, keyed by **executable path** with a timestamp value. Writing a far-future date (e.g., year 3024) suppresses the nag per-app; requires logout/login; needs Full Disk Access for Terminal. Jeff Johnson (lapcatsoftware, Sep 21, 2024): https://lapcatsoftware.com/articles/2024/8/10.html
- **[OBSERVED]** Community automation exists: `screencapture-nag-remover` (https://github.com/luckman212/screencapture-nag-remover), discussed on HN: https://news.ycombinator.com/item?id=41598112
- **[CLAIM]** Because the plist keys on bundle path, renaming/moving the app re-triggers the prompt (HN 41598112). Some users even changed their system clock to dodge prompts (SimplyMac, 2024: https://www.simplymac.com/macos/users-are-changing-their-system-date-to-the-future-to-bypass-macos-sequoias-screen-recording-prompts ).
- `tccutil` has **no** command to manage this (only `reset`) — there is no sanctioned programmatic way for us to pre-grant or silence anything. [OBSERVED — man page behavior, noted by HN user NotPractical in https://news.ycombinator.com/item?id=41560228 ]

### 1.4 How incumbents handled/messaged it

- **CleanShot X [OBSERVED — changelog, https://cleanshot.com/changelog ]:** never shipped a "nag fix" (none exists to ship); entries are compatibility-level: 4.7.3 (Jul 2, 2024) "Fixed bug causing the screen to freeze when a screen capture alert appears on macOS Sequoia beta"; 4.7.4 (Sep 11, 2024) "Enhanced compatibility with macOS Sequoia". Apple's 15.1 fix was reported by press as covering CleanShot X (MacRumors above). CleanShot was the canonical example app in the community plist workaround (`defaults write … "/Applications/CleanShot X.app/Contents/MacOS/CleanShot X" -date "3024-…"`, HN 41598112).
- **Shottr [OBSERVED — vendor docs]:** FAQ documents the sharpest real-world failure mode: *"MacOS ties permission to an instance of the app that was running when you first granted the permission"* — moving Shottr (e.g., ~/Downloads → /Applications) strands the grant; users must delete the stale entry in System Settings → Privacy & Security → Screen Recording and re-add. https://shottr.cc/kb/faq . Changelog notes "more robust checking for Screen Recording permissions" (v1.9.x era). Privacy page confirms permission scope: Screen Recording to capture; **Accessibility only for Scrolling Capture** ("allows Shottr to scroll other apps"): https://shottr.cc/kb/privacy
- **Xnip:** no Sequoia-specific permission messaging found beyond generic grant instructions; no evidence of special handling. (Searched Jun 2026; absence noted, not proof.)
- **Apple's posture:** users assumed feedback resulted in the 15.1 fix; Jeff Johnson (developer, HN user *lapcat*): *"A lot of people complained by this, including the news media. I can guarantee it wasn't your bug report that spurred the change."* https://news.ycombinator.com/item?id=41560228

### 1.5 VOC — verbatim quotes about permission-nag pain (onboarding copy fodder)

- VOC: *"It's only a good thing if you can disable it, and you can't. I know which apps I granted permission, don't bug me about it. This is terrible UX design."* — mmcnl (https://news.ycombinator.com/item?id=41598112)
- VOC: *"All the permission grants are summarized in system preferences. Much more elegant to go do your own audit than have to respond to nag screens."* — CodeWriter23 (https://news.ycombinator.com/item?id=41598112)
- VOC: *"An opinionated OS only works if you agree with all the vendor's opinions."* — wkat4242 (https://news.ycombinator.com/item?id=41598112)
- VOC: *"It's especially frustrating since you always stumble upon it when you have something else in mind, [thus] your flow is broken to re-confirm something you did a month ago."* — mrtksn (https://news.ycombinator.com/item?id=41560228)
- VOC: *"Does it mean macOS will periodically ask me again and again that Teams/Zoom/etc need screen recording permissions? As if I didn't have enough pop-ups and prompts in my life already"* — isodev (https://news.ycombinator.com/item?id=41560228)
- VOC (dev): *"I've always been proud that xScope is a tool that sits quietly in the background, ready when you need it. So much for the 'quietly' part…"* — Craig Hockenberry (via https://mjtsai.com/blog/2024/08/08/sequoia-screen-recording-prompts-and-the-persistent-content-capture-entitlement/)
- VOC (dev/press): *"Worst decision Apple has made in years."* — Matthew Cassinelli (same Tsai roundup)
- Context piece: TidBITS, "macOS 15 Sequoia's Excessive Permissions Prompts Will Hurt Security" (Aug 12, 2024): https://tidbits.com/2024/08/12/macos-15-sequoias-excessive-permissions-prompts-will-hurt-security/ — alert-fatigue argument; useful framing for empathetic onboarding copy.

---

## 2. Capture APIs (sanctioned surface, minimums, performance)

### 2.1 API surface and deprecation timeline

- **ScreenCaptureKit (SCK)** — introduced **macOS 12.3** (2022). The sanctioned capture framework. [OBSERVED] https://developer.apple.com/documentation/screencapturekit/ ; WWDC22 "Meet ScreenCaptureKit": https://wwdcnotes.com/documentation/wwdcnotes/wwdc22-10156-meet-screencapturekit/
- **`SCScreenshotManager`** — still-image capture API, **macOS 14.0+**; replaces `CGWindowListCreateImage`; shares SCK's `SCContentFilter`/`SCStreamConfiguration`. [OBSERVED] https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager ; WWDC23 "What's new in ScreenCaptureKit": https://developer.apple.com/videos/play/wwdc2023/10136/ ; Nonstrict deep-dive (2023): https://nonstrict.eu/blog/2023/a-look-at-screencapturekit-on-macos-sonoma/
- **`SCContentSharingPicker`** — system picker UI, **macOS 14.0+**; the only path documented to be exempt from Sequoia's recurring re-auth (§1.2). [OBSERVED] https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker
- **`CGWindowListCreateImage` / legacy CG capture** — **deprecated macOS 14.0**, and marked **obsoleted in macOS 15.0**: building against the macOS 15 SDK with a 15.0 deployment target fails with *"'CGWindowListCreateImage' is unavailable: obsoleted in macOS 15.0 - Please use ScreenCaptureKit instead"*. [OBSERVED] MacPorts ticket #71136: https://trac.macports.org/ticket/71136 ; Apple dev forums: https://developer.apple.com/forums/thread/740493 ; JUCE breakage in 15.0: https://github.com/juce-framework/JUCE/issues/1414
- **HDR capture** — SCK gained HDR support at WWDC24 (macOS 15): https://developer.apple.com/videos/play/wwdc2024/10088/ [OBSERVED]
- **macOS 26 Tahoe** — no major new SCK screenshot API surfaced in WWDC25 coverage we could find (searched Jun 2026); Tahoe-era changes are mostly TCC-policy-side (§1.1). Check https://developer.apple.com/documentation/updates/screencapturekit before spec freeze (page wouldn't render to text in this pass). [GAP — verify in Xcode]

### 2.2 Minimum-macOS decision

- Incumbents' floor: **Shottr supports macOS 10.15+** [OBSERVED, https://shottr.cc/kb/faq : "Shottr runs on macOS Catalina (10.15) and up"]; CleanShot X historically similar (10.13/10.15-era floor). They achieve this by keeping legacy CG capture paths alive — which is exactly what now triggers Apple's "deprecated content capture technologies" nag policy (§1.2) and which can't even be *compiled* against modern SDKs without availability shims.
- **Defensibility of 13+/14+ in 2026:** Strong. (a) `SCScreenshotManager` — the only non-deprecated still-capture API — requires **14.0**; supporting 13 means writing an SCStream frame-grab fallback for one OS version. (b) macOS 14 shipped Sep 2023; by mid-2026 a 14+ floor covers three-going-on-four major releases (14, 15, 26), the standard support window for indie Mac utilities. (c) Every Apple Silicon Mac and all Intel Macs sold from ~2018 run 14. **Recommendation: target macOS 14.0+, single modern code path (SCScreenshotManager + SCK), zero deprecated-API liability.** [INFERENCE from OBSERVED API floors above]
- Risk note: nothing in Apple docs promises SCScreenshotManager (non-picker) escapes periodic re-auth (§1.2). Onboarding must still assume re-auth dialogs exist.

### 2.3 Accessibility (AXUIElement) needs

- **Scrolling capture**: requires the **Accessibility** TCC permission to synthesize scroll events in other apps — confirmed by Shottr's own privacy doc: Accessibility *"required only for the Scrolling Capture feature, which allows Shottr to scroll other apps while taking their screenshots."* [OBSERVED] https://shottr.cc/kb/privacy . CleanShot's scrolling capture similarly needs Accessibility (per Panaitiu's sandbox writeup, §4.3). Design implication: make Accessibility a **lazy, feature-gated permission** requested at first scrolling capture, never at onboarding.
- **Window detection/selection**: window enumeration for window-mode capture comes free with SCK (`SCShareableContent` window lists) under the Screen Recording grant; AX is *not* required for basic window capture. AX becomes relevant only for UI-element-level capture or window manipulation. [OBSERVED — SCK docs above; Shottr requires no AX for window capture per its privacy page]

### 2.4 OCR via Vision/VisionKit

- `VNRecognizeTextRequest` / `RecognizeTextRequest` (new Swift API): on-device text recognition; `supportedRecognitionLanguages` enumerates languages per revision. [OBSERVED] https://developer.apple.com/documentation/vision/vnrecognizetextrequest ; https://developer.apple.com/documentation/vision/recognizetextrequest
- **On-device guarantee**: Vision framework analysis runs entirely on-device (no network); this is a marketable privacy point for a local-first tool. [OBSERVED — Apple Vision docs: https://developer.apple.com/documentation/vision ]
- **Language coverage grows with OS version, not app version** — concrete evidence: CleanShot 4.8.4 (Oct 15, 2025): *"New OCR language support on macOS Tahoe — Czech, Danish, Dutch, Indonesian, Malay, Norwegian, Polish, Romanian, Swedish and Turkish"*; earlier CleanShot entry added Thai + Vietnamese (macOS 14-era). [OBSERVED] https://cleanshot.com/changelog . Baseline set (pre-2024, stable): English, French, Italian, German, Spanish, Portuguese, Chinese (Simpl./Trad.), Cantonese, Korean, Japanese, Russian, Ukrainian. Spec note: advertise "OCR languages depend on macOS version"; a 14+ floor gets ~14 languages, Tahoe ~24+.
- VisionKit `ImageAnalyzer` (Live Text) is the higher-level alternative; handles vertical East-Asian text better than raw Vision. [CLAIM — OCRmyPDF-AppleOCR notes: https://github.com/mkyt/OCRmyPDF-AppleOCR ]

### 2.5 Performance reference points

- **Shottr: "It takes only 17ms to grab a screenshot, and ~165ms to show it to you"** — verbatim from https://shottr.cc/ (fetched 2026-06-09). [CLAIM — vendor marketing, but the de facto speed bar reviewers quote.] Shottr also markets "tiny (2.3mb dmg) native app optimized for Apple Silicon" — size/native-ness is part of the same performance story.
- Spec target: capture-to-pixels-on-screen under ~200ms total; SCScreenshotManager single-frame capture on Apple Silicon is comfortably in this envelope [INFERENCE; benchmark during prototyping — no independent published SCK screenshot latency figures found].

---

## 3. Hotkey Takeover (⌘⇧3 / ⌘⇧4 / ⌘⇧5)

### 3.1 Why manual surrender is required

- The system screenshot shortcuts are **symbolic hotkeys** handled at the OS layer before app-level hotkey registrations; while macOS still binds them, a third-party `RegisterEventHotKey` registration for the same chord conflicts/loses — e.g., Maccy issue documenting that ⌘⇧-number chords get swallowed by the system screenshot handler: https://github.com/p0deje/Maccy/issues/1232 [OBSERVED — reproducible behavior]. Hence every app instructs users to **uncheck Apple's defaults** in System Settings → Keyboard → Keyboard Shortcuts → Screenshots first.
- There is **no public API** to toggle another symbolic hotkey. `tccutil`-style sanctioned control doesn't exist. The settings live in `~/Library/Preferences/com.apple.symbolichotkeys.plist` under `AppleSymbolicHotKeys` — screenshot-related IDs are **28** (save screen to file, ⌘⇧3), **29** (copy screen to clipboard), **30** (save selection), **31** (copy selection), **184** (Screenshot & recording options, ⌘⇧5). [OBSERVED — community plists/dotfiles: https://github.com/n0ts/macOS/blob/master/com.apple.symbolichotkeys.plist ; key-code reference: https://gist.github.com/jimratliff/227088cc936065598bedfd91c360334e ]
- A non-sandboxed app *can* technically rewrite that plist (`defaults write com.apple.symbolichotkeys …`) and force-apply with `/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u` [OBSERVED — Zameer Manji, Jun 2021 (pre-2024, but mechanism still referenced in current dotfiles): https://zameermanji.com/blog/2021/6/8/applying-com-apple-symbolichotkeys-changes-instantaneously/ ]. **No shipping screenshot app does this silently** — it uses a private framework, silently mutates user keyboard settings, and could break under future hardening. [ABSENCE OBSERVED in CleanShot/Shottr docs]
- Sequoia hardening note: macOS 15 began rejecting `RegisterEventHotKey` registrations whose only modifiers are Shift/Option (anti-keylogger change) — doesn't affect ⌘-based chords but constrains custom shortcut UIs. [OBSERVED] https://github.com/feedback-assistant/reports/issues/552 ; https://developer.apple.com/forums/thread/763878

### 3.2 State of the art in onboarding this friction

- **CleanShot X**: Settings → Shortcuts has a "**Use System Default Shortcuts**" button; choosing it **prompts the user to set CleanShot as the system screenshot tool** and walks them to System Settings to de-select Apple's bindings — guidance, not automation. [OBSERVED — third-party TIL doc: https://github.com/jbranchaud/til/blob/master/mac/use-default-screenshot-shortcuts-with-cleanshot-x.md ; https://ploegert.gitbook.io/til/os/mac/use-default-screenshot-shortcuts-with-cleanshot-x ] Default out-of-box CleanShot bindings avoid conflict instead (⌘⇧1 region, ⌘⇧2 window, etc.: https://www.pie-menu.com/shortcuts/cleanshot ).
- **Shottr/Xnip**: same pattern — docs tell users to uncheck the system shortcuts manually. No app found that automates the toggle. [ABSENCE OBSERVED, searched Jun 2026]
- **Best available smoothing — deep link:** System Settings supports `x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts` (Ventura+ System Settings), landing the user one click from the Screenshots pane. [OBSERVED — MacMost: https://macmost.com/creating-links-directly-to-system-settings.html ; pane-ID inventory: https://github.com/bvanpeski/SystemPreferences/blob/main/macos_preferencepanes-Ventura.md ] No deeper anchor to the Screenshots sub-section is documented — pair the deep link with an in-app screenshot/arrow overlay showing exactly which four checkboxes to clear.
- **Differentiator opportunity (design input):** (1) deep-link button + live detection — read `com.apple.symbolichotkeys.plist` (readable without TCC for non-sandboxed apps) to detect whether IDs 28–31/184 are still enabled and show a green check when the user has freed them; (2) offer a no-surrender default scheme (CleanShot-style ⌘⇧1/2) so the app works instantly pre-surrender; (3) optionally offer an "expert" one-click script path with explicit consent. Nobody ships (1) or (3) today. [INFERENCE from above]

---

## 4. Distribution Mechanics (direct, 2026)

### 4.1 Developer ID + notarization + Sequoia Gatekeeper

- Direct distribution requires an Apple Developer Program membership ($99/yr) → **Developer ID certificate**, **hardened runtime**, and **notarization** (notarytool). Notarized apps pass Gatekeeper cleanly. [OBSERVED] Apple, "Updates to runtime protection in macOS Sequoia" (Aug 2024): https://developer.apple.com/news/?id=saqachfa
- **Sequoia (15.0, Sep 2024) removed the Control-click "Open" override** for unsigned/un-notarized apps; users must now go to System Settings → Privacy & Security → "Open Anyway" per app. Apple's wording: software not signed correctly or notarized requires the Settings dance. [OBSERVED] same Apple dev news link; MacRumors: https://www.macrumors.com/2024/08/06/macos-sequoia-gatekeeper-security-change/ ; Tsai: https://mjtsai.com/blog/2024/07/05/sequoia-removes-gatekeeper-contextual-menu-override/
  - This is the change that hurts **Flameshot** (unsigned open-source builds) — every install now requires the multi-step override. For us: notarize from day one and this is a non-issue; it also raises the moat against unsigned freeware.
- **Tahoe 26 [CLAIM]**: no further Gatekeeper tightening found for notarized apps; TCC changes (§1.1) are the Tahoe story. Re-verify at 26.x point releases.

### 4.2 Auto-update norms

- **Sparkle 2** is the de facto standard updater for direct-distribution Mac apps (EdDSA-signed appcast feed over HTTPS; supports sandboxed apps via XPC). https://sparkle-project.org/ [OBSERVED — project docs; norm assertion is INFERENCE but uncontroversial: both CleanShot and Shottr self-update outside MAS]. Spec: ship Sparkle 2 + appcast from day one; notarize every update (Gatekeeper checks updates too).

### 4.3 Homebrew cask

- **Shottr is in homebrew/cask** (`brew install --cask shottr`, v1.9.1 at fetch time; Shottr's own homepage advertises `$ brew install shottr`). [OBSERVED] https://formulae.brew.sh/cask/shottr ; https://shottr.cc/
- **CleanShot also has a cask** (`cleanshot`, 4.8.8). [OBSERVED] https://formulae.brew.sh/cask/cleanshot
- Listing requirements are mechanical (stable download URL, sha256, real version); casks auto-bump. Treat `brew install --cask <us>` as a launch-week deliverable — it's how the Shottr-style technical audience installs.

### 4.4 Why neither incumbent is on the Mac App Store (verified, not assumed)

- MAS requires the **App Sandbox**. The sandbox **prohibits**: Accessibility permission use (global event synthesis — kills scrolling capture and keystroke overlays), audio loopback/driver installation (kills system-audio recording), Input Monitoring, arbitrary Full Disk Access, and private-framework calls. Documented app-by-app (including **CleanShot X explicitly**: "screen recording features requiring audio loopback, input monitoring, and accessibility permissions") by Alin Panaitiu, "Why aren't the most useful Mac apps on the App Store?" (Dec 3, 2021 — **pre-2024 but the sandbox rules are unchanged**): https://alinpanaitiu.com/blog/apps-outside-app-store/ [OBSERVED — dev writeup corroborated by Apple sandbox docs: https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox ]
- Nuance for v1 scope: plain SCK screenshot capture *is* possible sandboxed (sandboxed MAS recorders exist). The MAS-blocking features for a CleanShot/Shottr-class tool are **scrolling capture (AX)**, system-audio recording, tight Finder/file workflows, and **free-trial/licensing flexibility** (no real trials on MAS; Panaitiu above). So MAS isn't impossible for a gutted v1 — it's impossible for the product we're speccing. Distribution decision: **direct-first**, MAS optional later as a feature-reduced SKU (what Lunar does with a "lite" build, per Panaitiu).

---

## 5. Channel Economics (feeds pricing)

### 5.1 Setapp (MacPaw) — subscription pool model

- **Published rev-share [OBSERVED — Setapp docs]:** 70% of each user's subscription fee is split among the developers of apps that user *opened* during the billing cycle, weighted by per-app **price-tier multipliers** (tiers ~1–20); binary usage, not intensity: *"We do not take into account the number of usages of a particular app per month. The terms of revenue distribution are equal for apps used only once and for apps used every day."* Formula: `(70% of user fee) × (your multiplier ÷ Σ multipliers of all apps the user opened)`. Plus a **Partner Program +20%** of revenue from users you yourself bring (total cap ≈90%). Payouts processed at the start of each month; final reconciliation up to 28 days. https://docs.setapp.com/docs/distributing-revenue ; https://docs.setapp.com/docs/about-partner-program ; https://docs.setapp.com/docs/setapp-membership-revenue
- **Economic read for a screenshot tool:** Setapp's pool punishes cheap, frequently-co-used utilities — a $8–12 one-time-price app sits in a low tier and shares each subscriber's 70% with every other app they touched that month. This matches the Shottr dev's stated reason for declining Setapp — that joining would force him to *"hike the app price significantly"* [CLAIM — per our JTBD/market-research file; **primary source not re-located in this pass** (searched HN Algolia + web, Jun 2026); treat as community-reported until the original Reddit/Twitter comment is pinned]. CleanShot, priced at $29+ with subscription cloud, fits the model and is one of Setapp's flagship apps: https://setapp.com/apps/cleanshot
- **Setapp Marketplace (Mar 3, 2026) [OBSERVED — press]:** Setapp now sells **single apps** — one-time lifetime licenses or per-app subscriptions (1/3/6/12-month) — without the all-apps membership; 70+ apps participating at launch. 9to5Mac: https://9to5mac.com/2026/03/03/setapp-now-lets-users-buy-or-subscribe-to-select-apps-individually/ ; MacPaw PR: https://www.prnewswire.com/news-releases/macpaw-launches-new-purchase-options-on-setapp-introducing-single-app-purchases-and-subscription-plans-302700175.html ; marketplace: https://app.setapp.com/marketplace . **The developer rev-share % for Marketplace single-app sales is not published** in Setapp's public docs as of Jun 2026 [GAP — ask Setapp directly if this channel matters]. Strategically: Marketplace makes Setapp viable as a *secondary storefront* even for one-time-purchase pricing — the objection Shottr's dev had applies to the pool model, not necessarily to Marketplace.

### 5.2 Merchant-of-record: Paddle vs FastSpring

- **CleanShot uses Paddle** [OBSERVED — checkout flow / long-standing]; **Shottr uses FastSpring** [OBSERVED — Shottr's own FAQ tells VAT-invoice questions to "reach out to [FastSpring]" : https://shottr.cc/kb/faq ].
- **Paddle**: published flat **5% + $0.50 per transaction**, all-inclusive MoR (global sales tax/VAT remittance, fraud, billing). [OBSERVED] https://www.paddle.com/compare/fastspring ; corroborated: https://lumscope.com/reviews/paddle/ (2025)
- **FastSpring**: **no public rate card**; negotiated, typically quoted ~5–8% (standard rate often cited ≈8.9%). [CLAIM — competitor and third-party sources: Paddle's comparison page above; Fungies MoR pricing guide 2026: https://fungies.io/merchant-of-record-pricing-guide-2026/ ; Dodo Payments roundup: https://dodopayments.com/blogs/paddle-alternatives ]
- Pricing-model input: on a $12 one-time sale, Paddle ≈ $1.10 (9.2%); on $29 ≈ $1.95 (6.7%) — MoR overhead falls as price rises, mildly favoring CleanShot-style price points; either way MoR ≪ Setapp pool dilution and ≪ MAS 15–30%.

---

## 6. URL Scheme / Automation Surface

### 6.1 Incumbent precedent (the integration bar we must meet)

- **CleanShot X** — `cleanshot://` URL-scheme API (introduced v3.8.1, Jul 15, 2021; pre-2024 but actively maintained — 4.8.6, Dec 4, 2025 fixed "broken Raycast extension and incorrect handling of the URL Scheme API permissions"). Commands: `capture-area`, `capture-fullscreen`, `capture-window`, `capture-previous-area`, `self-timer`, `scrolling-capture`, `all-in-one`, `capture-text` (OCR), `pin`, `open-annotate`, `open-from-clipboard`, `record-screen`, `open-history`, `open-settings`, `toggle-desktop-icons`, `add-quick-access-overlay`; params `x,y,width,height,display,action(copy/save/annotate/upload/pin)`, file paths. [OBSERVED] https://cleanshot.com/docs/api ; changelog: https://cleanshot.com/changelog
- **Shottr** — URL schemes since v1.8 (2024), gated behind an opt-in "URL Schema API" setting: `shottr://show`, `shottr://grab/fullscreen|area|repeat|window|scrolling|scrolling/reverse|delayed[=N]|append`, `shottr://ocr`. Official Raycast extension + Alfred workflow are built on it. [OBSERVED] https://shottr.cc/kb/urlschemes ; Raycast extension PR: https://github.com/raycast/extensions/pull/14750 ; AlternativeTo coverage of 1.8 (Oct 2024): https://alternativeto.net/news/2024/10/screenshot-app-shottr-1-8-brings-new-backdrop-tool-raycast-and-alfred-integration-and-more/
- Note Shottr's security touch: URL scheme is **off by default**, enabled in settings — a sensible default we should copy (CleanShot's Dec 2025 fix suggests they retro-fitted permissioning).

### 6.2 What's expected in the Tahoe era

- **App Intents is now first-class on macOS:** Tahoe's Spotlight runs app **actions** directly (Apple: "hundreds of actions… developers can surface even more using the App Intents API"), with parameterized intents callable from Spotlight, Shortcuts, and Apple Intelligence. [OBSERVED] Apple Newsroom (Jun 2025): https://www.apple.com/newsroom/2025/06/macos-tahoe-26-makes-the-mac-more-capable-productive-and-intelligent-than-ever/ ; WWDC25 "Develop for Shortcuts and Spotlight with App Intents": https://developer.apple.com/videos/play/wwdc2025/260/ ; 9to5Mac: https://9to5mac.com/2025/06/10/macos-26-spotlight-gets-actions-clipboard-manager-custom-shortcuts/
- Neither incumbent ships real AppIntents/Shortcuts actions (their integrations are URL-scheme-only) [ABSENCE OBSERVED — no Shortcuts actions documented for either as of Jun 2026]. **Spec recommendation:** ship both layers — (1) a `ourapp://` URL scheme mirroring the CleanShot command set (Raycast/Alfred compatibility costs ~nothing once actions exist), and (2) native **AppIntents** for capture-area/capture-window/capture-fullscreen/OCR-to-clipboard, which get Spotlight actions, Shortcuts, and future Apple-Intelligence invocation for free on 26+. Targeting macOS 14+ keeps full AppIntents availability (framework is 13+; Spotlight-actions surfacing is a 26 feature).
- Shortcuts itself is URL-callable (`shortcuts://run-shortcut?name=…`) for round-trip workflows: https://support.apple.com/guide/shortcuts-mac/run-a-shortcut-from-a-url-apd624386f42/mac [OBSERVED]

---

## Synthesis: hard constraints → spec/onboarding decisions

1. **Permission UX is a designable moment, not avoidable plumbing.** One Screen Recording grant (no relaunch needed on 14+ with SCK), periodic re-auth dialogs that we cannot suppress (no entitlement path for us), and a path-sensitivity gotcha (move-after-grant). Onboarding must: install to /Applications before requesting the grant (kills the Shottr FAQ failure mode), explain the "Allow For One Month"-style dialog *before* macOS shows it, and include a permission-health check screen.
2. **Screenshots-only does NOT exempt us from the re-auth regime** — but it does exempt us from microphone/system-audio permissions and minimizes capture-indicator exposure; message v1 as "one permission, ever."
3. **Target macOS 14+** and build exclusively on SCScreenshotManager/SCK: zero deprecated-API code, the exact APIs Apple's nag policy favors, smallest possible TCC surface. Accessibility only lazily, for scrolling capture.
4. **Hotkey surrender can't be automated safely, but it can be 10x better-guided:** deep link `x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts` + live read of `com.apple.symbolichotkeys` (IDs 28–31, 184) to show a real-time "shortcuts freed ✓" check — nobody does this today.
5. **Distribution:** Developer ID + hardened runtime + notarization is mandatory in practice post-Sequoia (Control-click bypass removed 15.0); Sparkle 2 + Homebrew cask at launch; MAS structurally excluded for the full product (sandbox vs. AX/trials), matching both incumbents.
6. **Pricing channels:** direct via Paddle (5% + $0.50, published) beats FastSpring's opaque ~5–8.9%; Setapp's 70%-pool model dilutes low-priced utilities (the Shottr objection), but the Mar 2026 Setapp Marketplace (single-app lifetime/subscription sales) reopens Setapp as a secondary storefront — rev-share for Marketplace unpublished, ask directly.
7. **Automation:** URL scheme (off-by-default toggle) + native AppIntents from v1 — AppIntents is the Tahoe-era differentiator neither incumbent has, and Spotlight-actions surfacing makes it visible.

## Open gaps / verify before spec freeze

- Whether non-picker `SCScreenshotManager` capture triggers the periodic re-auth on current 15.x/26.x builds — conflicting 2024 reports; **empirically test on 15.7 and 26.x hardware** (1-day spike).
- Exact Tahoe 26.x re-auth cadence for regularly-used GUI screenshot apps (community signal says relaxed-15.1 policy persists; no Apple doc states it).
- Primary source for the Shottr-dev Setapp quote ("hike the app price significantly") — not re-located; pin the Reddit/HN/Twitter original before citing externally.
- Setapp Marketplace developer rev-share % — unpublished; requires direct outreach.
- ScreenCaptureKit "updates" page contents for macOS 26 additions (page didn't render to text; check in Xcode 26 SDK diffs).
