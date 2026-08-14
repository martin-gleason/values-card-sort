#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Regenerate the compiled deck from data/deck.v1.json.
# See scripts/generate_deck.py for why the deck is compiled rather than bundled.

set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/generate_deck.py "$@"
