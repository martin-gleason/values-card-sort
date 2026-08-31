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

*(none found in this project's documents)*

-----

#AI/Claude
