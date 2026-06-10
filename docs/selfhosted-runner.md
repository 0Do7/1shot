# Self-hosted Mac runner (task 1.6, design D8/D13)

Why it exists: GitHub-hosted macOS runners cannot interactively grant Screen Recording
or Accessibility, so the live-capture integration tests, the scrolling failure suite
(task 7.8), and XCUITest flows run here. Hosted CI still covers everything
deterministic (`.github/workflows/ci.yml`).

## Provisioning checklist

1. Hardware: any Apple Silicon Mac on macOS 14+ that can stay plugged in
   (a Mac mini is ideal). Dedicated machine or VM — it will hold standing
   Screen Recording permission, so don't use a personal Mac.
2. Create a dedicated `runner` user (Standard is fine; auto-login ON — TCC and
   XCUITest need a live GUI session, so the runner runs as a LaunchAgent, never
   a LaunchDaemon).
3. Run `Scripts/setup-selfhosted-runner.sh` as that user, then follow its printed
   registration steps. Use the runner label `oneshot-capture` — workflows target it
   with `runs-on: [self-hosted, oneshot-capture]`.

## Permissions (manual, one-time — the point of this machine)

System Settings → Privacy & Security, grant to the runner's host process
(`Runner.Listener` appears after the first job attempts capture; Terminal during
smoke-testing):

- **Screen & System Audio Recording** — capture tests
- **Accessibility** — scroll-synthesis tests (task 7.3+)

Verify with the S0 probe (`cd Spikes/S0ReauthProbe && swift run`): expect
`CGPreflightScreenCaptureAccess: true` and `✓ captured … (no picker)`.

S0 spike note: on macOS 26.3 the TCC grant took effect **without** restarting the host
process; budget for a logout/login anyway when grants don't stick (observed behavior on
older releases differs — see `docs/spikes/s0-screencapture-reauth.md`).

## Display

Live capture tests need a real resolution. Headless Mac minis: attach an HDMI dummy
plug (4K) or enable a virtual display; record which one the failure-suite fixtures
were tuned against. Keep one fixed display arrangement — the scrolling failure suite
asserts pixel geometry.

## Restore procedure

The runner is deliberately cattle, not pet:

1. Erase / reinstall macOS (or restore the base Time Machine snapshot taken after
   first provisioning).
2. Re-run the provisioning checklist above (≈15 min, two manual TCC clicks).
3. Re-register the runner (old registration can be force-removed in repo Settings →
   Actions → Runners).
4. Re-run the S0 probe smoke check before un-pausing the queue.

Anything not covered by the script + this doc is a bug in this doc — fix the doc,
don't accumulate tribal knowledge on the machine.

## Status

- [x] Setup script + restore docs
- [ ] Physical machine provisioned and registered (owner action — needs hardware)
- [ ] `selfhosted.yml` workflow targeting `oneshot-capture` (lands with task 7.8)
