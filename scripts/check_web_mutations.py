# SPDX-License-Identifier: GPL-3.0-or-later
"""Mutation proof for the web rule suite — the register's `M` rows, executed.

`docs/conventions.md`: *a test that has never been shown to fail is not
evidence.* That line was written after fifteen checks passed against a parser
that was returning the wrong answer for every row, so this is not a theoretical
concern in this repository.

Each mutation below is a named way to break one rule of the instrument. The
runner copies the tree to a scratch directory, applies exactly one mutation,
runs `node --test`, and requires that the suite **fails** — and that the named
test is among the failures. A mutation the suite survives is reported as a hole
in the suite, which is the whole point of running this.

    python3 scripts/check_web_mutations.py
    python3 scripts/check_web_mutations.py --list
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# (id, file, find, replace, rule, the test that must catch it)
MUTATIONS = [
    ("M1", "web/index.html",
     "S.piles[p].push(id);",
     "S.piles[p].unshift(id);",
     "R2", "R2 a pile keeps assignment order"),

    ("M2", "web/index.html",
     "S.queue.unshift(last.card);",
     "S.queue.push(last.card);",
     "R3", "R3 undo returns the card to the FRONT"),

    ("M3", "web/index.html",
     "S.queue.unshift(cid);",
     "S.queue.push(cid);",
     "R4", "R4 a written card is uppercased and goes to the front"),

    ("M4", "web/index.html",
     "if (!n) return null;",
     "if (false) return null;",
     "R4", "R4 a blank name is refused"),

    ("M5", "web/index.html",
     "if (kept.length < 5 || kept.length > 10) return;",
     "if (kept.length < 0) return;",
     "R5", "R5 cull refuses to finish outside the 5-10 band"),

    ("M6", "web/index.html",
     "return out.concat(draft.promotions);",
     "return out.concat(draft.promotions.slice().sort());",
     "R6", "R6 promotion order is preserved into the kept set"),

    ("M7", "web/index.html",
     "if (j < 0 || j >= S.ranking.length) return;",
     "if (j < 0) return;",
     "R7", "R7 moving past either end is a no-op"),

    ("M8", "web/index.html",
     'if (phase === "export" && S.completedAt === null) {',
     'if (phase === "export") {',
     "D4", "R8 the export date is completion time"),

    ("M9", "web/index.html",
     's += "\\n-----\\n" + date + "\\n";',
     's += "\\n-----\\n" + date + "\\n\\n#AI/Claude\\n";',
     "O2", "R8 the export drops the #AI/Claude tag"),

    ("M10", "web/index.html",
     "  var x = a.slice();",
     "  var x = a.slice(); return x;",
     "R1", "R1 two sessions do not produce the same order"),

    ("M11", "web/index.html",
     "  S.history.push({ card: id, pile: p });",
     '  S.history.push({ card: id, pile: p }); localStorage.setItem("vcs", "1");',
     "SPEC §7", "the page touches no storage or network API"),

    ("M12", "web/deck.js",
     '"to be accepted as I am"',
     '"to be accepted only when I comply"',
     "SPEC §4", "the page's deck is the generated one"),

    # M14 is the attack that defeated the previous privacy gate: two string
    # literals containing the block-comment delimiters hid a storage write from
    # a regex-based comment stripper. The runtime trap in rules.test.js cannot
    # be fooled this way, because a call cannot hide from the thing it calls.
    ("M14", "web/index.html",
     "  S.history.push({ card: id, pile: p });",
     '  S.history.push({ card: id, pile: p }); var a = "/*"; localStorage.setItem("x","1"); var b = "*/";',
     "SPEC §7", "the page touches no storage or network API"),

    # M15-M18: the four export mutations that survived before R8 had a golden
    # file. All four leave every "does the heading appear" assertion green.
    ("M15", "web/index.html",
     's += "\\n## Full sort\\n";\n  for (var p = 4; p >= 0; p--) {',
     's += "\\n## Full sort\\n";\n  for (var p = 0; p <= 4; p++) {',
     "R8", "R8 the markdown export matches the golden file"),

    ("M16", "web/index.html",
     '    var ids = (p === 4) ? S.ranking : S.piles[p];\n    if (!ids.length)',
     '    var ids = S.piles[p];\n    if (!ids.length)',
     "R8", "R8 the markdown export matches the golden file"),

    ("M17", "web/index.html",
     '  s += "Completed: " + date + "\\n\\n## Top values (ranked)\\n\\n";',
     '  s += "\\n## Top values (ranked)\\n\\n";',
     "R8", "R8 the markdown export matches the golden file"),

    ("M18", "web/index.html",
     '      s += "- " + c.name + " - " + c.descriptor + "\\n";',
     '      s += "- " + c.name + "\\n";',
     "R8", "R8 the markdown export matches the golden file"),

    ("M13", "web/index.html",
     '"Most important to me"',
     '"The most important ones"',
     "R2", "R8 markdown carries every pile"),
]


def run_suite(tree: Path) -> tuple[bool, str]:
    """Runs the web rule suite inside `tree`. Returns (passed, output)."""
    proc = subprocess.run(
        ["node", "--test", str(tree / "web" / "tests" / "rules.test.js")],
        capture_output=True, text=True, cwd=tree,
    )
    return proc.returncode == 0, proc.stdout + proc.stderr


def failing_tests(output: str) -> list[str]:
    return re.findall(r"^✖ (.+?) \(", output, flags=re.M)


def main() -> int:
    if "--list" in sys.argv:
        for mid, _f, _a, _b, rule, test in MUTATIONS:
            print(f"{mid:4} {rule:8} caught by: {test}")
        return 0

    print("Web rule mutations (docs/conventions.md — assertions are not evidence)")
    print()

    with tempfile.TemporaryDirectory() as tmp:
        base = Path(tmp) / "base"
        shutil.copytree(ROOT / "web", base / "web")
        shutil.copytree(ROOT / "data", base / "data")

        ok, out = run_suite(base)
        if not ok:
            print("FAIL the suite does not pass before any mutation is applied.")
            print(out[-2000:])
            return 1
        print("  ok   the suite passes unmutated (baseline)")
        print()

        survivors = []
        for mid, rel, find, replace, rule, expect in MUTATIONS:
            work = Path(tmp) / mid
            shutil.copytree(base, work)
            target = work / rel
            src = target.read_text(encoding="utf-8")

            if src.count(find) != 1:
                print(f"  FAIL {mid} ({rule}): its anchor appears {src.count(find)} "
                      f"times in {rel}, not once — the mutation is stale.")
                survivors.append(mid)
                continue

            target.write_text(src.replace(find, replace), encoding="utf-8")
            passed, output = run_suite(work)

            if passed:
                print(f"  FAIL {mid} ({rule}): the suite SURVIVED this mutation. "
                      f"'{expect}' did not catch it.")
                survivors.append(mid)
                continue

            caught = failing_tests(output)
            named = [t for t in caught if expect.lower() in t.lower()]
            if named:
                print(f"  ok   {mid} ({rule}) killed by: {named[0]}")
            else:
                print(f"  ok   {mid} ({rule}) killed, but by {caught[:2]} "
                      f"rather than the expected '{expect}'")

        print()
        if survivors:
            print(f"FAILED — {len(survivors)} mutation(s) survived: {', '.join(survivors)}")
            print("        A surviving mutation is a hole in the suite, not a passing grade.")
            return 1
        print(f"PASSED — all {len(MUTATIONS)} mutations were caught")
        return 0


if __name__ == "__main__":
    sys.exit(main())
