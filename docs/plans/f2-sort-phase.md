# F2 — Sort phase

**Status:** planned, awaiting approval. **Branch:** `f2/sort-phase` (from `main`
once F1 merges).
Working doc — `docs/specs/SPEC.md` is the contract. This records how F2 is meant to
be executed and which calls have already been made.

## Scope

SPEC §10 gives F2 as "Sort phase (R1–R4, R9–R11)". R1 (shuffle) shipped in F1,
so the new rules are:

| Rule | What it means here |
|---|---|
| **R2** | One card at a time off the front of the queue, assigned to exactly one of five contract piles |
| **R3** | LIFO undo over sort history; the undone card returns to the **front** of the queue and leaves its pile |
| **R4** | User-written card, name required and uppercased, descriptor defaulting to "a value I wrote myself", inserted at the **front** of the queue |
| **R9** | Destroying an in-progress session requires explicit confirmation |
| **R10** | Resume mid-phase across launches — F1 shipped the store; F2 makes the *sort screen* resume exactly |
| **R11** | Hardware keyboard: 1–5 assign, U undoes. Full Keyboard Access on every screen |

**Out of scope:** R5/R6 (cull, F3), R7 (rank, F4), R8 (export, F5), the theme
engine (F8), the history list (F6). F2 ends at the queue-empty interstitial.

## Decisions already taken (2026-08-28, both ratified)

- **Card face: the standard lined index card (Note Card).** Other themes are
  built at F8. Note Card is already SPEC §5.3's default and a port of the
  reference implementation's ruled index card, so this is not throwaway work —
  F8 generalises it into the theme engine rather than replacing it. This is
  what stops F2 being blocked behind C5.
- **R2 interaction: five pile buttons**, as the reference does. Drag-to-pile and
  swipe were both rejected. Buttons are real controls, so 44pt targets,
  VoiceOver labels and R11's 1–5 keys fall out for free under D5; drag would
  need a bespoke accessible path for every drop target. Design boldness stays on
  the card face and desk surface per SPEC §3.1, not in the gesture.

## What F1 left for this gate

`SessionState` already carries every field F2 needs — `queue`, `piles`,
`history`, `customCards`, `currentCard`, `sortedCount`, `isWellFormed` — but it
has **no mutating operations**. F1 built the container; F2 builds the verbs.
That is the whole of F2-T1, and it lands in the rule package where it is
testable by `swift test` without a simulator.

## Tasks

### F2-T1 — Kit: the sort operations (R2, R3, R4)

Add to `ValuesCardSortKit`, pure and simulator-free:

- `mutating func assign(to pile: Pile)` — pops the front of the queue, appends
  to that pile, pushes a `SortMove`. Appending (not inserting) is load-bearing:
  R6 defines kept order as *Most important* order, so pile order is assignment
  order.
- `mutating func undo()` — pops the last `SortMove`, removes that card from its
  pile, pushes it back onto the **front** of the queue.
- `mutating func addCustomCard(name:descriptor:)` — uppercases and trims the
  name, defaults the descriptor, appends to `customCards`, inserts the new
  `CardID` at the **front** of the queue.

Every operation is a no-op on an empty queue / empty history rather than a trap,
matching the reference's guard clauses. `isWellFormed` must hold after each.

### F2-T2 — App: the sort screen and the Note Card face

- `SortView` — the card face, the five pile buttons, Undo, Add card, and the
  queue-empty interstitial.
- `NoteCardFace` — the lined index card. Ruled lines, the value name, the
  descriptor. This is the one place design lives.
- The interstitial is an explicit state *inside* the sort phase, matching
  `reference/valuescardsort.jsx:375–379`. That is what satisfies R4's "custom
  cards available during Sort, **including after the queue empties**": if the
  queue emptying advanced the phase automatically, that clause would be
  unimplementable. Its Continue button is a placeholder until F3.

### F2-T3 — R9 abandon and R10 resume

- Abandon flows through `SessionStore`'s existing explicit archive call (the
  F1 adversarial review already fixed this from being a side effect of a
  getter), behind a confirmation dialog.
- Resume restores the sort screen mid-queue, not merely the fact of a session.

### F2-T4 — R11 keyboard

1–5 and U on macOS and iPadOS, suppressed while a text field has focus (the
reference guards on `INPUT`/`TEXTAREA`; the native equivalent is focus state).
Full Keyboard Access is part of the §6 gate, not a separate nicety.

### F2-T5 — Accessibility gate, evidence, adversarial review

`performAccessibilityAudit()` at default **and** largest sizes, both
appearances, zero exemptions (D5). Screenshots into `docs/evidence/f2/`. Any
stock component that cannot pass gets a `docs/departures.md` entry with what was
tried (D7). Adversarial review before F2 is called done.

## Rule → test mapping

Each rule gets a named test, per SPEC §5.2.

| Rule | Test | Layer |
|---|---|---|
| R2 | `R2_assignmentMovesTheFrontCardIntoExactlyOnePile` | `swift test` |
| R2 | `R2_pileOrderIsAssignmentOrder` (guards R6) | `swift test` |
| R3 | `R3_undoIsLIFOAndReturnsTheCardToTheFront` | `swift test` |
| R3 | `R3_undoOnEmptyHistoryIsANoOp` | `swift test` |
| R4 | `R4_customCardGoesToTheFrontOfTheQueue` | `swift test` |
| R4 | `R4_customCardNameIsUppercasedAndDescriptorDefaults` | `swift test` |
| R9 | `R9_abandoningRequiresConfirmation` | UI test |
| R10 | `R10_resumeRestoresTheExactQueuePosition` | app test |
| R11 | `R11_numberKeysAssignAndUUndoes` | UI test |
| §6 | `test_A11y_sortScreen…` at both sizes | UI test (the gate) |

## Assumptions I am making rather than asking

State them so they are easy to overrule at review:

1. **Undo covers pile assignments only.** SPEC R3 says "LIFO over the *sort
   history*", and the reference records only placements. Adding a custom card is
   therefore not undoable, and undoing a placement does not remove a custom card
   added afterwards.
2. **A custom card counts toward the session total** once added —
   `cardsAddedAfterStart` already exists in `SessionState` for exactly this.
3. **The interstitial's Continue is inert in F2** and gets its destination in F3,
   the same way F1's root screen said "the sort screen arrives in F2".
4. **Pile buttons show `Pile.shortLabel`**, with the full contract label as the
   accessibility label — the five labels in SPEC R2 are contract and must not be
   paraphrased where they are read aloud.

## Risks

- **The §6 gate on a denser screen.** F1 needed a hand-built `GroupedSurface`
  because `List` could not pass a strict audit. The sort screen has more
  controls, and a five-button stack at AccessibilityXXXL is where Dynamic Type
  problems surface. Budget for at least one D7 departure.
- **The card face is the first real design surface in this app.** Everything
  before it was stock chrome. It must still pass contrast at both appearances.
