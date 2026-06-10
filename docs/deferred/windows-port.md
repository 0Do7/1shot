# Deferred: Windows Port

**Status:** post-PMF horizon goal (locked 2026-06-09). Mac first.

## Why the lane is open (report §1.10, §8.4)
- Both incumbents formally ceded Windows [OBSERVED]: cleanshot.com FAQ "no planned release";
  shottr.cc FAQ "doesn't seem likely… codebase is not portable."
- The "orphaned Snagit individual" (Mac+Windows, subscription-hating) is actively told to split
  across ShareX + CleanShot — a one-time-priced cross-platform app is the only clean answer.
- Demand signals are real but anecdotal; economics unproven (report §10.9).

## Constraint to respect
ShareX + the upgraded Snipping Tool set Windows expectations at "everything free" — a port must
sell polish/UX/**library**, not capture mechanics.

## Architectural hooks kept in MVP (the whole point of the portable spec)
- OpenSpec domain spec (annotation model, editing operations, library schema, file pipeline,
  destination plugins) written platform-agnostically.
- Capture engine and UI shell are explicitly platform modules.
- Name/brand chosen Windows-proof (locked naming constraint).

## Revisit trigger
PMF on Mac + dedicated Windows-market research before committing.
