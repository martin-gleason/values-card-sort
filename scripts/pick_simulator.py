# SPDX-License-Identifier: GPL-3.0-or-later
#
# Print an xcodebuild -destination for a concrete, available iOS simulator.
#
# CI must not pin a simulator by model name. Xcode 26 dropped "iPhone 16", and
# a pinned name breaks whenever the runner image changes its device set — this
# is the only job that runs the SPEC §6 accessibility gate while macOS UI tests
# wait on C2, so it must not fail for cosmetic reasons. "OS=latest" with the
# "Any iOS Simulator Device" placeholder does not resolve either: the
# placeholder carries no runtime, so xcodebuild rejects the pair.
#
# So: ask simctl what actually exists, take the newest iOS runtime, and prefer
# an iPhone within it. Fail loudly if there is nothing to run on.

import json
import re
import subprocess
import sys


def runtime_version(identifier):
    """iOS-26-5 -> (26, 5). Unparseable runtimes sort last, not crash."""
    m = re.search(r"iOS-([0-9]+(?:-[0-9]+)*)$", identifier)
    if not m:
        return ()
    return tuple(int(p) for p in m.group(1).split("-"))


def main():
    raw = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        capture_output=True, text=True, check=True,
    ).stdout
    devices = json.loads(raw)["devices"]

    ios = [(runtime_version(rt), rt, devs)
           for rt, devs in devices.items()
           if "SimRuntime.iOS-" in rt and devs]
    ios = [entry for entry in ios if entry[0]]
    if not ios:
        sys.exit("no available iOS simulator runtime on this machine")

    _, runtime, candidates = max(ios, key=lambda e: e[0])
    usable = [d for d in candidates if d.get("isAvailable", True)]
    if not usable:
        sys.exit(f"runtime {runtime} has no available devices")

    # Prefer an iPhone; the accessibility gate is authored against phone layout.
    phones = [d for d in usable if d["name"].startswith("iPhone")]
    device = (phones or usable)[0]

    print(f"platform=iOS Simulator,id={device['udid']}")
    print(f"picked {device['name']} on {runtime}", file=sys.stderr)


if __name__ == "__main__":
    main()
