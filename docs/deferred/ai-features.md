# Deferred: AI / On-Device Intelligence Features

**Status:** cut from MVP 2026-06-09 (no LLM usage until PMF). MVP keeps only non-AI equivalents:
Apple Vision OCR (not an LLM) and heuristic auto-naming (app + window title + OCR keywords).

## The features
1. **AI auto-naming** — model-generated descriptive filenames ("figma-dashboard-header.png").
   MVP fallback: heuristic naming from provenance + top OCR tokens (covers ~80% of the value).
2. **Semantic library search** — "find the screenshot of the blue pricing table" beyond exact
   OCR text match. (Tidyshot-class; iOS AI-organizer wave proves demand at scale.)
3. **Auto-redaction of PII/API keys** — on-device detection + one-tap blur-all.
   (BlurData/PageRedact prove standalone willingness-to-pay.)
4. **Smart cropping** — content-aware crop suggestions.

## Evidence (research report §1.6, §8.5, §9 #53)
- VOC: "Can it automatically tag keywords based on image content? …screenshot on Safari of a
  cat drinking milk → keywords: safari browser, cat, milk…"
- Community constraint (critical): AI welcome **only** if local and useful — "You had me at
  'AI: none'" gets upvotes; vibe-coded AI apps get torched in r/macapps.
- Framing rule when revived: "on-device intelligence," never "AI-powered."

## Monetization note (report §6)
If on-device → higher **one-time** tier. If server-side → the only legitimately
subscription-shaped offering, priced well under the $96–120/yr rage line (~$4–6/mo).

## Architectural hooks kept in MVP
- Library schema includes an extensible metadata/embedding column (nullable) so semantic
  indexing can be added without migration pain.
- Redaction pipeline = same blur primitives as manual tools; detection is a pluggable analyzer.

## Revisit trigger
PMF + a premium-tier monetization decision.
