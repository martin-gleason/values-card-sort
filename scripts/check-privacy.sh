#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Privacy gate — SPEC §7 (binding), TESTING.md layer 5.
# Implementation and rationale live in scripts/check_privacy.py.

set -euo pipefail
cd "$(dirname "$0")/.."

# Two surfaces, two scanners. The Swift one lexes Swift; the web one lexes
# JS/HTML. `web/` was in neither for the whole of Web/F1, so this step passed
# while the page was unscanned — the gate reported on a surface it never read.
fail=0
python3 scripts/check_privacy.py "$@" || fail=1
echo
python3 scripts/check_web_privacy.py "$@" || fail=1
exit $fail
