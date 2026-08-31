# F1 — Foundation (+ harness)

**Status:** built, awaiting gate. **Branch:** `f1/foundation`.
Working doc — `docs/specs/SPEC.md` is the contract; this records how F1 was executed
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
| `scripts/check-privacy.sh` | SPEC §7 — zero networking APIs, no network entitlement (own lexer tests in `scripts/test_check_privacy.py`) |
| `scripts/check-spdx.sh` | SPEC §8 — licence header on every source file |
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
- **Tests** — 28 package tests, 11 app tests, 6 UI tests, 27 privacy-lexer tests.

## Verification

All commands run, all output shown in the F1 PR.

Numbers below are post-review-fix.

| Command | Result |
|---|---|
| `python3 scripts/test_check_privacy.py` | 27 lexer checks pass |
| `scripts/check-deck.sh` | 8 checks pass |
| `scripts/check-privacy.sh` | 16 Swift files + 2 entitlement sources, clean, 1 declared exemption |
| `scripts/check-spdx.sh` | 26 of 26 source files carry the header |
| `swift test` | 28 tests, 4 suites, pass |
| `xcodebuild build` iOS Simulator + macOS | succeeded |
| `xcodebuild test` iOS Simulator | 11 unit + 6 UI, pass |
| `xcodebuild test` macOS | 11 unit, pass (UI blocked — see below) |

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

## Adversarial review (CLAUDE.md workflow step 4)

Run before calling F1 done. It found **11 findings** in work this document had
already reported as verified, which is the argument for the step. All fixed in
`6541fb4`; each fixed gate was re-tested against the exploit that beat it.

The three that mattered most:

1. **The privacy gate could be blinded for an entire file by one line.** A
   nested string inside `\(…)` interpolation was read as closing the outer
   string, so `"prefix \("/*") suffix"` opened a block comment that never
   closed and hid a real `URLSession` call further down. Reproduced, then the
   scanner was replaced with a context-stack lexer and given 27 tests of its
   own, including that exploit. TESTING.md layer 5 calls this gate
   "deterministic, not advisory" — it was advisory.
2. **`SessionStore.inProgress()` violated R9 from inside a getter.** It
   archived duplicate sessions by writing `completedAt` on the record while
   leaving the encoded blob saying `nil`, so the next ordinary
   read-modify-write un-archived it; and it permanently ended a live sort with
   no confirmation. Now a pure read, with archiving as an explicit call.
3. **CI could not have run the accessibility gate.** The iOS destination was
   pinned to `iPhone 16`, which does not exist under Xcode 26, and no Xcode
   version was selected. Since macOS UI tests wait on C2, that job is the only
   place SPEC §6 is enforced.

Also fixed: `#Unique` foreclosing the CloudKit door SPEC §3 requires stay open;
`Package.swift` documenting the deck symlink backwards (the exact configuration
that shipped an empty bundle); `try?` swallowing a decode failure the code
elsewhere insists must surface; `isWellFormed` not covering the fields F3/F4
will mutate; `fatalError` on store-open; a debug-only test flag live in release
builds; the SPDX gate covering only `.swift`; and a quadratic path.

Confirmed clean by the review: hash equivalence between the Python and Swift
canonical serializations (verified by execution against the real deck *and* an
adversarial Unicode fixture — precomposed vs decomposed, astral-plane, ZWJ,
BOM, CRLF, embedded quotes — both matching); deck immutability; layering
(zero SwiftData/SwiftUI in the rule package); scope (no F2–F10 leakage); and
R1/R10 fidelity against the reference implementation.

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
