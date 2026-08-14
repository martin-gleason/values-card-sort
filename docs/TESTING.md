# Test plan (harness)

The harness makes drift impossible: every pinned rule in SPEC §5.2 gets a named test, CI runs them on every PR, and branch protection keeps red merges out of `main`.

## Layers

1. **Deck fidelity** (runs in CI without Xcode, and again in Swift Testing from the app bundle)
   - `deck.v1.json` parses; `cardCount == 83 == cards.count`; ids are 1…83 contiguous; names unique.
   - SHA-256 of the file equals the recorded hash in SPEC §4. Any diff fails.
2. **Rule tests** (Swift Testing, pure model layer — no UI)
   - One test (or group) per rule, named for it: `R1_shuffleIsCompletePermutation`, `R3_undoReturnsCardToFrontOfQueue`, `R5_cutCardsLandInVeryImportant`, `R6_cullGateRejectsUnder5AndOver10`, `R6_keptOrderIsSurvivorsThenPromotions`, `R8_exportMatchesGoldenFile`, `R10_midPhaseStateRoundTripsThroughPersistence`, etc.
   - R8 uses golden-file comparison: a fixture session → exact expected markdown.
3. **Snapshot tests** (test target only, F8) — card face per theme × light/dark × default and largest Dynamic Type size.
4. **Accessibility gate evidence** (per feature, before "done") — largest-Dynamic-Type screenshots both appearances; VoiceOver label audit of the screen's controls; documented in the PR.
5. **Privacy check** (CI grep) — app target contains no `URLSession`/`Network`/socket imports. Deterministic, not advisory.

## Commands

- Package/model tests: `swift test` (model layer lives in a local SPM package so rule tests run fast and CI-cheap).
- Full app tests: `xcodebuild test -scheme ValuesCardSort -destination <sim/mac>`.

A feature PR is mergeable when: rule tests for its Rs are green, fidelity green, privacy grep green, accessibility evidence attached, adversarial review logged.

-----
August 14, 2026

#AI/Claude
