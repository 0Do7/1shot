#!/bin/bash
# Portability law (design D2, build guide §2): DarkroomCore and DarkroomRender are
# the Windows-portable heart — they must never import AppKit/SwiftUI/UIKit.
# Runs on any OS (plain grep). CI job: portability-lint. No exemptions.
set -euo pipefail

cd "$(dirname "$0")/.."

PORTABLE_PACKAGES=(DarkroomCore DarkroomRender)
FORBIDDEN='^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+(AppKit|SwiftUI|UIKit)\b'

status=0
for pkg in "${PORTABLE_PACKAGES[@]}"; do
  dir="DarkroomKit/$pkg/Sources"
  if matches=$(grep -rnE "$FORBIDDEN" "$dir" --include='*.swift' 2>/dev/null); then
    echo "✗ $pkg violates the portability law (no AppKit/SwiftUI/UIKit):"
    echo "$matches"
    status=1
  else
    echo "✓ $pkg is portable"
  fi
done
exit $status
