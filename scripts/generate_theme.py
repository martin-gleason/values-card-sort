# SPDX-License-Identifier: GPL-3.0-or-later
"""Compile data/themes.v1.json into Swift.

Same reasoning as `generate_deck.py`, applied to colour. The tokens are gated by
`scripts/check_theme_contrast.py`; a card face that hand-copies them is a second
copy that can drift out from under the gate, and drifting colour is exactly how
`ACCENT #C75146` reached two surfaces unmeasured and failed on both (`D10`).

So the app reads no hex literals of its own: the only hex in the codebase lives
in `data/themes.v1.json`, which the contrast gate measures. A hand edit to the
generated file fails `--check`, and a token edit that drops a pair below its
threshold fails the contrast gate first.

**This is not the theme engine.** F8 owns that, and owns loading themes as data
so v1.5's "design your own card" is possible. F2 needs one theme's colours in a
form SwiftUI can use, and this is the smallest thing that keeps them honest.

The output lands in the **app** target, not `ValuesCardSortKit`: the rule package
deliberately depends on nothing but Foundation, so that `swift test` needs no
simulator. Colour is presentation and belongs on the other side of that line.

Usage:
    python3 scripts/generate_theme.py            # write the file
    python3 scripts/generate_theme.py --check    # verify it is up to date
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEMES = ROOT / "data" / "themes.v1.json"
OUTPUT = ROOT / "App" / "Theme" / "Theme.v1.generated.swift"


def swift_identifier(key: str) -> str:
    head, *rest = key.split("-")
    return head + "".join(part.capitalize() for part in rest)


def components(hex_colour: str) -> tuple[float, float, float]:
    h = hex_colour.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))  # type: ignore[return-value]


def render(data: dict) -> str:
    lines = [
        "// SPDX-License-Identifier: GPL-3.0-or-later",
        "//",
        "// GENERATED FILE — DO NOT EDIT.",
        "//",
        "// Produced by scripts/generate_theme.py from data/themes.v1.json.",
        "// Regenerate with: python3 scripts/generate_theme.py",
        "//",
        "// Every colour the card face uses comes from here, and every value here",
        "// is measured by scripts/check_theme_contrast.py against SPEC §6's",
        "// thresholds. A hand edit fails the regeneration check; a token change",
        "// that drops a pair below threshold fails the contrast gate first.",
        "//",
        "// See D10: the reference's single ACCENT token failed four of ten pairs",
        "// and reached two surfaces before anyone measured it.",
        "",
        "import SwiftUI",
        "",
        "/// A card face and the desk it sits on (SPEC §5.3).",
        "///",
        "/// Themes skin the card face and desk surface and nothing else — never",
        "/// chrome, navigation or system controls (SPEC §3.1).",
        "struct CardTheme: Sendable, Identifiable {",
        "    let id: String",
        "    let displayName: String",
        "    /// True when the card renders identically in light and dark.",
        "    ///",
        "    /// Every pair is card-face-internal or card-on-desk: none involves a",
        "    /// system background, so the ratios do not change with appearance. A",
        "    /// physical card on a desk looks the same whichever way the room is lit.",
        "    let appearanceIndependent: Bool",
        "",
        "    let desk: Color",
        "    let cardStock: Color",
        "    let ink: Color",
        "    let onDesk: Color",
        "    /// Accent as a FILL, behind white text.",
        "    let accentFill: Color",
        "    /// Accent as TEXT, on the card stock. Darker than the fill: the same",
        "    /// value cannot clear 4.5:1 in both roles.",
        "    let accentText: Color",
        "    /// Accent on the desk, where the surrounding luminance is far lower.",
        "    let accentOnDesk: Color",
        "",
        "    /// Decorative only — an index card's ruled lines identify no control",
        "    /// and carry no information, so WCAG 1.4.11 does not scope to them.",
        "    let rule: Color?",
        "    let ruleTop: Color?",
        "}",
        "",
        "private extension Color {",
        "    /// sRGB, matching how the contrast gate computes luminance.",
        "    init(srgb r: Double, _ g: Double, _ b: Double) {",
        "        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)",
        "    }",
        "}",
        "",
        "extension CardTheme {",
    ]

    for key, theme in data["themes"].items():
        tokens = theme["tokens"]
        if not all(isinstance(v, str) for v in tokens.values()):
            raise SystemExit(
                f"theme {key!r} still has per-appearance tokens; F2 supports only "
                "appearance-independent themes (see D10, D11)"
            )

        def colour(name: str, optional: bool = False) -> str:
            if name not in tokens:
                if optional:
                    return "nil"
                raise SystemExit(f"theme {key!r} is missing token {name!r}")
            r, g, b = components(tokens[name])
            return f"Color(srgb: {r:.6f}, {g:.6f}, {b:.6f})"

        lines += [
            f"    /// {theme['displayName']}"
            + ("  — the default (SPEC §5.3)." if theme.get("default") else "."),
            f"    static let {swift_identifier(key)} = CardTheme(",
            f'        id: "{key}",',
            f'        displayName: "{theme["displayName"]}",',
            f"        appearanceIndependent: {str(theme['appearanceIndependent']).lower()},",
            f"        desk: {colour('desk')},",
            f"        cardStock: {colour('cardStock')},",
            f"        ink: {colour('ink')},",
            f"        onDesk: {colour('onDesk')},",
            f"        accentFill: {colour('accentFill')},",
            f"        accentText: {colour('accentText')},",
            f"        accentOnDesk: {colour('accentOnDesk')},",
            f"        rule: {colour('rule', optional=True)},",
            f"        ruleTop: {colour('ruleTop', optional=True)}",
            "    )",
            "",
        ]

    default = next(k for k, t in data["themes"].items() if t.get("default"))
    lines += [
        "    /// Every theme this build ships, in menu order.",
        "    static let all: [CardTheme] = ["
        + ", ".join(swift_identifier(k) for k in data["themes"])
        + "]",
        "",
        f"    /// The default until Settings ships (F9). SessionState records it per session.",
        f"    static let `default` = {swift_identifier(default)}",
        "}",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    data = json.loads(THEMES.read_text(encoding="utf-8"))
    rendered = render(data)
    relative = OUTPUT.relative_to(ROOT)

    if "--check" in sys.argv:
        if not OUTPUT.exists():
            print(f"FAIL {relative} does not exist — run python3 scripts/generate_theme.py")
            return 1
        if OUTPUT.read_text(encoding="utf-8") != rendered:
            print(f"FAIL {relative} is not what data/themes.v1.json generates.")
            print("     Either the generated file was hand-edited, or the tokens")
            print("     changed without regenerating. Both put the card face out")
            print("     from under the contrast gate (D10).")
            return 1
        print(f"  ok   {relative} matches data/themes.v1.json")
        return 0

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(rendered, encoding="utf-8")
    print(f"wrote {relative} ({len(data['themes'])} theme(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
