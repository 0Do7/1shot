# Proposal: MVP — Project Darkroom (Mac screenshot tool)

## Why

Mac users choose between CleanShot X (polish, but renewal/cloud friction and 1-Mac licensing) and Shottr (speed, but dated UI, no library, solo-dev fragility). Market research (`research/00-research-report.md`) shows an unclaimed composite — "fast like Shottr, beautiful like CleanShot, honest pricing" — plus the largest unowned white space (a local searchable screenshot Library) and a winnable engineering crown (scrolling-capture reliability). Free OSS clones are commoditizing baseline capture within ~12 months, so the window is now.

## What Changes

Greenfield build of a native Swift menu-bar app for macOS 14+, distributed as notarized direct download. Everything below is new; full product rationale and acceptance bars live in `docs/02-prd.md` (PRD epics E1–E15 map 1:1 to the capabilities below).

- New capture engine (ScreenCaptureKit/SCScreenshotManager only; recording reserved as a first-class capture type for v2)
- New hybrid post-capture surface: persistent corner chip that is fully keyboard-driven and expands in-place into the editor
- New re-editable, platform-agnostic annotation document model + keyboard-first editor
- New redaction suite incl. Vision-based text-aware blur/erase and content-aware removal (no LLM, no network)
- New scrolling capture engine with live stitch preview, post-capture restitch, and a CI failure suite
- New on-device OCR/QR capture
- New pin/float windows, pixel tools (rulers/picker/contrast), and beautify/backgrounds with brand presets
- New local Library: FTS5 OCR search, heuristic auto-naming, provenance metadata, auto-import, Spotlight donation
- New destination plugin architecture (clipboard/file/app/S3-custom; hosted-cloud and LLM destinations are deferred drop-ins)
- New onboarding with guided hotkey takeover (live `com.apple.symbolichotkeys` verification) and permission-health screen
- New licensing (Paddle, 3 seats, 14-day dignified trial), Sparkle 2 updates, Homebrew cask
- Constraints throughout: local-first, zero telemetry by default, no accounts, no subscriptions, no AI; domain packages free of AppKit/SwiftUI imports (CI-enforced) for Windows portability

## Capabilities

### New Capabilities
- `capture-engine`: still-image capture modes (area/window/fullscreen/repeat/delayed/freeze), multi-display/DPI correctness, capture-type extensibility (E1)
- `post-capture-chip`: the corner chip surface — stacking, keyboard contract, drag-out, nothing-on-disk-until-decided (E2)
- `annotation-editor`: re-editable annotation document model, single-key tools, rendering quality bar, stitch/combine, expandable canvas (E3)
- `redaction`: blur/pixelate/black-out, text-aware blur/erase, content-aware removal, hardened export (E4)
- `scrolling-capture`: auto+manual scroll-stitch engine, live preview, restitch view, failure suite + honest failure messaging (E5)
- `ocr-capture`: region OCR to clipboard, language auto-detect, linebreak/indent modes, link+QR detection (E6)
- `pin-float`: always-on-top floats, opacity, click-through lock, hide-all (E7)
- `pixel-tools`: rulers, measurements, smart selection, color picker, WCAG/APCA contrast (E8)
- `beautify`: backdrops, padding/corners/shadow, brand presets, per-platform export sizes (E9)
- `library`: local FTS5 index, OCR search, heuristic auto-naming, provenance, smart folders/tags, auto-import, Spotlight, retention (E10)
- `output-destinations`: formats/templates/save rules + destination plugin architecture incl. S3/custom endpoint (E11)
- `onboarding-permissions`: install check, permission explainers + health screen, hotkey takeover wizard, 60-second first capture (E12)
- `utilities-settings`: hide desktop icons, history tray, settings with progressive disclosure, launch-at-login (E13)
- `automation`: AppIntents/Shortcuts/Spotlight actions, URL-scheme API, Raycast/Alfred extensions (E14)
- `licensing-updates`: Paddle license activation/trial, Sparkle 2 updates, Homebrew cask, public changelog (E15)

### Modified Capabilities
<!-- none — greenfield project -->

## Impact

- New repository (Swift Package Manager workspace + Xcode app target), new CI (GitHub Actions: build, tests, AppKit-import lint for domain packages, scrolling failure-suite rig, notarization pipeline).
- External dependencies: Sparkle 2, GRDB (SQLite/FTS5), Paddle SDK; Apple frameworks: ScreenCaptureKit, Vision, Core Image, AppIntents, Core Spotlight.
- No backend/server infrastructure of any kind (deliberate; see `docs/deferred/`).
- Architecture must preserve deferred-feature hooks: capture-type enum (video), destination plugins (cloud/LLM), nullable Library metadata columns (AI), platform-agnostic domain packages (Windows).
