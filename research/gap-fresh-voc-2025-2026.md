# Fresh Community Sentiment: Mac Screenshot Apps, mid-2025 → June 2026
### (Filling the 13-month post-PullPush blind spot)

**Research date:** 2026-06-09
**Window covered:** 2025-05-15 → 2026-06-09 (everything cited below is post-May-2025 unless flagged)
**Sources & method:** PullPush is dead for this window as expected. Reddit data was recovered via the **Arctic Shift archive API** (arctic-shift.photon-reddit.com), which indexes r/macapps through June 2026 — full comment sets pulled for ~20 key threads. HN via Algolia API (date-filtered `created_at_i > 2025-05-15`). Plus official changelogs/pricing pages (tagged [OBSERVED]), MacRumors, mjtsai.com, Lobsters, and web search. Reddit.com itself blocks all direct fetching (403 on www/old/api + jina proxy); permalinks below are standard reddit URLs reconstructed from archive data and are clickable.

Tags: **[OBSERVED]** = seen on official page/changelog/archive data. **[CLAIM]** = a commenter/reviewer said it. **VOC:** = verbatim user quote.

---

## TL;DR — What changed in the blind-spot window

1. **The ladder held at the top but the bottom rung exploded.** "Built-in → Shottr ($12) → CleanShot X ($29/Setapp)" is still the spine of every recommendation thread, but 2025–26 brought a flood of new entrants — open-source clones (macshot, Bettershot, Screendrop, ShotX, Scap), cheap App Store apps (Deskeen, Longshot, iSnapture $0.99), and AI-workflow tools (LazyScreenshots, Vibeshots). Free OSS "CleanShot clones" now get 76–107 upvote launches in r/macapps.
2. **Shottr v1.9 (Nov 2025) was a hit (150-upvote thread) and S3 upload partially defused "no cloud" — but the new #1 complaint is unambiguous: no video/GIF recording.** That is now the single feature keeping paying users on CleanShot X.
3. **CleanShot X shipped only one feature release (4.8, May 2025) in the entire 13 months; everything after was bug fixes + a Tahoe re-skin (4.8.5, Dec 2025).** "Is the renewal worth it this year?" is now a recurring thread theme; the "bug fixes behind paid renewal" anger is documented with screenshots from the dev's own support replies.
4. **Pricing events:** CleanShot BF 2025 = 30% off ($20.30) / renewal ~$13 / 50% via Unclutter bundle ($14.50); Shottr BF = $9; Setapp launched single-app purchases & standalone subscriptions Mar 3, 2026 to a largely cynical r/macapps reception ("a middleman taking money from small devs").
5. **The fastest-growing job is screenshot→LLM.** Multiple new tools explicitly market "paste into Claude/Cursor/Figma" workflows; HN users describe Shottr-OCR→Claude pipelines; r/macapps users annotate screenshots specifically "when I need AI help with something."
6. **AI is a double-edged sword in this community:** "You had me at 'AI: none'" gets upvotes, and vibe-coded screenshot apps get brutal backlash — but *local* AI for screenshot search/organization is welcomed.

---

## Q1. Has the recommendation ladder shifted since May 2025?

### The spine is intact
The Feb–Mar 2026 mega-thread **"Shottr vs CleanShot X in 2026. Which one are you actually sticking with?"** (r/macapps, 2026-02-27, score 54, 112 comments — https://www.reddit.com/r/macapps/comments/1rfyugm/shottr_vs_cleanshot_x_in_2026_which_one_are_you/) reads exactly like a 2024 thread: Shottr for value, CleanShot for polish/recording.

- VOC: "You're going to get a lot more people telling you to use Shottr, because it's cheaper. Cleanshot X is one of the most polished apps I've used. I don't mind paying a little more for something I use 10-20 times a day." (u/OneWeirdTrick, 2026-02-28, https://www.reddit.com/r/macapps/comments/1rfyugm/shottr_vs_cleanshot_x_in_2026_which_one_are_you/o7tov2s/)
- VOC: "shottr for 95% of my use. the scrolling capture is the one thing cleanshot does noticeably better, but I'm not paying a subscription for one feature." (u/parica99, 2026-03-06, https://www.reddit.com/r/macapps/comments/1rfyugm/shottr_vs_cleanshot_x_in_2026_which_one_are_you/o8y4ypt/)
- VOC: "Shottr. $12, does everything I need, and no subscription. The OCR and color picker alone are worth it." (u/Slight_Yesterday5484, 2026-02-28, https://www.reddit.com/r/macapps/comments/1rfyugm/shottr_vs_cleanshot_x_in_2026_which_one_are_you/o7vg3gk/)
- VOC: "I tried both and I really wanted to like Shottr but CleanShotX is just so much better. It had way more features and feels native to the point I can forget it's not part of the Mac experience." (u/PrivacyStack, 2026-02-27, https://www.reddit.com/r/macapps/comments/1rfyugm/shottr_vs_cleanshot_x_in_2026_which_one_are_you/o7pvx7q/)
- Counter-view on Shottr-as-replacement: VOC: "People always mention Shottr as a Cleanshot X replacement, and it just isn't. Yeah it has many of the same features, but not all of them and it's not nearly as user friendly in its workflow." (u/AmazingVanish, 2026-05-25, https://www.reddit.com/r/macapps/comments/1tmn04u/what_apps_from_setapp_do_you_think_are_worth/onpf8nc/)

### What actually changed: a swarm of new entrants (all post-May-2025)
[OBSERVED] from r/macapps launch threads & HN:

| Entrant | Date | Model | Traction signal |
|---|---|---|---|
| **Deskeen 2** | Sep 8, 2025 | ~$5–8 one-time, App Store | Launch thread score 107 / 99 comments (https://www.reddit.com/r/macapps/comments/1nbsesz/); repeatedly recommended as cheap CleanShot alt through 2026; "CleanShot X => Deskeen" replacement lists |
| **macshot** (OSS, native) | Mar 24, 2026 | Free, open source | Score 76 / 100 comments (https://www.reddit.com/r/macapps/comments/1s2pz3n/); dev ships requested features in hours; "Goodbye CleanShotX" testimonials |
| **Longshot** | ongoing, big push Mar–May 2026 | $4.99/yr or $12.99 lifetime, App Store | Score 26 thread (https://www.reddit.com/r/macapps/comments/1s27jjc/); recommended organically in Shottr nag thread |
| **Bettershot** (OSS) | Jan 2026 | Free/OSS | Show HN (https://news.ycombinator.com/item?id=46644356) |
| **Screendrop** (OSS, BYO R2 cloud) | May 2026 | Free/OSS | Show HN (https://news.ycombinator.com/item?id=48321189) + r/macapps posts |
| **ShotX** (OSS) | Apr 2026 | Free/OSS | r/macapps (https://www.reddit.com/r/macapps/comments/1sxifwv/) |
| **Scap** | Feb–Mar 2026 | paid, native | v1.1 thread score 18 (https://www.reddit.com/r/macapps/comments/1s4xdx7/) |
| **iSnapture** | Mar 2026 | $0.99 one-time, 560KB | dev-promoted as "less than a coffee" (https://www.reddit.com/r/macapps/comments/1rfyugm/.../oda1csy/) |
| **LazyScreenshots** | 2025–26 | paid | Marketed at "vibe coding & QA" — auto-paste into Claude/Figma (https://www.reddit.com/r/macapps/comments/1rfyugm/.../oc243mr/) |
| **Vibeshots** | May 2026 | ? | "a screenshot tool for people who paste into AI all day" (https://www.reddit.com/r/macapps/comments/1tmixgj/) |
| **ScreenSnap Pro** | Aug–Sep 2025 | $19 lifetime + cloud | Vibe-coded; community backlash (see Q5-AI) |
| **Mirowl** (screenshot organizer) | Jun 2026 | local-first, Rust/Tauri | "Screenshot Graveyard" pitch (https://www.reddit.com/r/macapps/comments/1tvh7bc/) |
| **EasyShot** | Mar 2026 | ? | Show HN (https://news.ycombinator.com/item?id=47436732) |

- VOC (the mood this created): "I would check this out. The days of paid screenshot software may be at an end. [github.com/sw33tLie/macshot]" (u/NJRonbo, 2026-04-22, https://www.reddit.com/r/macapps/comments/1rfyugm/shottr_vs_cleanshot_x_in_2026_which_one_are_you/ohlve7u/)
- VOC (DIY-with-AI threat, HN): "In the last few months I've used Claude Code to build personalized versions of Superwhisper (voice-to-text), CleanShot X (screenshot and image markup), and TextSniper (image to text). The only cost was some time and my $20/month subscription." (HN, 2026-01-06, https://news.ycombinator.com/item?id=46515882)
- VOC (fatigue): "If this is another goddamn screenshot app….oh" (u/apexinnovator, 2025-09-23, https://www.reddit.com/r/macapps/comments/1nojld1/this_screenshot_app_is_worse_than_shottr/nftatuj/) — and "nooooooo lol. we've reached peak macapps omg" (u/Interesting-Head-841, 2025-08-26, https://www.reddit.com/r/macapps/comments/1mzxv63/building_the_best_screenshot_taking_mac_app/naqzjov/)

### Longshot: modest rise, not a ladder change
- [OBSERVED] Only one significant Longshot thread post-May-2025 (Mar 24, 2026, score 26) — vs. its 2024 launch hype. Pricing $4.99/yr or $12.99 lifetime, App Store distribution.
- It does get organic referrals: VOC: "I purchased shorttr license, but switched to this finally: [Longshot]… also a paid app" (u/iftttalert, 2025-10-06, https://www.reddit.com/r/macapps/comments/1nz52c4/shottr_becomes_nagware_if_you_dont_pay/ni0bcpv/); "I agree, Longshot is great and also supports screen recording (video/screencast)." (u/theHaxxor, same thread, ni11a8k/)
- VOC (conversion): "I've been using Longshot for quite some time now. I bought it the same day I downloaded it. I switched from CleanShot X to Longshot. It's a fantastic app I recommend." (u/ApeCheeksClapper, 2026-03-24, https://www.reddit.com/r/macapps/comments/1s27jjc/longshot_scrolling_screenshots_offline_ocr_and/oc7nioc/)
- [CLAIM] Perceived as "mostly targeted at the Chinese market" by one commenter (https://www.reddit.com/r/macapps/comments/1s27jjc/.../oc82a3b/). A user asked the dev for a **Windows port** (oct00ed/) — unanswered ambition overlap with ours.
- **Xnip: effectively faded.** Zero new r/macapps posts since 2019 [OBSERVED via archive search]; only residual mentions in lists (e.g., MacRumors thread below).

### Other ladder notes
- **ScreenFloat 2.x had a genuine resurgence** as "a different kind of screenshot app" (library/organization angle) — dedicated review thread 2026-03-07, score 23 (https://www.reddit.com/r/macapps/comments/1rmw0p1/). See Q5-organization.
- **MacRumors "Screenshot App?" thread (Nov 25–26, 2025):** recommendations = built-in, CleanShot X ("extra features", "currently running a Black Friday sale"), Shottr, Xnip, Flameshot, SnagIt, ScreenFloat. No Longshot. (https://forums.macrumors.com/threads/screenshot-app.2471906/) [OBSERVED]
- **TidBITS/Engst (via mjtsai, Jan 12, 2026):** multi-app reality — Engst uses ScreenFloat (borders), CleanShot X ("the ability to combine screenshots… not found elsewhere"), and built-in for menus; commenter: "CleanShot X is one of the best Mac utilities I've used." (https://mjtsai.com/blog/2026/01/12/mac-screenshot-utilities/) [CLAIM]
- Niche tools keep absorbing the video job Shottr lacks: **Kap**, **Claquette**, **Gifski**, **Screen Studio**, **Cap** (open source, "Free for personal… $59 lifetime" per commenters, https://www.reddit.com/r/macapps/comments/1rfyugm/.../o7qak3b/).

---

## Q2. Shottr v1.9 / v1.9.1 reactions

### [OBSERVED] Facts
- **v1.9 (Nov 24, 2025):** S3-compatible upload (Amazon/CloudFlare/Backblaze), magnifier/zoom callout, hand-drawn annotation styles, bendable arrows, object snapping, **"macOS scrolling capture workaround deployed,"** clipboard-delay fix. (https://shottr.cc/newversion.html)
- **v1.9.1 (Dec 17, 2025):** more S3 providers (Tencent, Yandex, Minio), fixes incl. "S3 upload failures on non-Gregorian calendar systems," app-freeze fix. Still the current version as of June 2026 — i.e., **no release in ~6 months**.
- Tiers [OBSERVED via thread]: **Basic $12** (5 devices per user comments) and **"Friends Club" ~$30** (early/experimental builds). Site FAQ: free forever with periodic purchase prompts; dev "plan[s] to add more features and raise its price in the future."

### Reception: enthusiastic, but the wishlist scream is VIDEO
Release thread score 150, 40+ comments (https://www.reddit.com/r/macapps/comments/1p5ayxb/shottr_v19_is_here/). The download server fell over on day one ("I think the site got hit too hard that the server is down.. 😢", nqhuzsc/).

- VOC (top wish, 10 pts): "Amazing! I wish we also had a video recording with voice capture feature." (u/yevheniikovalchuk, 2025-11-24, https://www.reddit.com/r/macapps/comments/1p5ayxb/shottr_v19_is_here/nqhy38h/)
- VOC (9 pts): "Wish they'd add GIF/video capture 😔 Makes me wonder what the demo GIF in the patch notes was made with!" (u/sojtucker, 2025-11-24, nqhy52u/)
- VOC: "love shottr but why oh why can it not do video capture please I'm begging you" (u/imnotdabluesbrothers, 2025-11-27, https://www.reddit.com/r/macapps/comments/1p82arx/shottr_9_for_black_friday/nr2vbd1/)
- VOC: "For realz… it's the best app, just needs video." (u/Gold240sx, 2025-11-27, same thread, nr4x07h/)
- VOC (Cleanshot defection consideration): "Wow, that's app looks very promising. Considering move from cleanshot x. Thanks for this post." (u/rez0n, 2025-11-24, nqj6qw1/)

### Did S3 defuse "no cloud"?
**Partially.** The complaint mutated from "no cloud at all" to "no one-shortcut shareable link / no native cloud" for some, while others now see Shottr converging on CleanShot:
- VOC: "I think with the latest Shottr update (saving to cloud, both theirs - limited, and your own - unlimited) it could be going in that direction. Next update is probably video." (u/sibotix, 2025-11-28, https://www.reddit.com/r/macapps/comments/1p6nijk/cleanshot_x_2025_black_friday_sale_is_now_on/nr5teo6/)
- VOC (the remaining gap): "The one thing I actually miss is CleanShot's cloud upload — one shortcut and you get a shareable URL instantly, super handy for quick Slack screenshares." (u/7thDegreeExponent, 2026-02-28, https://www.reddit.com/r/macapps/comments/1rfyugm/.../o7t3ggd/)
- Smaller wishes in the release thread: save-to-specific-folder (nqxgnqt/), edit annotations after saving (nqoc9tz/), direct share sheet (nqjlbt9/), Mac App Store availability (nqk2mqb/), menu-bar capture bug vs CleanShot (nqk2rqz/).

### Nag / paid-tier VOC (Oct–Nov 2025)
The "Shottr becomes nagware if you don't pay" thread (2025-10-06, 40 comments, https://www.reddit.com/r/macapps/comments/1nz52c4/) shows the community overwhelmingly **defends** the dev:
- VOC (28 pts): "$12 is a fair price for what Shottr brings to the table...." (u/MC_chrome, nhznw0t/)
- VOC (14 pts): "Alternative title: I don't want to spend 12$ on an app i use daily and I'm mad." (u/arts64, nhzugxm/)
- VOC (free-tier limits, OP): "The app doesn't even work entirely if you don't pay. There's a lot of features locked behind that paywall, including backgrounds, hiding the menu bar app, and even hiding the splash screen." (u/awesomeguy123123123, nhzpw14/)
- VOC (goodwill as moat): "Plus Shottr dev seems like a good person. The fact that they let you use it free and just nag you every so often to purchase, is amazing. I'll support devs like that." (u/-Visher-, 2025-11-28, https://www.reddit.com/r/macapps/comments/1p82arx/shottr_9_for_black_friday/nr93moy/)

### The "is it abandoned?" anxiety is real and recurring
"State of Shottr?" (2025-11-15, score 28, https://www.reddit.com/r/macapps/comments/1oxo0fy/):
- VOC: "Thought it was abandoned." (u/Human-Equivalent-154, 2025-11-24, https://www.reddit.com/r/macapps/comments/1p5ayxb/shottr_v19_is_here/nqihyjt/)
- VOC (43 pts, rebuttal): "Nope, he's testing a bunch of new features in a build that came out last week, so it's definitely still a live project. :)" (u/tech5c, noyh2yx/)
- VOC (defection): "Long time Shottr User here. I moved to Clean Shot recently since Shottr didn't improve much to me anymore." (u/JJM-9, nozsmy2/)
- VOC (May 2026, post-blind-spot freshest signal): "Shottr has a fraction of the features and barely gets any updates (0 so far in 2026)." (u/Snorlax_Returns, 2026-05-25, https://www.reddit.com/r/macapps/comments/1tmn04u/.../onq3c90/)
- VOC (support black hole): "few bugs has come to my acknowledgement and I do not know how to reach him… he has kept no option to reach him!!!!!!" (u/Sh_Islam, 2026-04-22, https://www.reddit.com/r/macapps/comments/1oxo0fy/state_of_shottr/ohktzs1/)
- VOC (annotation workflow gap vs CleanShot): "in Shottr when you take an area screenshot, you cannot retain a transparent background when annotating… If somehow the annotation usability could be improved, I would then be able to completely drop CleanShot X for this. Until then, it's a clunky frustrating workflow." (u/KimbraSlice, 2025-12-10, ntd8kxp/)

---

## Q3. CleanShot X 4.8.x, Tahoe overhaul, and the "stalled development" / renewal sentiment

### [OBSERVED] Release cadence (cleanshot.com/changelog)
- **4.8 — May 27, 2025**: the one real feature release of the window (color picker, editable window screenshots w/ background editing, **horizontal scrolling capture**, rotate/flip, OCR auto-language, WebP/HEIC, multi-page print).
- 4.8.4 — Oct 15, 2025: push notifications for Cloud comments/views; +10 OCR languages.
- **4.8.5 — Dec 2, 2025: "Sleek new interface for macOS Tahoe"** + Tahoe compat fixes.
- 4.8.6 (Dec 4), 4.8.7 (Dec 22): crash/Raycast fixes. 4.8.8 — Mar 23, 2026: mic/window-render/emoji fixes.
- **No 4.9 or 5.0 through June 2026.** Pricing unchanged: $29 one-time +1yr updates, $19/yr renewal, Cloud Pro $8–10/mo [OBSERVED cleanshot.com/pricing].

### Sentiment: love for the product, growing renewal skepticism
The product itself still earns superlatives:
- VOC: "i use Cleanshot X since 2022. it feels like Apple built it… there is no pressure to renew the license and even then it's an affordable price imo" (u/sleekLion, 2026-03-01, https://www.reddit.com/r/macapps/comments/1rfyugm/.../o81izl6/)
- VOC (HN): "CleanShot X is extremely good, in case anyone is looking for more endorsements." (2025-11-05, https://news.ycombinator.com/item?id=45826157)
- VOC (HN): "CleanShotX's tools are about 1 billion times faster/easier to use [than built-in]… about 99% of bug tickets I enter have a CleanShotX screenshot attached." (2025-11-05, https://news.ycombinator.com/item?id=45826010)

But the **"what did my renewal buy me this year?"** question got sharper because of the thin 2025 changelog:
- VOC: "This year the only major update was back in May, when they introduced horizontal scrolling and a few other things." (u/Black-PizzaClaw676, 2025-11-26, https://www.reddit.com/r/macapps/comments/1p6nijk/cleanshot_x_2025_black_friday_sale_is_now_on/nqwrtpp/)
- VOC: "Love the app, maybe it makes sense to renew every 2-3 years? My first year is ending soon and I cannot think of any new features that I would want." (u/8Rice, 2025-11-25, nqrq6tb/)
- VOC: "I'm not sure what is groundbreaking enough to renew over the past year, but I am still enticed, just to get the deal and support the development." (u/MReprogle, 2025-11-25, nqsihx5/)
- VOC (from what I can see they don't update very often): "V3's last update was on 8th Nov 2021. TBH I use it so much everyday I'm happy to pay the fees once a year on Black Friday sale 😂" (u/davidtse916, 2025-12-16, nuers9f/)

### License-renewal anger ("bug fixes behind renewal") — alive and documented
- VOC: "am i understanding the one-time payment correctly? you purchase the app, and then after a year you stop receiving updates unless you pay for it? so it's a one-time-payment subscription..that's. insane. i'd never support a product with such exploitative practices." (u/Golden_Antt, 2025-12-16, https://www.reddit.com/r/macapps/comments/1p6nijk/.../nuef307/)
- VOC: "These yearly renewals for some apps seems like a backdoor subscription and the new features weren't compelling enough to make me upgrade." (u/Zoraji, 2025-11-26, nqtk3cj/)
- VOC: "sucks you have to renew license all the time, i get it's for dev but it's just a dressed up sub model" (u/unfnshdx, 2025-05-28, https://www.reddit.com/r/macapps/comments/1kxdox3/cleanshot_x_added_auto_scrolling_and_horizontal/muofypz/)
- u/nez329 posted screenshots of CleanShot support confirming **bug fixes require an active update plan** and that old versions eventually break: "It does not work indefinitely, unfortunetly." + "consider not only adding new features but also **fixing existing bugs that require changes to resolve specific issues**" (2025-11-26, nqtujmp/ and nqttngf/). Another user pre-emptively emailed support to confirm Ventura support before renewing (nqw59f5/).
- The defense is equally loud: VOC: "It's a good middle ground, consumers don't want a subscription and the developers can't afford to offer perpetual updates. I only upgrade when there's a feature that's useful to me." (u/defenestrate_urself, 2025-11-25, nqryw6l/) — and on HN, CleanShot's pricing page is held up as the *model* for honest one-time+updates wording (2025-05-25, https://news.ycombinator.com/item?id=44091016).
- Single-Mac licensing is a recurring sore point — see Q5.
- Cloud upsell irritation: VOC: "I don't want to pay anymore to have their TRASH CLOUD PRODUCT shoved in my face." (u/BTForIT, 2026-01-10, https://www.reddit.com/r/macapps/comments/1p6nijk/.../nyusvet/) — and HN: "Honestly the cloud hosting aspect is overpriced but it does make sharing a picture/video super easy" (2025-11-05, https://news.ycombinator.com/item?id=45826010).

### Tahoe (macOS 26) specifics
- [OBSERVED] Official Tahoe redesign Dec 2, 2025 (4.8.5; X announcement: https://x.com/CleanShot/status/1996617794587340853). Beta-period breakage threads from June 2025 (https://www.reddit.com/r/macapps/comments/1l8hosq/): VOC: "I am [on the beta] and it's driving me nuts! I need CleanshotX for work :'(".
- [CLAIM] Lingering Tahoe bugs: HN, 2026-03-02: "there's a persistent bug where taking a screenshot with CleanShot somehow resets the DisplayPort driver and everything flips out for a minute… Infuriating." (https://news.ycombinator.com/item?id=47224675)
- [CLAIM] Recording reliability reports cluster in the window: "Screen recording silently stops after 12-18 minutes" (2026-01-04, https://www.reddit.com/r/macapps/comments/1q43q0e/), "45-minute export for a 55-minute 2K recording" (2026-02-15, 1r5g5pn/), mic-vs-system audio level issues (2026-01-26, 1qncx2n/), multi-track audio not separating (2026-02-15, 1r5gk0k/).
- [CLAIM] Cosmetic Tahoe lag noted by bloggers: CleanShot's squared window corners clash with Tahoe's rounded corners (leancrew.com, Oct 2025, https://leancrew.com/all-this/2025/10/mac-screenshots-for-the-nth-time/).
- **Net: the "development has stalled" narrative did not disappear — the Tahoe re-skin muted it briefly, but a year with one feature release sharpened the renewal-value question.** No AI features shipped or announced by CleanShot in this window [OBSERVED — changelog].

---

## Q4. Pricing events & reactions (mid-2025 → Jun 2026)

1. **CleanShot X Black Friday 2025** (Nov 25–Dec 1, 2025) [OBSERVED]: 30% off Basic ($29→$20.30), 50% off first year of Pro; renewals also discounted (~$13 — "the discount applies to the update renewal price too… I paid about $13 for my renewal", 26 pts, https://www.reddit.com/r/macapps/comments/1p6nijk/.../nqrl8v0/). Deeper cut via **Unclutter bundle at ~$14.50** (50%) which redditors openly routed around the official sale (26 pts, nqrxjj7/). Also in MacStories' **Editors' Choice 12-app bundle** ($76 for 12 apps incl. DaisyDisk, Default Folder X). Sale thread score 89/64 comments. One power user: "I just added 2 more years of renewals ($13/year for 2 licenses)… I'm good until 2030 now." (nqtoe47/)
2. **Shottr Black Friday 2025**: $12 → **$9** (thread score 62, https://www.reddit.com/r/macapps/comments/1p82arx/). Community pushback on even discounting: "It's already just $12. How low are you expecting it to go?… Fantastic product that is underpriced imo." (u/Warlock2111, nqjnlu0/ + nqw4ia7/). Friends Club ($30) was *not* discounted, to some disappointment (nr2yz4c/).
3. **AppSumo "Mac essentials" bundle** (surfaced Jan 2026): CleanShot Cloud Pro first year $39 (https://www.reddit.com/r/macapps/comments/1p6nijk/.../o1srv7x/).
4. **Setapp single-app purchases + standalone subscriptions — March 3, 2026** [OBSERVED: 9to5Mac https://9to5mac.com/2026/03/03/setapp-now-lets-users-buy-or-subscribe-to-select-apps-individually/; PR Newswire]. 60+ apps, monthly/yearly/lifetime options. r/macapps announcement thread (score 63, 33 comments, https://www.reddit.com/r/macapps/comments/1rjqygt/) was skeptical-to-hostile:
   - VOC (46 pts): "I've checked with Aldente and the purchase price through Setapp is more expensive than buying directly from the developer. So they are taking a cut...for whatever that's worth." (u/areyouredditenough, o8f3a5r/)
   - VOC (20 pts): "I just don't understand why i would ever want to pay setapp extra money for no reason?… just seems like a middleman taking money from small devs" (u/fluffy-cat-toes, o8gt253/)
   - VOC (21 pts, ex-integrator): "Setapp is a man in the middle designed to siphon money from developers at an unfair cost." (u/PromptThese5489, o8fsfua/) — telemetry/framework concerns confirmed by official u/Setappian account (o8gcxjg/).
   - Subscriber confusion/erosion through spring 2026: "why the heck am i being prompted to pay extra for these new apps despite having a subscription!?" (2026-04-28, oip5wi5/); "I am gonna go through my list of Apps I actually need/use and cancel SetApp - it is no longer worth it (to me)" (2026-05-13, oljgs7s/). One commenter referenced a Setapp **price increase** [CLAIM]: "It's cheaper to buy apps separately, especially now after the price increase." (o8lofje/)
   - Knock-on for CleanShot: in "What apps from Setapp are worth standalone purchase?" (2026-05-24, score 62, https://www.reddit.com/r/macapps/comments/1tmn04u/), **CleanShot X is the #1 most-named app to buy outright** — "CleanShot X — Indispensable for screenshots. Worth every penny." (ont37oa/). Setapp churners also report dropping CleanShot entirely for Shottr: "I don't think it makes sense to spend the money for Cleanshot when other apps do most of what it does for a lot less or free." (u/couldhvdancedallnite, 2026-03-01, https://www.reddit.com/r/macapps/comments/1rfyugm/.../o7z3zt5/)
5. **No CleanShot or Shottr list-price changes** in the window [OBSERVED — pricing pages]; Shottr's FAQ still pre-announces a future price raise. Shottr historic price context from users: "$8 a few years ago… Now it is $12, still very reasonable. CleanShotX is $30 for 1 year of updates… MUCH more expensive than Shottr." (12 pts, u/FuntimeBen, 2026-02-27, o7oxnfk/)

---

## Q5. Fresh complaints & wishlists (2025–2026)

### a) Scrolling capture reliability — still the #1 functional battleground
- **macOS 26.x broke Shottr's scrolling capture for many users** (Nov 2025): error literally says "macOS 13.5 introduced changes that prevent scrolling capture from working on this computer" while on 26.0.1 (https://www.reddit.com/r/macapps/comments/1p0ln5v/, npjrzgs/). Affected non-Chrome apps too; fixes were folk remedies (reset Accessibility permission, full reinstall, OS update). [OBSERVED] Shottr 1.9 changelog ships a "macOS scrolling capture workaround."
- Also broken on Tahoe for area screenshots in Sep 2025 (https://www.reddit.com/r/macapps/comments/1ntlkuy/).
- CleanShot's vertical+new horizontal scrolling (4.8) is cited as "noticeably better" by some (o8y4ypt/), while others prefer Shottr's: "I prefer Shottr, because of the Scrolling Capture implementation. In my opinion is better than CleanShot X in that point." (o7phv9n/). Earlier defections cite the inverse: "Shottr scrolling screenshot was finicky for me when I tried last year." (nqrr7ly/)
- Mitigating trend: "Be aware that all the browsers have full page screenshots built in now." (10 pts, o7oisjj/)

### b) Screenshot library / organization — an emerging, under-served job
- ScreenFloat 2.0 is the poster child: "Shottr doesn't create a reference library of screenshots with smart folders, tagging and search… [CleanShot] has a limited History feature. Its OCR feature set does not have the ability to act on links in text, clickable phone numbers or a text search of screenshots." (u/amerpie, 2026-03-07/08, https://www.reddit.com/r/macapps/comments/1rmw0p1/.../o98ygrn/ and o947zvd/)
- VOC: "FWIW I find Screenfloat to be excellent… it has a window that stores all your shots and does iCloud Sync… 1-time purchase. Very native, snappy and nice." (u/voltaire-o-dactyl, 2026-03-04, o8iqu5l/)
- New-app energy: Mirowl ("Screenshot Graveyard", local OCR search, Jun 2026); "Best Mac Screenshot Organizer?" (Mar 2026, 1rpxxoe/); "I built a fully automated Mac screenshot organizer with local AI" (May 2026, 1tqtfvx/); the 40,000-screenshots-wife story app (Mar 2026, 1s3e9dy/ — mocked for AI hype but 27 comments of engagement).
- VOC (wishlist): "Can it automatically tag keywords based on image content? …screenshot on Safari of a cat drinking milk outside an old countryside house → keywords: safari browser, cat, milk, countryside, house, 2025." (u/ziovelvet, 2025-08-25, https://www.reddit.com/r/macapps/comments/1mzxv63/.../nao021n/)

### c) AI features — wanted only on the community's terms
- Anti-AI-slop backlash is fierce: the ScreenSnap Pro saga (Aug–Sep 2025) — "19$ for ai code? cool" (23 pts, namwq4r/); "Just look how many AI apps have been done in past 6 months by this vibe coder" (26 pts, nfs6dur/); "this is malware, avoid downloading" (nft39cn/). A May 2026 "free CleanShot X alternative" was torched for being "vibe coded electron slop" with a copy-pasted CleanShot website screenshot (10 pts, https://www.reddit.com/r/macapps/comments/1t3awmz/.../ojtt5sr/). **"Native" is a trust signal**: "You're positioning your app as an alternative in a niche where polished native apps like cleanshot and Shottr already exist, while your app… is NOT a native app." (oju3umh/)
- VOC (anti-AI as a feature): "You had me at 'AI: none'." (u/Few_Major_8226, 2026-03-24, https://www.reddit.com/r/macapps/comments/1s27jjc/.../oc6uv8u/)
- But AI-adjacent *workflow* value is embraced: annotation-for-AI ("when I… need ai help with something, annotating it before sharing seems to help a bunch with clarity" — u/mathewharwich, 2026-02-27, o7sd8yq/; "never thought to use it and annotate with AI. Thanks for sharing!" — u/iamtechy, 2026-03-15, oaislj0/), and local AI organizers (above) get a fair hearing.

### d) Multi-Mac licensing
- VOC: "their app is tied to one mac, two mac based on pricing… after 1 year you won't get free updates, this is very limiting factor… Whereas, Shottr is only 12$… Go for shottr." (u/Sh_Islam, 2026-02-27, https://www.reddit.com/r/macapps/comments/1rfyugm/.../o7oklww/)
- VOC: "Im a cleanshot paid user, i gonna give it a try because only one mac user license is allowed :( And recurring cost every year..." (u/Sampl3x, 2026-03-28, https://www.reddit.com/r/macapps/comments/1s2pz3n/.../ocxgsp6/)
- VOC: "I think paying more is fine, but if you have to keep paying every year and pay for every device, that becomes way too expensive." (u/discoveringnature12 — thread OP, 2026-02-28, o7tucdi/)
- VOC (Shottr's edge): "Shottr. The $12 one-time for 5 devices is hard to argue with." (u/Slight_Yesterday5484, 2026-02-28, o7oxm4r/) — and users literally rotate one CleanShot seat between two Macs using ScreenFloat as filler (o92l0y1/).

### e) Screenshot→LLM workflows (fastest-growing job — confirmed)
- New tools are being built *specifically* for this: **LazyScreenshots** — "the main thing I wanted… was being super fast in switching between taking screenshot and the app I am currently working on especially when vibe coding & doing QA… CMD+Shift+2 → Take screenshot → Copy to Clipboard → Open Claude/Figma → Paste; Burst mode → copies ALL OF THEM to clipboard" (dev u/abouelatta, 2026-03-23, https://www.reddit.com/r/macapps/comments/1rfyugm/.../oc243mr/). **Vibeshots** — "a screenshot tool for people who paste into AI all day (capture, annotate, auto-blur secrets, bulk-paste)" (2026-05-24, 1tmixgj/). **Ahsk v2.1** — follow-up conversations on screenshot analysis (Dec 2025, 1pvcpcz/).
- HN evidence of the daily pipeline: "Get a screenshot app. Shottr is awesome… Paste UI on a GitHub PR. Paste Figma into a LLM. Paste bugs into Slack." (2025-08-05, https://news.ycombinator.com/item?id=44795542); Shottr OCR→clipboard→VS Code in 3 keystrokes (2025-11-11, https://news.ycombinator.com/item?id=45883631); "I use Shottr on my MacBook to immediately OCR my screenshots" (2025-12-14, id=46265479); blog/tooling wave: "Automatically Copy macOS Screenshot Path for Claude Code" (hboon.com), "How to Paste Screenshots into Claude Code" guides, SupaSidebar "Best Mac Apps for AI Coders in 2026". Anthropic-adjacent HN threads show people pasting shottr.cc/cleanshot.com share links of Claude Code sessions as a matter of course (e.g., https://news.ycombinator.com/item?id=46841459, 2026-01-31).
- Even shortcuts-and-paste speed is the stated core value: "the most valuable feature I see is the ability to capture a screenshot via shortcuts… edit with simple, easy shortcuts… then save with another quick shortcut." (2025-12-20, https://www.reddit.com/r/macapps/comments/1pr39qn/.../nv10gyb/)

### f) Misc fresh wishlists worth cataloging
- Zoom-in/magnifier demand pre-dated Shottr 1.9's magnifier: "Screenshot tool with zoom/magnifier function" (Sep 2025, 1ntk4ei/); "If only Cleanshot would offer Zoom Ins…" (o7s24x7/).
- Capture menus + area without menu-bar interference (Shottr bug, nqk2rqz/).
- Consistent window-detection cropping with padding — beloved Shottr power feature (o80w4j3/ with GIF).
- Fixed-aspect/fixed-size capture with background fill (oju19ja/).
- Save source URL with screenshot (oc7jz5b/ — "always looked for a screenshot [app] that saves the website link from which the screenshot was taken").
- OCR length limits ("I've hit the max when trying to OCR all apps in my Applications folder" — nr9xamy/), delayed-capture hotkey with adjustable >3s delay (same).
- Trust requirements for newcomers: real dev identity, trial before purchase, no opaque cloud ("advertised with cloud storage on the devs servers without any transparency in regards of encryption… Huuuge red flag 🚩" — naqmpg0/).

---

## Q6. VOC quote bank for landing-page copy (all post-May-2025, verbatim, permalinked)

### Pain — pricing/licensing
1. "so it's a one-time-payment subscription..that's. insane." — 2025-12-16 (https://www.reddit.com/r/macapps/comments/1p6nijk/cleanshot_x_2025_black_friday_sale_is_now_on/nuef307/)
2. "sucks you have to renew license all the time… it's just a dressed up sub model" — 2025-05-28 (https://www.reddit.com/r/macapps/comments/1kxdox3/cleanshot_x_added_auto_scrolling_and_horizontal/muofypz/)
3. "I'm not paying a subscription for one feature." — 2026-03-06 (https://www.reddit.com/r/macapps/comments/1rfyugm/shottr_vs_cleanshot_x_in_2026_which_one_are_you/o8y4ypt/)
4. "if you have to keep paying every year and pay for every device, that becomes way too expensive" — 2026-02-28 (…/o7tucdi/)
5. "only one mac user license is allowed :( And recurring cost every year..." — 2026-03-28 (https://www.reddit.com/r/macapps/comments/1s2pz3n/os_macshot_free_native_macos_screenshot/ocxgsp6/)
6. "I don't want to pay anymore to have their TRASH CLOUD PRODUCT shoved in my face." — 2026-01-10 (https://www.reddit.com/r/macapps/comments/1p6nijk/.../nyusvet/)
7. "Cleanshot pricing model is terrible, I won't ever purchase that!" — 2026-02-27 (…/o7q0ieo/)
8. "Hate its renew after 1 year policy; its costly and they even want people to renew for update" — 2025-11-25 (…/nqrkgvu/)

### Pain — product gaps
9. "love shottr but why oh why can it not do video capture please I'm begging you" — 2025-11-27 (https://www.reddit.com/r/macapps/comments/1p82arx/shottr_9_for_black_friday/nr2vbd1/)
10. "No screen recording kills Shottr for me. Otherwise it's a great app." — 2026-05-24 (https://www.reddit.com/r/macapps/comments/1tmn04u/.../onoy07v/)
11. "Can't take a scrolling screenshot — Unfortunately, macOS 13.5 introduced changes…' and it's weird as it says macOS 13.5, whilst i'm using 26.0.1" — 2025-11-18 (https://www.reddit.com/r/macapps/comments/1p0ln5v/.../npjrzgs/)
12. "Until then, it's a clunky frustrating workflow." (Shottr annotation vs CleanShot) — 2025-12-10 (https://www.reddit.com/r/macapps/comments/1oxo0fy/state_of_shottr/ntd8kxp/)
13. "taking a screenshot with CleanShot somehow resets the DisplayPort driver and everything flips out for a minute… Infuriating." — 2026-03-02 (https://news.ycombinator.com/item?id=47224675)
14. "Shottr has a fraction of the features and barely gets any updates (0 so far in 2026)." — 2026-05-25 (https://www.reddit.com/r/macapps/comments/1tmn04u/.../onq3c90/)
15. "I'm very weary of paying nowadays as app devs disappear quick lol. My go to was mono snapshot but it got really buggy or not updated for 26… I still miss monosnapshot and I had paid for it too." — 2026-02-27 (…/o7oz7pg/)

### Praise / aspiration — the bar to beat
16. "it feels like Apple built it… for me is a no brainer" — 2026-03-01 (…/o81izl6/)
17. "feels native to the point I can forget it's not part of the Mac experience." — 2026-02-27 (…/o7pvx7q/)
18. "CleanShotX's tools are about 1 billion times faster/easier to use… about 99% of bug tickets I enter… have a CleanShotX screenshot attached." — 2025-11-05 (https://news.ycombinator.com/item?id=45826010)
19. "Cleanshot should be bundled with osx." — 2026-02-27 (…/o7s4rhv/)
20. "Why would you use anything but Shottr on macOS?… the software is simply on a whole different level. They deserve all the fame." — 2026-01-29 (https://news.ycombinator.com/item?id=46817594)
21. "I use it so often now it's amazing I ever didn't have a screenshot tool like that before." — 2026-02-27 (…/o7sctp5/)
22. "I've had multiple people ask me what I use after I send them a screen shot and to me, that's the hallmark of a great app." — 2025-11-27 (https://www.reddit.com/r/macapps/comments/1p82arx/.../nr2thuz/)
23. "Shottr is one of the apps I use many times every day." — 2025-11-24 (https://www.reddit.com/r/macapps/comments/1p5ayxb/shottr_v19_is_here/nqit45l/)
24. "$12 is a fair price for what Shottr brings to the table...." — 2025-10-06 (https://www.reddit.com/r/macapps/comments/1nz52c4/.../nhznw0t/)
25. "This and TextSniper are probably my most used 'minor' apps that I can't live without." — 2025-11-25 (…/nqmw8dx/)
26. "Shottr - uses less system resources. The editing and annotation tools work way better and look better." — 2026-02-27 (…/o7qwt16/)
27. "Cleanshot X here simply because it has both screenshotting & screen recording in one app and it just works flawlessly everytime." — 2026-02-27 (…/o7oknb0/)
28. "the OCR text grab is surprisingly accurate, and the scrolling capture works without fussing around… try shottr first and only buy cleanShot if you hit a wall." — 2026-03-04 (…/o8m0wtv/)
29. "Plus Shottr dev seems like a good person… I'll support devs like that." — 2025-11-28 (https://www.reddit.com/r/macapps/comments/1p82arx/.../nr93moy/)
30. "I paid $8 a few years ago… Now it is $12, still very reasonable. CleanShotX is $30 for 1 year of updates… MUCH more expensive." — 2026-02-27 (…/o7oxnfk/)

### Aspiration — the new jobs
31. "being super fast in switching between taking screenshot and the app I am currently working on especially when vibe coding & doing QA" — 2026-03-23 (…/oc243mr/)
32. "Paste UI on a GitHub PR. Paste Figma into a LLM. Paste bugs into Slack or a support tool." — 2025-08-05 (https://news.ycombinator.com/item?id=44795542)
33. "when I want to select unselectable text I just do OCR with a simple and fast shortcut" — 2025-09-26 (https://news.ycombinator.com/item?id=45385811)
34. "whether someone shares code or error log as screenshot on slack, it's 3 steps: 1. cmd+opt+control+o 2. select the area 3. cmd+v in vscode" — 2025-11-11 (https://news.ycombinator.com/item?id=45883631)
35. "My screenshots go into a Screenshots album… [vs] 40,000 screenshots on her phone… all completely impossible to find again." — 2026-03-25 (https://www.reddit.com/r/macapps/comments/1s3e9dy/) (the organization job, both sides)
36. "I wish I could edit the annotations after I saved the image. It would be awesome." — 2025-11-25 (https://www.reddit.com/r/macapps/comments/1p5ayxb/.../nqoc9tz/)
37. "You had me at 'AI: none'." — 2026-03-24 (https://www.reddit.com/r/macapps/comments/1s27jjc/.../oc6uv8u/)
38. "Goodbye CleanShotX. I downloaded and installed this, and now I can say the same thing." (re: free OSS macshot) — 2026-04-22 (…/ohokc56/)
39. "I just don't understand why i would ever want to pay setapp extra money for no reason?" — 2026-03-03 (https://www.reddit.com/r/macapps/comments/1rjqygt/.../o8gt253/)
40. "I wouldn't hesitate to pay the $12 for Shottr though, it's a fantastic app & the dev is really decent" — 2025-10-06 (https://www.reddit.com/r/macapps/comments/1nz52c4/.../nhzzpwl/)

---

## Strategic implications for our product (synthesis)

1. **Video/GIF capture is the #1 conversion lever in this market** — it is simultaneously Shottr's loudest wishlist item and CleanShot's stickiest retention feature ("I'll stay in Cleanshot X as I can record videos/gifs"). Our v1 no-video decision means we must win decisively on the *screenshot* jobs and must catalog video as the single most-cited deferred feature.
2. **Pricing white space:** the community's stated ideal (repeated verbatim) is *lifetime bug fixes + paid feature upgrades*: "I would prefer at least for bug updates to be lifetime by developer at the very least and only new features to be paid. Much like Agenda." (nqun73b/). CleanShot's "bug fixes behind renewal" is its most defensible-to-attack flank; Shottr's $12/5-devices sets the value anchor.
3. **"Native Swift" is now an explicit purchase criterion** — vibe-coded Electron clones get destroyed in r/macapps. Our native bet aligns with the community's strongest filter; lead with it.
4. **The screenshot→LLM job is real, growing, and unowned** — current solutions are tiny indie hacks (LazyScreenshots, Vibeshots, hammerspoon scripts). Burst-capture → bulk paste, auto-blur secrets before paste, copy-path-for-Claude-Code, and annotate-for-AI-clarity are concrete observed behaviors.
5. **Screenshot library/search/organization is the second unowned job** (ScreenFloat is the only serious incumbent; CleanShot's history is "limited"). Local-first AI search/tagging would be welcomed *if* explicitly on-device.
6. **Trust is the moat for new entrants:** real identity, trial, transparent (or absent) cloud, responsive dev. Shottr's "decent dev" halo and macshot's ship-in-an-hour responsiveness earn outsized loyalty; Shottr's "is it abandoned?" wobble shows cadence/communication is part of the product.
7. **Distribution note:** Setapp's pivot makes the all-you-can-eat bundle weaker and standalone purchase the community default ("buy direct from the dev for cheaper"); our direct-download-first plan matches the wind direction.
