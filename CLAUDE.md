# Values Card Sort: Digital Tool

Open-source SwiftUI multiplatform app (iOS/iPadOS 18+, macOS 15+) of the public-domain Personal Values Card Sort (Miller, C'de Baca, Matthews & Wilbourne, UNM 2001). Copyleft (GPL-3.0-or-later). This is a **tool, not a project**: small, finished, faithful.

@docs/conventions.md
@docs/conventions-local.md

## The contract

- `docs/specs/SPEC.md` is the ratified contract. You may **propose** spec deltas; the maintainer ratifies. You never edit the spec on your own authority.
- `data/deck.v1.json` is **immutable** after C1 sign-off. Never edit it. A deck change is a new versioned file + a ratified spec delta. It is a **build input**, not a bundled resource: the deck is compiled into Swift by `scripts/generate_deck.py` (D6). Never hand-edit the generated file. Two hashes plus a regeneration check plus a runtime check must stay green.
- `reference/valuescardsort.jsx` is the behavioral reference for phase rules R1–R11. When native idiom and reference behavior conflict, flag it — don't silently pick.

## Non-negotiable rules

- **Privacy:** no network code, no analytics, no third-party SDKs in the app target. Zero exceptions without ratification.
- **Accessibility is a gate with NO exemptions (D5):** no feature is done until its screens pass SPEC §6 (Dynamic Type at largest size, VoiceOver, 44pt targets, contrast, Reduce Motion). `performAccessibilityAudit()` runs at default and largest sizes; fix the view, never waive the rule. Show evidence in `docs/evidence/<feature>/`.
- **System-components-first:** stock SwiftUI chrome everywhere; all design boldness lives on the card face + desk surface. Themes never touch chrome. **Exception (SPEC §3.1, D7):** where a stock component fails the §6 audit, replace it with a system-coloured hand-built equivalent — and record it in `docs/departures.md` with what you tried and screenshots in `docs/evidence/`. An undocumented departure is a defect; `scripts/check-departures.sh` enforces it.
- **SPDX headers** (`GPL-3.0-or-later`) on every source file.
- **Verification, not assertion:** a feature is done when `xcodebuild test` (or `swift test` for the package) passes and you show the command + result.

## Workflow

1. **Session start / restart:** adversarial review of what shipped (`.claude/agents/adversarial-reviewer.md`) + re-read SPEC §10 feature list. Never resume blind.
2. **Plan under Ultrathink:** read the spec, batch clarifying questions, paraphrase back, then plan. Flag `Deep spec required:` in the plan summary when a gate is decision-dense (F8 theme engine is the likely candidate).
3. **Build under ultracode** unless the planning prompt says otherwise.
4. **Adversarial review** fires at the end of every feature, before it is called done.
5. **Gates need Marty's verbal yes.** Feature order: F1 → F2 → F3 → F4 → F5 → F6 → F7 → (F8 after C5) → F9 → F10. Chores C1–C5 run on the human track; F8 is blocked by C5, TestFlight by C2–C4.

## Decisions

Closed decisions stay closed. New scope gets the question: *current sprint, or backlog?*
