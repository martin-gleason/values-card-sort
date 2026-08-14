# Contributing

Thanks for looking. This is a **tool, not a project**: small, finished, and
faithful to the printed instrument. The most useful contributions are ones that
make it more faithful, more accessible, or more private — not ones that make it
bigger.

## Licensing and distribution — read before you open a PR

Code and original art are **GPL-3.0-or-later**. By contributing you agree your
work is licensed the same way, and that **the maintainer distributes builds via
TestFlight and, later, the App Store**.

That last part matters and is why this note exists. Apple's distribution terms
and the GPL are in tension for projects with multiple copyright holders: the
maintainer can distribute his own GPL code through the App Store without
conflict, but he cannot grant Apple's terms over *your* copyright unless you
agree. Contributing here means you agree.

The instrument data (`data/deck.v*.json`) is **public domain** and stays that
way — the repo's copyleft covers code and original art only.

Every source file carries an SPDX header. CI enforces it:

```
// SPDX-License-Identifier: GPL-3.0-or-later
```

## Getting set up

```
brew install xcodegen        # build-time only; nothing links into the app
./scripts/bootstrap.sh       # compiles the deck + generates ValuesCardSort.xcodeproj
swift test                   # rule + deck tests, fast, no simulator
```

`ValuesCardSort.xcodeproj` is **generated and gitignored**. Edit `project.yml`
and re-run bootstrap; never commit a project file.

## The rules that are not negotiable

These are contract, not preference. A PR that breaks one will not merge.

- **Privacy (SPEC §7).** No network code, no analytics, no third-party SDKs in
  the app target. Zero exceptions without ratification. `scripts/check-privacy.sh`
  enforces it. Attribution *links* are fine — they open in the system browser.
- **The deck is immutable, and compiled in (SPEC §4).** `data/deck.v1.json` is a
  *build input*: `scripts/generate_deck.py` compiles it into Swift, and the app
  ships no loadable deck file. A deck change is a new versioned file plus a
  ratified spec delta. Four locks guard it — two pinned hashes, a regeneration
  check, and a runtime hash check the app enforces at launch. Do not edit the
  generated Swift; run `./scripts/generate-deck.sh`.

  This is deliberate hardening, not ceremony. The app puts text in front of
  people at hard moments, and a card altered to something cruel would be easy
  to miss in a large diff.
- **Accessibility is a gate, not a feature (SPEC §6).** No screen is done until
  it passes at the largest Dynamic Type size with VoiceOver, 44pt targets, and
  Reduce Motion honored. `Tests/ValuesCardSortUITests` runs the audit.
- **System-components-first (SPEC §3.1).** Stock SwiftUI chrome everywhere. All
  design boldness lives on the card face and desk surface. Themes never touch
  chrome.
- **Verification, not assertion.** "It works" is not a claim; a pasted command
  and its output is. Show them in the PR.

## The spec is the contract

`docs/SPEC.md` is ratified. You may **propose** changes — open an issue, or add
to `docs/plans/spec-deltas.md` — but the maintainer ratifies. Please don't
change behavior the spec pins (the five pile labels, the 5–10 cull range, the
export format) in a PR that is nominally about something else.

`reference/valuescardsort.jsx` is the behavioral reference for rules R1–R11.
Where native idiom and the reference conflict, **say so in the PR** rather than
quietly picking one.

## Before you open the PR

```
python3 scripts/test_check_privacy.py   # the privacy gate's own lexer tests
./scripts/check-deck.sh          # deck fidelity + regeneration
./scripts/check-privacy.sh       # no networking APIs
./scripts/check-spdx.sh          # licence headers
swift test                       # rules
xcodebuild test -scheme ValuesCardSort -destination 'platform=iOS Simulator,name=iPhone 16'
```

Conventional commits, `<type>(<id>): <description>` — e.g.
`feat(F2-T1): sort queue and pile assignment`. Branches are `<feature-id>/<slug>`.
Rebase-and-merge, no squash: every commit survives for audit.

## Scope

The roadmap in SPEC §9 is deliberate. Session compare is 1.1, "design your own
card" is 1.5, and the Schwartz PVQ-RR is out of scope entirely. New ideas are
welcome as issues, where they get the project's standing question: *current
sprint, or backlog?*

## A note on what this app is

It is a self-help tool, not a clinical service, and it is not affiliated with or
endorsed by the instrument's authors or the University of New Mexico. People use
it at hard moments in their lives. Please weigh changes with that in mind.

-----
August 14, 2026
