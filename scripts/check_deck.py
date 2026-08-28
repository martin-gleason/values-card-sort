# SPDX-License-Identifier: GPL-3.0-or-later
"""Deck fidelity gate — SPEC §4, TESTING.md layer 1.

Dependency-free on purpose: this runs on a bare Ubuntu CI runner with no Xcode,
no Swift, and no pip install step, so deck drift is caught on every PR for
almost nothing. Swift Testing re-asserts the same facts against the resource
the app actually loads (DeckFidelityTests), covering the other failure mode:
a correct file that never reaches the bundle.

Two hashes are pinned, and the reason is C1:

  FILE_SHA256    — SPEC §4's hash of the whole file. Strongest possible check,
                   but self-invalidating: C1 sign-off edits
                   instrument.verification *inside* this file, which changes
                   the hash. Enforced until sign-off, then re-pinned.
  PAYLOAD_SHA256 — hash of just the 83 cards in a canonical, language-neutral
                   serialization. Survives the sign-off edit, so card drift
                   keeps failing CI forever.

The payload form is separator-delimited rather than JSON so that Python and
Swift cannot disagree about key ordering or string escaping:

    id US name US descriptor   (per card, in file order)
    joined by RS

where US = U+001F, RS = U+001E — control characters that cannot occur in the
card data. Deck v1 is pure ASCII, verified.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DECK = ROOT / "data" / "deck.v1.json"
SCHEMA = ROOT / "data" / "deck.schema.json"
GENERATED = ROOT / "Sources" / "ValuesCardSortKit" / "Deck" / "Deck.v1.generated.swift"

EXPECTED_COUNT = 83
FILE_SHA256 = "13a3db92c997eb98679237fe3ddf22b40d4379528a9f991bbf1894ef6847ad8d"
PAYLOAD_SHA256 = "10a4c3938226a83f72724809d91f817051d29164f517554b5b3ac6f6775c25d4"

US = chr(0x1F)
RS = chr(0x1E)

failures: list[str] = []


def check(condition: bool, message: str) -> None:
    if condition:
        print(f"  ok   {message}")
    else:
        print(f"  FAIL {message}")
        failures.append(message)


# --------------------------------------------------------------------------
# A minimal JSON Schema (draft 2020-12) validator.
#
# Only the keywords data/deck.schema.json actually uses are implemented. A
# real validator would mean a pip dependency in the one CI job whose whole
# point is being free; a schema nothing checks would mean the contract is
# decoration. This is the narrow path between those.
# --------------------------------------------------------------------------
def validate(instance, schema, path="$") -> list[str]:
    errors: list[str] = []

    def err(msg: str) -> None:
        errors.append(f"{path}: {msg}")

    if "const" in schema and instance != schema["const"]:
        err(f"expected const {schema['const']!r}, got {instance!r}")

    expected_type = schema.get("type")
    if expected_type:
        ok = {
            "object": lambda v: isinstance(v, dict),
            "array": lambda v: isinstance(v, list),
            "string": lambda v: isinstance(v, str),
            # bool is a subclass of int in Python; the deck has no booleans.
            "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
        }[expected_type]
        if not ok(instance):
            err(f"expected type {expected_type}, got {type(instance).__name__}")
            return errors

    if isinstance(instance, str):
        if "minLength" in schema and len(instance) < schema["minLength"]:
            err(f"shorter than minLength {schema['minLength']}")
        if "pattern" in schema and not re.match(schema["pattern"], instance):
            err(f"{instance!r} does not match pattern {schema['pattern']}")

    if isinstance(instance, int) and not isinstance(instance, bool):
        if "minimum" in schema and instance < schema["minimum"]:
            err(f"{instance} below minimum {schema['minimum']}")
        if "maximum" in schema and instance > schema["maximum"]:
            err(f"{instance} above maximum {schema['maximum']}")

    if isinstance(instance, list):
        if "minItems" in schema and len(instance) < schema["minItems"]:
            err(f"{len(instance)} items, minItems {schema['minItems']}")
        if "maxItems" in schema and len(instance) > schema["maxItems"]:
            err(f"{len(instance)} items, maxItems {schema['maxItems']}")
        if schema.get("uniqueItems") and len(instance) != len({json.dumps(i, sort_keys=True) for i in instance}):
            err("items are not unique")
        if "items" in schema:
            for i, item in enumerate(instance):
                errors.extend(validate(item, schema["items"], f"{path}[{i}]"))

    if isinstance(instance, dict):
        for key in schema.get("required", []):
            if key not in instance:
                err(f"missing required property {key!r}")
        props = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            for key in instance:
                if key not in props:
                    err(f"unexpected property {key!r}")
        for key, subschema in props.items():
            if key in instance:
                errors.extend(validate(instance[key], subschema, f"{path}.{key}"))

    return errors


def main() -> int:
    print("Deck fidelity (SPEC §4)")

    if not DECK.exists():
        print(f"  FAIL {DECK} does not exist")
        return 1

    raw = DECK.read_bytes()

    try:
        deck = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"  FAIL deck.v1.json does not parse: {exc}")
        return 1
    check(True, "deck.v1.json parses")

    schema = json.loads(SCHEMA.read_text())
    schema_errors = validate(deck, schema)
    check(not schema_errors, "validates against data/deck.schema.json")
    for e in schema_errors[:20]:
        print(f"       {e}")

    cards = deck.get("cards", [])
    check(deck.get("cardCount") == EXPECTED_COUNT == len(cards),
          f"cardCount == cards.count == {EXPECTED_COUNT} "
          f"(got cardCount={deck.get('cardCount')}, cards={len(cards)})")

    ids = [c.get("id") for c in cards]
    check(ids == list(range(1, EXPECTED_COUNT + 1)), "ids are contiguous 1…83 in file order")

    names = [c.get("name") for c in cards]
    check(len(set(names)) == len(names), "card names are unique")

    file_hash = hashlib.sha256(raw).hexdigest()
    check(file_hash == FILE_SHA256, f"file SHA-256 matches SPEC §4 ({file_hash[:12]}…)")
    if file_hash != FILE_SHA256:
        print(f"       expected {FILE_SHA256}")
        print(f"       actual   {file_hash}")
        print("       If this is chore C1 sign-off, re-pin FILE_SHA256 here and in SPEC §4.")
        print("       Any other cause is deck drift — the deck is immutable (SPEC §4).")

    blob = RS.join(f"{c['id']}{US}{c['name']}{US}{c['descriptor']}" for c in cards)
    payload_hash = hashlib.sha256(blob.encode("utf-8")).hexdigest()
    check(payload_hash == PAYLOAD_SHA256,
          f"card-payload SHA-256 matches ({payload_hash[:12]}…)")
    if payload_hash != PAYLOAD_SHA256:
        print(f"       expected {PAYLOAD_SHA256}")
        print(f"       actual   {payload_hash}")
        print("       The 83 cards themselves changed. This never passes without a ratified")
        print("       spec delta and a new versioned deck file (SPEC §4).")

    # The compiled deck must be exactly what this JSON generates.
    #
    # The app ships Swift, not JSON (SPEC §4, ratified 2026-08-14): there is no
    # deck resource in the bundle to swap, and no soft JSON target in a diff.
    # That only holds if the generated Swift cannot drift from its source, so
    # regeneration is asserted here rather than trusted.
    #
    # Together with the two hashes this means a card's text cannot be changed
    # by editing the JSON (hashes fail), by editing the generated Swift
    # (regeneration fails), or by patching the binary (the app re-checks the
    # payload hash at launch and refuses to run).
    generator = ROOT / "scripts" / "generate_deck.py"
    if generator.exists():
        result = subprocess.run(
            [sys.executable, str(generator), "--check"],
            capture_output=True,
            text=True,
        )
        check(result.returncode == 0,
              "compiled deck matches data/deck.v1.json (no hand edits)")
        if result.returncode != 0:
            for line in (result.stdout + result.stderr).strip().splitlines():
                print(f"       {line}")
    else:
        print("  FAIL scripts/generate_deck.py is missing; the deck cannot be verified")
        failures.append("generator missing")

    check(GENERATED.exists(),
          "the deck is compiled into Swift, not bundled as a loadable resource")

    # There must be no JSON deck anywhere the app could load at runtime.
    stray = [
        path.relative_to(ROOT)
        for path in ROOT.rglob("deck.v*.json")
        if "data" not in path.relative_to(ROOT).parts and ".build" not in path.parts
    ]
    check(not stray, "no deck JSON outside data/ (nothing shippable to swap)")
    for path in stray:
        print(f"       stray: {path}")

    print()
    if failures:
        print(f"FAILED — {len(failures)} check(s)")
        return 1
    print("PASSED — deck is faithful and frozen")
    return 0


if __name__ == "__main__":
    sys.exit(main())
