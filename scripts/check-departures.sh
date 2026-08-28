#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Departures register gate — SPEC §3.1 (D7), §6.
# Implementation and rationale in scripts/check_departures.py.

set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/check_departures.py "$@"
