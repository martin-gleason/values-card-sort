# Proposed spec deltas

Working doc. `docs/SPEC.md` is the ratified contract and the agent never edits
it on its own authority (CLAUDE.md). Everything here is a **proposal** until
Marty says yes; ratified items move into SPEC.md and `docs/decisions.md` and
are struck from this file.

Status legend: **Ratified** (verbally, in session — awaiting transcription into
SPEC.md) · **Proposed** (needs a yes) · **Withdrawn**.

---

## D1 — O1: minimum OS versions · **Ratified 2026-08-14**

iOS/iPadOS **18.0**, macOS **15.0**, built against the Xcode 26 / iOS 26 SDK.

Closes SPEC §11 O1 as proposed. Implemented in `project.yml` and
`Package.swift`. Nothing in F1–F10 needs a newer API, and a free self-help tool
should not exclude anyone still on last year's OS.

**SPEC edit:** §3 "Proposed minimums (ratify)" → "Minimums (ratified
2026-08-14)". §11 — strike O1.

---

## D2 — O2: `#AI/Claude` in the export footer · **Ratified 2026-08-14**

**Dropped** from the public build.

Closes SPEC §11 O2 as proposed. It is Marty's personal filing convention and
has no business in a stranger's values export. This pins the R8 golden file,
which F5 depends on.

**SPEC edit:** §5.2 R8 — remove the parenthetical open item, state that the
export ends with the date rule. §11 — strike O2.

---

## D3 — §4: pin a card-payload hash alongside the file hash · **Ratified 2026-08-14**

Add to SPEC §4: the fidelity test asserts **two** hashes.

| Hash | Value | Scope |
|---|---|---|
| File SHA-256 | `13a3db92…6847ad8d` | the whole `deck.v1.json`, as §4 already says |
| Card-payload SHA-256 | `10a4c393…775c25d4` | the 83 cards only, canonically serialized |

**Why.** The file hash is self-invalidating by design. Chore C1's sign-off edits
`instrument.verification` *inside* the deck file, so the sanctioned edit breaks
the fidelity test, and `fixtures/README.md` already anticipates re-pinning.
That is fine once, but it means the strongest guarantee in the repo goes soft
at exactly the moment the deck is declared verified. A payload hash survives
metadata edits and keeps *card* drift failing forever.

Verified empirically rather than argued: simulating the C1 edit trips only the
file hash and leaves the payload hash green; tampering with one descriptor
trips both.

**Canonical form.** Separator-delimited, not JSON, so `scripts/check_deck.py`
and `DeckLoader.canonicalPayload(of:)` cannot disagree about key ordering or
string escaping:

```
id U+001F name U+001F descriptor        (per card, in file order)
joined by U+001E
```

Deck v1 is pure ASCII (asserted by a test), so the separators cannot collide
with card data.

> Note: an earlier draft of the plan quoted `86ae6d89…c751037`, a hash of the
> cards as compact sorted-key JSON. Replaced — it depended on two languages'
> JSON encoders agreeing, which is a needless thing to bet a contract on.

**SPEC edit:** §4 — add the payload hash row and the canonical-form definition.

---

## D4 — R8: the export date is `completedAt`, not "now" · **Proposed**

**Reference/native conflict, flagged not silently resolved** (CLAUDE.md).

`reference/valuescardsort.jsx:238` computes the export date as
`new Date().toLocaleDateString("en-US", …)` — evaluated when the markdown is
rendered, in the browser's locale. Two consequences:

1. Re-exporting a session completed last March stamps it with **today's** date.
   SPEC §5.2 R8 says the export carries the "completion date", and SPEC §5.4
   requires re-export from session detail, so this is reachable in normal use.
2. The output is locale-dependent, so the golden-file test TESTING.md layer 2
   requires would pass or fail depending on the machine's region.

**Proposal.** The export renders `session.completedAt`. The golden-file test
pins a fixed date and a fixed locale; the shipping app formats in the user's
locale, since an exported personal document should read naturally to its owner.

**Open sub-question for F5:** should the *body* of the export be locale-
formatted at all, given the pile labels and attribution are fixed English
strings in 1.0? Consistent English (`en_US_POSIX`) may read better than a
half-localized document. Answer at the F5 gate.

**SPEC edit:** §5.2 R8 — name `completedAt` explicitly, and add a line on
locale.

---

## D5 — TESTING.md layer 4: make the accessibility gate a check · **Proposed**

Layer 4 currently reads: *"Accessibility gate evidence (per feature, before
'done') — largest-Dynamic-Type screenshots both appearances; VoiceOver label
audit of the screen's controls; documented in the PR."*

Every other layer is executable. This one is a promise, and it is the layer
covering the requirement SPEC §6 calls a **gate**.

**Proposal.** Layer 4 becomes XCUITest `performAccessibilityAudit()` on every
screen, at default *and* `AccessibilityXXXL` content sizes, plus the existing
screenshots as evidence rather than as the check.

This already earned its place in F1: the audit caught a real clipping bug — the
start button's icon left too little room for its label at accessibility sizes —
that no one would have noticed reading the code.

**Two documented exemptions, both narrow, both on stock chrome:**

- **`.contrast`** — the audit reports "nearly passed" for every text element on
  the root screen, including a semibold primary label on the system grouped
  background at roughly 15:1. It is reporting low confidence behind translucent
  system materials, not a real failure. All flagged elements are stock SwiftUI,
  which SPEC §3.1 deliberately makes Apple's ("the chrome is Apple's; we write
  none of it").
- **`.dynamicType`** — "partially unsupported" on four plain `Text` views using
  stock text styles. Checked rather than assumed: re-running the audit at
  `AccessibilityXXXL` with those views scrolled into view leaves them unflagged,
  and the only surviving issue is an element with no label and no identifier
  that the app does not own.

**`.textClipped` is never exempted** — it is the check that found the real bug.

**The exemptions must not spread.** SPEC §6's contrast requirement bites hardest
on the themed card face, where the colours are ours. F8 runs the contrast audit
on themed surfaces with **no** exemption, plus the computed contrast table §6
already demands from the design session.

**Needs a decision from Marty:** the exemptions are a judgment call on a gate,
which is exactly the kind of thing that should not be made silently. If you'd
rather the audit run fully strict and simply fail on stock chrome, say so and
the tests flip.

**TESTING.md edit:** rewrite layer 4; note the exemptions and their scope.

---

## D6 — deck file location · **Proposed (housekeeping)**

The real deck bytes now live at
`Sources/ValuesCardSortKit/Resources/deck.v1.json`, and **`data/deck.v1.json`
is a symlink to it**.

**Why.** SwiftPM copies resource symlinks verbatim into the built bundle, so a
link *inside* `Resources/` arrives at runtime still pointing at a relative path
that no longer resolves — the app silently ships with no deck. (Found by the
deck test failing, not by reasoning about it.) Pointing the link the other way
gives SwiftPM real bytes to copy while keeping SPEC §4's path working for every
reader, script, and human.

`scripts/check-deck.sh` asserts the two paths are byte-identical, by content
rather than by link direction, so this still holds if an editor replaces the
symlink with a copy during C1.

**Consequence for C1:** editing `instrument.verification` through
`data/deck.v1.json` works normally in any editor that writes through symlinks.
If your editor replaces the file instead, the check will tell you, and
`ln -sf ../Sources/ValuesCardSortKit/Resources/deck.v1.json data/deck.v1.json`
restores it.

**SPEC edit:** §4 — one sentence noting the canonical path is a link to the
package resource, and why.

-----
August 14, 2026

#AI/Claude
