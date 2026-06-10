# Deferred: Send-to-LLM Destination

**Status:** cut from MVP 2026-06-09 (user decision: no LLM-flavored features until PMF). Zero
server cost as designed — it targets the *user's own* LLM tools — but deferred for scope and
brand-cleanliness reasons.

## The feature
- Configurable paste destination (Claude Code, Cursor, ChatGPT, custom app/URL scheme):
  one keystroke sends **image + OCR text + provenance metadata (app, window title, URL)** as a
  single payload.
- **Burst capture → bulk paste**: take N shots, multi-select in tray, send all at once.
- **Auto-blur secrets before paste**: on-device pattern detection (API keys, emails, tokens)
  blurs before the image leaves the app, with one-tap reveal-override.

## Why it was on the list (evidence, research report §1.6, §7 job 2)
- Screenshot→LLM is the fastest-growing job 2024→2026; devs paste UI bugs into Claude
  Code/Cursor daily. No incumbent owns it.
- Micro-tools (LazyScreenshots, Vibeshots) exist purely for this job — demand proof.
- VOC: "Paste UI on a GitHub PR. Paste Figma into a LLM. Paste bugs into Slack or a support
  tool." (HN, report §9 #49)
- VOC: the 3-keystroke OCR→VS Code loop (§9 #50) shows the interaction budget to beat.

## Architectural hook kept in MVP
The share/destination system is a plugin surface (clipboard, file, app targets). Adding an LLM
destination later is a new destination plugin + payload composer — no core changes.

## Revisit trigger
PMF signals (retention + organic dev-community traction), or a competitor shipping it first.
