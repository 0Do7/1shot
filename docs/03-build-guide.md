# Build Guide — Multi-Agent Implementation (Model-Agnostic)

Date: 2026-06-09 · For: any coding agent (Claude, GPT, Gemini, human) implementing the MVP
Source of truth chain: `docs/02-prd.md` (WHAT/WHY) → `openspec/changes/mvp/design.md` (HOW) → `openspec/changes/mvp/specs/*/spec.md` (testable requirements) → `openspec/changes/mvp/tasks.md` (work units)

## 0. Orientation for any agent picking up work

1. Read `openspec/changes/mvp/design.md` in full (it's short and decisive).
2. Read the spec file(s) for the capability your task group touches.
3. Claim a task group (a `##` section in `tasks.md`) — never individual tasks from a group someone else owns.
4. Check `tasks.md` checkboxes for current state; tick boxes as you complete tasks (the OpenSpec apply phase parses `- [ ]` format — keep it exact).
5. When a spec and the PRD disagree, the spec wins (specs were reconciled later); when a spec is silent, the PRD wins; log any new conflict you find in `docs/spec-conflicts.md` rather than silently choosing.

The grilled-and-locked product decisions live in `docs/00-decisions.md`. Do not relitigate them in code (e.g., do not add telemetry, accounts, subscriptions, AI/LLM calls, or Mac App Store affordances — see `docs/deferred/` for why).

## 1. Lane map (who can work in parallel)

```
Wave 0 (sequential, 1 agent): tasks §1 — spikes S0/S1, repo scaffold, CI, perf harness, runner
Wave 1 (parallel ×3):  §2 core   §3 capture            §14.1-14.2 commerce-mock
Wave 2 (parallel ×6):  §4 chip   §5 editor   §7 scroll  §8 ocr   §13 platform   §11 destinations
Wave 3 (parallel ×4):  §6 redaction   §9 library   §10 visuals   §12 onboarding
Wave 4 (integration):  §14.3-14.6 commerce-real   §15 beta & launch
```

- Dependencies are stated at the top of each task group; trust them, not vibes.
- The **scroll lane (§7) is the schedule's critical risk** — staff it first and never pull its agent to other lanes. Its fixture-based stitcher tests (7.1, 7.2) run on hosted CI; only the live failure suite (7.8) needs the self-hosted runner.
- `[demote-able]` tasks (6.4, 11.2, 13.6) may slip to fast-follow by decision of the human owner only — agents do not demote on their own.

## 2. Repo conventions (mechanically enforced where possible)

- **Repo root:** this directory becomes the repo (git init in task 1.3). SPM workspace layout per design D2.
- **Portability law (CI-enforced):** `DarkroomCore` and `DarkroomRender` import Foundation/CoreGraphics-level frameworks only — never AppKit/SwiftUI/UIKit. The CI lint (task 1.4) greps imports; do not add exemptions.
- **Swift 6, strict concurrency.** Domain types are `Sendable` value types; app layer is `@MainActor`. No `@unchecked Sendable` without a comment stating the invariant.
- **Style:** SwiftFormat + SwiftLint configs from task 1.3 are law; match surrounding code; comments only for non-obvious constraints.
- **Branches/PRs:** one branch per task group (`lane/scroll`, `lane/library`…); PR per task or small task cluster; CI green required; another agent (or the human) reviews cross-lane interface changes.
- **Interface changes:** anything touching `DarkroomCore` public API after Wave 1 requires a note in the PR description flagging which lanes consume it.

## 3. Definition of Done (every task)

1. The spec scenarios covering the task pass as automated tests (each `#### Scenario:` is a test case — name tests after scenarios: `test_chip_neverStealsFocus`).
2. Performance budgets touched by the task are asserted via the harness (task 1.5), not eyeballed.
3. Golden snapshots (render quality) added/updated only with explicit human sign-off — render quality is a product feature.
4. No new network calls (the only permitted endpoints: Paddle activation, Sparkle appcast, user-configured S3).
5. Checkbox ticked in `tasks.md`; deviations from spec logged in `docs/spec-conflicts.md`.

## 4. Testing topology

| Layer | Where it runs | What |
|---|---|---|
| Unit (Core/Render/OCR/naming/stitcher-on-fixtures) | Hosted CI, every PR | Fast, deterministic; fixture frame sequences make the stitcher testable without permissions |
| Snapshot (annotation rendering, beautify) | Hosted CI | Goldens reviewed as design assets |
| Performance budgets | Hosted CI (signpost asserts) + release cert on real hardware (15.2) | hotkey→chip <200ms p95, editor <400ms, search <50ms@10k |
| Live capture integration + scrolling failure suite | Self-hosted Mac runner (permissions pre-granted) | Terminal/VS Code/Finder-columns/Mos/Scroll-Reverser/sticky-header/lazy-load; **release gate** |
| XCUITest flows | Self-hosted runner | Onboarding grant/deny paths, the 7 PRD acceptance flows |

## 5. Things agents must never do (the trust posture, condensed)

- No telemetry/analytics SDKs; no automatic crash upload; no phoning home.
- No account/login surface. No subscription scaffolding.
- No AI/LLM calls of any kind, on-device or server (Vision OCR is permitted — it's an OS framework; see `docs/deferred/ai-features.md` for the boundary).
- Never hold user data hostage: files visible on disk, Library readable forever regardless of license state, exports never watermarked.
- Never silently degrade: failed capture/stitch/OCR states are explicit UX, not garbage output (a recurring spec requirement — search specs for "honest").
- Never write `com.apple.symbolichotkeys` or other system settings; guide + verify only.

## 6. Milestones → calendar shape

| Milestone | Exit criteria |
|---|---|
| **M0 Foundation** | §1 done; S0/S1 findings merged into specs if they force changes |
| **M1 Core loop** | capture → chip → editor → export works end-to-end; budgets green |
| **M2 Differentiators** | scroll (with restitch + failure suite), redaction, OCR, Library indexing+search |
| **M3 Full surface** | visuals, destinations, onboarding, utilities, automation |
| **M4 Beta** | licensing (real Paddle), Sparkle channel, beta exit gates (PRD §10) |
| **M5 Launch** | rename task, 1.0 pipeline, launch artifacts (PRD §9) |

## 7. Implementation kickoff command

When implementation starts, agents use the OpenSpec apply flow:
```
/opsx:apply   # or: follow openspec-apply-change skill against change "mvp"
```
which walks `tasks.md` in order with the specs as acceptance criteria.

## 8. Post-MVP pointers

Deferred features (with architectural hooks already specced): `docs/deferred/README.md`.
Landing page, naming, and launch copy work from `research/00-research-report.md` §9 (VOC bank) — separate workstream, not this repo's code.
