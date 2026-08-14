# Harness + F1 Foundation — Values Card Sort: Digital Tool

## Context

`docs/SPEC.md` is a complete, well-formed contract, and `data/deck.v1.json` is verified faithful to the
reference implementation (83 cards, ids 1–83 contiguous, names unique, **zero** mismatches against
`reference/valuescardsort.jsx`, file SHA-256 matches SPEC §4). What does *not* exist is anything the spec
depends on to be enforceable: no git repo, no Xcode project, no Swift code, no CI, no
`data/deck.schema.json` (despite `$schema` pointing at it), no `.claude/agents/adversarial-reviewer.md`
(despite CLAUDE.md's workflow steps 1 and 4 requiring it).

So the harness is prose, not enforcement — exactly the drift CLAUDE.md and `docs/TESTING.md` exist to
prevent. This plan builds the enforcement surface first, then **F1** (SPEC §10: scaffold, deck contract
loader, SwiftData session model, fidelity tests, R1), leaving a repo that builds and tests on
iOS · iPadOS · macOS and fails CI on deck drift, network code, or a missing SPDX header.

Ratified verbally this session: **O1** iOS/iPadOS 18 + macOS 15 · **XcodeGen** project generation ·
**payload hash added** alongside the file hash · **O2** `#AI/Claude` dropped from the export footer.

Scope stops at F1. No sort UI (F2), cull (F3), rank (F4), export (F5), or themes (F8).

---

## Part A — Harness (unblocks everything)

### A1. Repository
- `git init` on `main`; baseline commit of the existing ratified docs; then work on branch `f1/foundation`.
- `.gitignore`: `.DS_Store`, `.build/`, `DerivedData/`, `*.xcodeproj` (generated), `.swiftpm/`, `xcuserdata/`.
- C3 (GitHub remote + branch protection) stays Marty's chore. CI is authored now, dormant until then.

### A2. `data/deck.schema.json`
JSON Schema (draft 2020-12) for the deck contract — fixes the dangling `$schema`. Pins: `deckVersion`,
`instrument` block, `cardCount`, and `cards[]` with `id` (integer ≥1), `name` (uppercase pattern),
`descriptor`, `additionalProperties: false`, `minItems`/`maxItems` 83, unique ids.

### A3. `scripts/` — the checks, runnable identically locally and in CI
| Script | Asserts |
|---|---|
| `check-deck.sh` | schema validation; `cardCount == cards.count == 83`; ids contiguous; names unique; file SHA-256 == SPEC §4 `13a3db92…6847ad8d`; **payload SHA-256 == `86ae6d89…c751037`**; deck resource symlink resolves to `data/deck.v1.json` |
| `check-privacy.sh` | no `URLSession`, `import Network`, `NWConnection`, `CFSocket`, `WKWebView`, `URLConnection` in app or package sources. Deliberately **not** a URL-string grep — SPEC §5.5 requires real attribution links via `Link`/`openURL`, which stay legal |
| `check-spdx.sh` | every `.swift` file carries `// SPDX-License-Identifier: GPL-3.0-or-later` |
| `bootstrap.sh` | `xcodegen generate` — the one command a fresh clone needs |

### A4. `.github/workflows/ci.yml`
Three jobs, per `docs/conventions.md`'s enforcement surface:
1. **contract** (ubuntu, cheap): `check-deck.sh` + `check-privacy.sh` + `check-spdx.sh`.
2. **package** (macOS): `swift test` — the pure rule layer, no Xcode project needed.
3. **app** (macOS): `bootstrap.sh` → `xcodebuild build` (iOS Simulator + macOS) → `xcodebuild test`.

### A5. `.claude/agents/adversarial-reviewer.md`
The reviewer CLAUDE.md already promises. Charter: re-read SPEC §5.2 rule-by-rule against the diff, hunt
for rule drift vs `reference/valuescardsort.jsx`, check the §6 accessibility gate and §7 privacy rule, and
report findings rather than fix them.

### A6. Docs
- `docs/plans/` created (your global rule: specs and plans in separate dirs) holding this plan as
  `docs/plans/f1-foundation.md`.
- `docs/plans/spec-deltas.md` — proposals awaiting ratification (below).
- `CONTRIBUTING.md` — the GPL-3.0-or-later / TestFlight contributor note SPEC §8 calls for.
- README fix: it currently claims the spec is "ratified" while SPEC's header says "awaiting ratification."
- `docs/decisions.md`: log the four decisions ratified this session.

### A7. Spec deltas (proposed; `docs/SPEC.md` edited only on your word)
1. **O1 closed** — iOS/iPadOS 18, macOS 15.
2. **O2 closed** — `#AI/Claude` dropped from the export footer.
3. **§4 payload hash** — assert both hashes. *Why:* C1 sign-off edits `instrument.verification` inside the
   deck file, so the file-hash test is self-invalidating by design. The payload hash survives it and keeps
   card drift failing forever.
4. **R8 date semantics** — the reference renders `new Date()` at export time in browser locale, so
   re-exporting an old session stamps *today's* date, non-deterministically. Native must use
   `session.completedAt`. This is a reference/native conflict, flagged not silently resolved.
5. **TESTING.md layer 4** — replace "evidence documented in the PR" with XCUITest
   `performAccessibilityAudit()` plus Dynamic Type launch arguments, making the a11y gate deterministic
   rather than prose. Screenshots remain, as evidence rather than as the check.

---

## Part B — F1 Foundation

### B1. `ValuesCardSortKit` — local SPM package, pure Swift
No SwiftData, no SwiftUI, so `swift test` stays fast and CI-cheap (per TESTING.md "Commands").

- `Deck/` — `ValueCard`, `Deck`, `DeckLoader` (loads the bundled JSON via `Bundle.module`).
  - Resource wiring: `Sources/ValuesCardSortKit/Resources/deck.v1.json` is a **symlink** to
    `data/deck.v1.json`. One true copy, preserving immutability; `check-deck.sh` guards the link.
- `Model/`
  - `Pile` — the five R2 contract labels, `CaseIterable`, ordered Not → Most.
  - `SessionPhase` — `.sort, .cull, .rank, .export`.
  - `CardID` — `enum { case deck(Int); case custom(UUID) }`. Replaces the reference's collision-prone
    `"c" + Date.now()`.
  - `CustomCard` — name (uppercased, required), descriptor (default *"a value I wrote myself"*).
  - `SessionState` — `Codable`, `Sendable`, value type, exactly SPEC §5.1's fields: `id`, `startedAt`,
    `completedAt`, `deckVersion`, `shuffleOrder` (immutable, R1), `queue`, `piles` (`[[CardID]]`, 5
    elements, subscripted by `Pile`), `history`, `cut`, `promotions` (ordered — R6 depends on it),
    `ranking`, `customCards`, `phase`, `themeID`.
  - Note: `shuffleOrder` and `queue` are stored separately. SPEC §5.1 asks for both the persisted shuffle
    and the live position; the reference conflates them by shrinking one array.
- `Rules/Shuffler.swift` — Fisher–Yates over an injected `RandomNumberGenerator`, so the app uses the
  system RNG and tests use a seeded `SplitMix64`.

### B2. App target — `ValuesCardSort`
`project.yml` (XcodeGen) defines one multiplatform SwiftUI target via `supportedDestinations: [iOS, macOS]`
(iPadOS rides with iOS), deployment iOS 18.0 / macOS 15.0, plus test and UI-test targets, linking the local
package. SPDX header on every file.

- `Persistence/SessionRecord.swift` — SwiftData `@Model` persisting the `Codable` `SessionState`. Kept a
  thin envelope so rule logic never depends on SwiftData, and so CloudKit stays possible later (SPEC §3).
- `Persistence/SessionStore.swift` — at most one in-progress session (SPEC §5.1); create / resume / archive.
- `App/` — minimal stock-SwiftUI shell that launches on all three platforms, loads the deck, reports the
  card count, and starts or resumes a session with a placeholder for the Sort phase. Deliberately thin:
  R9's confirm-to-destroy UI belongs to F2, not here.

### B3. Tests
**Package (`swift test`):**
- `DeckFidelityTests` — parses; `cardCount == 83 == cards.count`; ids contiguous; names unique; file hash;
  payload hash.
- `R1_shuffleIsCompletePermutation` — output is a permutation of all 83 + customs, no loss, no dupes.
- `R1_shuffleIsDeterministicUnderSeed` — seeded RNG reproduces an exact order.
- `R1_shuffleOrderIsFixedAtSessionStart` — `shuffleOrder` is unchanged by queue consumption.
- `R10_midPhaseStateRoundTripsThroughCodable` — a mid-cull fixture encodes and decodes identical.

**App (`xcodebuild test`):**
- `R10_midPhaseStateRoundTripsThroughSwiftData` — in-memory `ModelContainer`.
- `LaunchSmokeTest` — app launches on iOS sim and macOS.
- `A11y_launchScreenPassesAccessibilityAudit` — `performAccessibilityAudit()`, plus a run at
  `UICTContentSizeCategoryAccessibilityXXXL` via launch argument. First instance of the §6 gate as code.

### B4. Task/commit breakdown (branch `f1/foundation`, conventional commits, rebase-and-merge)
`chore(harness)` A1–A6 · `feat(F1-T1)` package + loader + fidelity · `feat(F1-T2)` session model + shuffler +
R1/R10 · `feat(F1-T3)` XcodeGen project + SwiftUI shell + SwiftData store · `test(F1-T4)` app + a11y tests ·
`docs(F1-T5)` review log + evidence.

---

## Verification (commands and results shown, not asserted)

```
scripts/check-deck.sh                # schema, counts, both hashes, symlink
scripts/check-privacy.sh             # zero networking APIs
scripts/check-spdx.sh                # headers on every .swift
swift test                           # deck fidelity + R1 + R10 (package)
scripts/bootstrap.sh                 # xcodegen generate
xcodebuild build -scheme ValuesCardSort -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild build -scheme ValuesCardSort -destination 'platform=macOS'
xcodebuild test  -scheme ValuesCardSort -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Then an **adversarial review** pass (CLAUDE.md workflow step 4) before F1 is called done, and largest-
Dynamic-Type screenshots in both appearances as §6 evidence.

CI itself cannot be *exercised* until C3 creates the GitHub repo — the workflow is authored now and the
same checks run locally today via `scripts/`, so nothing in the harness is unverified prose.

## Out of scope for this gate
F2 sort UI · F3 cull · F4 rank · F5 export and the R8 golden file · F6 history · F7 custom cards across
sessions · F8 themes (blocked by C5) · C1 PDF verification (fixtures absent) · pushing to GitHub (C3).
