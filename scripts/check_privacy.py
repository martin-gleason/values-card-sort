# SPDX-License-Identifier: GPL-3.0-or-later
"""Privacy gate — SPEC §7 (binding), TESTING.md layer 5.

  "Local-only. No network code, no analytics, no accounts, no third-party
   SDKs. The binary makes zero network connections; nothing in the codebase
   may import a networking API for app functionality."

Two things this checks for that a naive grep gets wrong, both of which matter
because a gate with false positives is a gate people learn to ignore:

1. **Comments and doc comments are stripped first.** The code explains *why*
   it avoids CloudKit and networking; those explanations must not trip the
   check that enforces the avoidance.

2. **APIs are matched, not URLs.** SPEC §5.5 REQUIRES the About screen to link
   to the instrument's source PDF, and SPEC §2 requires attribution URLs in the
   deck data. Those open in the system browser via SwiftUI `Link`/`openURL`,
   which starts no connection from this process. Flagging them would flag the
   attribution the spec demands.

String literals are deliberately NOT stripped: a networking symbol appearing in
a string is worth a human look.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Networking entry points. If one of these appears in shipping source, the app
# can open a socket, and SPEC §7 is broken.
FORBIDDEN = re.compile(
    r"\b("
    r"URLSession|URLConnection|URLRequest|NSURLSession|NSURLConnection"
    r"|NWConnection|NWListener|NWBrowser|NWPathMonitor"
    r"|CFSocket\w*|CFStream\w*|CFHTTP\w*|CFNetwork"
    r"|getaddrinfo|socket\s*\("
    r"|WKWebView|UIWebView|SFSafariViewController"
    r"|CKContainer|CKDatabase|CKRecord"
    r"|MCSession|NetService|NSNetService"
    r")\b"
)

# `import Network`, `import WebKit`, etc. — matched separately so that the word
# "Network" in an identifier is not itself an offence.
FORBIDDEN_IMPORTS = re.compile(
    r"^\s*(?:@[\w()]+\s+)*import\s+"
    r"(Network|NetworkExtension|CFNetwork|WebKit|CloudKit|MultipeerConnectivity|SafariServices)\b"
)

SEARCH_ROOTS = ["Sources", "App", "Tests"]


def strip_comments(source: str) -> str:
    """Blank out // line comments and /* */ block comments, preserving line
    numbering so findings still cite the right line."""
    out: list[str] = []
    i = 0
    n = len(source)
    in_line_comment = False
    block_depth = 0  # Swift block comments nest.
    in_string = False
    string_delimiter = ""

    while i < n:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < n else ""

        if in_line_comment:
            if ch == "\n":
                in_line_comment = False
                out.append(ch)
            else:
                out.append(" ")
            i += 1
            continue

        if block_depth:
            if ch == "/" and nxt == "*":
                block_depth += 1
                out.append("  ")
                i += 2
                continue
            if ch == "*" and nxt == "/":
                block_depth -= 1
                out.append("  ")
                i += 2
                continue
            out.append("\n" if ch == "\n" else " ")
            i += 1
            continue

        if in_string:
            out.append(ch)
            if ch == "\\":
                if nxt:
                    out.append(nxt)
                    i += 2
                    continue
            elif source.startswith(string_delimiter, i):
                in_string = False
            i += 1
            continue

        if ch == "/" and nxt == "/":
            in_line_comment = True
            out.append("  ")
            i += 2
            continue
        if ch == "/" and nxt == "*":
            block_depth = 1
            out.append("  ")
            i += 2
            continue
        if ch == '"':
            in_string = True
            string_delimiter = '"""' if source.startswith('"""', i) else '"'
            out.append(ch)
            i += 1
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def main() -> int:
    roots = [ROOT / r for r in SEARCH_ROOTS if (ROOT / r).is_dir()]
    if not roots:
        print("Privacy (SPEC §7)")
        print("  skip no Swift sources yet")
        return 0

    print(f"Privacy (SPEC §7) — scanning: {', '.join(r.name for r in roots)}")

    findings: list[str] = []
    scanned = 0

    for root in roots:
        for path in sorted(root.rglob("*.swift")):
            scanned += 1
            code = strip_comments(path.read_text(encoding="utf-8"))
            for number, line in enumerate(code.splitlines(), start=1):
                rel = path.relative_to(ROOT)
                if match := FORBIDDEN.search(line):
                    findings.append(f"{rel}:{number}: {match.group(1)}")
                if match := FORBIDDEN_IMPORTS.search(line):
                    findings.append(f"{rel}:{number}: import {match.group(1)}")

    if findings:
        print("  FAIL networking API found in shipping source:")
        for finding in findings:
            print(f"       {finding}")
        print()
        print("FAILED — SPEC §7 is binding and admits zero exceptions without ratification.")
        return 1

    print(f"  ok   no networking API in {scanned} Swift file(s)")

    # A sandbox entitlement is as much a capability as an import.
    entitlements = sorted(ROOT.rglob("*.entitlements"))
    offenders = [
        e.relative_to(ROOT)
        for e in entitlements
        if "network.client" in e.read_text() or "network.server" in e.read_text()
    ]
    if offenders:
        print(f"  FAIL network entitlement requested in: {offenders}")
        return 1
    if entitlements:
        print(f"  ok   no network entitlement in {len(entitlements)} entitlements file(s)")

    print()
    print("PASSED — local-only")
    return 0


if __name__ == "__main__":
    sys.exit(main())
