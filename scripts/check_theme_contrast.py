# SPDX-License-Identifier: GPL-3.0-or-later
"""Theme contrast gate — SPEC §5.3 card faces, §6 thresholds.

`docs/design/design-handoff-card-themes.md` already required this:

    A contrast table: card-name and descriptor text over their actual
    backgrounds, light and dark, with computed ratios. Body >= 4.5:1, large
    text >= 3:1. A theme that fails contrast gets revised here, not in the
    build.

Nobody had run it. When it was finally run, **four of ten Note Card pairs
failed** — every one of them the `ACCENT` token, inherited unmeasured from
`reference/valuescardsort.jsx`. The same token had already produced a real
contrast defect on the web port earlier the same day, because both surfaces
copied it from the one source.

That is the whole argument for this file. A table in a document is a promise; a
table a script computes from the tokens the app actually uses is a gate. The
`M` register's own principle applies: prove it can fail, and it fails here on
any token edit that drops a pair below its threshold.

**What is deliberately NOT checked.** Tokens named in a theme's `decorative`
list. WCAG 1.4.11 scopes to graphics needed to understand content or identify a
control; an index card's ruled lines are neither. That is an exemption granted
by the criterion's own scope, not a waiver of it — and it is listed in the data
where a reader can see it, rather than being silently skipped here.

    python3 scripts/check_theme_contrast.py
    python3 scripts/check_theme_contrast.py --table    # print the full table
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEMES = ROOT / "data" / "themes.v1.json"


def _srgb(channel: float) -> float:
    c = channel / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(hex_colour: str) -> float:
    h = hex_colour.lstrip("#")
    if len(h) != 6:
        raise SystemExit(f"not a 6-digit hex colour: {hex_colour!r}")
    r, g, b = (int(h[i : i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * _srgb(r) + 0.7152 * _srgb(g) + 0.0722 * _srgb(b)


def contrast(fg: str, bg: str) -> float:
    a, b = luminance(fg), luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def resolve(token: str, palette: dict[str, str]) -> str:
    """A pair entry is either a token name or a literal hex colour."""
    if token.startswith("#"):
        return token
    if token not in palette:
        raise SystemExit(f"theme references an undefined token: {token!r}")
    return palette[token]


def appearances(theme: dict) -> list[tuple[str, dict[str, str]]]:
    tokens = theme["tokens"]
    # A flat token map means the theme renders identically in both appearances.
    if all(isinstance(v, str) for v in tokens.values()):
        return [("both", tokens)]
    return [(name, palette) for name, palette in tokens.items()]


def main() -> int:
    show_table = "--table" in sys.argv
    data = json.loads(THEMES.read_text(encoding="utf-8"))
    thresholds = data["thresholds"]

    print("Theme contrast (SPEC §5.3 card faces, §6 thresholds)")

    failures: list[str] = []
    checked = 0

    for key, theme in data["themes"].items():
        decorative = set(theme.get("decorative", []))
        for appearance, palette in appearances(theme):
            label = f"{theme['displayName']} ({appearance})"
            if show_table:
                print(f"\n  {label}")
            for name, fg_token, bg_token, kind in theme["contrast"]:
                need = thresholds[kind]
                fg, bg = resolve(fg_token, palette), resolve(bg_token, palette)
                ratio = contrast(fg, bg)
                checked += 1

                # A pair whose *background* is a decorative element is still
                # checked — text has to be readable wherever it lands. A pair
                # whose foreground is decorative is not text at all.
                if fg_token in decorative:
                    if show_table:
                        print(f"    skip {name:34} {fg_token} is decorative (1.4.11 does not apply)")
                    continue

                ok = ratio >= need
                if show_table:
                    print(f"    {'ok  ' if ok else 'FAIL'} {name:34} "
                          f"{fg} on {bg}  {ratio:5.2f}:1  need {need}")
                if not ok:
                    failures.append(
                        f"{label}: {name} — {fg} on {bg} is {ratio:.2f}:1, needs {need}:1"
                    )

    print()
    if failures:
        print(f"  FAIL {len(failures)} pair(s) below threshold:")
        for f in failures:
            print(f"       {f}")
        print()
        print("FAILED — a theme that fails contrast is revised in the tokens, not waived here (D5).")
        return 1

    print(f"  ok   {checked} pair(s) checked across "
          f"{len(data['themes'])} theme(s), all at or above threshold")
    print()
    print("PASSED — every card face is readable on its own surface")
    return 0


if __name__ == "__main__":
    sys.exit(main())
