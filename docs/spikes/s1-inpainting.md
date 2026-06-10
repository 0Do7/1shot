# Spike S1 — Core Image inpainting quality (task 1.2, design D9)

Date: 2026-06-09 · Machine: Apple Silicon, macOS 26.3 (25D125) · Code: `Spikes/S1Inpainting/`

## Question

Can Core Image built-ins deliver acceptable content-aware removal, or does the MVP
ship a blur-fill fallback while a custom patch-match kernel waits (task 6.4 is
demote-able to fast-follow)?

## Method

Five synthetic screenshot-like fixtures with **known ground-truth backgrounds**
(flat window chrome, vertical gradient, dark code editor, white web page, photographic
texture). An "object" is composited over each; three CI-only removal techniques fill
the hole; RMSE (0–255) is measured inside the hole against ground truth, plus visual
review of the PNGs in `Spikes/S1Inpainting/output/`. Deterministic (seeded LCG), re-runnable.

Techniques:
- **blurFill** — seed hole with ring-average color, one wide Gaussian pass (the D9 "blur-fill fallback" baseline)
- **diffusionFill** — seed with ring average, then 7 blur-and-reblend passes with shrinking sigma so border colors diffuse inward
- **patchShift** — clone the band above/below the hole into it, feathered edges (one-patch proxy for patch-match)

## Results

CIFilter census on 26.3: **247 filters, zero inpaint/heal/reconstruct candidates** —
Core Image ships no built-in inpainting. "CI's inpainting" from design D9 does not exist;
the real choice is CI-composable approximations vs a custom kernel.

RMSE inside hole (lower better) · render time at 800×600:

| Fixture | blurFill | diffusionFill | patchShift |
|---|---|---|---|
| 1-flat | 51.6 | 13.0 | **0.0** |
| 2-gradient | 31.9 | **8.1** | 26.1 |
| 3-code (structured) | 78.4 | **59.4** | 96.9 |
| 4-web (structured) | 84.0 | **80.4** | 123.4 |
| 5-texture | 38.9 | **15.5** | 17.1 |

All techniques render in <20ms warm (first CI pipeline build ~280ms).

Visual review: diffusionFill is near-invisible on flat/gradient/texture (faint haze at
worst); on structured content (code/web text) every technique leaves an obvious smudge —
**no naive fill can reconstruct occluded text/UI structure**; that requires true
patch-match (or ML, which is banned for MVP).

## Decision

1. **MVP ships diffusionFill** as the content-aware removal implementation (task 6.4):
   CI-only, fast, clearly beats the blur-fill baseline (2–4× lower RMSE everywhere),
   excellent on the backgrounds users most often clean up (desktop, window chrome,
   hero gradients).
2. **Honest-failure UX required** (consistent with spec language): compute ring/hole
   texture variance before applying; when the surroundings are structured (high
   variance / text detected via existing Vision pass), show the live preview and let
   the user judge — never claim magic. Exact heuristic tuned during 6.4.
3. **Custom patch-match Metal kernel = post-MVP upgrade**, only if beta feedback
   demands structured-content removal. Do not build it now.
4. patchShift is not worth shipping as a separate mode (wins only on perfectly flat
   fills where diffusionFill is already imperceptible).

## Spec impact

- `specs/redaction/spec.md` content-aware-removal requirement: implementation =
  diffusion fill; no change to requirement text needed (it already mandates honest
  fallback messaging).
- Design D9 note: "Core Image inpainting" → "CI diffusion fill" (no built-in exists).
