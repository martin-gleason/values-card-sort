# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests for the privacy gate's lexer.

The gate is only as good as `strip_comments`. An adversarial review found that
an earlier version could be blinded for an entire file by one line of ordinary
Swift, so the lexer now has its own tests — a gate whose parser is untested is
a gate that reports PASSED for reasons nobody has checked.

Run: python3 scripts/test_check_privacy.py
"""

from __future__ import annotations

import sys

from check_privacy import AMBIGUOUS, FORBIDDEN, FORBIDDEN_IMPORTS, allow_markers, strip_comments

failures: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}{(' — ' + detail) if detail else ''}")
        failures.append(name)


def visible(source: str) -> str:
    """What the gate actually greps."""
    return strip_comments(source)


def hides(source: str, needle: str = "URLSession") -> bool:
    return needle not in visible(source)


print("Privacy gate lexer")

# --- comments really are stripped -------------------------------------------
check("line comments are stripped", hides("// URLSession\nlet x = 1\n"))
check("block comments are stripped", hides("/* URLSession */\nlet x = 1\n"))
check("nested block comments are stripped", hides("/* a /* URLSession */ b */\n"))
check("doc comments are stripped", hides("/// see URLSession\n"))

# --- but code is not --------------------------------------------------------
check("plain code survives", not hides("let s = URLSession.shared\n"))
check(
    "code after a line comment survives",
    not hides("// harmless\nlet s = URLSession.shared\n"),
)
check(
    "code after a block comment survives",
    not hides("/* harmless */\nlet s = URLSession.shared\n"),
)

# --- the regression that prompted these tests -------------------------------
# A nested string inside \(…) interpolation was read as closing the outer
# string, leaving the lexer in code mode inside string content. The `/*` then
# opened a block comment that never closed and blanked the rest of the file.
check(
    "interpolation containing a nested string with /* does not blind the file",
    not hides('let g = "prefix \\("/*") suffix"\nlet s = URLSession.shared\n'),
)
check(
    "interpolation containing a nested string with // does not blind the line",
    not hides('let g = "see \\("https://x.example") ok"\nlet t = URLSession.shared\n'),
)
check(
    "interpolation containing a nested string with // on the SAME line",
    not hides('let g = "see \\("//x") ok"; let t = URLSession.shared\n'),
)

# --- other string forms -----------------------------------------------------
check(
    "raw strings do not treat backslash as an escape",
    not hides('let p = #"a\\"#\nlet s = URLSession.shared\n'),
)
check(
    "raw string interpolation uses hashed escapes",
    not hides('let p = #"x \\#("/*") y"#\nlet s = URLSession.shared\n'),
)
check(
    "multiline strings close correctly",
    not hides('let m = """\n/* not a comment */\n"""\nlet s = URLSession.shared\n'),
)
check(
    "an escaped quote does not close the string",
    not hides('let q = "he said \\"/*\\" ok"\nlet s = URLSession.shared\n'),
)
check(
    "nested interpolation survives",
    not hides('let d = "a \\("b \\("c") d") e"\nlet s = URLSession.shared\n'),
)
check(
    "a string containing a networking symbol is still visible (conservative)",
    not hides('let s = "URLSession"\n'),
)

# --- line numbering is preserved so findings cite the right line ------------
stripped = strip_comments("/* a\nb\nc */\nlet s = URLSession.shared\n")
check(
    "line numbers survive multi-line comments",
    stripped.splitlines()[3].strip() == "let s = URLSession.shared",
    repr(stripped.splitlines()),
)

# --- the patterns themselves ------------------------------------------------
check("URLSession is forbidden", bool(FORBIDDEN.search("URLSession.shared")))
check("import Network is forbidden", bool(FORBIDDEN_IMPORTS.search("import Network")))
check("import CloudKit is forbidden", bool(FORBIDDEN_IMPORTS.search("import CloudKit")))
check(
    "a URL string alone is not a finding (SPEC §5.5 needs attribution links)",
    not FORBIDDEN.search('let u = URL(string: "https://motivationalinterviewing.org")'),
)
check(
    "openURL is not a finding",
    not FORBIDDEN.search("openURL(sourceURL)") and not AMBIGUOUS.search("openURL(sourceURL)"),
)
check("Data(contentsOf:) is ambiguous", bool(AMBIGUOUS.search("try Data(contentsOf: url)")))
check("String(contentsOf:) is ambiguous", bool(AMBIGUOUS.search("String(contentsOf: u)")))
check("Process() is ambiguous", bool(AMBIGUOUS.search("let p = Process()")))

# --- allow markers ----------------------------------------------------------
markers = allow_markers("// privacy-ok(file-url): bundle resource only\nlet d = 1\n")
check("allow markers are parsed", markers.get(1, "").startswith("file-url:"))
check(
    "allow markers are read before stripping",
    "privacy-ok" not in visible("// privacy-ok(x): y\n"),
)

print()
if failures:
    print(f"FAILED — {len(failures)} check(s)")
    sys.exit(1)
print("PASSED — the lexer sees what it should and blanks what it should")
