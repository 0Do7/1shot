# Spike S0 — SCScreenshotManager re-auth behavior (task 1.1, design D5, Open Q1)

Date: 2026-06-09 · Probe: `Spikes/S0ReauthProbe/` · Empirical machine: macOS 26.3 (25D125), Apple Silicon
Sources for the research half are linked inline; confidence tags: [OBSERVED] = our probe, [HIGH]/[MED]/[LOW] = sourced research.

## Question

Does non-picker `SCScreenshotManager` trigger the Sequoia/Tahoe periodic screen-capture
re-auth, and what must the permission-health UX (tasks 3.6, 12.3) plan for?

## Answer (short)

**Yes — the monthly "bypass the system private window picker" re-auth applies to us and
cannot be suppressed app-side.** It keys off non-picker TCC Screen Recording usage, not
off SCStream vs one-shot capture, not off deprecated APIs. Mitigation is UX design, not
engineering: since 15.1 the approval timestamp refreshes on every capture, so active
users rarely see the dialog; the permission-health screen must treat re-auth as a
routine state, never an error.

## Empirical findings (26.3, our probe) [OBSERVED]

- Non-picker `SCScreenshotManager.captureImage` works after a normal TCC grant: full
  6016×3384 display captured with no picker and no per-capture prompt.
- Latency: `SCShareableContent` enumeration 20–27 ms; capture 75–140 ms warm (~78 ms
  steady-state). **Enumeration + capture ≈ 100 ms total leaves ~100 ms of the 200 ms
  hotkey→chip budget for the chip itself — budget is feasible (PRD §7).**
- The TCC grant took effect **without restarting** the host process (grant while the
  process was alive; next call succeeded). Don't assume a relaunch is required, but
  keep the relaunch hint in recovery copy — older releases behaved differently.
- Denied state is clean and detectable: `CGPreflightScreenCaptureAccess() == false` and
  `SCStreamErrorDomain code -3801` ("user declined TCCs"). No crash, no zombie state.
- The approval-timestamp store (`~/Library/Group Containers/group.com.apple.replayd/
  ScreenCaptureApprovals.plist`) exists on 26.3 and is TCC-protected from normal reads —
  we cannot read our own re-auth deadline to warn users preemptively.
- Not yet observed: the periodic dialog itself (requires ≥1 month wall-clock or an
  infrequent-use pattern). Long-run observation continues on this machine and moves to
  the self-hosted runner once provisioned.

## Research findings (sourced)

1. **The nag applies to any non-picker capture, including one-shot
   `SCScreenshotManager.captureImage`** — confirmed by Apple DTS (Quinn) and
   reproduced with minimal SCK code; reportedly fires from the second capture
   invocation in the naive case. [HIGH]
   https://developer.apple.com/forums/thread/765103
2. **Cadence:** 15.0 shipped monthly ("Allow For One Month"); 15.1 made the timer
   refresh on each capture, so regularly-used apps effectively stop being nagged;
   unused ~30 days → re-prompt. [HIGH]
   https://9to5mac.com/2024/10/07/macos-sequoia-screen-recording-popups/
   https://lapcatsoftware.com/articles/2024/8/10.html
3. **Tahoe (26.x) carries the policy forward unchanged** — no new exemption, no relief
   in any 26.x release note. New sharp edges instead: TCC attributes Screen Recording
   to the *responsible process* (never capture from spawned helpers/LaunchAgents);
   non-bundled plain executables no longer appear in System Settings on 26.1+; user
   reports of buggy every-reboot prompts on 26.1–26.4 (CleanShot X affected). [MED]
   https://forums.macrumors.com/threads/tahoe-repeatedly-asking-to-bypass-the-window-picker.2475572/
4. **`com.apple.developer.persistent-content-capture` is not available to us:**
   VNC/remote-access apps only, case-by-case grant by Apple; Quinn: "only for screen
   sharing products". [HIGH]
   https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.persistent-content-capture
5. **`SCContentSharingPicker` is not viable** for hotkey-driven region/window capture
   UX (system picker per session); no shipping screenshot tool adopted it. CleanShot X,
   Shottr, Xnapper all simply eat the nag. [HIGH/MED]
6. **15.2 not yet empirically tested by us** — no Sequoia machine available. Research
   indicates 15.1+ behavior is the steady state across 15.2–15.7. Revisit if beta
   testers on 15.x report otherwise. [MED]

## Decisions for dependent tasks

- **D5 confirmed:** stay on non-picker `SCScreenshotManager`. No picker, no entitlement
  application, no plist hacks (we never ship workarounds that need Full Disk Access).
- **Permission state machine (3.6):** model states `unknown / granted / denied /
  reauthSuspected` (named as implemented in OneShotCapture). `reauthSuspected` is detectable only reactively (capture fails or the
  system dialog appears) — we cannot read the deadline. Treat -3801 after prior success
  as probable re-auth, re-preflight, and route to recovery copy.
- **Permission-health screen (12.3):** present the monthly dialog as *expected macOS
  behavior* with one-click recheck; copy must say capture keeps working after "Allow For
  One Month" and that frequent use defers it. Never call it an error; never blame the user.
- **Onboarding (12.1):** set expectations at grant time — one sentence noting macOS may
  periodically re-confirm screen access. Trust posture: we explain the OS, we don't
  fight it.
- **App architecture:** all capture calls must originate from the main app bundle
  process (Tahoe responsible-process attribution) — relevant for AppIntents/URL-scheme
  entry points (13.4/13.5) and the self-hosted runner (runner runs as LaunchAgent in a
  GUI session; capture happens inside the app under test, which is fine).
- **Release gate addition (15.4):** beta exit checklist gains "re-auth dialog observed
  and recovery flow exercised on 15.x and 26.x at least once" (cannot be CI-automated;
  calendar-driven manual check on the runner).

## Still open (tracked, non-blocking)

- Observe the actual dialog on this 26.3 machine over the next month (probe stays
  installed; re-run `swift run S0ReauthProbe` after ≥30 days idle).
- Acquire/borrow a 15.x machine or VM before beta to exercise the recovery flow there.
