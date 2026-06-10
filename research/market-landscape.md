# Market Landscape & Pricing-Model Map — Screenshot Tools (June 2026)

**Vein:** Wider competitive landscape + pricing-model map (context for positioning and the pricing decision).
**Researched:** 2026-06-09. Tags: [OBSERVED] = seen on official page/changelog/primary source; [CLAIM] = reviewer/aggregator said it. VOC = verbatim voice-of-customer quote.

---

## 1. Executive Summary

1. **The category's biggest story of 2024–2026 is pricing-model whiplash.** Snagit went subscription-only (Jan 2025) and Screen Studio killed its one-time license (Sep 2025) — both triggered visible, quotable backlash. Meanwhile the apps users *praise* on pricing (CleanShot X, Shottr, Xnapper) all use **one-time purchase + 1 year of updates** (the "Sketch model"). For a Mac utility, one-time-with-update-renewal is the evidence-backed safe choice; pure subscription is the evidence-backed reputational risk.
2. **The free floor keeps rising.** Windows Snipping Tool now ships OCR, screen recording with audio, trimming, redaction, GIF export, and a color picker for free; ShareX/Greenshot/Snipaste are free; Shottr is functionally free; new OSS Mac entrants (Capso, Cap) are free. Anything you charge for must beat a genuinely good free baseline — capture itself is worth $0.
3. **Acceptable price anchors (Mac, individual):** $12–$35 one-time feels fair (Shottr $12–30 pay-what-you-want, CleanShot $29, Xnapper $29.99, PicPick $29.99 commercial). $39/yr (Snagit) is tolerated-but-resented; ~$108–$240/yr (Screen Studio, Zight Pro) draws "way overpriced" reactions for anything screenshot-shaped. VOC: "charge me once or I won't pay the 'just 10$/month' == 120$/year for a screenshot app is waaay overpriced."
4. **The cloud-sharing-first players (Zight, Droplr, Monosnap) are stagnating** — acquired, buggy, or "looking abandoned" per reviewers — which is partly why the local-first decision is well-timed; but it also shows cloud sharing alone no longer supports a standalone subscription business.
5. **White space:** a polished native app that is (a) one-time priced, (b) local-first/private, (c) spans capture → annotate → beautify → organize/search in one tool, and (d) eventually cross-platform (Mac+Windows) — no one currently does all four. The Windows paid market is nearly empty because ShareX+Snipping Tool set expectations at "free," so a Windows port must win on polish/UX, not features.

---

## 2. Competitor Profiles (2025–2026 state)

### 2.1 Xnapper (Mac, screenshot beautifier)
The archetypal "make it pretty" screenshot app: auto-balanced backgrounds, padding, rounded corners, smart redaction of emails/tokens, annotation — aimed at people posting screenshots publicly (marketing, social, docs). Mac-only, with a separately-sold iOS app. [OBSERVED] Pricing is one-time perpetual: **Basic $29.99 (1 Mac), Personal $54.99 (2 Macs), Standard $79.99 (3 Macs), each with 1 year of updates; renewal at 40% discount; "If you don't renew, you can still use the last version you have forever"**; Team tier at $5/device/month; 30-day no-questions refund (https://xnapper.com/pricing). Free version watermarks output [CLAIM] (https://myappleguide.com/xnapper-review/). Also on Setapp and periodically on AppSumo for as little as **$5 lifetime** [CLAIM] (https://daveswift.com/xnapper/, https://appsumo.com/products/xnapper/) — a sign the maker treats deal-channel volume as marketing, and a price-anchoring hazard for the whole beautifier niche.

**Relevance to us:** validates "beautify" as a paid job-to-be-done; its single-purpose nature (no scrolling capture, no OCR-centric workflow) is the gap a "best of both worlds" app closes. The beautifier niche is getting crowded and partly commoditized by free web tools (Pika.style, PostSpark, shots.so — https://pika.style/, https://postspark.app/).

### 2.2 Snagit / TechSmith (Mac+Windows, the enterprise incumbent) — **the cautionary pricing tale**
Decades-old, deepest feature set in the category (capture, scrolling, OCR, video, templates, stamps, simplify tool). [OBSERVED] **TechSmith moved Snagit to subscription-only starting with Snagit 2025 (launched Jan 2025): ~$39/year individual, ~$48/user/yr business; includes install on 2 machines** (https://support.techsmith.com/hc/en-us/articles/27009223314701-TechSmith-Transition-to-Annual-Subscription-Pricing-Model-in-2025, https://www.techsmith.com/store/snagit). Previous perpetual price was ~$63. Existing perpetual licenses keep working but get no new versions; maintenance holders got a >60% loyalty discount [OBSERVED on support page].

The backlash is loud and citable:
- [CLAIM] LowEndBox: maintenance lapses (30-day window/year) get a perpetual license "immediately revoked and you are forced into the annual plan" — author calls it "a licensing 'gotcha' and a pretty disgusting greed move" (https://lowendbox.com/blog/dont-upgrade-snagit-past-2024-avoid-techsmiths-license-gotcha-trap-with-a-great-free-alternative/). Same article's recommended escape hatches: ShareX (Windows), **CleanShot (Mac, "paid, non-subscription")**, PicPick.
- [CLAIM] Long-time users "feeling betrayed after years of supporting the product with perpetual purchases"; complaints about "having to pay indefinitely for software they'd already bought" (https://www.screensnap.pro/blog/snagit-pricing, https://www.webhostingtalk.com/showthread.php?t=1935276).
- [CLAIM] German reseller warning piece: "Wake up and pay attention! – License change at TechSmith" (https://sos-software.com/en/techsmith-license-change/).

**Relevance to us:** Snagit's churn is recruitable. Its feature list ≈ ceiling of "power" expectations; its pricing move ≈ the exact resentment our pricing can position against.

### 2.3 Monosnap (Mac/Win/Chrome, freemium capture + cloud)
Capture + screencast + cloud storage, popular with support teams. Freemium: [CLAIM] free plan (personal use, 2GB cloud, limited file types), paid from ~$2.50–$3/user/mo (commercial use, 10GB, integrations); enterprise tiers add OCR, SSO, on-prem storage (https://support.monosnap.com/hc/en-us/articles/5551061095698-Compare-Monosnap-Plans, https://www.capterra.com/p/60571/Monosnap/, https://www.g2.com/products/monosnap/pricing). Users praise simplicity ("The functions that are there are extremely intuitive to use and provide great value for quick edits" — VOC via https://www.benzinga.com/money/business/monosnap-review) but report slow uploads [CLAIM, same source]. Notably, OCR is gated to *paid/enterprise* — which Shottr and even Windows Snipping Tool give away free. Low energy as a product; pricing is cheap because the product competes at the commodity layer.

### 2.4 Zight, ex-CloudApp (cross-platform, cloud-sharing/async-video SaaS)
The "share a link instantly" pioneer, rebranded CloudApp→Zight in 2023, now pitching AI + async video for support/sales teams. [OBSERVED via plans page metadata + aggregators] Free plan capped (~25 items, 90-sec videos); **Pro $9.95/user/mo annual ($119.40/yr) or ~$12 monthly; Teams $8/user/mo (min 3 users)**; Enterprise custom; another packaging/pricing update rolling out March 31 2026 (https://zight.com/plans/, https://zight.com/blog/new-zight-plans-pricing-update-2026/, https://www.capterra.com/p/154298/CloudApp/pricing/). Sentiment is split: 4.6/5 on G2 overall [CLAIM] but recent reviewers say "with the new branding the software unfortunately is buggy and there are no updates, looking abandoned," "pricing has increased, making the value less clear," refund/support complaints ("worst customer service ever seen") (https://www.softwareworld.co/software/zight-formerly-cloudapp-reviews/, https://www.capterra.com/p/154298/CloudApp/).

**Relevance to us:** Zight is what "screenshot tool as cloud SaaS subscription" looks like at endgame — team-priced, AI-sprinkled, and resented by individual users. It validates deferring cloud to v2 and never making it the *price carrier* for individuals.

### 2.5 Droplr (cross-platform, cloud-sharing)
Same generation as CloudApp; effectively in maintenance/harvest mode. [CLAIM] Acquired (PitchBook lists a 2022 acquisition; Skyvera — a TeleStrategies/“buy-and-hold software” shop — acquired it in Aug 2023) (https://pitchbook.com/profiles/company/59168-17, https://www.cbinsights.com/company/droplr). Pricing: Pro ~$8/mo, Teams ~$9/user/mo; free tier deletes drops after 30 days [CLAIM] (https://www.capterra.com/p/157955/Droplr/pricing/). Little product news since 2023. **Signal: the standalone "screenshot→cloud link" subscription category is consolidating/dying** — the job got absorbed by Slack, Loom, CleanShot Cloud, and OS tools.

### 2.6 Screen Studio (Mac, adjacent: polished screen recording) — **the second cautionary pricing tale**
The premium "beautiful demo video" recorder (auto-zoom, smooth cursor, 4K export). Directly relevant to our v2 video ambitions. Pricing history [OBSERVED via PriceTimeline + screen.studio]: **2022: $89 one-time → added subs → Sep 2025: one-time ($229) killed; now $9/mo billed yearly ($108/yr) or $20/mo monthly** (https://pricetimeline.com/news/173, https://screen.studio/). Founder Adam Pietrasiak publicly recanted the $229 one-time price: **VOC (founder): "About Screen Studio's $229 price: I deeply regret doing that. There was a lot of hate related to it and I mostly agree with it… I think I lost some of my reputation because of that."** (https://x.com/pie6k/status/1973321084641358308). Reviewers consistently flag the model: "In a market where comparable tools offer lifetime licenses in the $129–150 range, the subscription model is Screen Studio's most consistent point of friction" [CLAIM] (https://screenbuddy.xyz/blog/screen-studio-alternative, https://matte.app/blog/screen-studio-review). A cottage industry of one-time-priced alternatives now markets *against* its pricing (ScreenBuddy "$29.99 vs $29/mo", CursorClip — https://screenbuddy.xyz/blog/screen-studio-alternative, https://cursorclip.com/blog/cursorclip-vs-screenstudio/).

### 2.7 Flameshot (OSS, Linux-first, also Win/Mac)
Free, open source, GPL. Revived after a 3-year gap: v13.0 Aug 2025, v13.3 Oct 2025, v14 beta improving multi-monitor and fractional scaling [OBSERVED] (https://github.com/flameshot-org/flameshot/releases). macOS support exists (now native arm64) but is rough: unsigned/un-notarized binaries require security overrides; brew install issues [OBSERVED issue #4125] (https://github.com/flameshot-org/flameshot/issues/4125, https://flameshot.org/docs/installation/installation-osx/). **Signal:** OSS keeps annotation/capture free on every platform, but distribution polish (signing, notarization, OS integration) is exactly where native paid apps stay defensible.

### 2.8 ShareX (Windows, OSS) — **what Windows users will expect from us later**
The free, open-source Windows power tool: capture/record any region with one keystroke, upload to **80+ destinations**, heavy automation (workflows, after-capture pipelines), full annotation editor (shapes, step counters, blur, stickers), plus a toolbox (color picker, ruler, QR, OCR). Actively maintained: .NET 9 upgrade and steady releases through 2025 [OBSERVED] (https://getsharex.com/, https://github.com/ShareX/ShareX). Critiques: dated/overwhelming UI for non-power-users [CLAIM] (https://atomisystems.com/screencasting/sharex-windows-review-pros-cons-and-an-alternative/). **Implication for our Windows port:** Windows users expect *all capture mechanics + automation for $0*; the only purchasable deltas are design quality, beautification, organization/search, OCR quality, and "it just works" defaults. (PickPick — free personal/$29.99 commercial; Greenshot, Lightshot, Snipaste — free; https://www.screensnap.pro/blog/best-screenshot-tools-windows, https://sourceforge.net/software/compare/Greenshot-vs-PicPick-vs-Snipaste/.)

### 2.9 Windows Snipping Tool (the free floor on Windows)
Massively upgraded 2024–2025 [OBSERVED via coverage of official updates]: built-in **OCR/"Text actions"** (copy text, copy as table, auto-redact emails/phone numbers), **screen recording with audio + in-app trimming** (v11.2501.7.0), **color picker** with HEX/RGB/HSL (v11.2504.38.0, May 2025), GIF export of recordings, Visual Search with Bing (https://www.americanbar.org/groups/law_practice/resources/law-technology-today/2025/snipping-tool-allows-ocr-screen-captures/, https://www.neowin.net/news/snipping-tool-is-getting-a-handy-new-feature-for-screen-recording/, https://www.makeuseof.com/new-snipping-tool-features-that-more-useful-than-it-used-to-be/). **Signal:** Microsoft is sherlocking the commodity layer (OCR, recording, color picker, redaction). Differentiation must live above that layer.

### 2.10 Notable new entrants, 2024–2026
The long tail is exploding around four themes — beautify, organize, privacy, and "Screen Studio but one-time":
- **Pixera** (Mac, 2025 PH launch) — one-shortcut beautify: auto-blur, mesh gradients, smart redaction; "macOS-native, privacy-friendly" (https://www.producthunt.com/products/pixera).
- **Pickle** (Mac) — "native, privacy-first screenshot manager… redact sensitive info, and share a clean, private link" (https://www.producthunt.com/products/pickle-9).
- **Tidyshot** (Mac) — menu-bar organizer: on-device AI auto-sorts/renames screenshots, OCR-searchable (https://www.hunted.space/product/tidyshot-screenshot-organizer-macos/launches/tidyshot-screenshot-organizer-macos). Organization/search is an emerging job none of the incumbents own.
- **Capso** (Mac, free OSS, Swift/Apple Silicon) — annotation + one-click beautification, free (https://www.producthunt.com/products/capso).
- **ScreenSnap Pro** (Mac, $29 one-time) — markets itself aggressively as the "no subscription" CleanShot alternative via SEO content (https://www.screensnap.pro/blog/best-cleanshot-x-alternative-in-2026-plus-4-more-options-for-mac-users). Whole marketing site is built on subscription resentment — proof the wedge works.
- **Cap** (cap.so, Mac+Win, OSS Loom/Screen-Studio alternative) — free tier; **$58 one-time desktop license** for unlimited local recording or $8.16/user/mo Pro cloud [CLAIM] (https://cap.so/, https://github.com/CapSoftware/cap). Shows "one-time for local, subscription only for cloud" hybrid working in the adjacent recording space — a direct template for our v2.
- **Skrin** (Windows) — "Xnapper alternative for Windows" beautifier (https://skrin.app/compare/xnapper-alternative) — early evidence of paid-Windows-beautifier demand.
- Web beautifiers (free/cheap): **Pika.style** (freemium + API), **PostSpark**, **shots.so** (https://pika.style/pricing, https://postspark.app/) — commoditizing basic "pretty screenshot" output.

### 2.11 Context anchors (from the other vein, summarized here for the map)
- **CleanShot X** [OBSERVED]: **$29 one-time** ("The Mac app — yours to keep, forever," 1 yr updates, 1GB cloud), $19/yr optional update renewal; **Cloud Pro $8/mo annual / $10 monthly** (unlimited cloud, always-latest app); on Setapp; 30-day refund (https://cleanshot.com/pricing). Mac-only — FAQ says no Windows version planned (https://cleanshot.com/faq). Still shipping fast (4.8, May 2025: color picker, editable window screenshots, horizontal scrolling capture — https://cleanshot.com/changelog).
- **Shottr** [OBSERVED]: freemium/pay-what-you-want — "Shottr can be used for free for as long as you want," "name your price, or enter $0," license formally needed for S3 upload/hiding menubar icon; dev: "I plan to add more features and raise its price in the future" (https://shottr.cc/). Third parties describe current tiers as **$12 Basic / $30 "Friends Club"** [CLAIM] (https://www.screensnap.pro/blog/cleanshot-x-vs-shottr).
- **Setapp** (our later channel): $9.99/mo membership, 250+ apps, includes CleanShot X and Xnapper; since Mar 2026 also sells selected apps individually [CLAIM] (https://setapp.com/pricing, https://9to5mac.com/2026/03/03/setapp-now-lets-users-buy-or-subscribe-to-select-apps-individually/).

---

## 3. Pricing-Model Map

| Product | Platform | Model | Individual price | Notes |
|---|---|---|---|---|
| macOS built-in / Snipping Tool | OS | Free | $0 | Free floor; Snipping Tool now has OCR, recording, trim, color picker, redaction |
| ShareX / Greenshot / Lightshot / Snipaste / Flameshot / Capso | Win/Linux/Mac | OSS-free | $0 | Sets Windows expectation: everything free |
| Shottr | Mac | Freemium, pay-what-you-want one-time | $0–$30 (≈$12 typical) | "Name your price"; nagware for free users |
| CleanShot X | Mac | **One-time + optional update renewal**; cloud sub separate | $29 once, $19/yr optional; Cloud Pro $8/mo | The model users praise; cloud is the only subscription |
| Xnapper | Mac | One-time + 1yr updates (renew −40%) | $29.99 | Keep-forever last version; $5 AppSumo deals exist |
| PicPick | Win | Free personal / one-time commercial | $29.99 | Rare paid Windows survivor |
| Cap | Mac/Win | OSS + one-time desktop OR cloud sub | $58 once, or $8.16/mo Pro | Hybrid local-license/cloud-sub template |
| Monosnap | Mac/Win | Freemium subscription | ~$3/user/mo | Cheap; OCR gated to paid/enterprise |
| Snagit | Mac/Win | **Subscription-only since Jan 2025** | $39/yr ($48/user/yr business) | Perpetual killed; major backlash |
| Droplr | cross | Subscription | ~$8/mo | Acquired (Skyvera), harvest mode |
| Zight (CloudApp) | cross | Freemium subscription | $9.95/user/mo annual (~$119/yr) | Team-oriented; "buggy / looks abandoned" reviews |
| Screen Studio | Mac | **Subscription-only since Sep 2025** | $108/yr ($20/mo monthly) | One-time killed; founder regret tweet |
| Setapp (channel) | Mac | Bundle subscription | $9.99/mo | Contains CleanShot + Xnapper |

### Where the subscription backlash shows up (evidence)
- **Snagit:** "a licensing 'gotcha' and a pretty disgusting greed move" (https://lowendbox.com/blog/dont-upgrade-snagit-past-2024-avoid-techsmiths-license-gotcha-trap-with-a-great-free-alternative/); users "feeling betrayed," "pay indefinitely for software they'd already bought" [CLAIM] (https://www.screensnap.pro/blog/snagit-pricing, https://www.webhostingtalk.com/showthread.php?t=1935276).
- **Screen Studio:** founder VOC above; reviewers: subscription is "the most consistent point of friction" (https://screenbuddy.xyz/blog/screen-studio-alternative).
- **Zight:** "pricing has increased, making the value less clear" [CLAIM] (https://www.softwareworld.co/software/zight-formerly-cloudapp-reviews/).
- **General utility-subscription fatigue:** VOC: "charge me once or I won't pay the 'just 10$/month' == 120$/year for a screenshot app is waaay overpriced." — freefaler, HN, 2025-07-23 (https://hn.algolia.com/api/v1/search?query=%22screenshot%22%20%22subscription%22&tags=comment).
- **What one-time love sounds like** (pre-2024, possibly stale but directionally durable): VOC: "CleanShot was by far the best, and costs the least. Unlike most tools which are SaaSified and require a monthly subscription, CleanShot still offers a one-off license." — gingerlime, HN 2021; "It's a steal." — julianlam, HN 2021; "Sketch, CleanShot, and Jetbrains come to mind… pay once, get forever usage of the software, and one year of free updates." — dceddia, HN 2025-08-02 (https://hn.algolia.com/api/v1/search?query=CleanShot%20subscription&tags=comment).
- **Shottr love (free + fast + OCR)**: VOC: "Why would you use anything but Shottr on macOS?… the software is simply on a whole different level." — koiueo, HN 2026-01-30; "I take a screenshot of a screenshot and hit 'O' immediately after. Saves me from first saving the file" — internetter, HN 2025-11-11; "when I want to select unselectable text I just do OCR with a simple and fast shortcut" — danielfalbo, HN 2025-09-26 (https://hn.algolia.com/api/v1/search?query=Shottr&tags=comment).

### Fair vs. outrageous (synthesis of price points users react to)
- **Fair / praised:** $0 (Shottr) with voluntary payment; **$29–$35 one-time** with 1yr updates (CleanShot, Xnapper, ScreenSnap Pro, PicPick) — repeatedly called "a steal" / "best value."
- **Grudging:** $39/yr Snagit — accepted by businesses, resented by individuals who used to own it.
- **Rejected:** $10/mo-class subs for individual screenshot use ("$120/year for a screenshot app is waaay overpriced"); $229 one-time for a recorder (founder himself regrets it); $108–$240/yr recorder subs spawning one-time competitors.
- **Anchoring hazard:** AppSumo $5 lifetime deals (Xnapper) teach deal-hunters that beautifiers are worth $5.

### Pricing implication for our decision (evidence-based options)
1. **CleanShot/Xnapper model (strongest evidence):** one-time ~$29 + 1 yr updates, optional discounted renewal, keep-last-version-forever, 30-day refund. This is the model every loved Mac utility in this niche uses, and the model competitors' marketing weaponizes against subscribers.
2. **Cap/CleanShot hybrid for v2:** keep app one-time; charge subscription *only* for genuinely recurring-cost services (cloud sharing, heavy AI) — users demonstrably accept "$8/mo for unlimited cloud" while rejecting "$10/mo for an app."
3. **AI premium tier:** if AI is on-device, bundle in the one-time price or a higher one-time tier; if server-side, it's the legitimate subscription carrier. No competitor has yet nailed "AI features tier" in this category (Zight's AI is team-SaaS-flavored) — open ground, but price it under the $120/yr rage line.

---

## 4. Table-Stakes vs. Differentiators

**Table-stakes (free tools already do these; absence = disqualification):**
region/window/full capture & hotkeys; basic annotation (arrows, text, shapes, blur/pixelate, step counters); copy-to-clipboard flow; **OCR/copy-text** (Snipping Tool, Shottr, ShareX all free); color picker (Snipping Tool, CleanShot, ShareX); pin/float screenshot (Snipaste, Shottr); basic redaction; Retina/multi-monitor correctness; tiny/fast/native feel (Shottr's 2.3MB is the bar users brag about).

**Differentiators (what people actually pay for or rave about):**
- **Scrolling capture that actually works** (CleanShot "best on Mac" [CLAIM] https://efficient.app/apps/cleanshot; Shottr's is free but finicky per reviewers).
- **One-click beautify** (Xnapper/Pixera job): backgrounds, padding, device frames, *smart auto-redaction of emails/tokens*.
- **Post-capture overlay/quick-actions UX** (CleanShot's floating thumbnail; Shottr's keyboard-driven speed).
- **Organization & search of screenshot history** (Tidyshot's wedge; nobody big owns this).
- **Privacy/local-first as a stated value** (Pixera, Pickle marketing language — resonates post-cloud-fatigue).
- **Self-destructing/private share links** (v2; CleanShot Cloud's hook).
- **Polished recording with auto-zoom** (v2; Screen Studio job at non-rage pricing — Cap's $58 one-time shows the lane).
- Developer/designer extras: pixel ruler, measurements, CSS-ish color formats (Shottr's beloved niche).

**Anti-features to avoid (per VOC):** watermarks on free tier (Xnapper's most-cited annoyance), forced accounts, public-by-default links (Lightshot's reputation stain — https://www.screensnap.pro/blog/best-screenshot-tools-windows), license-revocation gotchas (Snagit), killing one-time licenses after launch (Screen Studio).

---

## 5. White Space

1. **"Power + Pretty + Private" in one app.** Shottr = power/no polish-for-sharing; Xnapper = pretty/no power; CleanShot = both-ish but Mac-only with cloud-flavored upsell. A single native app covering capture→annotate→beautify→OCR→organize, local-first, one-time priced, has no direct occupant.
2. **Screenshot library/organization.** Everyone competes on capture; nobody incumbent owns "find that screenshot from three weeks ago" (on-device OCR search, auto-naming). Tidyshot proves demand exists; it's a feature, not yet a company.
3. **The orphaned Snagit individual user.** Corporate-grade features, hates the subscription, on both Mac and Windows. They're actively being told to split across ShareX + CleanShot today (https://lowendbox.com/blog/dont-upgrade-snagit-past-2024-avoid-techsmiths-license-gotcha-trap-with-a-great-free-alternative/). A future Mac+Windows one-time app is the only clean answer — and CleanShot has publicly declined Windows (https://cleanshot.com/faq).
4. **Paid-quality Windows screenshot UX.** ShareX is powerful-but-overwhelming; Snipping Tool is basic; PicPick is dated. "CleanShot for Windows" remains an unfilled, frequently-searched slot (third parties literally sell cloud-Mac workarounds for it — https://www.roundfleet.com/library/cleanshot-x).
5. **AI that serves the screenshot job, locally.** Auto-redaction, auto-naming, semantic search, smart cropping on-device — candidate premium tier with no entrenched competitor; server AI only behind a modest subscription.

---

## 6. Source Index (primary ones)
- https://cleanshot.com/pricing · https://cleanshot.com/faq · https://cleanshot.com/changelog
- https://shottr.cc/
- https://xnapper.com/pricing
- https://support.techsmith.com/hc/en-us/articles/27009223314701-TechSmith-Transition-to-Annual-Subscription-Pricing-Model-in-2025 · https://www.techsmith.com/store/snagit
- https://lowendbox.com/blog/dont-upgrade-snagit-past-2024-avoid-techsmiths-license-gotcha-trap-with-a-great-free-alternative/ · https://www.webhostingtalk.com/showthread.php?t=1935276 · https://sos-software.com/en/techsmith-license-change/
- https://zight.com/plans/ · https://zight.com/blog/new-zight-plans-pricing-update-2026/ · https://www.softwareworld.co/software/zight-formerly-cloudapp-reviews/
- https://www.capterra.com/p/157955/Droplr/pricing/ · https://pitchbook.com/profiles/company/59168-17 · https://www.cbinsights.com/company/droplr
- https://screen.studio/ · https://pricetimeline.com/news/173 · https://x.com/pie6k/status/1973321084641358308
- https://github.com/flameshot-org/flameshot/releases · https://github.com/flameshot-org/flameshot/issues/4125
- https://getsharex.com/ · https://github.com/ShareX/ShareX
- Snipping Tool 2025 coverage: https://www.americanbar.org/groups/law_practice/resources/law-technology-today/2025/snipping-tool-allows-ocr-screen-captures/ · https://www.neowin.net/news/snipping-tool-is-getting-a-handy-new-feature-for-screen-recording/ · https://www.makeuseof.com/new-snipping-tool-features-that-more-useful-than-it-used-to-be/
- New entrants: https://www.producthunt.com/products/pixera · https://www.producthunt.com/products/pickle-9 · https://www.producthunt.com/products/capso · https://www.hunted.space/product/tidyshot-screenshot-organizer-macos/launches/tidyshot-screenshot-organizer-macos · https://cap.so/ · https://skrin.app/compare/xnapper-alternative · https://pika.style/pricing · https://postspark.app/
- HN VOC: https://hn.algolia.com/api/v1/search?query=Shottr&tags=comment · https://hn.algolia.com/api/v1/search?query=CleanShot%20subscription&tags=comment
- Setapp: https://setapp.com/pricing · https://9to5mac.com/2026/03/03/setapp-now-lets-users-buy-or-subscribe-to-select-apps-individually/
