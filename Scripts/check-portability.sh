#!/bin/bash
# Portability law (design D2, build guide §2): OneShotCore and OneShotRender are
# the Windows-portable heart — they must never import AppKit/SwiftUI/UIKit.
# Runs on any OS (plain grep). CI job: portability-lint. No exemptions.
set -euo pipefail

cd "$(dirname "$0")/.."

PORTABLE_PACKAGES=(OneShotCore OneShotRender)
FORBIDDEN='^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+(AppKit|SwiftUI|UIKit)\b'

status=0
for pkg in "${PORTABLE_PACKAGES[@]}"; do
  dir="OneShotKit/$pkg/Sources"
  if matches=$(grep -rnE "$FORBIDDEN" "$dir" --include='*.swift' 2>/dev/null); then
    echo "✗ $pkg violates the portability law (no AppKit/SwiftUI/UIKit):"
    echo "$matches"
    status=1
  else
    echo "✓ $pkg is portable"
  fi
done

# No deprecated capture APIs (spec:capture-engine "No deprecated APIs in the
# binary", design D5): every capture path goes through ScreenCaptureKit /
# SCScreenshotManager. CGWindowListCreateImage & friends must never appear.
DEPRECATED='CGWindowListCreateImage|CGWindowListCreateImageFromArray|CGDisplayCreateImage'
if matches=$(grep -rnE "$DEPRECATED" OneShotKit OneShot --include='*.swift' 2>/dev/null); then
  echo "✗ deprecated capture API referenced (use ScreenCaptureKit instead):"
  echo "$matches"
  status=1
else
  echo "✓ no deprecated capture APIs"
fi

exit $status
