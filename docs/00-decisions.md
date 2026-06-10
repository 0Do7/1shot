# Project Decisions — Screenshot Tool (working title TBD)

Date: 2026-06-09 · Method: /grill-me interview · Status: locked unless revisited explicitly

## Product
| Decision | Choice | Rationale |
|---|---|---|
| Competitors studied | CleanShot X + Shottr | The two most-compared Mac screenshot tools; premium-polish vs fast-and-cheap |
| Differentiation | Market-guided best-of-both-worlds | Mine what users love in each, encapsulate in one app. AI features reserved for a premium tier later. |
| Cross-platform | Mac first; Windows on the horizon | Secondary goal, but architecture/spec must not paint us into a Mac-only corner |
| v1 scope | Local-first. No video recording, no cloud sharing | Both deferred-but-designed-for (v2 roadmap). v1 = capture + instant editing + OCR + best utility features of both apps |
| Pricing | **Undecided — research-driven** | Subscription resentment is the known dominant sentiment; decide from review/Reddit evidence |

## Engineering
| Decision | Choice | Rationale |
|---|---|---|
| Stack | Native Swift (AppKit/SwiftUI) | This market punishes non-native feel; Shottr is loved for being tiny/instant |
| Portability strategy | Platform-agnostic domain spec | Editing model, annotation engine, file pipeline specified independently of UI layer so Windows is a spec-driven rewrite, not a code port |
| Distribution | Direct download (notarized DMG + Sparkle + Paddle/Lemon Squeezy); Setapp as post-launch channel | Full API freedom; Setapp is curated → treated as milestone, not launch dependency |
| Spec format | Hybrid: markdown for research/PRD/VOC docs + OpenSpec for engineering spec & tasks | Model-agnostic, multi-agent-implementable |

## Brand
- Name candidates in two tracks: category-evocative AND abstract/brandable
- Hard filters: Windows-proof connotations; obtainable .com or .app; no trademark/App Store collisions
- Landing page copy must be voice-of-customer (verbatim language from research)

## PRD round (locked 2026-06-09, second /grill-me)
| Decision | Choice |
|---|---|
| MVP cut-line | **Everything in the v1 strategy is the MVP** (Tier A+B+C incl. scrolling capture AND Library) — demote-able items flagged in tasks |
| Hero positioning | Best-of-both-worlds ("Fast like Shottr. Beautiful like CleanShot. Honest pricing."); library/reliability as supporting sections; revisable |
| Pricing | Structure locked (one-time, 3 Macs, bug-fixes-free-forever pledge, 14-day trial, Agenda-style upgrades, Paddle MoR); **exact price decided at launch** ($19–29 corridor) |
| LLM/AI features | **None until PMF — zero production-cost rule.** Send-to-LLM + AI features moved to `docs/deferred/` (retrievable, with architectural hooks) |
| Launch path | Private beta (50–200 from r/macapps/X waitlist) → coordinated public paid launch (PH + r/macapps + comparison-SEO page) |
| Trial expiry rule | 24h capture grace → capture disables; Library browse/search/re-edit/export work forever unlicensed |
| Platform floor | macOS 14+ (ScreenCaptureKit/SCScreenshotManager only) |
| Product name | **1shot** (decided 2026-06-09, supersedes codename "Project Darkroom"). Code identifiers use `OneShot` prefix, bundle ID `com.sidequests.oneshot` (digit can't lead a Swift module / bundle-ID segment — 1Password precedent); document extension `.1shot` |

## Pipeline
1. ✅ Multi-agent research → `research/00-research-report.md`
2. ✅ Feature add/cut + user flows → `docs/01-feature-strategy.md` (+ `docs/deferred/`)
3. ✅ PRD → `docs/02-prd.md`
4. ✅ OpenSpec build spec → `openspec/changes/mvp/` (proposal, design, 15 specs, tasks) + `docs/03-build-guide.md`
5. 🟡 Naming: **done — "1shot"** (rename applied repo-wide 2026-06-09); landing page copy from VOC bank still open
6. 🟡 Implementation (`/opsx:apply` on change "mvp") — in progress since 2026-06-09 (Wave 0 done)
