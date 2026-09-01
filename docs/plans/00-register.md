# Register — values-card-sort

**Reconstructed from this project's own documents, not authored.** Every row
names the file and line it came from. A row nobody can trace back is a claim,
and a claim written down reads exactly like a recorded fact.

A `Status` of `unknown` means the source said nothing about status. It is a
question for the owner, not a guess.

> **Defined in more than one place** — kept the first, reported the rest.
> Which is authoritative is not the agent's call.

> - `D1` also at `docs/specs/SPEC.md:36` — kept the first, at `docs/plans/spec-deltas.md:44`
> - `D2` also at `docs/specs/SPEC.md:37` — kept the first, at `docs/plans/spec-deltas.md:45`
> - `D3` also at `docs/specs/SPEC.md:38` — kept the first, at `docs/plans/spec-deltas.md:46`
> - `D4` also at `docs/specs/SPEC.md:39` — kept the first, at `docs/plans/spec-deltas.md:47`
> - `D5` also at `docs/specs/SPEC.md:40` — kept the first, at `docs/plans/spec-deltas.md:48`
> - `D6` also at `docs/specs/SPEC.md:41` — kept the first, at `docs/plans/spec-deltas.md:49`

---

## Decisions (D)

ADR-style: numbered, dated, **immutable once ratified**. A decision is never edited —
it is superseded by a later entry that links back. A rejected decision stays, struck
through, so it is not re-proposed.

**One intake path.** Anything that changes scope enters as a `D<n>`. An item with no
number has not been decided, however clearly it was said aloud.

| ID | Status | Milestone | Decision | Source |
|---|---|---|---|---|
| D1 | unknown | — | O1 closed: minimums are iOS/iPadOS 18, macOS 15, built against the Xcode 26 SDK. | `docs/plans/spec-deltas.md:44` |
| D2 | unknown | — | O2 closed: the #AI/Claude tag is dropped from the public build's export footer. Pins the R8 golden file. | `docs/plans/spec-deltas.md:45` |
| D3 | unknown | — | A card-payload hash pinned alongside the file hash. The file hash is self-invalidating — chore C1's sign-off edits instrument.verification i | `docs/plans/spec-deltas.md:46` |
| D4 | unknown | — | R8's export date is session.completedAt, not render-time "now"; the reference implementation misdates re-exports. The export body is locale  | `docs/plans/spec-deltas.md:47` |
| D5 | unknown | — | The accessibility gate has no exemptions. Every audit rule, every screen, default and largest content sizes; fix the view, never waive the r | `docs/plans/spec-deltas.md:48` |
| D6 | unknown | — | The deck is compiled into the binary, not bundled as JSON. An editable deck is a vector for harm; this app puts text in front of people at h | `docs/plans/spec-deltas.md:49` |
| D7 | unknown | — | SPEC §3.1 amended: stock components except where they fail the §6 gate. List cannot pass a strict audit — six issues survived every remedy t | `docs/plans/spec-deltas.md:50` |
| D8 | ratified | Web | SPEC §10 gains a second milestone, `Web`, holding the GitHub Pages port; IDs are milestone-qualified (`Web/F1`, `Web/F1-T3`) because the repo now carries two milestones at once. | `docs/plans/spec-deltas.md:51` |
| D9 | ratified | Web | Pages deploys via an Actions artifact upload of `web/`, superseding "serves `/web` from `main`, no Actions build" (2026-08-29) — branch-based Pages accepts only `/` or `/docs`, so that clause was never implementable. Verified live: `curl` returns HTTP 200, 44463 bytes, title "Personal Values Card Sort", 0 Jekyll references; `deck.js` HTTP 200 with 83 cards, identical to the repository's. | `docs/plans/spec-deltas.md:52` |
| D10 | ratified | MVP | Note Card's `ACCENT` splits into three measured tokens by role — `accentFill #C34F45`, `accentText #A04139`, `accentOnDesk #D1554A`. The reference's `#C75146` fails 4 of 10 pairs in the design handoff's own required contrast table, which nobody had run; the same token had already caused a live defect on the web. Note Card is appearance-independent, so no dark palette is owed. The table is now a gate: `scripts/check_theme_contrast.py`. | `docs/plans/spec-deltas.md:15` |
| D11 | proposed | MVP | Mucha theme definition sourced from the mothballed Mucha-Design-System: 9 of 9 pairs pass. Desk remapped to `violet.900 #251929` (its `bg.canvas→surface-1` is a 1.12:1 elevation step, not a desk); dark variant dropped on evidence (dark card on dark desk = 1.25:1, and no stock satisfies both constraints). Ornament, type and mocks still owed. Source repo has no LICENSE — provenance is the owner's call. | `docs/plans/spec-deltas.md:54` |

## Risks (RR)

| ID | Risk | Status | Likelihood | Impact | Mitigation | Owner | Source |
|---|---|---|---|---|---|---|---|

*(none found in this project's documents)*

## Owner items (O)

Outstanding items only the owner can close.

| ID | Item | P | Status | Source |
|---|---|---|---|---|

*(none found in this project's documents)*

## Chores (C)

`conventions.md`: *a chore gets a file only when it has tasks and a verification
step; a one-line chore lives in the register.* This is that register. A chore with
its own plan file is listed here too, with a link, so one read gives all of them —
the absence of that read is how a chore killed by a ratified delta stayed open for
days on the owner's track.

| ID | Chore | P | Status | Owner | Plan | Source | TD |
|---|---|---|---|---|---|---|---|
| C1 | Download both source PDFs into fixtures/, then review the agent's card-by-card verification and sign off | — | unknown | — | — | `docs/specs/SPEC.md:165` | td:6hPqwQqHqHCjgr9q |
| C2 | Apple Developer Program enrollment ($99/yr) | — | unknown | — | — | `docs/specs/SPEC.md:166` | td:6hPqwQw5gJvC4MpH |
| C3 | Create the GitHub repository; enable branch protection on main | — | done — repo exists and is public | — | — | `docs/specs/SPEC.md:167` |
| C4 | App Store Connect + TestFlight setup, beta review submission | — | unknown | — | — | `docs/specs/SPEC.md:168` | td:6hPqwR2h2wHHXrVH |
| C5 | Run the design session with docs/design/design-handoff-card-themes.md; bring back theme specs | — | unknown | — | — | `docs/specs/SPEC.md:169` | td:6hPqwR5v7GGW75jq |

## Gates (G)

A gate is an **event**, not a place — but the event has to be recorded somewhere or it
exists only in the conversation where it happened. It is not inferable from the
filesystem: the first attempt flagged six features as awaiting a gate and all six were
already built.

| ID | Gate | Status | Plan written | Crossed | What the owner said | Source |
|---|---|---|---|---|---|---|

*(none found in this project's documents)*

## Hooks (H)

Deterministic enforcement. Prose is advisory; hooks are not. An `H<n>` is a plan-local
label and **never appears in a commit, branch, or PR title**.

| ID | Hook | Surface | Protects | Status | Source |
|---|---|---|---|---|---|

*(none found in this project's documents)*

## Mutations (M)

Named ways to break the code, each paired with the test that must catch it.
A test is not evidence until a mutation proves it can fail.

| ID | File | Mutation | Caught by | Status | Source |
|---|---|---|---|---|---|
| M1 | `web/index.html` | S.piles[p].push(id);… | R2 a pile keeps assignment order | caught | `scripts/check_web_mutations.py` |
| M2 | `web/index.html` | S.queue.unshift(last.card);… | R3 undo returns the card to the FRONT | caught | `scripts/check_web_mutations.py` |
| M3 | `web/index.html` | S.queue.unshift(cid);… | R4 a written card is uppercased and goes to the front | caught | `scripts/check_web_mutations.py` |
| M4 | `web/index.html` | if (!n) return null;… | R4 a blank name is refused | caught | `scripts/check_web_mutations.py` |
| M5 | `web/index.html` | if (kept.length < 5 || kept.length > 10) return;… | R5 cull refuses to finish outside the 5-10 band | caught | `scripts/check_web_mutations.py` |
| M6 | `web/index.html` | return out.concat(draft.promotions);… | R6 promotion order is preserved into the kept set | caught | `scripts/check_web_mutations.py` |
| M7 | `web/index.html` | if (j < 0 || j >= S.ranking.length) return;… | R7 moving past either end is a no-op | caught | `scripts/check_web_mutations.py` |
| M8 | `web/index.html` | if (phase === "export" && S.completedAt === null) {… | R8 the export date is completion time | caught | `scripts/check_web_mutations.py` |
| M9 | `web/index.html` | s += "\n-----\n" + date + "\n";… | R8 the export drops the #AI/Claude tag | caught | `scripts/check_web_mutations.py` |
| M10 | `web/index.html` | var x = a.slice();… | R1 two sessions do not produce the same order | caught | `scripts/check_web_mutations.py` |
| M11 | `web/index.html` | S.history.push({ card: id, pile: p });… | the page touches no storage or network API | caught | `scripts/check_web_mutations.py` |
| M12 | `web/deck.js` | "to be accepted as I am"… | the page's deck is the generated one | caught | `scripts/check_web_mutations.py` |
| M13 | `web/index.html` | "Most important to me"… | R8 markdown carries every pile | caught | `scripts/check_web_mutations.py` |
| M14 | `web/index.html` | S.history.push({ card: id, pile: p });… | the page touches no storage or network API | caught | `scripts/check_web_mutations.py` |
| M15 | `web/index.html` | s += "\n## Full sort\n";
  for (var p = 4; p >= 0; p… | R8 the markdown export matches the golden file | caught | `scripts/check_web_mutations.py` |
| M16 | `web/index.html` | var ids = (p === 4) ? S.ranking : S.piles[p];
    if… | R8 the markdown export matches the golden file | caught | `scripts/check_web_mutations.py` |
| M17 | `web/index.html` | s += "Completed: " + date + "\n\n## Top values (rank… | R8 the markdown export matches the golden file | caught | `scripts/check_web_mutations.py` |
| M18 | `web/index.html` | s += "- " + c.name + " - " + c.descriptor + "\n";… | R8 the markdown export matches the golden file | caught | `scripts/check_web_mutations.py` |
| M19 | `web/index.html` | if (i === -1) return;            // state already ma… | R3 undo refuses to act on a malformed state | caught | `scripts/check_web_mutations.py` |
| M20 | `data/themes.v1.json` | Note Card's accent reverted to the reference's `#C75146` | theme contrast gate (fails exactly the 4 original pairs) | caught | `scripts/check_theme_contrast.py` |
| M21 | `data/themes.v1.json` | Mucha card stock darkened toward the desk | theme contrast gate (7 pairs) | caught | `scripts/check_theme_contrast.py` |

All 19 are executed by `python3 scripts/check_web_mutations.py`, which applies
each to a scratch copy of the tree and requires the suite to fail. The generated
register of them is `web/tests/mutations.md`. **This section read "(none found)"
while nineteen mutations existed in the repository** — the register was
reconstructed from documents, and these live in a script.

-----

#AI/Claude
