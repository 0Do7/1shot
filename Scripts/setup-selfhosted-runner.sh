#!/bin/bash
# Self-hosted Mac runner setup (task 1.6, design D8/D13).
# Run ON the runner machine, as the dedicated `runner` user, AFTER the manual
# TCC grants described in docs/selfhosted-runner.md (Screen Recording + Accessibility
# cannot be granted from a script — that is the whole reason this runner exists).
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/0Do7/screenshot}"
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"

echo "==> Xcode CLT + Homebrew toolchain"
xcode-select -p >/dev/null || xcode-select --install
command -v brew >/dev/null || /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install xcodegen swiftlint swiftformat

echo "==> Keep the machine awake and self-recovering"
sudo pmset -a sleep 0 displaysleep 0 disksleep 0 autorestart 1
sudo systemsetup -setcomputersleep Never >/dev/null 2>&1 || true

echo "==> GitHub Actions runner"
if [ ! -d "$RUNNER_DIR" ]; then
  mkdir -p "$RUNNER_DIR" && cd "$RUNNER_DIR"
  ARCH=$(uname -m | sed 's/x86_64/x64/;s/arm64/arm64/')
  LATEST=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest |
    /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))')
  curl -fsSL -o runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v${LATEST}/actions-runner-osx-${ARCH}-${LATEST}.tar.gz"
  tar xzf runner.tar.gz && rm runner.tar.gz
fi

cat <<'EOF'

Next (manual, requires a registration token — expires after 1h):
  1. Get a token: repo Settings → Actions → Runners → New self-hosted runner
  2. cd ~/actions-runner && ./config.sh --url REPO_URL --token TOKEN \
       --labels darkroom-capture --name darkroom-mac-1 --unattended
  3. Install as a LaunchAgent (NOT a daemon — TCC permissions are per-GUI-session):
       ./svc.sh install && ./svc.sh start
  4. Verify TCC grants per docs/selfhosted-runner.md §Permissions, then run the
     smoke check:  Spikes/S0ReauthProbe → expects "✓ captured ... (no picker)"
EOF
