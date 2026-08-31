# Spec deltas

Working doc. `docs/specs/SPEC.md` is the ratified contract and the agent never edits
it on its own authority (CLAUDE.md). Proposals live here until Marty says yes;
once ratified **and transcribed into SPEC.md**, they drop to the ledger at the
bottom rather than sitting here pretending to still be open.

Status legend: **Proposed** (needs a yes) · **Ratified** (yes given, not yet in
SPEC.md) · **Landed** (in SPEC.md — see the ledger) · **Withdrawn**.

---

## Open

### D8 — SPEC §10 gains a second milestone, `Web` — **Proposed**

**What changes.** §10's feature list is a single unnamed table of `F1`–`F10`
plus the chore track. It gains a second table beside it:

> **Milestone `Web`** — a self-contained static port of the instrument, served
> from GitHub Pages, so it is usable by anyone with a browser without waiting
> for TestFlight.
>
> | ID | Feature | Notes |
> |---|---|---|
> | `Web/F1` | The port: deck emitter, sort, cull, rank, export, accessibility gate | R1–R11 **except R10** — there is no persistence to resume from |
> | `Web/F1b` | Retrofit: adversarial review fixes | privacy gate, R8 golden file, 1.4.10 reflow, `beforeunload` |
> | `Web/F2` | Pages deployment | see `D9` |

**And an ID rule**, because this is the first time the repo has carried two
milestones at once: **IDs are milestone-qualified** — `Web/F1`, `Web/F1-T3`,
branch `Web/F1/port`, commit scope `feat(Web/F1-T2)`. The native milestone's
`F1`–`F10` keep their bare form and are untouched.

**Why not `F11`.** The web port is not a feature of the native app. Appending
it files it under a milestone it does not belong to, and it would sit in the
same table as `F8`'s "blocked by C5" and `F10`'s "final gate before TestFlight"
— neither of which it is on the far side of.

**Why not a chore.** `conventions.md` settles that with one question: *would a
user notice?* A working instrument in a browser is user value. Ownership is a
property of the unit, not the thing that classifies it — the baseline's own
paragraph about `C6` being wrongly opened as `F7a` is about exactly this.

**Why not a new `W` axis**, which `docs/plans/web-version.md` floated. Axis 1
has four structural kinds, and a fifth means amending the vendored
`docs/conventions.md` — which a project never edits in place, so it would have
to change upstream and be re-pinned. Milestone qualification buys the same
uniqueness for nothing.

**Status of the work.** Marty allocated the ID on 2026-08-31 and approved
`docs/plans/web-f1-port.md`; `Web/F1` and `Web/F1b` are built and merged. This
delta is therefore a **transcription of a decision already taken**, not a fresh
proposal — but SPEC.md is the contract and only Marty writes to it.

**Where it lands.** SPEC §10.

---

D1–D7 are all ratified and transcribed. The remaining open items are
SPEC §11's O3, O4 and O5, which belong to later gates:

- **O3** — summary-card image export in 1.0 or 1.1 (decide at F5).
- **O4** — which "Civic" (answer in the C5 design session).
- **O5** — app icon; a separate logo-rules session.
  `App/Assets.xcassets/AppIcon.appiconset` is an empty placeholder so the build
  stays clean until then.

One thing worth deciding *before* F6 rather than during it:

### F6 and SwiftUI `List`

D7 settled the principle — accessibility beats component provenance — and F1's
root screen was the easy case, because it was never really a list. **F6's
session history is.** It wants swipe-to-delete and selection, which `List`
provides and a `ScrollView` does not, and `List` cannot pass the §6 audit. So
F6 either rebuilds those affordances by hand or re-opens D5 for that one
screen. Not a decision to discover halfway through building it.

---

## Ledger — ratified and landed in SPEC.md

All ratified 2026-08-14, transcribed 2026-08-15. Kept because SPEC.md records
the *what* and this records the *why*.

| # | Delta | Landed in |
|---|---|---|
| **D1** | O1 closed: minimums are iOS/iPadOS 18, macOS 15, built against the Xcode 26 SDK. | SPEC §3, §11 |
| **D2** | O2 closed: the `#AI/Claude` tag is dropped from the public build's export footer. Pins the R8 golden file. | SPEC §5.2 R8, §11 |
| **D3** | A **card-payload hash** pinned alongside the file hash. The file hash is self-invalidating — chore C1's sign-off edits `instrument.verification` *inside* the file — so the payload hash is what keeps card drift failing forever. Verified by simulating both the sign-off edit and a card tamper. | SPEC §4 |
| **D4** | R8's export date is `session.completedAt`, not render-time "now"; the reference implementation misdates re-exports. The export body is **locale formatted**, so the golden test pins a fixed date and locale while the app pins neither. | SPEC §5.2 R8 |
| **D5** | The accessibility gate has **no exemptions**. Every audit rule, every screen, default and largest content sizes; fix the view, never waive the rule. Forced out two real defects — including white-on-system-blue button text at 4.02:1, under §6's own 4.5:1 floor. | TESTING.md layer 4 |
| **D6** | The deck is **compiled into the binary**, not bundled as JSON. An editable deck is a vector for harm; this app puts text in front of people at hard moments. Four locks, each verified by executing the attack. | SPEC §4 |
| **D7** | SPEC §3.1 amended: stock components **except where they fail the §6 gate**. `List` cannot pass a strict audit — six issues survived every remedy tried, while identical content in a `ScrollView` audits clean. Departures are recorded in `docs/departures.md` with evidence, enforced by `scripts/check-departures.sh`. | SPEC §3.1 |

-----
August 15, 2026

#AI/Claude
