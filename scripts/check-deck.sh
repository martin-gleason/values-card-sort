#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Deck fidelity gate (SPEC §4, TESTING.md layer 1).
#
# Runs without Xcode or Swift so CI can gate cheaply on every PR. The same
# assertions run again in Swift Testing against the bundled resource, so the
# deck is checked both as a file on disk and as data the app actually loads.

set -euo pipefail
cd "$(dirname "$0")/.."

exec python3 scripts/check_deck.py "$@"
