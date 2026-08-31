# Web F1 — the port

**Milestone:** `Web` · **Feature:** `Web/F1` · **Status:** planned, awaiting approval
**Branch:** `Web/F1/port` (from `main`, once `main` is real — see Sequencing)
**Owner:** agent

Working doc. `docs/specs/SPEC.md` is the contract and
`docs/plans/web-version.md` is the ratified decision record for this milestone;
this file records *how* the port is executed and which calls have been made.

---

## Structural ID

Ratified by the owner, 2026-08-31, closing the question
`docs/plans/web-version.md` left open ("needs a structural ID when it is pulled
into a sprint").

**A new milestone `Web`, with its own `F` numbering.** The web port is not a
feature of the native app, so appending `F11` to SPEC §10 would file it under a
milestone it does not belong to. It is not a chore either — conventions Axis 1
settles that with one question, *would a user notice?*, and a working instrument
in a browser is user value.

**IDs are milestone-qualified, in git and in citations: `Web/F1`, `Web/F1-T3`.**
Two bare `F1`s in one repository would make every citation ambiguous, which is
the one thing the ID system exists to prevent. Qualification buys uniqueness
without inventing a fourth structural kind — the alternative was a `W` axis,
which cannot be added without amending the vendored `docs/conventions.md`
upstream, and a new axis is a large price for a naming collision.

- Branch: `Web/F1/port`
- Commits: `feat(Web/F1-T2): port the sort phase state machine`
- The native milestone's `F1`–`F10` are untouched and keep their bare form.

**This allocation needs recording in `docs/decisions.md` and a proposed spec
delta** adding the `Web` milestone to SPEC §10. I do not edit the spec.

---

## Sequencing — why `main` comes first

`main` today holds only the harness baseline: 11 files, no `Sources/`, no
`Tests/`, no `scripts/`, and the spec still at the pre-`C1` path `docs/SPEC.md`.
All of `F1` and `C1` sits unmerged on `f2/sort-phase`.

The ratified decision is that **Pages serves `/web` from `main`**. Opening a
`web/` PR against today's `main` would land the page beside a CI workflow whose
`scripts/` do not exist there, so `Web/F1-T1`'s deck-regeneration gate would
have nothing to run — the check would be green because it never executed, which
is the failure mode this repo has already been bitten by twice.

**So: `f2/sort-phase` → `main` first** (owner's call, 2026-08-31), then
`Web/F1/port` branches from a `main` that carries the deck, the generator and
the CI it is gated by.

### Blocking defect, already fixed on `f2/sort-phase`

`swift test` did not compile. Two errors in
`Tests/ValuesCardSortKitTests/ZZ_AdversarialVerificationTests.swift`, both
arriving in `a7771eb` — a `C1` chore commit that was never test-run:

| Site | Error | Fix |
|---|---|---|
| `:130` | `#expect(session.piles.allSatisfy(\.isEmpty))` — the macro's `rethrows` analysis loses that a key path cannot throw | closure-literal form, as `R2_AssignTests:87` already uses |
| `:93`, `:117`, `:239` | `#require(session.addCustomCard(…))` — the macro decomposes its argument into a closure capturing the receiver immutably, so a `mutating` call is illegal inside it | hoist the call out; the result is still `#require`d non-nil |

Fixing the compile surfaced **a real assertion defect** the broken build had
been hiding: `ZZ_drainThenAddThenAssignThenFullyUnwindToTheOriginalSession`
asserted `queue.last == fresh.shuffleOrder.last` after a full unwind. Undo is
LIFO (R3), so the written card — assigned last — is undone *first* and every
deck card is prepended in front of it; the queue ends as the original shuffle
order **with the written card behind it**. The rule code is correct; the test
read the tail as if it were still the deck's. Replaced with a strictly stronger
pair: `Array(queue.dropLast()) == fresh.shuffleOrder` and
`queue.last == written.cardID`.

**Verified:** `swift test` → `Test run with 51 tests in 8 suites passed after
1.198 seconds.`

This is a defect fix and takes no gate. It is recorded here because it is the
reason `main` can be merged into at all.

---

## Scope

Carried unchanged from `docs/plans/web-version.md`. Not re-litigated.

**In:** the whole instrument — R1 shuffle, R2 sort into the five contract piles,
R3 undo, R4 custom cards, R5/R6 cull and promotion, R7 rank, R8 export, R9 reset
with confirmation, R11 keyboard `1`–`5` and `U`. Note Card face only. Markdown
copy, JSON download, PDF via print stylesheet.

**Out:** themes beyond Note Card, session history, **R10 resume** (there is no
persistence to resume from), any network call after the page loads.

## Architecture

```
web/
  index.html      markup + CSS + JS, one file, no build step
  deck.js         GENERATED from data/deck.v1.json — never hand-edited
scripts/generate_deck.py    gains a JS emitter beside the Swift one
```

The reference's three `window.storage` touchpoints (`:157`, `:169`, `:196`) are
**removed, not reimplemented**, and the `useEffect` persistence hook at
`:166–170` disappears entirely.

## Tasks

Foundational group first, labelled honestly as delivering nothing on its own;
then vertical slices, each a checkpoint that can be held in the hand.

| Task | What | Checkpoint |
|---|---|---|
| **T1** | **Foundational — no user-visible value.** JS emitter in `generate_deck.py` → `web/deck.js`; regeneration check wired into `check-deck.sh` and CI; `web/index.html` shell — desk surface, header, attribution line, phase indicator; SPDX headers on both files | `generate_deck.py --check` fails on a hand-edit of `web/deck.js` |
| **T2** | **Sort** — R1 shuffle, Note Card face, five pile buttons, R3 undo, R4 custom cards, R9 reset with confirmation, R11 keyboard | 83 cards sorted end to end in a browser |
| **T3** | **Cull** — R5 cut to 5–10, R6 promotion from *Very important* when the top pile is short | the 5–10 constraint gates the Continue button |
| **T4** | **Rank** — R7 forced ordering, up/down as real buttons | a ranked list, reorderable by keyboard alone |
| **T5** | **Export** — R8 markdown copy, JSON download on the native `SessionState` schema, print stylesheet for PDF. Date is **completion time** (`D4`), footer carries **no `#AI/Claude` tag** (`O2`) | all three exports produced from one finished sort |
| **T6** | **Accessibility gate + deploy** — axe-core in CI across every phase, keyboard-only traversal of a complete sort, evidence in `docs/evidence/web/`; enable Pages on `main` serving `/web` | axe returns zero violations on all four phases |

## Verification

Assertions are not evidence. Each of these is a command whose output goes in the PR.

- **Deck cannot drift** — `python3 scripts/generate_deck.py --check` covers the
  Swift *and* JS emitters; hand-edit either and CI fails.
- **Rule fidelity** — R1–R11 need a test harness that does not exist here; there
  is no XCTest on this surface. A plain Node test file runs the state machine
  headlessly against the reference's semantics. **Node is a CI dev-dependency
  and ships nothing to the browser**, exactly as axe-core does.
- **Mutations** — at least one `M<n>` per rule the tests protect, each recorded
  with the named test that catches it. A suite never shown to fail is not
  evidence; this repo has the register entry explaining why.
- **Accessibility** — axe-core, WCAG 2.2 AA, zero exemptions, every phase.
- **Privacy** — `check-privacy.sh` extended to the web surface, or a sibling
  check: assert the shipped `index.html` contains no `fetch`, no `XMLHttpRequest`,
  no `localStorage`, no `sessionStorage`, no `document.cookie`, and no external
  URL in `src`/`href` beyond the attribution links.

## Risks

Carried from the milestone plan, unchanged.

- **The state machine is the whole product.** A 95%-faithful port is a different
  instrument. Rule-by-rule tests are not optional.
- **`beforeunload` is unreliable by design** — browsers ignore it without prior
  interaction and style the prompt themselves. A courtesy, not a promise, and
  the UI must not imply otherwise.
- **Print output is browser-dependent**; page breaks differ across Safari,
  Chrome and Firefox.
- **No persistence makes the sort fragile on mobile**, where tab eviction is
  routine. Say so plainly on the start screen.

## Open for the owner

1. **`Web/F1` as the ID form** — confirm, since it is a shape the vendored
   conventions do not spell out.
2. **A proposed spec delta** adding the `Web` milestone to SPEC §10. I never
   edit the contract.
3. **Node as a CI dev-dependency** for the rule harness and axe. Ships nothing
   to the browser, but it is a dependency the native side does not have.
4. **`docs/plans/00-status.md` names `scripts/gen_status.py`, which is not in
   the repo**, so its freshness hook cannot run; its title also reads
   `code-process-review`. Separate defect — current sprint, or backlog?
