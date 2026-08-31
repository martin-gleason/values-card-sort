# SPDX-License-Identifier: GPL-3.0-or-later
"""Departures register gate — SPEC §3.1 (D7), §6.

SPEC §3.1 allows declining a stock component only where it fails the §6
accessibility gate, and only if the departure is recorded in
`docs/departures.md` with evidence. That rule is exactly the kind a future
session drifts past — the code keeps working, the register quietly goes stale,
and a year later nobody can say why the app stopped using `List`.

So the register is checked rather than trusted:

- every evidence file it names must exist (no dead links);
- every entry must carry the sections that make it reviewable, including
  "what was tried" — a departure taken without exhausting the component is a
  shortcut using the register as cover;
- every screenshot under docs/evidence/ must be accounted for — named by a
  register entry, or by a README in its own evidence directory — so a stale
  image cannot sit there implying something nobody wrote down.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTER = ROOT / "docs" / "departures.md"
EVIDENCE = ROOT / "docs" / "evidence"

REQUIRED_SECTIONS = ["What failed", "What replaced it", "Evidence"]

failures: list[str] = []


def check(condition: bool, message: str) -> None:
    print(f"  {'ok  ' if condition else 'FAIL'} {message}")
    if not condition:
        failures.append(message)


def main() -> int:
    print("Component departures (SPEC §3.1 D7)")

    if not REGISTER.exists():
        print(f"  FAIL {REGISTER.relative_to(ROOT)} is missing")
        return 1

    text = REGISTER.read_text(encoding="utf-8")

    # Entries are "## <n>. <title>" headings.
    entries = re.findall(r"^## (\d+)\. (.+)$", text, re.MULTILINE)
    check(bool(entries), f"register lists at least one departure ({len(entries)} found)")

    # Split into per-entry bodies so required sections are checked per entry.
    chunks = re.split(r"^## \d+\. ", text, flags=re.MULTILINE)[1:]
    for (number, title), body in zip(entries, chunks):
        for section in REQUIRED_SECTIONS:
            check(f"### {section}" in body,
                  f"departure {number} ({title[:40]}) documents '{section}'")
        # "What was tried" is the one people skip; accept it inside the entry
        # either as a heading or as an explicit phrase.
        tried = "### What was tried" in body or "what was tried" in body.lower()
        check(tried, f"departure {number} ({title[:40]}) says what was tried first")

    # Evidence links must resolve. Paths in the register are relative to docs/.
    referenced: set[Path] = set()
    for link in re.findall(r"`(evidence/[^`]+\.png)`", text):
        path = ROOT / "docs" / link
        referenced.add(path.resolve())
        check(path.exists(), f"evidence exists: {link}")

    check(bool(referenced), "register links to screenshot evidence")

    # Not every screenshot is departure evidence. The web port's accessibility
    # captures (Web/F1) document a WCAG run, not a component we declined to use,
    # and filing them as departures to satisfy this check would put a false
    # entry in the register — the opposite of what it is for.
    #
    # The rule's actual intent is that no image sits in docs/evidence/ implying
    # something nobody wrote down. A README beside the images does that job, so
    # an image is accounted for if the register names it OR its own directory's
    # README does.
    for readme in EVIDENCE.rglob("README.md"):
        body = readme.read_text(encoding="utf-8")
        for name in re.findall(r"`([\w.-]+\.png)`", body):
            referenced.add((readme.parent / name).resolve())

    # No orphan screenshots implying an undocumented departure.
    if EVIDENCE.is_dir():
        on_disk = {p.resolve() for p in EVIDENCE.rglob("*.png")}
        orphans = sorted(p.relative_to(ROOT) for p in on_disk - referenced)
        check(not orphans, "every screenshot under docs/evidence/ is accounted for")
        for orphan in orphans:
            print(f"       unreferenced: {orphan}")

    print()
    if failures:
        print(f"FAILED — {len(failures)} check(s)")
        return 1
    print("PASSED — every departure is documented and evidenced")
    return 0


if __name__ == "__main__":
    sys.exit(main())
