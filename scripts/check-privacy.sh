#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Privacy gate — SPEC §7 (binding), TESTING.md layer 5.
# Implementation and rationale live in scripts/check_privacy.py.

set -euo pipefail
cd "$(dirname "$0")/.."

exec python3 scripts/check_privacy.py "$@"
