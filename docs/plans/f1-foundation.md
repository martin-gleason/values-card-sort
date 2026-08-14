# F1 — Foundation (+ harness)

**Status:** built, awaiting gate. **Branch:** `f1/foundation`.
Working doc — `docs/SPEC.md` is the contract; this records how F1 was executed
and what it cost.

## Why this gate came first

SPEC §10 puts F1 first: "project scaffold, deck contract loader, SwiftData
session model, fidelity tests (R1 partial)". But the spec's harness was prose —
`docs/TESTING.md` described five test layers and `docs/conventions.md` named
`.github/workflows/ci.yml` as the enforcement surface, and none of it existed.
Neither did `data/deck.schema.json` (which `deck.v1.json` already pointed at),
`.claude/agents/adversarial-reviewer.md` (which CLAUDE.md's workflow requires at
steps 1 and 4), or a git repository.

So the harness was built first, then F1 on top of it.

## What shipped

### Harness

| Artifact | Enforces |
|---|---|
| `data/deck.schema.json` | the deck contract's shape; fixes the dangling `$schema` |
| `scripts/check-deck.sh` | SPEC §4 — schema, counts, contiguity, uniqueness, two hashes, resource parity |
| `scripts/check-privacy.sh` | SPEC §7 — zero networking APIs, no network entitlement |
| `scripts/check-spdx.sh` | SPEC §8 — licence header on every Swift file |
| `scripts/bootstrap.sh` | generates the Xcode project from `project.yml` |
| `.github/workflows/ci.yml` | all of the above plus both test suites, per PR |
| `.claude/agents/adversarial-reviewer.md` | the reviewer CLAUDE.md promises |

Every gate was **negative-tested** — each was shown to fail on the defect it
exists to catch, because a gate that cannot fail is decoration.

### F1

- **`ValuesCardSortKit`** — local SPM package, pure Swift. Deck model and
  validating loader; `Pile` (the five R2 contract labels); `CardID`
  (`deck(Int)` / `custom(UUID)`); `CustomCard`; `SessionState` (every SPEC §5.1
  field); `Shuffler` (R1, injected RNG) and a seeded generator for tests.
  No SwiftData, no SwiftUI — `swift test` needs no simulator.
- **App target** — one SwiftUI codebase for iOS, iPadOS and macOS, generated
  from `project.yml`. `SessionRecord` (SwiftData envelope around the Codable
  state) and `SessionStore` (at-most-one-in-progress, start/resume/complete/
  abandon). A stock-chrome shell that loads the deck, starts a sort, and shows
  a resumed session's exact position.
- **Tests** — 28 package tests, 8 app tests, 6 UI tests.

## Verification

All commands run, all output shown in the F1 PR.

| Command | Result |
|---|---|
| `scripts/check-deck.sh` | 8 checks pass |
| `scripts/check-privacy.sh` | 16 Swift files, 1 entitlements file, clean |
| `scripts/check-spdx.sh` | 17 of 17 files carry the header |
| `swift test` | 28 tests, 4 suites, pass |
| `xcodebuild build` iOS Simulator + macOS | succeeded |
| `xcodebuild test` iOS Simulator | 8 unit + 6 UI, pass |
| `xcodebuild test` macOS | 8 unit, pass (UI blocked — see below) |

## What the gates caught

Worth recording, because it is the argument for building them first:

1. **The bundled deck was a dangling symlink.** SwiftPM copies resource
   symlinks verbatim, so the built bundle contained a link to a relative path
   that no longer resolved — the app would have shipped with no deck at all.
   Caught by `DeckFidelityTests` failing, not by review. Fixed by inverting the
   link (see `spec-deltas.md` D6).
2. **A clipped label at accessibility sizes.** The start button's icon left too
   little room for its text at `AccessibilityXXXL`. Caught by
   `performAccessibilityAudit()`; invisible in code review.
3. **The privacy gate's own false positive.** Its first version flagged the word
   "CloudKit" inside comments explaining why the app avoids CloudKit. Rewritten
   to strip comments before matching — a gate that cries wolf is a gate people
   learn to ignore.

## Known limitations

- **macOS UI tests are blocked on chore C2.** macOS XCUITest requires a real
  signing identity: the runner app and the `.xctest` bundle must share a Team
  ID, so unsigned builds are refused and ad-hoc signing fails to load the
  bundle. The macOS app builds and its unit tests run; the SPEC §6 audit runs
  on iOS against the same SwiftUI views. Revisit at C2.
- **CI is authored but unexercised** until chore C3 creates the GitHub
  repository. The same checks run locally today via `scripts/`.
- **C1 is still pending** — the fixtures directory has no PDFs, so the
  card-by-card claim in SPEC §2 remains unverified. What *is* verified: the
  deck matches `reference/valuescardsort.jsx` exactly, with zero mismatches
  across all 83 names and descriptors.

## Open, needs Marty

Six deltas in `docs/plans/spec-deltas.md`. Four are ratified verbally and just
need transcribing into SPEC.md. **Two need a decision:**

- **D4** — R8's export date. The reference implementation stamps *today* rather
  than the session's completion date, and formats in the browser's locale.
  Native should use `completedAt`. Flagged, not silently resolved.
- **D5** — the accessibility-audit exemptions (`.contrast`, `.dynamicType` on
  stock chrome). A judgment call on a gate, which should not be made silently.

## Not in this gate

F2 sort UI · F3 cull · F4 rank · F5 export and the R8 golden file · F6 history ·
F7 custom cards across sessions · F8 themes (blocked by C5) · C1 verification ·
pushing to GitHub (C3).

-----
August 14, 2026

#AI/Claude
