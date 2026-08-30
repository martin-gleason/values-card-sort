# Web version — GitHub Pages port of the card sort

**Status:** planned, **backlogged behind F2**. Not started.
**Needs a structural ID** when it is pulled into a sprint. It is not a Feature
of the native app, so an `F` number would be wrong — `W1` is the obvious
candidate, but that is the maintainer's call to make when it is scheduled.

A self-contained static port of `reference/valuescardsort.jsx`, so the
instrument is usable by anyone with a browser without waiting for TestFlight.

## Ratified decisions (2026-08-29)

| # | Decision | Why |
|---|---|---|
| 1 | **One self-contained `index.html`, no build step.** React ported to vanilla JS. No bundler, no `node_modules`, no CDN. Pages serves `/web` from `main`. | SPEC §3 forbids app-target dependencies. A companion artifact that ships a supply chain would undercut the claim the native app makes. View-source is the whole program. |
| 2 | **PDF via print stylesheet + `window.print()`**, not a PDF library. | Zero bytes shipped; text stays selectable and screen-reader readable; honours the user's paper size. Cost: an OS dialog, and the filename is not ours to set. |
| 3 | **No persistence at all**, plus a `beforeunload` warning. | The guarantee stays absolute — nothing is ever written — while an accidental reload does not silently destroy twenty minutes of work. |
| 4 | **Deck generated from `data/deck.v1.json`.** | The deck contract exists to stop instrument drift. Two hand-copied decks reintroduce exactly the failure it prevents. |
| 5 | **Accessibility is a gate:** WCAG 2.2 AA, no exemptions, axe-core in CI. | The web analogue of D5. A promise that is not executed is not a gate — this repo has already been bitten twice by exactly that. |
| 6 | **JSON download mirrors the native `SessionState` schema.** | One schema documents both surfaces, and a web sort could later be opened natively. |
| 7 | **Backlogged behind F2.** | New scope answers "current sprint, or backlog?" — this one is backlog. |

## Carried over from already-ratified native decisions

These are not new calls; they are the same rulings applied to a second surface.

- **D4 — the export date is the completion time, not render time.** The
  reference stamps `new Date()` inside a `useMemo` at line 238, so re-rendering
  an old result misdates it. The web version captures completion once.
- **O2 — the `#AI/Claude` tag is dropped.** The reference emits it at the end of
  the markdown export. A Pages deployment is a public build, so O2 applies.
- **R1–R11 are the behavioural contract**, exactly as for the native app. The
  reference implementation is the pinned source for them.
- **GPL-3.0-or-later with SPDX headers**, and the instrument attribution stays
  in both the UI and every export.

## Scope

**In:** the full instrument — shuffle (R1), sort into the five contract piles
(R2), undo (R3), custom cards (R4), cull (R5, R6), rank (R7), export (R8),
reset with confirmation (R9), keyboard 1–5 and U (R11). Note Card styling only.
Markdown copy, JSON download, PDF print.

**Out:** themes beyond Note Card, session history, resume (R10 — there is no
persistence to resume from), any network call after the page loads.

## Architecture

```
web/
  index.html          markup + CSS + JS, one file
  deck.js             GENERATED from data/deck.v1.json — never hand-edited
scripts/generate_deck.py   gains a JS emitter beside the Swift one
```

Three `window.storage` touchpoints in the reference (lines 157, 169, 196) are
removed rather than reimplemented. The `useEffect` persistence hook at 166–170
disappears entirely.

## Tasks (when scheduled)

1. **Deck emitter** — extend `generate_deck.py` to write `web/deck.js`; add the
   regeneration check to `check-deck.sh` and CI so the web deck cannot drift.
2. **Port the state machine** — the four phases and R1–R11, vanilla JS, no
   framework. This is where the reference is the authority.
3. **Note Card face and desk surface** — port the ruled index card.
4. **Export surfaces** — markdown copy, JSON download (native schema), print
   stylesheet for PDF.
5. **Accessibility gate** — axe-core CI job across every phase, plus a
   keyboard-only traversal of a complete sort. Evidence in `docs/evidence/web/`.
6. **Pages deployment** — serve `/web` from `main`; no Actions build.
7. **Adversarial review** before it is called done.

## Risks

- **The state machine is the whole product.** A port that is 95% faithful is a
  different instrument. Rule-by-rule tests against the reference are not
  optional, and there is no XCTest here — the harness has to be built.
- **`beforeunload` is unreliable by design.** Browsers ignore it without prior
  interaction and style the prompt themselves. It is a courtesy, not a promise,
  and the UI should not imply otherwise.
- **Print output is browser-dependent.** The print stylesheet needs checking in
  at least Safari, Chrome and Firefox; page-break behaviour differs.
- **No persistence makes the sort fragile on mobile**, where tab eviction is
  routine. Worth stating plainly on the start screen.
