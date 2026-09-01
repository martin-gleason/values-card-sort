# Component departures

Every place this app declines a stock SwiftUI component, and why.

SPEC §3.1 is system-components-first, with one ratified exception (D7,
2026-08-14): **except where a stock component fails the §6 accessibility
gate**, which is absolute and admits no exemptions (D5). Where that happens,
the component is replaced with a hand-built equivalent using the system's own
colours, metrics and Dynamic Type styles — visually the platform's component,
carrying no design of its own.

This file is the record. **A departure that is not written down here, with
evidence, is a defect, not a departure.** Each entry must carry:

1. the stock component declined, and where;
2. the exact audit rule(s) it failed;
3. **what was tried** before giving up on it — a departure taken without
   exhausting the component is a shortcut wearing this file as cover;
4. what replaced it, and why the replacement is design-neutral;
5. light/dark screenshots at default *and* largest content sizes, in
   `docs/evidence/<feature>/`.

`scripts/check-departures.sh` verifies that every evidence file named here
exists, so this cannot rot into dead links.

---

## 1. SwiftUI `List` — declined on the root screen (F1)

**Component:** `List` / `Section`, SPEC §3.1's "lists: stock SwiftUI".
**Where:** `App/Views/RootView.swift`; replacement in `App/Views/GroupedSurface.swift`.
**Ratified:** D7, 2026-08-14.

### What failed

Under D5's no-exemption rule, the root screen inside a `List` produced **six**
audit issues:

| Rule | Element | Note |
|---|---|---|
| `Dynamic Type: partially unsupported` | four plain `Text` rows | They use stock text styles and **demonstrably do scale** — the largest-size screenshots show them wrapping correctly. The flag is not reproduced by the real rendering. |
| `Contrast nearly passed` | the two `Section` headers | The system's own grey header colour. |

### What was tried

All measured, none assumed. The count never went below six:

- explicit `.font(.body)` text styles on every row
- explicit `.foregroundStyle(.primary)` instead of inherited styles
- `.fixedSize(horizontal: false, vertical: true)` to force ideal height
- `.listStyle(.plain)` and inset-grouped
- `.listRowBackground(...)` with fully opaque colours
- wrapping row content in a `VStack` rather than bare `Text` rows
- collapsing rows into single explicit accessibility elements with explicit labels
- scrolling every row fully into view before auditing, at both content sizes

The identical content in a `ScrollView` audits **clean**. The flags live in
`List`'s backing store, not in the content.

### What replaced it

`GroupedSection` in `App/Views/GroupedSurface.swift`: a `ScrollView` + `VStack`
using `systemGroupedBackground` / `secondarySystemGroupedBackground`, a 10pt
continuous corner radius, and Dynamic Type styles throughout. Nothing themed,
nothing invented, no colour that is not a system colour. It reads as the
platform's inset-grouped list — compare the screenshots.

Row backgrounds are **opaque** deliberately: the audit cannot resolve a contrast
ratio behind translucent material and reports "nearly passed" for text that is
in fact far above threshold. Opacity makes the real ratio computable, so the
flag goes away because the question became answerable, not because it was
suppressed.

### Evidence

- `evidence/f1/root-light-default.png`
- `evidence/f1/root-dark-default.png`
- `evidence/f1/root-light-ax5.png`
- `evidence/f1/root-dark-ax5.png`

### Still open

**F6 is where this bites.** The session history is genuinely a list and wants
swipe-to-delete, which `List` provides and a `ScrollView` does not. That gate
has to choose between rebuilding the affordance and reopening D5. Decide it at
F6, not before.

---

## 2. The system accent colour — declined app-wide (F1)

**Component:** the default `AccentColor` (system blue, `#007AFF`).
**Where:** `App/Assets.xcassets/AccentColor.colorset`.
**Ratified:** implied by D5; recorded here because it is a departure from Apple's default, not from a component.

### What failed

`Contrast` — white button text on the system blue is **4.02:1**, below SPEC §6's
**4.5:1** floor for body text. Apple's own default does not meet the bar this
spec sets. This is a genuine failure, not an audit artefact.

### What was tried

Unlike §1 there was no way to keep the default and pass, because the ratio is
arithmetic rather than an introspection limit. What was weighed:

- **Keep `.borderedProminent` with the system tint and waive the rule** —
  rejected, D5 admits no exemptions, and unlike §1's flags this one is real:
  4.02:1 is genuinely below the floor.
- **Drop to a bordered/plain button so the tint carries text, not fill** —
  worse. Tinted *text* on the grouped background is 4.0:1 or below too, and the
  control reads as less prominent than the screen's primary action deserves.
- **Keep the tint and use a darker label colour on the fill** — dark text on
  mid-blue is legible but is not a look the platform uses anywhere; it would
  have been invented design, which §3.1 forbids.
- **Darken the accent itself** — chosen. It keeps the platform's shape,
  typography and behaviour, changes only a colour value, and is the one option
  that clears 4.5:1 in both appearances.

### What replaced it

| Appearance | Colour | White-text contrast |
|---|---|---|
| Light | `#0B57D0` | **6.39:1** |
| Dark | `#2563EB` | **5.17:1** |

Ratios computed, not eyeballed — the arithmetic is in the F1 commit and
reproducible from the sRGB values above. Still an unadorned system-style blue;
it reads as the platform's tint, just dark enough to be legible.

### Evidence

Same four screenshots as §1 — the button is the prominent control on that
screen.

-----
August 15, 2026

#AI/Claude

---

## 3. Stock buttons on the themed desk — declined on the sort screen (F2)

### What failed

`Button("Undo", systemImage: …)` and its sibling, in their stock form, sitting on
the Note Card desk. `performAccessibilityAudit` returned six issues on the sort
screen, and these two controls owned four of them:

    contrast: Contrast failed              element: "Undo"
    contrast: Contrast failed              element: "Write your own card"
    Dynamic Type: partially unsupported    element: "Undo"
    Dynamic Type: partially unsupported    element: "Write your own card"

A bordered button picks its tint against a *system* background. These sit on
`#20392F` felt, where that tint does not clear 4.5:1. The Dynamic Type issue was
separate: the SF Symbol beside the label does not grow with it.

### What was tried

1. **Stock `Button` with a system tint.** The failing baseline above.
2. **Explicit `foregroundStyle` on the Button, background as a modifier.**
   Cleared the contrast issue; both controls still reported "Dynamic Type
   partially unsupported".
3. **`ViewThatFits` to switch between a row and a stack.** Kept the Dynamic Type
   failure — it chooses a candidate layout by measuring it, which reads as type
   that will not grow. Replaced with an `AnyLayout` switch on
   `dynamicTypeSize.isAccessibilitySize`, the same pattern `RootView` uses.
4. **Dimming the disabled Undo.** `.disabled` applies its own dimming on top of
   any opacity, and the measured floor on this surface is 0.7 — the conventional
   0.4 lands at **2.58:1**. WCAG exempts inactive controls; D5 admits no
   exemptions, so the control is now *absent* until there is something to undo
   rather than present and hard to see.

### What replaced it

A hand-built control carrying no design of its own: the desk's own `onDesk`
token (7.44:1 on a 12%-white lift of the desk), a system text style, system
weight, a 44pt target, and the colours set *inside* the label — the shape the
pile buttons already use and which the audit passes. No SF Symbol, following the
rule `RootView` recorded at F1: the icon's width is width the label needs.

### Evidence

    $ xcodebuild test -scheme ValuesCardSort -only-testing:ValuesCardSortUITests
    Test Case 'test_A11y_sortScreenPassesAuditAtDefaultSize' passed
    Test Case 'test_A11y_sortScreenPassesAuditAtLargestDynamicTypeSize' passed
    10 of 10 UI tests passed

**Screenshots are owed and not yet attached.** F1's departures carry light/dark
captures at default and largest sizes; F2's do not. `SortScreenEvidence` drives
the screen in all four configurations and attaches captures, but they are not
being retained in the result bundle — `xcresulttool export attachments` returns
an empty manifest — so the extraction is unresolved rather than done. Recorded
here rather than quietly skipped: this entry is weaker than entries 1 and 2
until those four images exist.

### Still open

The screenshots above, and whether this departure generalises. Every themed
surface will have this problem — F3's cull screen and F4's rank screen sit on
the same desk. If it recurs, the answer is a shared `deskButton` in the theme
layer rather than a third and fourth entry here.
