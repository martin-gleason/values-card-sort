#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Licensing gate — CLAUDE.md non-negotiable rule, SPEC §8.
# "SPDX headers (GPL-3.0-or-later) on every source file."
#
# Copyleft only holds if the notice is actually there, and a header is exactly
# the kind of rule an agent drifts past at 2am, so it is a check, not prose.

set -euo pipefail
cd "$(dirname "$0")/.."

EXPECTED='SPDX-License-Identifier: GPL-3.0-or-later'

echo "SPDX headers (SPEC §8)"

# CLAUDE.md says "every source file", not every Swift file. Scripts and CI
# config carry the notice too, so the copyleft claim covers the whole build.
files=$(find . \
  \( -name '*.swift' -o -name '*.py' -o -name '*.sh' -o -name '*.yml' \) \
  -not -path './.build/*' \
  -not -path './DerivedData/*' \
  -not -path './*.xcodeproj/*' \
  -not -path './.git/*' | sort)

if [ -z "$files" ]; then
  echo "  skip no sources yet"
  exit 0
fi

missing=()
while IFS= read -r f; do
  # Header must be near the top, not buried in a string literal at line 400.
  if ! head -6 "$f" | grep -qF "$EXPECTED"; then
    missing+=("$f")
  fi
done <<< "$files"

count=$(echo "$files" | wc -l | tr -d ' ')

if [ ${#missing[@]} -ne 0 ]; then
  echo "  FAIL ${#missing[@]} of $count source file(s) missing the SPDX header:"
  printf '       %s\n' "${missing[@]}"
  echo
  echo "  Add as the first line:  // $EXPECTED"
  exit 1
fi

echo "  ok   all $count source file(s) carry '$EXPECTED'"
echo
echo "PASSED — copyleft notice intact"
