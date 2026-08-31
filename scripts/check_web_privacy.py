# SPDX-License-Identifier: GPL-3.0-or-later
"""Privacy gate for the web surface — SPEC §7, on the files the page loads.

**Why this exists as its own gate.** `check_privacy.py` scans
`SEARCH_ROOTS = ["Sources", "App", "Tests"]` for Swift. `web/` was in none of
them, so CI's "Privacy (SPEC §7)" step passed regardless of what the page
contained, and the entire web privacy claim rested on one node test that did a
substring grep over regex-stripped source.

**Why that grep was not good enough**, in the exact words of the failure: it
stripped `/*…*/` with a lazy regex across the whole file, so *any two string
literals containing `/*` and `*/` deleted every line between them from the
gate's view.* This passes such a check while shipping both a storage write and
a network call:

    var a = "/*";
    localStorage.setItem("vcs_leak", JSON.stringify(S));
    var b = "*/";

The baseline already records why the Swift gate has its own test suite — "one
line of ordinary Swift could blind it for a whole file". This is the same bug,
found the same way, on the other surface. So the scanner here is string-aware
(see `strip_comments`) and has its own tests in `scripts/test_check_web_privacy.py`.

**What is scanned: only what the browser actually loads.** `web/index.html` and
every same-origin script it references. Not `web/tests/`, which is published but
never loaded by the page — and which must be free to *mention* the banned names,
being the thing that checks for them. Scanning it would force an allow-list, and
an allow-list is what let a beacon through last time.

    python3 scripts/check_web_privacy.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
ENTRY = WEB / "index.html"

# APIs that write to the device, or reach the network. None has a non-network,
# non-storage use, so none is excusable: SPEC §7 admits zero exceptions without
# ratification, and D3's "no persistence at all" is absolute on this surface.
FORBIDDEN = [
    ("localStorage", "writes to the device"),
    ("sessionStorage", "writes to the device"),
    ("indexedDB", "writes to the device"),
    ("openDatabase", "writes to the device"),
    ("document.cookie", "writes to the device"),
    ("fetch(", "reaches the network"),
    ("XMLHttpRequest", "reaches the network"),
    ("WebSocket", "reaches the network"),
    ("EventSource", "reaches the network"),
    ("sendBeacon", "reaches the network"),
    ("importScripts", "reaches the network"),
    ("new Image", "an image src is a GET; the classic tracking beacon"),
    ("new Audio", "an audio src is a GET"),
    ("navigator.geolocation", "reads the device's location"),
    ("navigator.mediaDevices", "reads camera or microphone"),
    ("RTCPeerConnection", "reaches the network"),
    ("SharedWorker", "reaches the network"),
    ("new Worker", "loads and runs a separate script"),
    ("serviceWorker", "installs a network proxy"),
]

# Dynamic import: `import(` anywhere in code is a network fetch of a module.
DYNAMIC_IMPORT = re.compile(r"\bimport\s*\(")

# Any src/href that loads something. A same-origin relative URL is fine; an
# absolute one means the page pulls a subresource from another host.
SUBRESOURCE = re.compile(
    r"<(?:script|link|img|iframe|audio|video|source|embed|object)\b[^>]*?"
    r"\b(?:src|href|data)\s*=\s*[\"']([^\"']+)[\"']",
    re.IGNORECASE | re.DOTALL,
)
# <a href> is a link the reader chooses to follow, not a subresource the page
# fetches. Those are checked separately and only for scheme sanity.
ANCHOR = re.compile(r"<a\b[^>]*?\bhref\s*=\s*[\"']([^\"']+)[\"']", re.IGNORECASE | re.DOTALL)


def strip_comments(source: str, html: bool) -> str:
    """Blank out comments while preserving line numbers, tracking string state.

    The whole point: a `/*` inside a string literal does NOT open a comment, so
    the blinding attack above cannot hide code from this scanner. Line count is
    preserved so findings can cite a line number.

    Handles `'`, `"` and backtick strings with backslash escapes, `//` line
    comments, `/* */` block comments, and — in HTML — `<!-- -->`. Template
    literal `${}` interpolation is treated as string content, which is
    conservative: it can only cause a false finding, never hide one.
    """
    out: list[str] = []
    i, n = 0, len(source)
    quote: str | None = None

    while i < n:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < n else ""

        if quote is not None:
            if ch == "\\" and quote != "`":
                out.append(" " if source[i : i + 2] != "\n" else "\n")
                out.append(" ")
                i += 2
                continue
            if ch == quote:
                quote = None
            out.append("\n" if ch == "\n" else ch)
            i += 1
            continue

        if ch in "\"'`":
            quote = ch
            out.append(ch)
            i += 1
            continue

        if ch == "/" and nxt == "/":
            while i < n and source[i] != "\n":
                out.append(" ")
                i += 1
            continue

        if ch == "/" and nxt == "*":
            while i < n and not (source[i] == "*" and i + 1 < n and source[i + 1] == "/"):
                out.append("\n" if source[i] == "\n" else " ")
                i += 1
            out.append("  ")
            i += 2
            continue

        if html and source.startswith("<!--", i):
            while i < n and not source.startswith("-->", i):
                out.append("\n" if source[i] == "\n" else " ")
                i += 1
            out.append("   ")
            i += 3
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def scripts_loaded_by(entry: str) -> list[str]:
    """Same-origin scripts the page pulls in, in document order."""
    return [
        m.group(1)
        for m in re.finditer(
            r"<script\b[^>]*?\bsrc\s*=\s*[\"']([^\"']+)[\"']", entry, re.IGNORECASE
        )
    ]


def main() -> int:
    print("Privacy — web surface (SPEC §7, D3 no-persistence)")

    if not ENTRY.exists():
        print("  skip web/index.html does not exist")
        return 0

    raw_entry = ENTRY.read_text(encoding="utf-8")
    findings: list[str] = []

    # The set of files the browser executes: the page, plus its own scripts.
    targets = [ENTRY]
    for src in scripts_loaded_by(raw_entry):
        if re.match(r"^[a-z]+:", src, re.IGNORECASE) or src.startswith("//"):
            findings.append(f"web/index.html: loads an off-origin script: {src}")
            continue
        path = (WEB / src).resolve()
        if not str(path).startswith(str(WEB.resolve())):
            findings.append(f"web/index.html: script escapes web/: {src}")
            continue
        if path.exists():
            targets.append(path)

    scanned = 0
    for path in targets:
        raw = path.read_text(encoding="utf-8")
        code = strip_comments(raw, html=path.suffix == ".html")
        rel = path.relative_to(ROOT)
        scanned += 1

        for number, line in enumerate(code.splitlines(), start=1):
            for needle, why in FORBIDDEN:
                if needle in line:
                    findings.append(f"{rel}:{number}: {needle} — {why}")
            if DYNAMIC_IMPORT.search(line):
                findings.append(f"{rel}:{number}: dynamic import() — reaches the network")

    # No subresource may come from another origin. Checked on the raw HTML, so
    # a commented-out example still fails rather than quietly becoming legal
    # the day someone uncomments it.
    for m in SUBRESOURCE.finditer(raw_entry):
        url = m.group(1)
        if re.match(r"^(?:[a-z]+:)?//", url, re.IGNORECASE):
            line = raw_entry[: m.start()].count("\n") + 1
            findings.append(f"web/index.html:{line}: off-origin subresource: {url}")

    # Links the reader may follow are allowed, but only over https, and they
    # are listed on success so a new one cannot appear unnoticed.
    links = sorted({m.group(1) for m in ANCHOR.finditer(raw_entry) if ":" in m.group(1)})
    for url in links:
        if not url.startswith("https://"):
            findings.append(f"web/index.html: non-https link: {url}")

    if findings:
        print("  FAIL the page writes to the device or reaches the network:")
        for f in findings:
            print(f"       {f}")
        print()
        print("FAILED — SPEC §7 is binding and admits zero exceptions without ratification.")
        return 1

    print(f"  ok   no storage or network API in {scanned} file(s) the page loads")
    print(f"  ok   every subresource is same-origin")
    for url in links:
        print(f"  note outbound link (reader-initiated): {url}")
    print()
    print("PASSED — the page writes nothing and fetches nothing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
