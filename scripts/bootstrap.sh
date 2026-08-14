#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The one command a fresh clone needs.
#
# ValuesCardSort.xcodeproj is GENERATED from project.yml and is gitignored.
# project.yml is the source of truth — edit that, never the project file.

set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  cat <<'EOF'
xcodegen is not installed.

  brew install xcodegen

It is a build-time tool only. Nothing from it links into the app, so SPEC §3's
"no third-party dependencies in the app target" is unaffected.
EOF
  exit 1
fi

echo "Generating ValuesCardSort.xcodeproj from project.yml…"
xcodegen generate --quiet
echo "Done. Open ValuesCardSort.xcodeproj, or:"
echo "  swift test                            # rule + fidelity tests (fast)"
echo "  xcodebuild test -scheme ValuesCardSort -destination 'platform=macOS'"
