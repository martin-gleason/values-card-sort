# SPDX-License-Identifier: GPL-3.0-or-later
"""Compile data/deck.v1.json into Swift source.

**Why the deck is compiled rather than bundled as JSON.**

Ratified 2026-08-14. The app is used by people at hard moments in their lives,
and the deck is the text it puts in front of them. A JSON file — in the repo,
in the app bundle, or on a device — is a soft target: a card's descriptor could
be changed to something harmful, and in a large JSON diff that is easy to miss.

Compiling it in removes the editing surfaces one at a time:

- **Nothing to swap at runtime.** The shipped binary carries Swift literals, not
  a parsable resource file. There is no `deck.v1.json` in the bundle to replace.
- **Nothing to edit quietly in a PR.** Changing the JSON changes the pinned
  hashes and fails CI; changing the generated Swift by hand fails the
  regeneration check, which asserts this script reproduces the file byte for
  byte. Both would have to be defeated together, deliberately, in a reviewed
  diff, and the hash re-pin is a visible, single-line, obviously-deliberate act.
- **Still verifiable at runtime.** `DeckLoader.validate` re-checks the payload
  hash against the compiled cards, so a patched binary fails too, and the app
  refuses to run a sort rather than showing text it cannot vouch for.

`data/deck.v1.json` remains the human-readable provenance record and the
surface for chore C1's card-by-card verification. It is a build input, not a
shipped artifact.

The only way a value reaches someone's deck at runtime is R4 — a card they
wrote themselves, in the app.

Usage:
    python3 scripts/generate_deck.py            # write the file
    python3 scripts/generate_deck.py --check    # verify it is up to date
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DECK_JSON = ROOT / "data" / "deck.v1.json"
SWIFT_OUTPUT = ROOT / "Sources" / "ValuesCardSortKit" / "Deck" / "Deck.v1.generated.swift"
JS_OUTPUT = ROOT / "web" / "deck.js"

US = chr(0x1F)
RS = chr(0x1E)


def swift_string(value: str) -> str:
    """A Swift string literal. The deck is ASCII, but escape defensively so a
    future deck cannot inject source."""
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )
    for ch in escaped:
        if ord(ch) < 0x20:
            raise SystemExit(f"refusing to emit a control character from {value!r}")
    return f'"{escaped}"'


def js_string(value: str) -> str:
    """A JavaScript string literal, escaped defensively for the same reason
    ``swift_string`` is: the deck is ASCII today and a future deck may not be.

    Two escapes here are not in the Swift emitter and are not decoration.
    ``<`` is escaped because a value containing ``</script>`` would end the
    surrounding element even inside a string literal — the one way text in a
    data file becomes markup. U+2028 and U+2029 are line terminators to a
    JavaScript parser but not to JSON, so they can break a literal that looked
    fine on the page it came from.
    """
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("<", "\\x3C")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
        .replace(" ", "\\u2028")
        .replace(" ", "\\u2029")
    )
    for ch in escaped:
        if ord(ch) < 0x20:
            raise SystemExit(f"refusing to emit a control character from {value!r}")
    return f'"{escaped}"'


def canonical_payload(cards: list[dict]) -> str:
    return RS.join(f"{c['id']}{US}{c['name']}{US}{c['descriptor']}" for c in cards)


def render_swift(deck: dict) -> str:
    cards = deck["cards"]
    instrument = deck["instrument"]
    lines = [
        "// SPDX-License-Identifier: GPL-3.0-or-later",
        "//",
        "// GENERATED FILE — DO NOT EDIT.",
        "//",
        "// Produced by scripts/generate_deck.py from data/deck.v1.json.",
        "// Regenerate with: ./scripts/generate-deck.sh",
        "//",
        "// The deck is compiled in rather than bundled as a JSON resource so that",
        "// the shipped app has no editable copy of the instrument text, and so a",
        "// hand edit here fails CI's regeneration check as well as the payload",
        "// hash. See scripts/generate_deck.py for the full rationale (SPEC §4).",
        "//",
        "// The pinned payload hash deliberately does NOT live in this file. It is",
        "// hand-maintained in DeckLoader.swift, so changing a card here cannot be",
        "// covered up by editing the constant on the next line.",
        "//",
        "// The instrument itself is public domain:",
        f"//   {instrument['title']}",
        f"//   {instrument['authors']}",
        f"//   {instrument['institution']}, {instrument['year']}",
        "",
        "extension Deck {",
        "    /// The deck as published, compiled into the binary.",
        "    public static let v1 = Deck(",
        f"        deckVersion: {swift_string(deck['deckVersion'])},",
        "        instrument: Instrument(",
        f"            title: {swift_string(instrument['title'])},",
        f"            authors: {swift_string(instrument['authors'])},",
        f"            institution: {swift_string(instrument['institution'])},",
        f"            year: {instrument['year']},",
        f"            copyright: {swift_string(instrument['copyright'])},",
        "            sources: [",
    ]
    for source in instrument["sources"]:
        lines.append(f"                {swift_string(source)},")
    lines += [
        "            ],",
        f"            verification: {swift_string(instrument['verification'])}",
        "        ),",
        f"        cardCount: {deck['cardCount']},",
        "        cards: [",
    ]
    for card in cards:
        lines.append(
            f"            ValueCard(id: {card['id']}, "
            f"name: {swift_string(card['name'])}, "
            f"descriptor: {swift_string(card['descriptor'])}),"
        )
    lines += [
        "        ]",
        "    )",
        "}",
        "",
    ]
    return "\n".join(lines)


def render_js(deck: dict) -> str:
    """The same deck as a JavaScript source file, for the web port (`Web/F1`).

    **Why generate this rather than keep the reference's inline array.**
    `reference/valuescardsort.jsx` carries its own copy of the 83 cards in a
    `RAW` literal. Shipping that copy would give the project two hand-maintained
    decks that drift apart silently — precisely the failure the deck contract
    exists to prevent — so the web deck is emitted from `data/deck.v1.json` and
    gated by the same `--check` that guards the Swift one.

    **What this file does NOT claim.** D6 compiles the deck into the native
    binary so the shipped app has no editable copy. A web page cannot make that
    promise: anyone can read and alter `deck.js` after downloading it. The
    guarantee here is narrower and worth stating plainly — the deck cannot drift
    *in this repository*, because a hand edit fails the regeneration check.

    A classic script assigning one frozen global, not an ES module: modules are
    blocked by CORS over `file://`, and the page must be openable by double
    clicking it, not only from a server.
    """
    cards = deck["cards"]
    instrument = deck["instrument"]
    lines = [
        "// SPDX-License-Identifier: GPL-3.0-or-later",
        "//",
        "// GENERATED FILE — DO NOT EDIT.",
        "//",
        "// Produced by scripts/generate_deck.py from data/deck.v1.json.",
        "// Regenerate with: ./scripts/generate-deck.sh",
        "//",
        "// A hand edit here fails CI's regeneration check, so the web deck and the",
        "// compiled Swift deck cannot drift apart from each other or from the",
        "// provenance record in data/deck.v1.json (SPEC §4).",
        "//",
        "// The instrument itself is public domain:",
        f"//   {instrument['title']}",
        f"//   {instrument['authors']}",
        f"//   {instrument['institution']}, {instrument['year']}",
        "",
        '"use strict";',
        "",
        "globalThis.VCS_DECK_V1 = Object.freeze({",
        f"  deckVersion: {js_string(deck['deckVersion'])},",
        "  instrument: Object.freeze({",
        f"    title: {js_string(instrument['title'])},",
        f"    authors: {js_string(instrument['authors'])},",
        f"    institution: {js_string(instrument['institution'])},",
        f"    year: {instrument['year']},",
        f"    copyright: {js_string(instrument['copyright'])},",
        "    sources: Object.freeze([",
    ]
    for source in instrument["sources"]:
        lines.append(f"      {js_string(source)},")
    lines += [
        "    ]),",
        f"    verification: {js_string(instrument['verification'])},",
        "  }),",
        f"  cardCount: {deck['cardCount']},",
        "  cards: Object.freeze([",
    ]
    for card in cards:
        lines.append(
            f"    Object.freeze({{ id: {card['id']}, "
            f"name: {js_string(card['name'])}, "
            f"descriptor: {js_string(card['descriptor'])} }}),"
        )
    lines += [
        "  ]),",
        "});",
        "",
    ]
    return "\n".join(lines)


TARGETS = (
    (SWIFT_OUTPUT, render_swift),
    (JS_OUTPUT, render_js),
)


def main() -> int:
    deck = json.loads(DECK_JSON.read_text(encoding="utf-8"))
    check_only = "--check" in sys.argv
    failed = False

    for output, render in TARGETS:
        rendered = render(deck)
        relative = output.relative_to(ROOT)

        if check_only:
            if not output.exists():
                print(f"FAIL {relative} does not exist — run ./scripts/generate-deck.sh")
                failed = True
                continue
            if output.read_text(encoding="utf-8") != rendered:
                print(f"FAIL {relative} is not what data/deck.v1.json generates.")
                print("     Either the generated file was hand-edited, or the deck changed")
                print("     without regenerating. Both are deck drift (SPEC §4).")
                print("     Run ./scripts/generate-deck.sh and review the diff.")
                failed = True
                continue
            print(f"  ok   {relative} matches data/deck.v1.json")
            continue

        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered, encoding="utf-8")
        print(f"wrote {relative} ({len(deck['cards'])} cards)")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
