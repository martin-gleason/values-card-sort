# F1 accessibility evidence (SPEC §6)

Captured 2026-08-14 on iOS 26.5 Simulator from the F1 root screen.

| File | Appearance | Content size |
|---|---|---|
| `root-light-default.png` | light | Large (default) |
| `root-light-ax5.png` | light | AccessibilityXXXL (largest) |
| `root-dark-ax5.png` | dark | AccessibilityXXXL (largest) |

At the largest accessibility size every string wraps and nothing truncates,
in both appearances. The start button drops its SF Symbol at accessibility
sizes — with the icon present its label clipped, which is the bug
`performAccessibilityAudit()` caught and `.textClipped` now guards against.

These are **evidence**, not the check. The check is
`Tests/ValuesCardSortUITests/AccessibilityGateTests.swift`, which runs the
audit at both sizes on every CI run. See docs/plans/spec-deltas.md D5.

-----
August 14, 2026
