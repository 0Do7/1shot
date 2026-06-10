# Jobs-to-be-Done & Real Usage Workflows — Mac Screenshot Tools
**Vein:** How people actually USE screenshot tools, where friction remains, and untapped potential
**Date:** 2026-06-09 | Researcher: subagent (JTBD vein)
**Tagging:** [OBSERVED] = seen on official page/changelog/primary artifact; [CLAIM] = reviewer/commenter said it; VOC = verbatim user quote.

---

## Executive summary

1. The single highest-frequency job is **"explain something visually to another person in under 10 seconds"** — capture → annotate (arrow/box/redact) → paste into Slack/Jira/GitHub. Annotation *speed* (not richness) is the decisive feature. One HN user: ~99% of his bug tickets carry a CleanShot screenshot.
2. The fastest-growing NEW job since 2024 is **screenshot-as-LLM-input**: pasting UI bugs, Figma frames, stack traces into ChatGPT/Claude/Cursor/Claude Code. No incumbent owns this destination yet.
3. **OCR is a daily-driver job, not a nice-to-have** — devs OCR error text out of Slack-posted screenshots, code from videos, IDs from family chat. Shottr users describe a 3-keystroke OCR habit used many times a day.
4. **Pin/float-to-screen** is an underrated "reference while working" job (data entry, copying between apps, standup notes) with a dedicated paid app (ScreenFloat) surviving on it alone.
5. **Beautification for social/marketing** is a validated, separately-monetized job (Xnapper, Pika, Shots.so, plus ~7 free web clones) that CleanShot absorbed via its Background tool — strong candidate for table stakes + premium presets.
6. **Clutter/organization is the great unsolved pain.** People bolt on Hazel rules, Dropbox folders, even custom S3 pipelines. On iOS an entire category of "AI screenshot organizer" apps (Captr, SnapSort, ScreenshotAI, SnapStash) has emerged — clear demand signal with no strong Mac-desktop equivalent.
7. The aspirational layer with real (not speculative) demand signals: **semantic/OCR search over screenshot history** (Rewind.ai, ScreenMemory, irchiver, the iOS organizer wave) and **auto-redaction of PII/API keys** (BlurData, PageRedact, FramedShot ecosystem exists already).
8. Power users glue screenshot tools into **Raycast (official CleanShot extension w/ deeplinks), Alfred workflows, Hazel, Shortcuts, and custom launchd scripts** — URL-scheme/CLI automation surface is a cheap, high-leverage feature.

---

## JOB 1 — Bug reporting & QA ("make the issue obvious before anyone asks")

**Trigger:** dev/PM/QA spots broken UI or behavior.
**Workflow:** hotkey area/window capture → Quick Access Overlay → arrows, boxes, numbered steps, redact → copy or cloud link → paste into Jira / Linear / GitHub issue / Slack.
**Destinations observed:** Jira, Linear, GitHub, Slack, internal ticketing.

- VOC: *"CleanShotX's tools are about 1 billion times faster/easier to use [than macOS Markup]. I use this tool all the time just to take a quick screenshot, add some arrows/circles/text/numbers and send it off… **I'd say about 99% of bug tickets I enter into our ticketing tool have a CleanShotX screenshot attached (or video).**"* — joshstrange, HN, 2025-11 (https://news.ycombinator.com/item?id=45826010)
- VOC: *"CleanShot X is extremely good, in case anyone is looking for more endorsements."* — tptacek, HN, 2025-11 (https://news.ycombinator.com/item?id=45826157)
- VOC: *"Get a screenshot app. Shottr is awesome. CMD+SHIFT+CTRL+4 and I can take a picture. **Paste UI on a GitHub PR. Paste Figma into a LLM. Paste bugs into Slack or a support tool.**"* — muzani, HN, 2025-08 (https://news.ycombinator.com/item?id=44795542)
- [CLAIM] Marker.io's Jira guide codifies the norm: find bug → screenshot → annotate (highlight problem area, arrow, blur private data) → paste into Jira; "a well-annotated screenshot answers questions before they're asked" (https://marker.io/blog/jira-bug-tracking).
- [OBSERVED] An entire adjacent-tool category exists to compress this loop (Usersnap "Capture for Jira", SaaSJet Issue Creator for Jira, Gleap → Jira with session metadata) (https://usersnap.com/l/capture-for-jira, https://saasjet.com/issue-creator-for-jira-cloud/, https://www.gleap.io/blog/issue-tracking-with-gleap-jira-a-brilliant-combination-for-the-perfect-bug-reporting-workflow) — evidence the generic screenshot tool still leaves friction at the *ticket-creation* step (metadata, env info, auto-attach).

**Features serving it:** instant annotate overlay, numbered-step stamps, blur/redact, copy-to-clipboard default, cloud link (CleanShot), capture history.
**Residual friction:** ticket metadata (browser, URL, OS) isn't carried with the image; multi-screenshot bugs need manual stitching/combining; cloud links require a subscription (CleanShot Cloud — VOC: *"Honestly the cloud hosting aspect is overpriced"* — joshstrange, same HN link above).

---

## JOB 2 — Screenshot → LLM (the new 2024+ job: "show the AI, don't tell it")

**Trigger:** dev wants AI to fix a visual bug, build from a design, or read an error.
**Workflow:** capture region → image lands on clipboard → Cmd+V into Claude Code / Cursor / ChatGPT → prompt.
**Destinations:** Claude Code, Cursor, ChatGPT, Raycast AI.

- VOC: *"Paste Figma into a LLM."* — muzani, HN, 2025-08 (https://news.ycombinator.com/item?id=44795542)
- [CLAIM] "Screenshots of misaligned components communicate more than five paragraphs of description… the bottleneck in this workflow isn't the AI model — it's the screenshot capture and paste step. Context switching kills focus." (https://www.lazyscreenshots.com/blog/visual-debugging-ai-screenshots/, 2026)
- [OBSERVED] Claude Code supports Cmd+V image paste; a GitHub issue tracks clipboard-paste support in the CLI (https://github.com/anthropics/claude-code/issues/12644); how-to posts proliferate (https://amanhimself.dev/blog/using-images-in-claude-code/).
- [OBSERVED] CleanShot X added "send screenshots to Raycast AI Chat from Annotate or the Quick Access Overlay" — incumbents are starting to treat AI chat as a *destination* (https://www.raycast.com/resources/how-to-screenshot-on-mac).
- Demand-signal for "personal AI rebuilds": VOC: *"In the last few months I've used Claude Code to build personalized versions of Superwhisper, CleanShot X, and TextSniper."* — LatencyKills, HN, 2026-01 (https://news.ycombinator.com/item?id=46515882) — the moat is polish + workflow depth, not any single feature.

**Untapped:** a first-class "send to AI" destination (configurable: Claude Code terminal, ChatGPT, local model), screenshot + OCR text + source-app metadata bundled as one paste payload.

---

## JOB 3 — Knowledge capture & OCR into notes ("steal the text back")

**Trigger:** text is visible but not selectable — Slack-posted screenshots, video lectures, PDFs, DRM'd pages, error dialogs, IDs sent by family.
**Workflow:** hotkey → drag region → OCR → text on clipboard → paste into VS Code / Google / Obsidian / Notion.

- VOC: *"I have Shottr keyboard shortcut (cmd+opt+control+o) setup to allow me to OCR from whatever is on the screen… **So whether someone shares code or error log as screenshot on slack, it's 3 steps:** 1. cmd+opt+control+o 2. select the area to OCR 3. cmd+v in vscode or google"* — alyyousuf7, HN, 2025-11 (https://news.ycombinator.com/item?id=45883631)
- VOC: *"when I want to select unselectable text I just do OCR with a simple and fast shortcut"* — danielfalbo, HN, 2025-09 (https://news.ycombinator.com/item?id=45385811)
- VOC: *"It does text recognition too, so whenever my wife sends me some kind of ID via a screenshot, I can just copy from that."* — muzani, HN, 2025-08 (https://news.ycombinator.com/item?id=44795542)
- VOC: *"I use Shottr on my MacBook to immediately OCR my screenshots"* — lumirth, HN, 2025-12 (https://news.ycombinator.com/item?id=46265479)
- VOC: *"OCR tools like this are extremely useful when dealing with excerpting text from certain websites (slack) or taking class notes from video."* — seltzered_, HN, 2022-11 (https://news.ycombinator.com/item?id=33706155) *(pre-2024, but corroborated by the 2025 quotes above)*
- [OBSERVED] Screenotate (macOS/Windows) is a whole product built on this job: every screenshot is OCR'd and saved **with the URL and window title of where it was taken** (https://screenotate.com/ via https://news.ycombinator.com/item?id=34430018) — provenance metadata is the differentiating idea.
- [CLAIM] Obsidian users paste screenshots into vaults and worry about storage bloat; no smooth screenshot→note pipeline exists ("raw screenshots will take up too much storage" — ZJun, https://forum.obsidian.md/t/workflow-about-screenshots/33764).
- [CLAIM] TextSniper "pays for itself within a day" for heavy OCR users (https://www.screensnap.pro/blog/best-ocr-software-mac, 2026).

**Residual friction:** OCR output loses formatting (code indentation, tables); no automatic link back to source app/URL (except Screenotate); nothing routes OCR text into Notion/Obsidian automatically.

---

## JOB 4 — Documentation, tutorials & blog posts ("the six-step treadmill")

**Trigger:** writing a KB article, README, tutorial, release notes.
**Workflow:** capture window (clean background, hidden desktop icons) → annotate with numbered steps → consistent padding/border → export → rename → move to assets folder → insert in doc. Repeat 20×.

- [CLAIM] "The reason most documentation has bad screenshots is that the workflow is tedious: capture, switch to an annotation tool, annotate, export, rename the file, move it to the right folder, then insert it into your doc — **six steps and at least three app switches per screenshot.**" (https://www.lazyscreenshots.com/blog/professional-screenshots-documentation-tutorials/, 2026)
- [CLAIM] Re-editable annotations are "a lifesaver" for doc maintenance — Snagit and CleanShot X let you save and re-edit annotations later; keeping screenshots up to date after UI changes is the #1 maintenance pain (https://www.shotomatic.com/blog/best-screenshot-automation-tool, 2026). Shotomatic exists purely to *re-take* doc screenshots automatically — demand signal for "screenshot refresh."
- [OBSERVED] CleanShot features built for this job: hide desktop icons, window capture with/without background, self-timer, scrolling capture, "combine screenshots" (https://cleanshot.com/features).
- VOC (multi-tool reality): Adam Engst (TidBITS, 2026-01) uses *multiple* utilities — ScreenFloat for floating reference + border-on-export, CleanShot X to "combine screenshots," and built-in macOS capture for menu-with-shadow shots that still require "a multi-step process… compositing them in Preview" (via https://mjtsai.com/blog/2026/01/12/mac-screenshot-utilities/; original: https://tidbits.com/2026/01/05/why-i-use-multiple-screenshot-utilities-on-the-mac/).
- VOC: *"Snagit's cross-platform muscle and slightly more mature editor workflow (especially for step tools and batch processing) often wins out when building large sets of documentation"* [CLAIM] (https://www.shotomatic.com/blog/best-screenshot-automation-tool).

**Untapped:** project-scoped capture presets (naming pattern + save folder + annotation style per project); re-editable annotation files; batch consistency (same padding/border/scale across a doc set); detect-and-retake stale screenshots.

---

## JOB 5 — Design feedback & pixel inspection ("for those who care about pixels")

**Trigger:** design QA against Figma; checking spacing/colors on a live build; async design review.
**Workflow A (inspection):** capture → zoom → ruler/measure px distances → color-pick → compare with spec.
**Workflow B (feedback):** capture live UI → annotate → drop into Figma/Slack thread.

- [OBSERVED] Shottr explicitly markets to "designers, front-end engineers, mobile developers… those who care about pixels": screen ruler, color picker (multiple formats), magnifier, pinned screenshots, "only 17ms to grab a screenshot" (https://shottr.cc/).
- [OBSERVED] CleanShot pairs with PixelSnap for measurement (https://cleanshot.com/features).
- VOC: *"Preview has tons of useful features like crop, annotations, color picker, ruler, OCR"* (on Shottr) — Leftium, HN, 2026-03 (https://news.ycombinator.com/item?id=47447633)
- [OBSERVED] Adjacent category handles the in-context part: BugHerd (click element on live site → task), OverlayQA (capture CSS properties + design-vs-implementation diff) (https://bugherd.com/blog/best-design-feedback-tools, https://overlayqa.com/blog/visual-feedback-tools/). Generic screenshot tools lose the *element/CSS context* that these capture.

**Residual friction:** measured values (px, hex) don't flow anywhere — you read them off the screen and retype; no Figma destination integration in CleanShot/Shottr.

---

## JOB 6 — Social content & screenshot beautification ("make it look shippable")

**Trigger:** indie hacker / marketer posting product shots, tweets, code, or launch images.
**Workflow:** capture → auto-balance padding → gradient/backdrop, rounded corners, shadow, device/browser frame → export sized for X/LinkedIn/Instagram.

- [OBSERVED] Dedicated paid tools: Xnapper ("beautiful screenshots for marketing/social media" — VOC by ZeroTalent listing his Mac setup, HN 2024-06, https://news.ycombinator.com/item?id=40634341), Pika ("beautify marketing screenshots… increase reach and engagement", https://pika.style/use-cases), Shots.so, TweetPik, TwitterShots; plus ≥7 free web clones (screenzy.io, screenshot.rocks, fabpic.app, codeimage.dev…) listed by a user challenging a paid product (https://news.ycombinator.com/item?id=40085522) — heavy commoditization at the low end.
- [OBSERVED] CleanShot absorbed the job: Background tool — "Create beautiful social media posts," padding, alignment, "Magical Auto Balance" (https://cleanshot.com/features). VOC: *"the background feature was copied 1:1 from Xnapper"* — anconam, HN, 2023-09 (https://news.ycombinator.com/item?id=37635281); VOC: *"Clean shot is exactly like xnapper but better in every single aspect"* — bdlowery, 2023-09 (https://news.ycombinator.com/item?id=37624690).
- Cautionary VOC on niche tools' QA: *"Aesthetics is the purpose of buying the product, otherwise non-aesthetic screenshots are built into macOS… There was no bug fix."* — unsupp0rted re: Xnapper arrow/crop bug, HN 2023-09 (https://news.ycombinator.com/item?id=37623214) → polish/support is the wedge.
- Shottr also added "gradients backgrounds, shadows and rounded corners" [OBSERVED] (https://shottr.cc/).

**Untapped:** saved brand presets (already Xnapper's "core feature" per its founder, https://news.ycombinator.com/item?id=41564648); per-platform export sizes; video beautification (VOC: *"Xnapper is really cool. Anything similar but for videos?"* — guzik, HN 2023-09, https://news.ycombinator.com/item?id=37627362 — v2 note).

---

## JOB 7 — Customer support ("answer with a picture, close the ticket")

**Trigger:** support agent must explain steps or confirm a bug from a customer.
**Workflow:** capture → annotate (arrows, "steps", blur customer PII) → upload → paste link in Zendesk/Intercom/Help Scout macro; reuse hosted images across saved replies.

- [CLAIM] "Support agents often find that a quick annotated screenshot or a 5-second GIF is faster and clearer than a full video response" (https://zight.com/blog/screen-recorder-for-customer-support/).
- [CLAIM] Teams using visual replies report "up to 67% fewer follow-up messages per ticket" (https://jam.dev/blog/screen-recording-tools-for-modern-customer-support-teams).
- [OBSERVED] Screendesk/ScreenPal exist as helpdesk-native capture integrations (Zendesk, Intercom, Freshdesk, Help Scout) (https://screendesk.io/, https://screenpal.com/integrations/zendesk).
- Blur-customer-data is non-negotiable here; image *reuse/organization* ("upload images to content hosting to organize and reuse them") matters more than in dev jobs.

**Note for v1 (local-first):** the cloud-link half of this job is deferred to v2, but annotate-and-attach (file/clipboard) still works locally; support teams are a weaker v1 ICP.

---

## JOB 8 — Reference-while-working: pin/float ("picture-in-picture for screenshots")

**Trigger:** need info from one window while typing in another (form filling, coding against an example, copying figures, standup notes).
**Workflow:** capture → pin as floating always-on-top window → work → discard.

- [OBSERVED] ScreenFloat is a whole paid app on this job: float above all windows, pin to Spaces or to a specific app, drag into other apps, double-click workflows (de-retinize + crop + annotate in one action) (https://www.screenfloatapp.com/, https://www.macstories.net/reviews/screenfloat-2-0-floating-reference-screenshots-and-management-from-the-macs-menu-bar/).
- [OBSERVED] Both CleanShot ("Pin any screenshot to the screen," opacity, Lock Mode — https://cleanshot.com/features) and Shottr ("floating always-on top borderless windows" — https://shottr.cc/) ship it.
- VOC: *"Shottr/Cleanshot — For markup and **pinning info on the screen**"* — wingerlang's setup list, HN 2024-06 (https://news.ycombinator.com/item?id=40631174).

---

## JOB 9 — Compliance, receipts & evidence (thin but real)

**Trigger:** preserve proof — order confirmations, payment records, chat agreements, disappearing web content.
- [OBSERVED] CleanShot Cloud offers "self destruct" timers and password-protected links, marketed for "sensitive client work" (https://cleanshot.com/features; https://daveswift.com/cleanshot-x/) — privacy controls, the inverse of retention.
- VOC (personal web archive motivation): *"the web is not as permanent as it used to be… I wanted a way to have a screenshot-based 'archive.org' but for yourself, so that it works with non-public content too."* — lazyjeff (irchiver author), HN 2023-07 (https://news.ycombinator.com/item?id=36881708).
- Scrolling capture serves this job (capture a full conversation/page as one artifact) [OBSERVED on Shottr: "long web page or capture conversation," https://shottr.cc/].
- **Evidence strength: weak/indirect** — no strong VOC of Mac users hiring CleanShot/Shottr specifically for compliance. Treat as a long-tail benefit (timestamped filenames, scrolling capture, history retention), not a marquee job.

---

## POWER-USER ECOSYSTEM — automation, launchers, glue

- **Raycast:** official CleanShot X extension — trigger Capture Area/Window/Fullscreen/Scrolling, "Open History," browse "entire screenshot history without leaving Raycast"; built on CleanShot's URL-scheme deeplinks [OBSERVED] (https://github.com/raycast/extensions/tree/3a28a53bf10eb44eee9f664ee9d40ece08974fad/extensions/cleanshotx, https://www.raycast.com/resources/how-to-screenshot-on-mac). CleanShot also pipes captures into Raycast AI Chat [OBSERVED]. **Implication: a documented URL scheme / CLI is a cheap feature that buys an ecosystem.**
- **Alfred:** community CleanShot X workflow on the Alfred forum (https://www.alfredforum.com/topic/16960-cleanshot-x-workflow/) [OBSERVED].
- **Hazel:** the canonical fix for screenshot clutter — "If Name matches pattern Screen Shot * → Move to ~/Pictures/Screenshots/, rename with date"; users key rules off "CleanShot" in the filename (https://www.asianefficiency.com/technology/hazel-intro/, https://jennifermack.net/2015/02/04/screenshot-workflow-with-hazel/ [2015 — stale but the pattern persists in 2026 guides]).
- **Custom pipelines:** VOC: *"dump to s3 so I can paste around links to screenshots everywhere for work — This has got to be the 'todo list app' for people who aren't app devs; mine is for MacOS + launchd + hammerspoon and **I use Shottr for annotation**"* — philsnow, HN 2026-01 (https://news.ycombinator.com/item?id=46817644; repo: https://github.com/philsnow/shots-filed). People hand-roll the cloud half and keep the capture/annotate half — supports local-first v1 + bring-your-own-destination hooks.
- **ScreenFloat double-click workflows** run AppleScripts/Siri Shortcuts on a shot [OBSERVED] (https://blog.eternalstorms.at/2024/01/17/get-to-know-screenfloat-2-part-i-an-overview/) — precedent for Shortcuts actions as power feature.
- Frequency anchor: VOC: *"I bought Shottr because it's a convenience app and **I use it hundreds of times per day** and I save a tremendous amount of time and clicks… it's $8 once and does a LOT"* — shinycode, HN 2024-09 (https://news.ycombinator.com/item?id=41699263).

---

## THE ORGANIZATION/CLUTTER PAIN (unsolved on desktop)

- Default behavior dumps screenshots on the Desktop; the fix today is external automation (Hazel/Dropbox). VOC: *"If one uses Dropbox too, letting Dropbox manage screenshots is a clean way"* — Brajeshwar, HN 2022-06 (https://news.ycombinator.com/item?id=31773850).
- Ask-HN demand: *"What is your software pipeline to manage screenshots? If we could: bucket and tag, turn them to tasks, follow ups"* — erbdex, 2022-07 (https://news.ycombinator.com/item?id=32220815).
- [OBSERVED] CleanShot's answer is partial: 1-month capture history with type filtering + cloud tags (https://cleanshot.com/features). No local tagging/search of the archive.
- **iOS proves the demand at scale:** a whole app category — Captr ("AI… recognizes recipe/product/idea/document and sorts it"), SnapSort, ScreenshotAI (fabric.so), SnapStash, ScreenshotSearch ("100% on-device… library into a searchable database") (https://captr.app/blog/how-to-organize-iphone-screenshots, https://fabric.so/screenshot-ai, https://www.snapstash.app/, https://apps.apple.com/us/app/screenshot-search-chat/id6756539898). [CLAIM] "average smartphone user takes over 20 screenshots per week… more than 1,000 per year" (https://letitsorti.com/journal/best-app-to-organize-screenshots-iphone-android). No incumbent Mac screenshot tool does this.

---

## ASPIRATIONAL LAYER — what people wish screenshots could do (with demand evidence)

1. **Search everything I've ever captured (OCR/semantic).** Rewind.ai built a company on continuous capture + OCR index — VOC: *"takes screenshots continuously and uses mac's system OCR to index everything you've ever looked at… When you search it pulls up screenshots that match."* — jazzyjackson, HN 2023-07 (https://news.ycombinator.com/item?id=36870500). Personal builds exist: VOC: *"ScreenMemory — It's similar to Rewind/Recall (but without AI), I revisit days before standups and retrospectives"* — wingerlang, HN 2024-06 (https://news.ycombinator.com/item?id=40631174). Plus the iOS organizer wave above. **A local, on-device searchable screenshot library is the most evidenced unmet wish.**
2. **Auto-redaction of PII/API keys.** Tool ecosystem already monetizing it: BlurData ("drop screenshots… sensitive data is detected and highlighted in seconds… 100% offline, GDPR & HIPAA-ready", https://blurdata.app/), PageRedact ("auto-detects emails, phone numbers, IBANs, credit cards, and API keys"), FramedShot guides specifically for "Redact API keys… in screenshots" (https://framed-shot.com/guides/redact-api-keys-screenshots/), Scribe Smart Blur (https://scribe.com/tools/image-blur-redaction). On-device detection + one-click blur inside the capture flow = natural premium/AI-tier feature.
3. **Provenance metadata** — save *where* a screenshot came from (URL, window title) automatically; Screenotate has done this for years and keeps getting recommended on HN (https://screenotate.com/, https://news.ycombinator.com/item?id=34430018).
4. **Auto-categorize/auto-name on capture** (receipt vs code vs design vs meme) — proven by Captr/SnapSort on iOS; on Mac only generic AI renamers (NameQuick, Zush) exist (https://www.namequick.app/blog/namequick-vs-hazel-smarter-file-organization-mac).
5. **Re-takeable/refreshable documentation screenshots** — Shotomatic's whole pitch (https://www.shotomatic.com/blog/best-screenshot-automation-tool).
6. **Webcam-overlay screen recording** (v2): VOC: *"One reason I use Cleanshot is that it can also record screencasts with a floating recording of my face via the webcam."* — geekybiz, HN 2026-01 (https://news.ycombinator.com/item?id=46691369).

---

## CROSS-CUTTING SIGNALS FOR PRODUCT DECISIONS

- **Speed is the product.** Shottr brags "17ms to grab a screenshot," 2.3 MB dmg [OBSERVED, https://shottr.cc/]; VOC praises center on "quick," "fast," "hundreds of times per day." Any added intelligence must not slow the hotkey→clipboard path.
- **Pricing sentiment (feeds the open pricing decision):** strong one-time-purchase preference in this category. VOC: *"I don't use Loom — I use CleanShot X and it was a one-time $30 payment… for an app whose use case doesn't change… there's probably not much value in recurring payments."* — Shank, HN 2026-01 (https://news.ycombinator.com/item?id=46717351). VOC: *"it's $8 once and does a LOT"* — shinycode (Shottr). The only recurring-feel piece users tolerate is cloud hosting — and even fans call it "overpriced" (joshstrange).
- **Quality/trust bar:** OS-level fragility is punished — VOC: *"taking a screenshot with CleanShot somehow resets the DisplayPort driver and everything flips out… Infuriating."* — michaelbuckbee, HN 2026-03 (https://news.ycombinator.com/item?id=47224675); macOS Sequoia's recurring screen-recording permission nags hit Shottr users (https://news.ycombinator.com/item?id=41560228, 2024).
- **Multi-tool reality = positioning gap.** Power users run CleanShot + Shottr + ScreenFloat + TextSniper simultaneously (TidBITS/mjtsai 2026 thread) because no single app covers capture-speed + pin + OCR + beautify + organize. "Best of both worlds" is literally how users behave today, by paying twice.
- VOC (love language for the category): *"My latest find is shottr.cc… Build a simple thing that solves a problem really well… keep refining."* — nicbou, HN 2025-08 (https://news.ycombinator.com/item?id=44948108); *"Why would you use anything but Shottr on macOS? …the software is simply on a whole different level. They deserve all the fame."* — koiueo, HN 2026-01 (https://news.ycombinator.com/item?id=46817594).

---

## JOB × FEATURE × DESTINATION MATRIX (summary)

| Job | Must-have features | Destinations | Biggest residual friction |
|---|---|---|---|
| Bug reporting/QA | instant annotate, numbered steps, blur, history | Jira, Linear, GitHub, Slack | env metadata lost; cloud link costs extra |
| Screenshot→LLM | clipboard-first capture, OCR bundle | Claude Code, Cursor, ChatGPT | context switch; no native "send to AI" |
| OCR/knowledge capture | 1-hotkey OCR, formatting retention | VS Code, Google, Obsidian, Notion | no source provenance; no note-app routing |
| Documentation | re-editable annotations, presets, combine, scrolling | docs sites, Markdown repos, KB | 6-step/3-app loop; stale screenshots |
| Design QA/feedback | ruler, color picker, magnifier, pin | Figma, Slack | measurements don't flow anywhere |
| Social/beautify | auto-balance backgrounds, presets, frames | X, LinkedIn, Product Hunt | brand presets, per-platform sizes |
| Customer support | blur PII, steps tool, reusable library | Zendesk, Intercom, Help Scout | needs cloud links (v2) |
| Pin/reference | float, per-app/Space pinning, opacity | (on-screen) | none major — table stakes now |
| Compliance/receipts | scrolling capture, timestamps, retention | Finder/archive | weak demand; long-tail |
| Organization (meta) | tagging, search, auto-sort | local library | unsolved on Mac; iOS proves demand |
