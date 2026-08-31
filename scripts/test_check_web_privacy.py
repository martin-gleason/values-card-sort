# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests for the web privacy gate's own scanner.

The baseline records why the Swift gate carries a test suite: *"an adversarial
review showed one line of ordinary Swift could blind it for a whole file."*
The web gate shipped with the same class of bug and it was found the same way,
so it gets the same treatment.

The load-bearing case is `test_string_literals_cannot_blind_the_scanner`: the
previous implementation stripped `/*…*/` with a lazy regex, so two string
literals were enough to hide arbitrary code from it.

    python3 scripts/test_check_web_privacy.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_web_privacy as gate  # noqa: E402

failures: list[str] = []


def check(ok: bool, label: str, detail: str = "") -> None:
    if ok:
        print(f"  ok   {label}")
    else:
        print(f"  FAIL {label}{chr(10) + '       ' + detail if detail else ''}")
        failures.append(label)


def visible(src: str, html: bool = False) -> str:
    return gate.strip_comments(src, html=html)


# --- the attack that defeated the previous gate ---------------------------

ATTACK = '\n'.join([
    'var a = "/*";',
    'localStorage.setItem("vcs_leak", JSON.stringify(S));',
    'new Image().src = "https://www.gnu.org/licenses/gpl-3.0.html";',
    'var b = "*/";',
])
check("localStorage" in visible(ATTACK),
      "test_string_literals_cannot_blind_the_scanner",
      "a /* inside a string must not open a comment")
check("new Image" in visible(ATTACK),
      "test_the_beacon_in_the_blinded_span_is_still_visible")

# --- comments really are stripped ----------------------------------------

check("localStorage" not in visible('// we never use localStorage\nvar x = 1;'),
      "test_line_comments_are_stripped")
check("localStorage" not in visible('/* no localStorage here */\nvar x = 1;'),
      "test_block_comments_are_stripped")
check("localStorage" not in visible('<!-- no localStorage -->\n<p>x</p>', html=True),
      "test_html_comments_are_stripped_in_html")
check("localStorage" in visible('<!-- no localStorage -->', html=False),
      "test_html_comments_are_NOT_stripped_in_js",
      "a .js file has no <!-- -->; treating it as one would hide code")

# --- string handling ------------------------------------------------------

check("localStorage" not in visible('var s = "a // b";\n// localStorage\n'),
      "test_a_slash_slash_inside_a_string_does_not_end_the_line_early")
check(visible('var s = "x";\nvar t = 2;').count("\n") == 1,
      "test_line_numbering_is_preserved")
check("fetch(" in visible("var s = 'quoted';\nfetch('/x');"),
      "test_code_after_a_single_quoted_string_is_still_seen")
check("fetch(" in visible("var s = `tpl`;\nfetch('/x');"),
      "test_code_after_a_template_literal_is_still_seen")
check("fetch(" in visible('var s = "esc\\"aped";\nfetch("/x");'),
      "test_an_escaped_quote_does_not_swallow_the_rest_of_the_file")

# --- the real files pass --------------------------------------------------

rc = gate.main()
check(rc == 0, "test_the_shipped_page_passes_the_gate", f"exit={rc}")

# --- and the gate fails when it should ------------------------------------

import re  # noqa: E402

entry = gate.ENTRY.read_text(encoding="utf-8")
try:
    for needle, mutation in [
        ("storage write", '<script>\nlocalStorage.setItem("x", "1");\n</script>'),
        ("network call", '<script>\nfetch("https://example.com/beacon");\n</script>'),
        ("image beacon", '<script>\nnew Image().src = "https://www.gnu.org/licenses/gpl-3.0.html";\n</script>'),
        ("blinded write", '<script>\nvar a = "/*";\nlocalStorage.setItem("x","1");\nvar b = "*/";\n</script>'),
        ("off-origin script", '<script src="https://cdn.example.com/x.js"></script>'),
    ]:
        gate.ENTRY.write_text(entry + "\n" + mutation, encoding="utf-8")
        check(gate.main() == 1, f"test_gate_fails_on_{needle.replace(' ', '_')}")
finally:
    gate.ENTRY.write_text(entry, encoding="utf-8")

print()
if failures:
    print(f"FAILED — {len(failures)} test(s): {', '.join(failures)}")
    sys.exit(1)
print("PASSED — the web privacy scanner cannot be blinded")
