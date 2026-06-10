# Reddit Sentiment Mining: CleanShot X vs Shottr (and the Mac screenshot-app market)

**Vein:** Reddit VOC via PullPush.io API (Pushshift successor)
**Date of research:** 2026-06-09
**Author:** Reddit-mining subagent

---

## 1. Methodology & corpus

- **Source:** PullPush.io Reddit archive (`api.pullpush.io/reddit/search/submission|comment`). The comment *text-search* endpoint was timing out server-side ("Response Timeout"), so the workflow was: (1) submission search across queries/subreddits, (2) per-thread comment harvest via `?link_id=<id>` (fast and reliable).
- **Queries run (submissions):** `cleanshot`, `shottr` (unrestricted + r/macapps, r/MacOS, sliced 2024-01-01→2025-01-01→index end), `"cleanshot vs"`, `"shottr vs"`, `cleanshot alternative`, `shottr alternative`, `screenshot` in r/macapps, `xnapper`.
- **Comment harvest:** full comment sets for ~40 high-signal threads (~1,000+ comments), including every "X vs Y", "is there anything better than…", "what screenshot app do you use", pricing-change, and bug threads found.
- **Corpus size:** ~600 submissions + ~1,000 comments, dominated by r/macapps (the de-facto venue for this debate), plus r/MacOS, r/ObsidianMD, r/ProductivityApps, r/apple.
- **IMPORTANT INDEX CAVEAT:** PullPush's index visibly **ends around mid-May 2025** (newest hits across all queries: 2025-05-14/15). There is **no late-2025/2026 Reddit data** in this corpus. Everything below is 2021–May 2025, with the bulk in 2024–2025. Anything pre-2024 is flagged.
- All quotes below are **VOC verbatims** [CLAIM] from real Reddit comments, with permalinks. Frequency counts are rough and biased toward the harvested threads (which skew r/macapps power users — exactly the audience that buys these apps).
- Raw JSON/text kept in `/Users/codyhung/Sidequests/screenshot/research/raw/`.

---

## 2. Headline findings (TL;DR)

1. **The market has a stable two-party structure with a free third pole.** Default mental model on Reddit: *macOS built-in (free, "good enough for 95%") → Shottr ($8–12 lifetime, "90% of CleanShot with style") → CleanShot X ($29 + 1yr updates / Setapp, "the best, the most polished").* Nearly every recommendation thread converges to this ladder.
2. **CleanShot's #1 complaint is not price level — it's the license model.** "One year of updates," "bug fixes held hostage behind renewal," and "one Mac per license" generate the angriest, most repeated comments. Subscription hatred is the loudest cultural force in r/macapps.
3. **Shottr's #1 complaint is scrolling-capture reliability** (cuts content off, skips frames, watermarked in free tier), followed by **slow/solo-dev update cadence** and a **dated, less-native UI**. CleanShot's scrolling capture is repeatedly cited as the single feature that justifies the upgrade.
4. **The most-loved features are not the headline ones.** Pin/float screenshot ("always on top") is a sleeper hit users "stumbled into" and now can't live without; auto-incrementing step numbers, capture-previous-area, OCR, and instant-link cloud upload each have devoted constituencies. Cloud is simultaneously the most-praised CleanShot exclusive *and* the most-cited "I never use it" feature — it splits the market cleanly.
5. **Speed is a feature.** "Buttery smooth," "crazy fast and never lags," "1–2 seconds is a lifetime"; Snagit is dismissed almost entirely because it's slow and "anti-Mac" on macOS despite having the best annotation/library toolset.
6. **Snagit is the wounded giant whose users are up for grabs.** TechSmith's move to subscription triggered visible exodus sentiment ("it's gone subscription, so hell no"; "epitome of enshitification"), but its **library** and **mature annotations** are the two things ex-Snagit users say nothing on Mac replaces.
7. **Willingness-to-pay is real but anchored low.** Shottr at $12 lifetime is "insane that it's basically free — I'd literally throw money at the developer." Community advice to a wannabe cheaper-CleanShot builder: don't compete on price; the slots at $0, $12, and $29 are taken; differentiate on use case or lose.
8. **Other names that keep recurring** (beyond the big two): Snagit, Flameshot (FOSS), Xnip (free + polished), Longshot (feature-rich lifetime, rising in 2024–25), CleanShot-adjacent specialists (TextSniper for OCR, Screen Studio for fancy video, Clop for compression, ScreenFloat for floating/library), Monosnap, Lightshot, Snipaste, Capto, Greenshot, Skitch (dead but missed), ShareX (Windows envy: "Sharex is the absolute goat. I miss it so much").

---

## 3. Why people choose CleanShot X over Shottr

Theme counts from comparison threads (rough, n≈45 explicit preference statements):
- **Polish / "feels native" / premium UX** — the most common reason (~15 mentions)
- **Scrolling capture quality** (~8)
- **Video/GIF recording** (Shottr has none) (~8)
- **Cloud upload + instant share link** (~6)
- **All-in-one replaces multiple apps (Shottr+Kap+Loom)** (~5)

### VOC — choosing CleanShot
- VOC: "Cleanshot X. The best." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/medqx7k/)
- VOC: "I don't change CleanshotX for anything tbh. Shottr is good but it doesn't feel as part of the macOS as CSX do." (https://reddit.com/r/macapps/comments/1iaysxg/is_there_anything_better_than_shottr/m9eopc5/)
- VOC: "Get Cleanshot X. Not sponsored… but I fucking love this app. Miles more polished than Shottr. Shottr IMO had a great selling point when it was free. If you compare the paid feature set, then Cleanshot X is wayy bette[r]." (https://reddit.com/r/macapps/comments/1h1oyuz/shottr_and_kap_or_cleanshot_x/lzdgrmd/)
- VOC: "$29 price tag is well justified and you will realize this yourself once you pay." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdwwegw/)
- VOC: "Scrolling capture is the best implemented, far better than Shottr (which I own and like, but do not use because of this)." (https://reddit.com/r/macapps/comments/1jur1n1/what_cleanshot_x_features_do_you_actually_use/mm68p9t/)
- VOC: "The main reason I decided to switch was the scrolling capture feature, which didn't quite work for me in Shottr. Plus… it's clear that CleanshotX offers a much more premium experience compared to Shottr." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdyabgi/)
- VOC: "Shottr is very good, but the X scrolling capture is leaps and bounds better and I use it a lot." (https://reddit.com/r/macapps/comments/1k9af1c/my_list_of_apps_id_pay_double_for/mpg2mhw/)
- VOC: "Whether it's a screenshot, video, or GIF – being able to quickly snip something, highlight it, and then instantly have the link ready in the clipboard to share… is super handy." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/me0d0rr/)
- VOC: "The fact that the annotations just look so damn good. It's so easy to make good-looking annotated screenshots. Most other tools like this produce ugly annotations." (https://reddit.com/r/macapps/comments/1jur1n1/what_cleanshot_x_features_do_you_actually_use/mm61axu/)
- VOC: "Best screenshot/screen recording tool I've used. Way better than native macOS tools and makes documentation easier." (https://reddit.com/r/ProductivityApps/comments/1k4yrhg/my_goto_mac_productivity_apps_that_are_actually/)
- VOC: "screen capture + headshot capture in the corner (saves me a lot of money from not needing Loom to do this alone)" (https://reddit.com/r/macapps/comments/1jur1n1/what_cleanshot_x_features_do_you_actually_use/mm4wm9y/)
- VOC: "CleanShotX is my favorite. - Fast. - Easy to edit. - Easy to send screenshots on the cloud and put the share link in the clipboard. - history of screenshot" (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdvu2cv/)
- VOC: "It's an absolutely beautifully designed program that has saved me a ton of time… With CleanShot it is two clicks." (https://reddit.com/r/ObsidianMD/comments/1km688x/cleanshot_for_mac_is_a_incredible/) — note this praise post still flags the price as "$30 one-time… also comes with SetApp."
- VOC: "One of the only apps I will happily pay for year after year" (https://reddit.com/r/ObsidianMD/comments/1km688x/cleanshot_for_mac_is_a_incredible/msavsqs/)
- VOC: "Cleanshot X accumulates them all nicely in app without cluttering my Pictures folder… I just save the ones I want, and let the others delete themselves… after 30 days." (https://reddit.com/r/macapps/comments/1jxlau1/screenshot_curiosity/mol2nt2/)
- VOC: "cleanshot's feature of screen recording a portion of the window is absolutely amazing." (https://reddit.com/r/macapps/comments/1k9af1c/my_list_of_apps_id_pay_double_for/mpfe20z/)
- VOC (Setapp pathway): "Cleanshot via Setapp. Otherwise I would still be using Shottr." (https://reddit.com/r/macapps/comments/1iaysxg/is_there_anything_better_than_shottr/m9gfctd/)
- VOC (Setapp pathway): "It is part of SetApp - which makes is quite reasonable if you use a few of their other apps." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdyivru/)

## 4. Why people choose Shottr over CleanShot X

Theme counts (rough, n≈40 explicit preference statements):
- **Price: free tier / $8–12 lifetime, no renewal** — dominant (~18)
- **Lightweight / fast / no lag** (~10)
- **"Does 90% of CleanShot"** — good-enough logic (~8)
- **Specific power tools**: OCR, pixel ruler, color picker, pin, repeat-area capture, backdrop (~8)
- **No per-Mac license hassle** (~3)
- **Goodwill toward the solo dev (Max)** — repeated purchases framed as "support/donation" (~8)

### VOC — choosing Shottr
- VOC: "This screenshot tool is so lightweight but does SO much more than the built-in Mac one… It's also crazy fast and never lags my system. The fact that this app is basically free is insane to me. I'd literally throw money at the developer." (https://reddit.com/r/macapps/comments/1k9af1c/my_list_of_apps_id_pay_double_for/ — viral "pay DOUBLE" list, 59↑, reposted across 5+ subs)
- VOC: "Shottr will still do 90% of CleanshotX, and do it with style." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdxygi8/)
- VOC: "It's IMHO the best screenshot app on Mac. There might be some with more features but not for this price and not as slick and low weight on the system." (https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr1odzr/)
- VOC: "shottr is one of the most useful and straightforward software tools i've used in years. the OCR, the pinning, the rulers, everything." (https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr0tdd6/)
- VOC: "Shottr is lightweight and simple. I have no need for cloud-based features and other bloat." (https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr1jr01/)
- VOC: "shottr is literally (literally) noticeably faster at taking and displaying… your screenshot than the native animated corner pop out thing." (https://reddit.com/r/macapps/comments/1bvo3ms/seeking_advice_screenfloat_2_vs_snagit_vs/ky1hus0/)
- VOC: "I use Shottr every single work day, without fail… Shottr is a solid 9.5/10." (https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr1hh3h/)
- VOC: "I found that doing a continuous scroll with Shottr is far superior than Cleanshot X. It's worth the donation!!" — note: minority counter-opinion on scrolling (https://reddit.com/r/macapps/comments/1iaysxg/is_there_anything_better_than_shottr/m9fyycd/)
- VOC: "In Cleanshot it only does an area, while Shottr does the entire window and it auto scrolls for you." (https://reddit.com/r/macapps/comments/rm5s3w/best_cleanshot_x_alternative/l0taavi/)
- VOC: "It's my go-to if I need to cut-out a vertical or horizontal chunk. CleanShotX can't do this." (https://reddit.com/r/macapps/comments/1iaysxg/is_there_anything_better_than_shottr/m9hq8kz/)
- VOC: "For transparent Shottr does better. CleanShotx can't accurately produce shadow." (https://reddit.com/r/macapps/comments/1j87ewh/screenshot_quality_shottr_vs_clean_shot_x/mh64nqr/)
- VOC: "Shottr - Best for repetitive region screenshot. I use this a lot when I give feedback to my designers and editors." (https://reddit.com/r/macapps/comments/1iaysxg/is_there_anything_better_than_shottr/m9f6xqc/)
- VOC: "fwiw shottr has colour picker (press tab) and distance (hold 1 for vertical and 2 for horizontal measuring)" (https://reddit.com/r/macapps/comments/1iaysxg/is_there_anything_better_than_shottr/m9gg9h9/)
- VOC (the canonical Shottr-features-over-native list): "blur / erase text… stampable ruler to show pixel distance… OCR with optional cutting of line breaks… pin to float, pin multiple things to do rapid caveman-style composition… add new captures to existing screenshot… demonstrably faster performance… less steps to copy the screenshot you just took" (https://reddit.com/r/macapps/comments/1bvo3ms/seeking_advice_screenfloat_2_vs_snagit_vs/ky1z5m3/)
- VOC (dev goodwill): "The Developer Max, sends out emails talking about new features every few months, asks our opinions… He responds to any messages I send." (https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr34oj8/)
- VOC (dev goodwill): "Shottr is great, i've bought it now to support the development" (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdwhg63/)
- VOC: "Map custom keyboard keys to Shottr for super fast screenshots. Backdrop feature and uploads work just amazingly!" (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdxvhiq/)

---

## 5. Loudest complaints — CleanShot X

Ranked roughly by frequency/heat in corpus:

1. **License model: "1 year of updates," bug fixes behind renewal** (the angriest theme)
   - VOC: "For me is the update policy. You only get updates for one year – which is fine for new features. But if your version gets a bug that is fixed on a newer version, you[r] only option is to renew your license to fix the bug..." (https://reddit.com/r/macapps/comments/1jur1n1/what_cleanshot_x_features_do_you_actually_use/mm72jl3/)
   - VOC: "This is what bothered me about CleanShot X too when I upgraded to Sequioa, I had to repurchase my license to get some b[u]gs fixed" (https://reddit.com/r/macapps/comments/1jur1n1/what_cleanshot_x_features_do_you_actually_use/mmail31/)
   - VOC: "the eventual change to only having yearly updates rubbed me the wrong way since I had bought it before that was added." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/me19kyd/)
   - VOC: "Buying each year a new license is bad" (https://reddit.com/r/macapps/comments/1h1oyuz/shottr_and_kap_or_cleanshot_x/lze40r2/)
   - VOC: "Same, but only because my employer pays for it. I don't think I would keep using it otherwise (especially now that they are full subscription)." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/me2wnmu/) [CLAIM — "full subscription" is the commenter's characterization]
   - VOC: "Cleanshot is really expensive. $30 for a single seat and only 1 year of updates included… Buying separate licenses (and upgrading them every few years) doesn't seem worth it." (https://reddit.com/r/macapps/comments/1bvo3ms/seeking_advice_screenfloat_2_vs_snagit_vs/ky162ub/)
2. **One-Mac-per-license / activation friction**
   - VOC: "Cleanshot is good, but the license sucks. To use on a different machine, the license must be transferred. I bought a copy for work so this makes it awkward to use on work and personal laptop." (https://reddit.com/r/macapps/comments/1bvo3ms/seeking_advice_screenfloat_2_vs_snagit_vs/ky5osgy/)
   - VOC: "You can only install it on one Mac at a time." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdz074g/)
   - VOC: "I still use Shottr at work because I don't want to pay for a second license." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdvgr12/)
3. **Price as gatekeeper** (drives Shottr's free-tier funnel)
   - VOC: "Heard Cleanshot X is the best out there, but I couldn't justify the $29 price tag for lifetime with one year of updates." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/ — OP)
   - VOC: "Cleanshot is wonderful, but it's very expensive. The OCR you have is one of the best I've seen, but it's a bit expensive. Do you know if there is a discount code…?" (https://reddit.com/r/macapps/comments/1hs5fm6/cleanshot_struggle/m56bsju/)
4. **Scrolling-capture height limit + missed pop-ups**
   - VOC: "The maximum height for scrolling screenshots isn't adjustable. If the scrolling is too long, you can't save the captured image. It can't capture pop-ups from certain apps, like Vallum. Shottr doesn't have these issues." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdz074g/)
5. **Perceived development stagnation (2025)**
   - VOC: "it seems that the development of the app has stalled… This becomes particularly noticeable when similar apps shine with new functions that I actually expected from CleanShot X… is the developer even still motivated?… [still] CleanShot X remains the best choice on Mac." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdyu2oq/ thread, comment mdytkj7 vicinity — permalink: https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdyuh26/)
6. **No library / weak multi-screenshot management** (the ex-Snagit gap)
   - VOC: "One of the biggest issues for me is that cleanshot doesn't have a library. Snagit on the other hand stores it at a location of choice (iCloud for me) so I can share screenshots between all my devices." (https://reddit.com/r/macapps/comments/1bvo3ms/seeking_advice_screenfloat_2_vs_snagit_vs/ky68pzc/)
   - VOC: "Cleanshot is better but having no library makes it a no go for me as well." (https://reddit.com/r/macapps/comments/1hl3cmh/which_tool_merge_snagit_and_cleanshot_fast_and/me8966k/)
   - VOC: "Yes, but Cleanshot is not changing anything on the library end… I asked them already 2 or 3 years ago. They have no intention to picking up that area which is so strong in Snagit." (https://reddit.com/r/macapps/comments/1hl3cmh/which_tool_merge_snagit_and_cleanshot_fast_and/m3kg6oe/)
   - VOC: "it completely falls down when it comes to: 1. Combining multiple images… 2. Cutting out the middle of a screenshot. Which I do A LOT because I deal with a lot of spreadsheets." (https://reddit.com/r/macapps/comments/1hl3cmh/which_tool_merge_snagit_and_cleanshot_fast_and/m3jj0oj/)
7. **Resource/size grumbles (occasional)**
   - VOC: "Is Cleanshot X supposed to take up so much storage? it's just a screenshot app🤔" (https://reddit.com/r/macapps/comments/1jrelxg/cleanshot_x_app_size/) — community answer: it's the saved video history, not the app.
   - Thread: "CleanShot X takes so much Memory resource" (https://reddit.com/r/macapps/comments/1ivcmw8/cleanshot_x_takes_so_much_memory_resource/)
8. **Cloud storage cap**
   - VOC: "CleanShotX without cloud subscription has very limited storage – only 1 gb, which doesn't expand after app licence renew." (https://reddit.com/r/macapps/comments/1jur1n1/what_cleanshot_x_features_do_you_actually_use/mm6sset/)
9. **Annotation gaps vs Snagit**
   - VOC: "I wish cleanshot had symbols to add. Like a green check mark or a red x, wish we could upload stickers… Mouse pointers with a yellow circle…" (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdxelgl/)
   - VOC: "I hope CleanShotX can eventually catch up with SnagIt's annotation & features." (https://reddit.com/r/macapps/comments/1iaysxg/is_there_anything_better_than_shottr/m9lhx5b/)
   - VOC: "I also got Cleanshot X. Paid for it as well. But honestly I don't like it. It also open[s] an editor after a screenshot but I find it clunky and unintuitive." (https://reddit.com/r/macapps/comments/1bvo3ms/seeking_advice_screenfloat_2_vs_snagit_vs/ky68pzc/)
10. Misc bugs in corpus: mic not recording in FaceTime (1j4x653), window-area capture incorrect (1hcfrbf), unable to self-start (1gzd8aa), "won't stop sharing my screen," "opens original image rather than latest edit" (1izu4lu).

## 6. Loudest complaints — Shottr

1. **Scrolling capture unreliability** (most-repeated single defect in the entire corpus)
   - VOC: "still scrolling screenshot not fixed in this app, xnip works better in that way" (https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr4snx8/)
   - VOC: "The only issue i have with Shottr (as a free user) is that the scrolling screenshot messes up quite a bit. Never happened to me when trying CleanShot X" (https://reddit.com/r/macapps/comments/1kdcjl3/is_there_anything_better_than_shottr_after_3/mqgn1un/)
   - VOC: "scrolling capture doesn't function well, it cut out some portion" (https://reddit.com/r/macapps/comments/1h1oyuz/shottr_and_kap_or_cleanshot_x/lzd9irm/)
   - VOC: "Scrolling screenshots are way better than they were before. They don't work in every app which is part of my problem." (https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr7b5pe/)
   - Free tier adds a **watermark on scrolling captures** — surfaced in the "features you actually use" thread (https://reddit.com/r/macapps/comments/1jur1n1/what_cleanshot_x_features_do_you_actually_use/mm4pckm/)
2. **No video / GIF recording** — users bolt on Kap/QuickRecorder/CleanShot; repeated requests ("I really want to see screen recordings there." https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr7psp9/)
3. **Slow, opaque update cadence (solo dev)**
   - VOC: "I appreciate shottr but have been increasingly disappointed in the lack of updates it gets and the lack of features compared to competitors… at this point even after the newest update I'm just gonna switch to cleanshotX." (https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr188x9/)
   - VOC: "the author is a bit slow to update it… when updating to macOS 15 beta and encountering problems, the author sent out a beta version, but it didn't solve the problem. In the end, I switched to other screenshot apps, which I wasn't used to, so I switched back to Shottr!" (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdx7wll/)
   - VOC: "It's really frustrating that Shottr doesn't work when I upgrade to macOS 15 Beta. Other alternatives just aren't as user-friendly." (https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr1mzfp/)
   - VOC: "The development of the app has reduced considerably in the past year." (https://reddit.com/r/macapps/comments/1fssvlt/shottr_18_released/lptbyag/)
4. **Dated / non-native UI**
   - VOC: "honestly, it's great….it just looks a little dated…" (https://reddit.com/r/macapps/comments/1iaysxg/is_there_anything_better_than_shottr/m9ln6m5/)
   - VOC: "I would like the developer to make the UI feel more minimalistic and similar to Apple's UI. The main competitor CleanShot made just this." (https://reddit.com/r/macapps/comments/1fssvlt/shottr_18_released/lpp95f1/)
   - VOC (2022, stale but vivid): "I see this app mentioned a lot but it is ugly as hell." (https://reddit.com/r/macapps/comments/rm5s3w/best_cleanshot_x_alternative/iiqvma5/)
5. **Editing-tool quality gaps** (one scathing regret-purchase)
   - VOC: "I've been very disappointed in Shottr… it only zooms at 100% increments, its blur tool doesn't blur (it only pixelates), and it's worse at annotations than Preview. I really regret buying it." (https://reddit.com/r/macapps/comments/1iaysxg/is_there_anything_better_than_shottr/m9fjbvd/)
   - VOC: "we were using it to draw annotations on a map and then needed to re-open the file and move these around but they were burnt in?" — no re-editable annotations (https://reddit.com/r/macapps/comments/1jwlubd/shottr_editing_saved_files/)
6. **OCR doesn't auto-recognize multiple languages** (drives TextSniper pairing): "I use TextSniper because Shottr's OCR function can't automatically recognize multiple languages." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdz074g/) Also no Hindi support (https://reddit.com/r/macapps/comments/1iwus16/how_can_i_capture_text_from_a_screen_via_ocr_for/)
7. **Output quality confusion**: screenshots look "less sharp," files much smaller, "no setting to change resolution/dpi/quality in Shottr" (https://reddit.com/r/macapps/comments/1j87ewh/screenshot_quality_shottr_vs_clean_shot_x/mh2vqm9/ thread); low quality when pasted into email (https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr1rc09/); "Shottr cannot capture white #fff" (1iz7avc).
8. **Annoyance bugs** (each a thread): splash screen on every login ("All I want is Shottr not giving me a splash screen when in login items… The dev knows, but it's not 'fixed' yet." https://reddit.com/r/macapps/comments/1fzaomz/there_will_be_a_price_increase_for_shottr/lr4p7nz/); closing Shottr window also closes Anki ("it's infuriating," 1kftk6i); captures Figma's selection dotted-line because capture isn't from a frozen screen since v1.8 (1joxuu7); tooltips don't appear in captures (1itxpc4); "Shottr gets automatically closed on a regular basis?" (1bavykp, 2024-03).
9. **Repeat-area capture UX**: "I see that Shottr does a 'repeat' shot, but the area it's about to capture isn't visible… If it somehow highlighted the region, so I could line it up first, it would be great." (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdza70e/)
10. **Corporate trust ceiling**: "Any Shottr alternative? Shottr got banned at my company machine" — commenters point at the anonymous-upload feature's privacy implications (https://reddit.com/r/macapps/comments/1go4d6b/any_shottr_alternative_shottr_got_banned_at_my/lwfowwn/). Reaction: "jfc.. glad i only used it for a few days. went monosnap->shottr->cleanshotx" (lwgkuav).

---

## 7. Features people actually use vs never touch

Primary source: "What CleanShot X features do you actually use?" (https://reddit.com/r/macapps/comments/1jur1n1/, Apr 2025, 41 comments — OP was scoping a cheaper competitor) plus recommendation threads.

**Heavily used / loved (in rough order of citation frequency):**
1. **Annotations** — but specifically *fast, good-looking* annotations; auto-incrementing step numbers called out: "The numbers increase automatically so it's way easier rather than having to add a circle and add text inside." (mm5litj)
2. **Scrolling capture** — "Scrolling capture is OP - not something I have to use often but is something that would be noticeably painful if gone!" (mm57zz9)
3. **Pin / float screenshot ("always on top")** — the sleeper: "I actually stumbled upon it by accidentally clicking the quick access icon and haven't looked back lol. It's a lifesaver for visual references while working in Photoshop or Illustrator." (mm4pzzf); "Floating Screenshots as a top favorite is really interesting. I hadn't expected that to be so high up." (OP, mm4iuud); "This is the big one for me… color matching, palette inspiration… saves me so much time compared to constantly switching windows." (1jxlau1/mmtbtxt)
4. **Copy-to-clipboard-first workflow / speed** — "Just being able to shot straight to the clipboard is also nice. Without saving something." (mm4swya); the native tool's extra clicks are the recurring enemy.
5. **Screen recording + GIF** (CleanShot only) — "screen recording to gif [is] worth the price alone" (mdzekrq)
6. **OCR** — daily for some ("I use OCR daily to pull readings," mm4swya); others outsource to TextSniper.
7. **Capture previous area / repeat shot** — "the ability to capture the previous area/selection with a shortcut key [is] a useful function" (ky39xxy)
8. **History / tray / self-cleaning screenshot pile** — keep Desktop clean, drag from tray into Slack/PowerPoint (1jxlau1/mol2nt2, 1hl3cmh/m3kuwdb)
9. **Cloud upload with instant link** — passionately used by a business minority: "I use the image hosting for my business and the markup, screenshots, video, and pinning are crucial." (mm97n4t)
10. **Backdrop/pretty backgrounds** — the social-sharing crowd (code snippets, marketing): Shottr's backdrop and Xnapper exist for this; "The backdrop feature that adds those gradient backgrounds to code screenshots is amazing." (1k9af1c)

**Never touched / contested:**
- **Cloud** is the most common "everything except…" answer: "everything except cloud upload" (mm6aa5p); "Personally, I use basically every feature beside the cloud thing" (mm569r9); "I'm interested to know why someone would need cloud functionality for screenshots." (mdyy0wf). ⚠️ Relevant to the local-first v1 decision — there is a vocal constituency that sees cloud as bloat, and another that calls it the killer feature. Both are real.
- A meaningful contingent insists **native macOS tools are enough**: "I would urge any new MacOS user to first take advantage of the native utilities… I wasted some time with such reddit recommendations." (mdybtki); "if I just need a basic screenshot tool for 99/100 screenshots I take, why not just use the native" (mdvusgb). This is the perpetual top-of-funnel objection any landing page must answer.

---

## 8. Switching stories (verbatim)

- **Shottr → CleanShot X** (scrolling + polish): "Used Shottr for quiet some time, bought Cleanshot X and never turn back." (https://reddit.com/r/macapps/comments/1h1oyuz/shottr_and_kap_or_cleanshot_x/lzdrwh2/) · "I used Shottr before I made the switch to CleanshotX! The main reason… the scrolling capture feature." (mdyabgi) · "Great product, I used it for a while when I moved to Mac. But then I found out there was cleanshotX and I switched" (lr15jlb) · "I used to use shottr but switched to CleanShot X. I am happy with that decision." (ky3r3d5) · "even after the newest update I'm just gonna switch to cleanshotX" (lr188x9)
- **CleanShot X → Shottr** (license anger, multi-Mac): "I purchased Cleanshot X during the last sale, but I decided to use Shottr… as my main screenshot app. Cleanshot X has a few things that annoyed me: Only one year of support per purchase. Only one Mac… These issues aren't present in Shottr." (mdz4kan) · "I used Cleanshot X before… but the eventual change to only having yearly updates rubbed me the wrong way… shottr is more than sufficient for my needs." (me19kyd)
- **Snagit → Shottr/CleanShot** (subscription + slowness): "I had Snagit through work but I finally dropped it for Shottr and haven't looked back." (mdxd6vl) · "SnagIt 2024 is the king of the hill if you want the best annotations… That said it's slow, sub & TechSmith as a company blows donkey ass." (m3kd2x2) · "it's gone subscription, so hell no." (m9lhqsv) · "now Techsmith announced that all their software is subscription based, so lots of folks will be leaving them for sure." (mde8ne0)
- **Skitch → CleanShot** (abandonware nostalgia): "I miss skitch. But cleanshot is the best now" (mdwio5b)
- **Chain migration**: "went monosnap->shottr->cleanshotx" (lwgkuav)
- **CleanShot → Tella** (recording-centric, 2024-01): "still subscription but I switched from cleanshot to tella personally" (kil8oef)
- **Shottr → Xnip** (scrolling bug): "does the scrolling screenshot still broken? Like it skips fram[es], only reason I switched to xnip" (lr4tijo)
- **Snagit-on-Windows émigrés** keep both: "I came to Mac after a decade of using Snagit on Windows. I like the look of the quick Cleanshot annotations… But it completely falls down…" (m3jj0oj)
- **Windows switchers** arrive asking for ShareX/Snipping Tool equivalents and get funneled to Shottr/CleanShot (1khn1de, 1kko57t, 1fscl6f "Is there any app like Shottr for Mac but for Windows" — note reverse direction too: Shottr fans wanting it ON Windows; relevant to the future Windows port).

## 9. What people say when recommending from scratch

The recommendation script is remarkably consistent across threads (1iu8s5o, 1iaysxg, 1kdcjl3, 1gccpa7, app-list megathreads):

1. "Just use ⌘⇧4/⌘⇧5, it's free" — always present, often top comment.
2. "Shottr — free, fast, does 90%" — the default third-party rec; appears in nearly every "best Mac apps" listicle post (e.g., 161↑ "Best Mac Apps to Download": "Its most useful feature is the OCR feature").
3. "CleanShot X if you want the best and don't mind paying / get it via Setapp."
4. Free-stack alternates: Xnip ("the most polished FREE screenshot app I've ever used… without forcing you to get the premium version," mdx85cf), Flameshot (FOSS, cross-platform; "must be run through rosetta on apple silicon, which makes it less appealing," lfm82d2), Monosnap, Snipaste, Lightshot, QuickRecorder for video.
5. Specialist add-ons recommended alongside: TextSniper (OCR), Clop (compression — "shottr + clop"), Kap/QuickRecorder (recording with free Shottr), Screen Studio ("CleanShotX [video] may seem good, but ScreenStudio does it much better," mm6sset), Xnapper/backdrop tools for pretty marketing shots.
- Community advice to a would-be builder of a cheaper CleanShot (thread 1jur1n1) is strategic gold:
  - "There have been so many attempts to replace Cleanshot... at various price points… would charging less than $12 for a lifetime license still be worth your while?… I'd suggest tackling an interesting use case or serving a specific customer base rather than aiming at price." (mmc9ga6)
  - "The challenge isn't just building a cheaper alternative—it's identifying genuine user pain points that aren't being addressed." (mm4kohv)
  - "if you price it the same, then I'd assume most people would think 'why would I pay the same for *less* features?'… people have been raving about CleanShot **forever** so you'll need more of an incentive… something that doesn't have the track record, proven long term support." (mm57zz9)
  - "Shottr has those 4 features mentioned + a lot more for $12. So I think you'd have to even price it lower than that." (mm5owwb)

## 10. Other tools that keep coming up (mention counts in harvested comment corpus)

Counts from comment bodies across ~40 threads (biased toward harvested threads; use as ordinal, not cardinal):

| Tool | Mentions | Role in conversation |
|---|---|---|
| Shottr | 146 | Free/cheap default |
| CleanShot X | 133 | Premium default |
| Snagit | 28 | Wounded giant; library + annotations benchmark; subscription exodus |
| Longshot | 17 | Rising feature-rich lifetime option (incl. dev self-promo, but real fans: "by far the best and most feature-rich one I've ever seen… lifetime $13," mpvl8lt) |
| Flameshot | 12 | FOSS answer; Rosetta-only on Apple Silicon is its drag |
| ScreenFloat | 10 | Floating/library specialist; "got an excellent update last year" (m9gcv96) |
| Clop | 10 | Compression sidekick ("shottr + clop") |
| Xnip | 9 | "Most polished free"; wins on scrolling reliability |
| Capto | 8 | Setapp-world also-ran |
| Dropshare | 6 | Upload/sharing specialist |
| TextSniper | 5 | OCR specialist that coexists with both leaders |
| iShot (Pro) | 5 | Chinese freemium; long screenshots |
| QuickRecorder | 5 | Free video recorder pairing with Shottr |
| Snipaste | 4 | Cross-platform free pin-centric tool |
| Greenshot | 4 | Windows habit carried over |
| Skitch | 3 | Dead, missed |
| Lightshot | 3 | "Freezes the screen" fans |
| ShareX | 3 | Windows envy benchmark ("absolute goat") |
| Monosnap | 3 | Free-with-caveats |
| Xnapper | 1 in comments (more in submissions) | Pretty-screenshot/backdrop niche; bought on AppSumo $5 |
| Others seen once | — | Zight, Zipshot, Capcha, Teampaper, Folge (training guides), McScreenShot, Snappr, Tella, Jumpshare, Loom, Screen Studio |

Adjacent pairings that define the power-user stack: Raycast (launcher + screenshot search), Maccy/Alfred clipboard, Obsidian/Notion paste targets, PowerPoint/Slack/Jira as destinations.

## 11. Pricing sentiment (evidence for the pricing decision)

- **Subscription is a slur in this community.** "I hate subscriptions with a passion" (top-voted 464↑ app-list post, 1jea4ua); Setapp threads full of "I'd rather own my software" ("there's no way I am subscribing to Setapp," mhdk9jh; "I started with SetApp and then ended up just purchasing life time licenses," mhfrqmj). TechSmith's subscription pivot is cited as a defection trigger.
- **CleanShot's $29 + 1-year-updates is tolerated by lovers, hated by pragmatists**; the *bug-fix-behind-renewal* framing is the reputational wound. Black Friday 50% sales ($14.50) and AppSumo giveaways are well-tracked deal events (r/AppHookup threads; "I only paid like $15 for two years of use now," lzfz72u).
- **Shottr's $8→$12 price increase (Oct 2024) produced a wave of goodwill purchases, not anger**: "Still a fantastic price for a fantastic app. Life got more expensive, can't blame the devs." (lr241nj); "I'm sure the developer is loving all these FOMO purchases :P" (lr2oliy); "Even if it costs $12 lifetime, I think it's a fantastic price!!!" (lr0vx96). Lesson: transparent, modest one-time pricing with a "support the dev" narrative converts this audience.
- **WTP ceiling signals:** "Would probably buy it for 10$ one time" (Setapp user of CleanShot, mm6axx vicinity — permalink mm6... in 1jur1n1: debruehe); "$12-15 sounds good" (mm7xhsz); suggested one-time $15–20 for a lean competitor positioned "budget product, but *without the bloat*" (mm57zz9). Meanwhile "pay DOUBLE" threads show beloved tools have pricing headroom *after* love is earned.
- **Setapp is a real acquisition channel** for CleanShot ("Cleanshot via Setapp. Otherwise I would still be using Shottr") and frequently the justification for the whole subscription.
- **Per-seat friction matters**: multi-Mac households/work+personal setups are common; one-Mac licenses actively push people to Shottr.

## 12. Theme loudness ranking (rough corpus counts)

Across ~1,200 comment-body lines in harvested threads (ordinal guide only):

| Theme | Rough mentions | Verdict |
|---|---|---|
| Free / price / value-for-money | 60+ | LOUD — every thread |
| Cloud/upload/share-link | ~38 | LOUD but polarized (love it or call it bloat) |
| Pin/float | ~38 | LOUD — and under-marketed by incumbents |
| Annotations quality/speed | ~34 | LOUD |
| Speed/lightweight | ~33 | LOUD |
| Scrolling capture | ~30 | LOUD — single biggest head-to-head differentiator |
| OCR | ~27 | LOUD-ish; multi-language is the unmet edge |
| License/subscription/renewal anger | ~21 | LOUD per-capita (highest emotional intensity) |
| Blur/redact | ~14 | MID — privacy/redaction is a real job (video redaction PSA thread too) |
| Setapp | ~9 | MID |
| Backdrop/pretty backgrounds | ~8 | MID — but viral in "pay double" posts |
| Ruler/color picker/measure | ~7 | NICHE but beloved by designers |
| Library/multi-shot management | ~6 threads' worth | NICHE in volume, DEEP in pain (ex-Snagit users have nowhere to go) |

## 13. Additional VOC quote bank (misc, for landing-page language)

- VOC (use-case framing): "Working with computers + people = the need to explain things with little arrows or even videos a hell of a lot of the time." (https://reddit.com/r/macapps/comments/1jxlau1/screenshot_curiosity/mmw2zpp/)
- VOC: "Plain screenshots don't tell the user where to look, in what order, or why, so of course the recipient has follow-up questions. That's exactly what these tools are there to fix." (https://reddit.com/r/macapps/comments/1jxlau1/screenshot_curiosity/mmtjrcz/)
- VOC: "I find my friends and colleagues rarely open links or download PDFs I send; an image gets looked at almost instantly. So screenshots have become my default sharing method." (https://reddit.com/r/macapps/comments/1jxlau1/screenshot_curiosity/mmtbtxt/)
- VOC (frequency): "Only if you do it frequently like I do (like 20 screenshots per day), then I would say it makes sense. Then again Shottr pro is $12, in that case for me it's worth it" (https://reddit.com/r/macapps/comments/1iu8s5o/what_screenshot_app_do_you_use/mdyxtt9/)
- VOC (jobs): "my job requires me to do lots of beautiful screenshots (with arrows, blurs etc) and I find the native screenshot app is not really capable of doing those things" (mdyrmnj)
- VOC (the comparison-shopper's regret): "Shottr - A pretty good one time purchase screenshot tool… however after I bought it I saw there was Cleanshot X, I'm still not sure Shottr was the smartest choice over Cleanshot, but pretty good nonetheless." (https://reddit.com/r/macapps/comments/1i748b1/rate_my_mac_apps_setup/)
- VOC (pricing psychology): "People who want the best possible screenshot app will get it. Those satisfied with just 'pretty good' will get Shottr. 95% of users will be happy with the built-in options." (mm569r9)
- VOC (Windows refugee): "insane that mac doesn't have sharex and you gotta pay for the 'equivalent'" (mm4vmtp)
- VOC (privacy/redaction job): "psa: redact sensitive info in your video content with cleanshot… ip addresses in your terminal logs, customer names, your email address, api keys" (https://reddit.com/r/buildinpublic/comments/1jrs011/)
- VOC (delight benchmark): "OMG the Shottr app is so useful! My first snip" (https://reddit.com/r/u_Sea_Strawberry_11/comments/1k9l4b6/)
- VOC (speed bar): "Also using it on a Mac, yes 1 to 2 seconds is a no go these days. That's almost like lunch break" (m3l1ygt)
- VOC (what a "merge Snagit+CleanShot" product would be): "Imagine you use the screenshot tool, and immediately have access to all other screenshots. You can click from screenshot A to B, make annotations here… then maybe you merge them. It's all within the app… SnagIt did that part right" (https://reddit.com/r/macapps/comments/1hl3cmh/which_tool_merge_snagit_and_cleanshot_fast_and/m3kp7e2/) — the thread title itself is a product spec: "fast and sleek as Cleanshot, library like Snagit."
- VOC (annotation spec): "With shotr… you can annotate directly in the window that pops up. And it has shortcuts for annotation which preview lacks… copy pasting an annotated screenshot takes a fraction of the time." (ky69egq)
- VOC (file size job): "I hate these screenshots that are >2MB when the same JPEG which is <250Kb can be as clear as the former." (m9hv971)
- VOC (save-location job): "Native app… remembers the last chosen location for saving and I can easily change between saving locations… I think no other 3rd party app even comes closer." (mdybtki)
- VOC (Shottr free-tier honesty): "I forgot I was using Shottr for free (which is amazing because the splash screen is always there). Finally ended my infinite free trial." (lr4s9wy)
- VOC (donation culture): "I purchased this app just as a thank you for long screenshots and excellent OCR, to the dev." (mcmhnal)
- VOC (skeptic to convert): "what extras do other apps bring to the table that I didn't even realise I couldn't live without? ;)" (mdydp0t)

## 14. Implications for our product (analyst synthesis, grounded in the above)

1. **Positioning slot that's actually open:** "fast and sleek as CleanShot, library like Snagit" + honest lifetime pricing + multi-Mac license. Nobody owns *organized screenshot memory* (library, search, OCR-indexed history). CleanShot's team has reportedly declined to build it for years.
2. **Scrolling capture must be flawless at launch** — it is the most-litigated feature in every comparison; Shottr's wobbliness here is the #1 reason people upgrade to CleanShot.
3. **License design is marketing.** Lifetime or transparent maintenance pricing, 2–3 Macs per license, and a public "bug fixes are always free" pledge would directly weaponize CleanShot's biggest wound and match the community's ethics. Avoid the word "subscription" anywhere near the core tier.
4. **Local-first v1 is defensible** — "no cloud bloat" has a vocal constituency and a corporate-trust angle (Shottr got banned at a company over its upload feature) — but catalog cloud-link sharing for v2: it's the single CleanShot feature business users call "crucial," and the instant-link-in-clipboard flow is the spec to match.
5. **Don't price-fight Shottr.** $12 lifetime with a generous free tier and dev-goodwill halo is unbeatable at the low end; community veterans explicitly warn entrants off pure-cheaper plays. Earn premium via polish + the library/organization gap + flawless scrolling; $15–29 one-time is the corridor the corpus supports.
6. **Sleeper features to ship and market loudly:** pin/float (with multi-pin composition), capture-previous-area with visible region preview (explicit Shottr complaint), auto-numbered annotation steps, real blur (not pixelate-only), re-editable annotations, multi-language OCR, file-size-conscious output controls, custom save locations.
7. **Top-of-funnel objection to answer on the landing page:** "⌘⇧5 already does this." The corpus's best answers: speed (fewer clicks to annotated-and-pasted), annotations that look good, scrolling capture, pinning, OCR — show, don't tell.
8. **Reddit channel notes:** r/macapps is the kingmaker venue; app-list posts and price-change announcements are the recurring high-engagement formats; the "Shottr price increase" thread shows a dev's transparent post converting fence-sitters en masse. Dev responsiveness (Max/Shottr) is itself a marketed feature.

## 14b. Addendum: the canonical head-to-head rundown (2023 thread, still-cited)

From "Cleanshot X vs Shottr" (r/macapps, Feb 2023, https://reddit.com/r/macapps/comments/10zm6xg/) ⚠️ 2023 — details may be stale but this framing persists in 2025 threads:

- VOC (the most balanced comparison in the corpus): "Both are terrific utilities. Shottr feels more like a pro tool and Cleanshot is an app that I would install on my mom's computer without thinking twice… video recording: only Cleanshot does it… precise screenshots: Shottr 5+ (zoom the entire image before crop)… Shottr can remove things from the image, Cleanshot can't… cloud upload: both have it, Shottr is harder to setup, Cleanshot charges extra for unlimited storage… **Cleanshot feels fancy at first and clunky after a while, Shottr is less eye catching but more straightforward.**" (https://reddit.com/r/macapps/comments/10zm6xg/cleanshot_x_vs_shottr/j8c73a4/)
- VOC (CleanShot pick rationale): "Cloud Integration for sending screenshots… when I need to send media on a chat that does not support it… The preview zoom when taking screenshot allows for pixel perfect screenshot, Shottr does not have it. The markup tools in Cleanshot are fantastic… Great integration with Pixel Snap 2." (https://reddit.com/r/macapps/comments/10zm6xg/cleanshot_x_vs_shottr/j8b22e1/)
- VOC (one-machine license again): "I paid for a personal license on my work MBP but it only covers one machine. I then use Shottr for the odd screenshot here and there on my personal laptop." (https://reddit.com/r/macapps/comments/10zm6xg/cleanshot_x_vs_shottr/j85hkyz/)
- VOC (Shottr cloud trust concern, the other side): "anything going into the cloud should be treated with caution, this rubs me the wrong way for some reason. Guess I'll give CleanShot a try; I've been a long time SnagIt user… [Snagit] just doesn't have a clean feeling on macos." (https://reddit.com/r/macapps/comments/10zm6xg/cleanshot_x_vs_shottr/je555lb/)
- VOC (gratitude economy): "Been using and enjoying Shottr Free for a couple years and just decided that purchasing the Friend's Club… was well deserved by the creator. It's a wonder how Apple hasn't implemented even a fraction of these free features… into the built-in screenshot app." (https://reddit.com/r/macapps/comments/10zm6xg/cleanshot_x_vs_shottr/jukj2ab/)

And from "Snagit/Camtasia going subscription-only model" (r/macapps, Jun 2024, https://reddit.com/r/macapps/comments/1d80esl/):
- VOC: "There are so many free alternatives to SnagIt, it really doesn't make sense to go subscription for that… it is just a local screen recording service!" (l77i4d4)
- Displacement recs in-thread: Shottr ("I use shottr too and I love it"), Zight, CleanShot, Screenflow, Canvid — confirming Snagit's subscription pivot (fall 2024, [OBSERVED] via linked TechSmith support article) as a live customer-displacement event.

## 15. Source thread index (primary harvested threads)

| Thread | Sub / date | Why it matters |
|---|---|---|
| What CleanShot X features do you actually use? | r/macapps 2025-04 (1jur1n1) | Feature-usage census + builder advice |
| What screenshot app do you use? | r/macapps 2025-02 (1iu8s5o) | 100-comment recommendation census |
| is there anything better than shottr | r/macapps 2025-01 (1iaysxg) | Shottr-centric landscape |
| is there anything better than shottr? after 3 months | r/macapps 2025-05 (1kdcjl3) | Redux; Longshot rising |
| Screenshot quality: Shottr vs Clean Shot X | r/macapps 2025-03 (1j87ewh) | Quality/dpi complaints |
| shottr and kap or cleanshot x? | r/macapps 2024-11 (1h1oyuz) | Bundle-vs-suite decision |
| There will be a price increase for Shottr / Shottr price goes up | r/macapps 2024-10 (1fzaomz, 1fzag7u) | Pricing sentiment goldmine |
| Seeking Advice: ScreenFloat 2 vs Snagit vs CleanShot X vs Shottr | r/macapps 2024-04 (1bvo3ms) | 4-way comparison; native-tools debate |
| Which tool? Merge Snagit and Cleanshot | r/macapps 2024-12 (1hl3cmh) | The library gap, spelled out |
| Any Shottr alternative? Shottr got banned at my company | r/macapps 2024-11 (1go4d6b) | Corporate trust issue |
| Screenshot Curiosity | r/macapps 2025-04 (1jxlau1) | Why people screenshot at all (use cases) |
| My list of apps I'd pay DOUBLE for | r/macapps 2025-04 (1k9af1c, 59↑) | WTP signals; Shottr love |
| CleanShot for Mac is Incredible (Obsidian) | r/ObsidianMD 2025-05 (1km688x, 60↑) | Cross-community praise + price pushback |
| Shottr 1.8 Released | r/macapps 2024-09 (1fssvlt) | Update-cadence frustration |
| I made an open-source alternative to Jumpshare and CleanShot X | r/macapps 2025-04 (1jtpoow, 53↑) | What people demand from a replacement |
| Cleanshot X vs Shottr | r/macapps 2023-02 (10zm6xg) ⚠️ pre-2024 | Canonical head-to-head rundown |
| Snagit/Camtasia going subscription-only model | r/macapps 2024-06 (1d80esl) | Snagit displacement event |
| Best Cleanshot X Alternative? | r/macapps 2021-12 (rm5s3w) ⚠️ pre-2024, stale but long-lived | Evergreen alternative-seeking |
| Need a cheaper alternative to Snagit for Mac | r/macapps 2022-01 (s4090o) ⚠️ stale | Snagit price refugees |
| Best apps on Setapp? | r/macapps 2025-03 (1j9j750) | Subscription-aversion culture |
| Cleanshot X app size / memory threads | r/macapps 2025 (1jrelxg, 1ivcmw8) | Perf grumbles |
| Shottr bug threads | r/macapps 2025 (1joxuu7, 1itxpc4, 1iz7avc, 1kftk6i, 1iob1vr) | Defect inventory |

*(All scores shown by PullPush for comments default to 1 — Reddit score data is unreliable in this archive; submission scores are accurate as-crawled.)*
