# SPDX-License-Identifier: GPL-3.0-or-later
"""Privacy gate — SPEC §7 (binding), TESTING.md layer 5.

  "Local-only. No network code, no analytics, no accounts, no third-party
   SDKs. The binary makes zero network connections; nothing in the codebase
   may import a networking API for app functionality."

TESTING.md calls this gate "deterministic, not advisory", so it has to survive
adversarial Swift, not just tidy Swift. Three things it gets right that a naive
grep gets wrong:

1. **Comments are stripped by a real lexer**, not a regex. The code explains
   *why* it avoids CloudKit and networking, and those explanations must not
   trip the check that enforces the avoidance. An earlier version used a
   simplified scanner that mishandled `\\(…)` interpolation containing a nested
   string: `"prefix \\("/*") suffix"` left it parsing string content as code,
   opening a block comment that blanked the rest of the file and hid a real
   `URLSession` call. `tests/` covers that case now.

2. **APIs are matched, not URLs.** SPEC §5.5 REQUIRES the About screen to link
   to the instrument's source PDF, and SPEC §2 requires attribution URLs in the
   deck data. Those open in the system browser via SwiftUI `Link`/`openURL`,
   which starts no connection from this process. Flagging them would flag the
   attribution the spec demands.

3. **Ambiguous APIs are flagged, then explicitly excused.** `Data(contentsOf:)`
   performs a synchronous GET when handed an http(s) URL, and the deck loader
   legitimately uses it on a file URL. Rather than omit it (a permanent hole)
   or ban it (impossible), each use must carry a `privacy-ok:` marker stating
   why. The marker is read from the ORIGINAL source, before comments are
   stripped, and every one of them is printed on a pass so they stay visible
   rather than becoming invisible permanent exemptions.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Unambiguous networking entry points.
FORBIDDEN = re.compile(
    r"\b("
    r"URLSession|URLConnection|NSURLSession|NSURLConnection|URLRequest"
    r"|NWConnection|NWListener|NWBrowser|NWPathMonitor|NWEndpoint"
    r"|CFSocket\w*|CFStream\w*|CFHTTP\w*|CFNetwork"
    r"|getaddrinfo|inet_addr"
    r"|WKWebView|UIWebView|SFSafariViewController"
    r"|CKContainer|CKDatabase|CKRecord|CKSubscription"
    r"|MCSession|MCBrowser\w*|NetService|NSNetService"
    r"|URLCredential|URLProtocol|URLCache"
    r")\b"
)

# APIs that reach the network only for some inputs. Allowed with a marker.
AMBIGUOUS = re.compile(
    r"("
    r"Data\s*\(\s*contentsOf\s*:"
    r"|String\s*\(\s*contentsOf\s*:"
    r"|NSData\s*\(\s*contentsOf\s*:"
    r"|\bProcess\s*\(\s*\)"
    r"|\bNSTask\b"
    r"|\bsocket\s*\("
    r")"
)

FORBIDDEN_IMPORTS = re.compile(
    r"^\s*(?:@[\w()]+\s+)*import\s+"
    r"(Network|NetworkExtension|CFNetwork|WebKit|CloudKit"
    r"|MultipeerConnectivity|SafariServices|CoreTelephony)\b"
)

# e.g.  // privacy-ok(file-url): bundle resource, never a remote URL
ALLOW_MARKER = re.compile(r"//\s*privacy-ok(?:\(([^)]*)\))?\s*:\s*(.+)")

# Network capability requested declaratively rather than in code.
ENTITLEMENT_KEYS = re.compile(r"network\.(client|server)")

SEARCH_ROOTS = ["Sources", "App", "Tests"]


def strip_comments(source: str) -> str:
    """Blank out comments, preserving line numbering and string content.

    A context stack, because Swift strings and code nest arbitrarily through
    `\\(…)` interpolation and each level can carry its own raw-string hashes.
    """
    out: list[str] = []
    i = 0
    n = len(source)

    # Each frame: ("code", block_comment_depth, interpolation_paren_depth)
    #          or ("string", delimiter, hash_count)
    stack: list[list] = [["code", 0, None]]

    def emit(text: str) -> None:
        out.append(text)

    def blank(text: str) -> None:
        emit("".join("\n" if c == "\n" else " " for c in text))

    while i < n:
        frame = stack[-1]
        ch = source[i]

        if frame[0] == "code":
            # Inside a block comment: consume, allowing nesting.
            if frame[1] > 0:
                if source.startswith("/*", i):
                    frame[1] += 1
                    blank(source[i : i + 2])
                    i += 2
                elif source.startswith("*/", i):
                    frame[1] -= 1
                    blank(source[i : i + 2])
                    i += 2
                else:
                    blank(ch)
                    i += 1
                continue

            if source.startswith("//", i):
                end = source.find("\n", i)
                end = n if end == -1 else end
                blank(source[i:end])
                i = end
                continue

            if source.startswith("/*", i):
                frame[1] = 1
                blank(source[i : i + 2])
                i += 2
                continue

            # Track parens so an interpolation frame knows where it ends.
            if frame[2] is not None:
                if ch == "(":
                    frame[2] += 1
                elif ch == ")":
                    frame[2] -= 1
                    if frame[2] == 0:
                        stack.pop()
                        emit(ch)
                        i += 1
                        continue

            # String opener, possibly raw (#"…"#) and possibly multiline.
            match = re.match(r'(#*)("""|")', source[i:])
            if match:
                hashes = len(match.group(1))
                delimiter = match.group(2)
                stack.append(["string", delimiter, hashes])
                emit(match.group(0))
                i += len(match.group(0))
                continue

            emit(ch)
            i += 1
            continue

        # frame[0] == "string"
        _, delimiter, hashes = frame
        escape = "\\" + "#" * hashes

        # Interpolation: push a code frame that ends at its matching ')'.
        if source.startswith(escape + "(", i):
            emit(source[i : i + len(escape) + 1])
            i += len(escape) + 1
            stack.append(["code", 0, 1])
            continue

        # Any other escape consumes the next character, so a `\"` cannot close.
        if source.startswith(escape, i) and i + len(escape) < n:
            emit(source[i : i + len(escape) + 1])
            i += len(escape) + 1
            continue

        closer = delimiter + "#" * hashes
        if source.startswith(closer, i):
            stack.pop()
            emit(closer)
            i += len(closer)
            continue

        emit(ch)
        i += 1

    return "".join(out)


def allow_markers(source: str) -> dict[int, str]:
    """Line number → justification, read before comments are stripped."""
    markers: dict[int, str] = {}
    for number, line in enumerate(source.splitlines(), start=1):
        if match := ALLOW_MARKER.search(line):
            scope = match.group(1) or "unscoped"
            markers[number] = f"{scope}: {match.group(2).strip()}"
    return markers


def main() -> int:
    roots = [ROOT / r for r in SEARCH_ROOTS if (ROOT / r).is_dir()]
    if not roots:
        print("Privacy (SPEC §7)")
        print("  skip no Swift sources yet")
        return 0

    print(f"Privacy (SPEC §7) — scanning: {', '.join(r.name for r in roots)}")

    findings: list[str] = []
    excused: list[str] = []
    scanned = 0

    for root in roots:
        for path in sorted(root.rglob("*.swift")):
            scanned += 1
            rel = path.relative_to(ROOT)
            original = path.read_text(encoding="utf-8")
            markers = allow_markers(original)
            code = strip_comments(original)

            for number, line in enumerate(code.splitlines(), start=1):
                # A marker on the line itself, or on the line above it.
                excuse = markers.get(number) or markers.get(number - 1)

                if match := FORBIDDEN.search(line):
                    # Never excusable — these have no non-network use.
                    findings.append(f"{rel}:{number}: {match.group(1)}")
                if match := FORBIDDEN_IMPORTS.search(line):
                    findings.append(f"{rel}:{number}: import {match.group(1)}")
                if match := AMBIGUOUS.search(line):
                    symbol = match.group(1).split("(")[0].strip()
                    if excuse:
                        excused.append(f"{rel}:{number}: {symbol} — {excuse}")
                    else:
                        findings.append(
                            f"{rel}:{number}: {symbol} reaches the network for "
                            f"http(s) URLs; add a `// privacy-ok(reason): why` marker"
                        )

    if findings:
        print("  FAIL networking API found in shipping source:")
        for finding in findings:
            print(f"       {finding}")
        print()
        print("FAILED — SPEC §7 is binding and admits zero exceptions without ratification.")
        return 1

    print(f"  ok   no networking API in {scanned} Swift file(s)")

    # Printed on success on purpose: an exemption nobody sees is a hole.
    for excuse in excused:
        print(f"  note allowed: {excuse}")

    # A sandbox entitlement is as much a capability as an import.
    #
    # The generated App/*.entitlements is gitignored, so on a clean CI checkout
    # it does not exist and checking only that file silently checks nothing.
    # project.yml is the committed source of truth and is always checked.
    sources = [ROOT / "project.yml", *sorted(ROOT.rglob("*.entitlements"))]
    checked = 0
    for source in sources:
        if not source.exists():
            continue
        checked += 1
        if match := ENTITLEMENT_KEYS.search(source.read_text()):
            print(f"  FAIL {source.relative_to(ROOT)} requests network.{match.group(1)}")
            print()
            print("FAILED — SPEC §7 is binding.")
            return 1

    if not (ROOT / "project.yml").exists():
        print("  FAIL project.yml is missing; entitlements cannot be verified")
        return 1
    print(f"  ok   no network entitlement in {checked} entitlement source(s)")

    print()
    print("PASSED — local-only")
    return 0


if __name__ == "__main__":
    sys.exit(main())
