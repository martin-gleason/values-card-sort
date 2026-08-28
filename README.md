# Values Card Sort: Digital Tool

A free, open-source, native Apple app (iOS · iPadOS · macOS, one SwiftUI codebase) of the **Personal Values Card Sort** — W. R. Miller, J. C'de Baca, D. B. Matthews & P. L. Wilbourne, University of New Mexico, 2001, public domain.

Sort 83 value cards into five piles, keep your 5–10 most important, rank them, and export the result as markdown. Everything stays on your device: no accounts, no analytics, **no network connections at all**.

**Status:** F1 (foundation) built; F2 (sort phase) next. `docs/SPEC.md` is version 1.0-draft — the contract the build follows, with the open items in §11 tracked in `docs/plans/spec-deltas.md` until Marty ratifies them. Feature work proceeds gate by gate. See `docs/SPEC.md` (the contract), `docs/TESTING.md` (the test plan), `docs/plans/` (working docs), and `CLAUDE.md` (the standing rules).

## Building

```
brew install xcodegen        # build-time only; nothing links into the app
./scripts/bootstrap.sh       # compiles the deck + generates the Xcode project (gitignored)
swift test                   # deck fidelity + phase-rule tests, no simulator needed
```

Requires Xcode 26 or later. Targets iOS/iPadOS 18+ and macOS 15+. See `CONTRIBUTING.md`.

## Provenance

The instrument is public domain. Sources:

- https://motivationalinterviewing.org/personal-values-card-sort
- https://motivationalinterviewing.org/sites/default/files/valuescardsort_0.pdf
- https://casaa.unm.edu/assets/inst/personal-values-card-sort.pdf

This app adapts the paper instrument for digital use; deviations are documented in `docs/SPEC.md` §2.1. `data/deck.v1.json` carries the deck as a versioned, hash-pinned contract.

## License

Code and original art: **GPL-3.0-or-later** (see `LICENSE`). Instrument data: public domain, attributed. This app is a self-help tool, not a clinical service, and is not affiliated with or endorsed by the instrument's authors or the University of New Mexico.

-----
August 14, 2026

#AI/Claude
