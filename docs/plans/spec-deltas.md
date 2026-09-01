# Spec deltas

Working doc. `docs/specs/SPEC.md` is the ratified contract and the agent never edits
it on its own authority (CLAUDE.md). Proposals live here until Marty says yes;
once ratified **and transcribed into SPEC.md**, they drop to the ledger at the
bottom rather than sitting here pretending to still be open.

Status legend: **Proposed** (needs a yes) · **Ratified** (yes given, not yet in
SPEC.md) · **Landed** (in SPEC.md — see the ledger) · **Withdrawn**.

---

## Open

### D10 — Note Card's ACCENT splits into three measured tokens — **Ratified**

**Ratified 2026-08-31.** `docs/design/design-handoff-card-themes.md` already
required a contrast table — *"Body ≥ 4.5:1, large text ≥ 3:1. A theme that fails
contrast gets revised here, not in the build."* Nobody had run it. Run, it fails
**four of ten pairs**, and every failure is the same token, `ACCENT #C75146`,
inherited unmeasured from `reference/valuescardsort.jsx`:

    rank numeral on paper        #C75146 on #FDFCF6   4.35:1  need 4.5  FAIL
    rank numeral crossing a rule #C75146 on #C9DEE9   3.22:1  need 4.5  FAIL
    white label on accent        #FFFFFF on #C75146   4.47:1  need 4.5  FAIL
    accent mark on felt          #C75146 on #20392F   2.78:1  need 3.0  FAIL

The same token had already produced a live defect on the web port the same
morning, because both surfaces copied it from the one source and neither
measured it.

`ACCENT` therefore becomes three tokens, by role, with values measured on the web
port: `accentFill #C34F45` (4.64:1 under white), `accentText #A04139` (4.56:1
even where it crosses a rule), `accentOnDesk #D1554A` (3.03:1 on the felt). Card
stock, ink and rules are untouched — the index-card look is intact, because only
the red was wrong.

**Note Card is appearance-independent.** Every pair is card-face-internal or
card-on-felt; none involves a system background, so all ratios are identical in
dark mode. The handoff's `"dark": { "…": "same shape, dark values" }` placeholder
is therefore not owed. A physical index card on a felt desk looks the same
whichever way the room is lit.

**The table becomes a gate.** `data/themes.v1.json` holds the tokens and the
pairs; `scripts/check_theme_contrast.py` computes them in CI. Proven to fail:
restoring `#C75146` fails exactly the four pairs above.

**Where it lands.** No SPEC change — §5.3 already names Note Card and defers the
palette to the handoff. This corrects the handoff's tokens and moves the table
from prose to a check.

---

### D11 — the Mucha theme definition, sourced from the mothballed design system — **Proposed**

**What it is.** SPEC §5.3 lists Mucha among v1.0's three themes, and F8 is blocked
on C5 returning theme specs. The mothballed `Mucha-Design-System` already contains
the substance: seven Art Nouveau ramps, a semantic layer, and parametric ornament
paths. `data/themes.v1.json` now carries a Mucha palette with every pair
measured — 9 of 9 passing.

**Two things were changed rather than adopted, both on evidence.**

*The desk is remapped.* That system's `bg.canvas → bg.surface-1` is a document
**elevation** step at **1.12:1** — adopted directly it renders an almost invisible
card. The card sort needs a card on a desk, the way Note Card gets paper on felt.
All eleven deep-ramp candidates clear both thresholds, so the choice was
aesthetic; Marty chose `violet.900 #251929` on 2026-08-31, which also keeps Mucha
visibly distinct from Note Card's green felt.

*The dark variant is dropped.* The gate caught it on its first run: the system's
dark layer puts a dark card on a dark desk at **1.25:1**. No stock in the ramp
satisfies both constraints — separating from a near-black desk needs a light
stock, and a light stock needs dark ink, which is the light palette. The best
candidate, `umber.500`, reached 3.26:1 stock/desk but only 4.35:1 ink/stock. So
Mucha is **appearance-independent too**, for Note Card's reason: paper is light,
and a card in a dark room is still a light card.

**Still owed for F8**, and not claimed here: ornament assets (the source has
parametric paths in `motifs/paths.js` and `whiplash.js`, not SVG files),
typography (Cormorant Garamond, and **no font binaries ship** in that repo), and
mock renderings.

**Provenance and licence are the owner's call**, which is why this is proposed
rather than ratified. The source repository has **no LICENSE file**. Marty owns
both, so he can grant one — but colour values transcribed as data is a different
act from vendoring files, and this repo is GPL-3.0-or-later and public.

**Where it lands.** No SPEC change; §5.3 already names Mucha. This fills the
handoff's deliverable for one of the three themes.

---

D1–D9 are all ratified and transcribed. The remaining open items are
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

D1–D7 ratified 2026-08-14 and transcribed 2026-08-15; D8–D9 ratified
2026-08-31. Kept because SPEC.md records the *what* and this records the *why*.

| # | Delta | Landed in |
|---|---|---|
| **D1** | O1 closed: minimums are iOS/iPadOS 18, macOS 15, built against the Xcode 26 SDK. | SPEC §3, §11 |
| **D2** | O2 closed: the `#AI/Claude` tag is dropped from the public build's export footer. Pins the R8 golden file. | SPEC §5.2 R8, §11 |
| **D3** | A **card-payload hash** pinned alongside the file hash. The file hash is self-invalidating — chore C1's sign-off edits `instrument.verification` *inside* the file — so the payload hash is what keeps card drift failing forever. Verified by simulating both the sign-off edit and a card tamper. | SPEC §4 |
| **D4** | R8's export date is `session.completedAt`, not render-time "now"; the reference implementation misdates re-exports. The export body is **locale formatted**, so the golden test pins a fixed date and locale while the app pins neither. | SPEC §5.2 R8 |
| **D5** | The accessibility gate has **no exemptions**. Every audit rule, every screen, default and largest content sizes; fix the view, never waive the rule. Forced out two real defects — including white-on-system-blue button text at 4.02:1, under §6's own 4.5:1 floor. | TESTING.md layer 4 |
| **D6** | The deck is **compiled into the binary**, not bundled as JSON. An editable deck is a vector for harm; this app puts text in front of people at hard moments. Four locks, each verified by executing the attack. | SPEC §4 |
| **D7** | SPEC §3.1 amended: stock components **except where they fail the §6 gate**. `List` cannot pass a strict audit — six issues survived every remedy tried, while identical content in a `ScrollView` audits clean. Departures are recorded in `docs/departures.md` with evidence, enforced by `scripts/check-departures.sh`. | SPEC §3.1 |
| **D8** | SPEC §10 gains a second milestone, **`Web`**, holding the GitHub Pages port, with **milestone-qualified IDs** (`Web/F1`, `Web/F1-T3`). Not `F11` — the port is not a feature of the native app. Not a chore — the conventions' own test is *would a user notice?*, and a working instrument in a browser is user value. Not a new `W` axis — that cannot be added without amending the vendored conventions upstream. Ratified 2026-08-31. | SPEC §10 |
| **D9** | Pages deploys via an **Actions artifact upload of `web/`**, superseding the "serves `/web` from `main`, no Actions build" half of the 2026-08-29 web decision. That clause was never implementable: branch-based Pages accepts only `/` or `/docs`, and while it read as settled the public URL served a Jekyll render of the README. Not a "build step" — no bundler, no generator; the deployed `deck.js` is byte-identical to the repository's. Verified against the live page, not the config: `curl` → HTTP 200, 44463 bytes, title *Personal Values Card Sort*, 0 Jekyll references; a complete sort driven on the deployed site; `localStorage` 0, `sessionStorage` 0, `document.cookie` "". Ratified 2026-08-31. | no SPEC change — deployment is not a spec requirement; supersedes `docs/plans/web-version.md` decision 1 in part |

-----
August 15, 2026

#AI/Claude
