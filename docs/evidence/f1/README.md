# F1 accessibility evidence (SPEC §6)

Captured 2026-08-14 on iOS 26.5 Simulator from the F1 root screen.

| File | Appearance | Content size |
|---|---|---|
| `root-light-default.png` | light | Large (default) |
| `root-dark-default.png` | dark | Large (default) |
| `root-light-ax5.png` | light | AccessibilityXXXL (largest) |
| `root-dark-ax5.png` | dark | AccessibilityXXXL (largest) |

At the largest accessibility size every string wraps and nothing truncates, in
both appearances. The start button drops its SF Symbol at accessibility sizes —
with the icon present its label clipped, which is the bug the audit caught.

These are **evidence**, not the check. The check is
`Tests/ValuesCardSortUITests/AccessibilityGateTests.swift`, which runs
`performAccessibilityAudit()` at both sizes on every CI run with **no
exemptions** (D5, ratified 2026-08-14).

Two things the strict gate changed about this screen:

- **The accent colour.** Apple's system blue gives white button text 4.02:1,
  below SPEC §6's 4.5:1 floor for body text. `App/Assets.xcassets/AccentColor`
  is 6.39:1 in light and 5.17:1 in dark, computed rather than eyeballed.
- **No `List`.** SwiftUI's `List` cannot pass a strict audit; see
  `docs/plans/spec-deltas.md` D7, which needs the maintainer's decision.

-----
August 14, 2026
